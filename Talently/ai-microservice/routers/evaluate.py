"""Evaluation endpoints for SAP RAP integration and external clients."""

from datetime import datetime
import logging
import re
from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, status

from core.config import settings
from converters.gdrive_fetcher import (
    GDriveInvalidUrlError,
    GDriveAccessDeniedError,
    GDriveUnsupportedFormatError,
    GDriveError,
)
from data.transform import format_evaluation_to_csv_row, save_evaluation_to_csv
from models.request import (
    EvaluateUrlRequest,
    ScoreResponse,
    FullEvaluationResponse,
    CsvExportResponse,
)
from services.input_handler import process_resume_to_markdown
from services.resume_parser import ResumeParser
from services.github_enricher import GitHubEnricher
from services.scoring_engine import ScoringEngine

logger = logging.getLogger("sap_evaluator.router")

router = APIRouter(prefix="/evaluate", tags=["Evaluation"])


def _execute_pipeline(
    gdrive_url: Optional[str] = None,
    file_bytes: Optional[bytes] = None,
    filename: Optional[str] = None,
    github_url: Optional[str] = None,
    role_name: Optional[str] = None,
    model_name: Optional[str] = None,
    offer_info: Optional[str] = None,
) -> Dict[str, Any]:
    """Execute end-to-end resume evaluation pipeline.

    1. Fetches/converts file to Markdown (from Google Drive link or raw upload).
    2. Parses 6 resume sections into JSONResume via LLM.
    3. Enriches candidate with GitHub repos & README analysis.
    4. Evaluates resume against target role rubric and computes final score.
    """
    try:
        # Step 1: Input handling & format conversion
        markdown_text, meta = process_resume_to_markdown(
            gdrive_url=gdrive_url, file_bytes=file_bytes, filename=filename
        )
    except GDriveAccessDeniedError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": "GDRIVE_ACCESS_DENIED", "message": str(e)},
        )
    except GDriveUnsupportedFormatError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "UNSUPPORTED_FORMAT", "message": str(e)},
        )
    except (GDriveInvalidUrlError, GDriveError, ValueError) as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "INPUT_PROCESSING_FAILED", "message": str(e)},
        )

    # Step 2: Resume parsing into JSONResume
    try:
        parser = ResumeParser(model_name=model_name)
        resume = parser.parse_resume(markdown_text)
    except Exception as e:
        logger.error(f"Error during resume parsing: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "RESUME_PARSING_FAILED", "message": str(e)},
        )

    # Step 3: Extract and enrich GitHub profile completely automatically
    resolved_github_url = github_url

    # Check 1: Extracted social profiles in resume
    if not resolved_github_url and resume.basics and resume.basics.profiles:
        for prof in resume.basics.profiles:
            net = (prof.network or "").lower()
            if net == "github" or "github.com" in (prof.url or ""):
                resolved_github_url = prof.url
                break

    # Check 2: Main website/portfolio URL
    if not resolved_github_url and resume.basics and resume.basics.url:
        if "github.com" in resume.basics.url:
            resolved_github_url = resume.basics.url

    # Check 3: Project repository URLs in resume
    if not resolved_github_url and resume.projects:
        for proj in resume.projects:
            if proj.url and "github.com/" in proj.url:
                resolved_github_url = proj.url
                break

    # Check 4: Regex scan across raw resume markdown text
    if not resolved_github_url:
        gh_match = re.search(r"https?://(?:www\.)?github\.com/([a-zA-Z0-9_-]+)", markdown_text)
        if gh_match:
            user_found = gh_match.group(1)
            if user_found.lower() not in {"topics", "trending", "explore", "settings", "orgs"}:
                resolved_github_url = f"https://github.com/{user_found}"

    if resolved_github_url:
        logger.info(f"Automatically extracted candidate GitHub URL: {resolved_github_url}")
    else:
        logger.info("No GitHub link detected in resume; proceeding with resume data only.")

    # Step 4: Initialize scoring engine early so we can access role position_title
    try:
        engine = ScoringEngine(role_name=role_name, model_name=model_name)
    except Exception as e:
        logger.error(f"Scoring engine initialization failure: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "SCORING_FAILED", "message": str(e)},
        )

    github_data = {}
    if resolved_github_url:
        try:
            enricher = GitHubEnricher(model_name=model_name)
            github_data = enricher.enrich_candidate(
                resolved_github_url,
                position_title=engine.role.position_title,
            )
        except Exception as e:
            logger.warning(f"GitHub enrichment failed, continuing without GitHub data: {e}")

    # Step 5: Scoring evaluation
    try:
        result = engine.evaluate(
            resume,
            github_data=github_data,
            offer_info=offer_info,
        )
        result["resolved_github_url"] = resolved_github_url
        result["github_data"] = github_data
        result["engine"] = engine
        return result
    except Exception as e:
        logger.error(f"Scoring engine failure: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "SCORING_FAILED", "message": str(e)},
        )


