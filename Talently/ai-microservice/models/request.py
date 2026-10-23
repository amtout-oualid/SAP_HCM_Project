"""API Request and Response schemas for FastAPI endpoints."""

from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, HttpUrl


class EvaluateUrlRequest(BaseModel):
    """Payload for evaluating a resume via Google Drive link.
    
    Used by SAP RAP application and external REST clients.
    """
    gdrive_url: str = Field(
        ...,
        description="Public Google Drive URL to candidate resume (PDF, DOCX, TXT, or MD)",
        examples=["https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/view"]
    )
    github_url: Optional[str] = Field(
        None,
        description="Optional GitHub profile URL. If omitted, parsed automatically from resume.",
        examples=["https://github.com/octocat"]
    )
    role: Optional[str] = Field(
        "software_engineering_intern",
        description="Evaluation role name matching a directory in roles/",
        examples=["software_engineering_intern"]
    )
    model_name: Optional[str] = Field(
        None,
        description="Override default LLM model configured in .env",
        examples=["gpt-4o-mini", "gpt-4o"]
    )
    offer_info: Optional[str] = Field(
        None,
        description="Single comprehensive string containing the job offer title, description, and requirements.",
        examples=["SAP Software Engineering Intern - Cloud & ABAP. Requirements: Strong proficiency in Python, REST APIs, Git, relational databases, clean code practices, and enthusiasm for enterprise software."]
    )


class ScoreResponse(BaseModel):
    """Concise scoring response tailored for direct SAP RAP integration."""
    status: str = "success"
    candidate_name: str
    score: float = Field(..., description="Final overall score achieved")
    max_score: float = Field(..., description="Maximum possible base score")
    percentage: float = Field(..., description="Percentage relative to max base score")
    recommendation: str = Field(..., description="STRONG_HIRE, HIRE, CONSIDER, or DO_NOT_HIRE")
    role: str
    key_strengths: List[str] = Field(default_factory=list)
    areas_for_improvement: List[str] = Field(default_factory=list)


class FullEvaluationResponse(BaseModel):
    """Comprehensive evaluation breakdown with all categories, evidence, and GitHub data."""
    status: str = "success"
    candidate_name: str
    role: str
    final_score: float
    max_score: float
    percentage: float
    recommendation: str
    scores: Dict[str, Dict[str, Any]]
    bonus_points: Dict[str, Any]
    deductions: Dict[str, Any]
    key_strengths: List[str]
    areas_for_improvement: List[str]
    github_profile: Optional[Dict[str, Any]] = None
    top_projects: Optional[List[Dict[str, Any]]] = None
    evaluation_timestamp: str


class CsvExportResponse(BaseModel):
    """Response returned when evaluation is exported/appended to CSV."""
    status: str = "success"
    message: str
    csv_file: str
    total_records: int
    saved_record: Dict[str, Any]


class RoleInfo(BaseModel):
    """Metadata regarding an available evaluation role."""
    name: str
    position_title: str
    categories: List[Dict[str, Any]]
    bonus_max: int
    max_final_score: int


class RoleListResponse(BaseModel):
    """Response containing available roles."""
    available_roles: List[RoleInfo]


class HealthResponse(BaseModel):
    """Microservice health check status."""
    status: str = "healthy"
    version: str = "1.0.0"
    service: str = "sap-evaluator-api"
    default_model: str
    default_role: str