@router.post(
    "/score",
    response_model=ScoreResponse,
    summary="Get concise evaluation score for SAP RAP application",
    description="Takes a Google Drive link and optional job offer info, evaluates the candidate, and returns a concise score and recommendation tailored for SAP RAP.",
)
def evaluate_score_for_rap(request: EvaluateUrlRequest):
    """Endpoint tailored for SAP RAP integration.

    RAP passes the Google Drive URL of the candidate's resume and receives the
    overall score, percentage, and recommendation.
    """
    logger.info(f"Received RAP evaluation request for GDrive URL: {request.gdrive_url}")
    result = _execute_pipeline(
        gdrive_url=request.gdrive_url,
        github_url=request.github_url,
        role_name=request.role,
        model_name=request.model_name,
        offer_info=request.offer_info,
    )

    return ScoreResponse(
        status="success",
        candidate_name=result["candidate_name"],
        score=result["final_score"],
        max_score=result["max_score"],
        percentage=result["percentage"],
        recommendation=result["recommendation"],
        role=result["role"],
        key_strengths=result.get("key_strengths", []),
        areas_for_improvement=result.get("areas_for_improvement", []),
    )


@router.post(
    "/full",
    response_model=FullEvaluationResponse,
    summary="Get complete evaluation breakdown",
    description="Returns detailed category scores, evidence, deductions, bonus breakdown, and GitHub repository analysis.",
)
def evaluate_full(request: EvaluateUrlRequest):
    """Complete evaluation endpoint returning full breakdown."""
    logger.info(f"Received full evaluation request for GDrive URL: {request.gdrive_url}")
    result = _execute_pipeline(
        gdrive_url=request.gdrive_url,
        github_url=request.github_url,
        role_name=request.role,
        model_name=request.model_name,
        offer_info=request.offer_info,
    )

    github_profile = result.get("github_data", {}).get("profile")
    top_projects = result.get("github_data", {}).get("projects")

    return FullEvaluationResponse(
        status="success",
        candidate_name=result["candidate_name"],
        role=result["role"],
        final_score=result["final_score"],
        max_score=result["max_score"],
        percentage=result["percentage"],
        recommendation=result["recommendation"],
        scores=result["scores"],
        bonus_points=result["bonus_points"],
        deductions=result["deductions"],
        key_strengths=result["key_strengths"],
        areas_for_improvement=result["areas_for_improvement"],
        github_profile=github_profile,
        top_projects=top_projects,
        evaluation_timestamp=datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
    )


@router.post(
    "/csv",
    response_model=CsvExportResponse,
    summary="Evaluate resume and export record to CSV",
    description="Evaluates the resume from Google Drive and appends the complete record to the persistent evaluations CSV file.",
)
def evaluate_and_export_csv(request: EvaluateUrlRequest):
    """Evaluates the resume and saves a row to CSV file on disk."""
    logger.info(f"Received CSV export evaluation request for GDrive URL: {request.gdrive_url}")
    result = _execute_pipeline(
        gdrive_url=request.gdrive_url,
        github_url=request.github_url,
        role_name=request.role,
        model_name=request.model_name,
        offer_info=request.offer_info,
    )

    csv_row = format_evaluation_to_csv_row(
        evaluation=result["raw_evaluation"],
        role=result["engine"].role,
        candidate_name=result["candidate_name"],
        final_score=result["final_score"],
        github_url=result.get("resolved_github_url"),
    )

    csv_path = settings.CSV_EXPORT_PATH
    total_records = save_evaluation_to_csv(csv_path, csv_row)

    return CsvExportResponse(
        status="success",
        message=f"Evaluation for '{result['candidate_name']}' successfully exported to CSV.",
        csv_file=csv_path,
        total_records=total_records,
        saved_record=csv_row,
    )


@router.post(
    "/upload",
    response_model=FullEvaluationResponse,
    summary="Upload resume file directly (PDF, DOCX, TXT, MD)",
    description="Alternative endpoint for testing or direct file submission via multipart/form-data.",
)
async def evaluate_direct_file_upload(
    file: UploadFile = File(...),
    role: str = Form("software_engineering_intern"),
    github_url: Optional[str] = Form(None),
    model_name: Optional[str] = Form(None),
    offer_info: Optional[str] = Form(None),
):
    """Upload a resume file directly without Google Drive."""
    content = await file.read()
    filename = file.filename or "resume.pdf"
    logger.info(f"Received direct file upload: {filename} ({len(content)} bytes)")

    result = _execute_pipeline(
        gdrive_url=None,
        file_bytes=content,
        filename=filename,
        github_url=github_url,
        role_name=role,
        model_name=model_name,
        offer_info=offer_info,
    )

    github_profile = result.get("github_data", {}).get("profile")
    top_projects = result.get("github_data", {}).get("projects")

    return FullEvaluationResponse(
        status="success",
        candidate_name=result["candidate_name"],
        role=result["role"],
        final_score=result["final_score"],
        max_score=result["max_score"],
        percentage=result["percentage"],
        recommendation=result["recommendation"],
        scores=result["scores"],
        bonus_points=result["bonus_points"],
        deductions=result["deductions"],
        key_strengths=result["key_strengths"],
        areas_for_improvement=result["areas_for_improvement"],
        github_profile=github_profile,
        top_projects=top_projects,
        evaluation_timestamp=datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
    )
