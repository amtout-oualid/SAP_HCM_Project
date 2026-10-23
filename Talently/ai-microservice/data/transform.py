"""Data normalization, prompt text converters, and CSV export utilities."""

import csv
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime

from models.resume import JSONResume


def extract_domain_from_url(url: str) -> str:
    try:
        if "://" in url:
            url = url.split("://")[1]
        domain = url.split("/")[0]
        if domain.startswith("www."):
            domain = domain[4:]
        return domain
    except Exception:
        return ""


def get_network_name(domain: str) -> str:
    domain_mapping = {
        "github.com": "GitHub",
        "linkedin.com": "LinkedIn",
        "leetcode.com": "LeetCode",
        "stackoverflow.com": "Stack Overflow",
        "hackerrank.com": "HackerRank",
        "behance.net": "Behance",
        "dev.to": "DEV Community",
        "twitter.com": "X",
        "x.com": "X",
    }
    return domain_mapping.get(domain, "")


def extract_username_from_url(url: str, domain: str) -> str:
    try:
        path = url.split(domain)[1] if domain in url else ""
        if not path:
            return ""
        path = path.lstrip("/")
        parts = [part for part in path.split("/") if part]
        if parts:
            if domain == "linkedin.com" and len(parts) > 1:
                return parts[1]
            elif domain == "stackoverflow.com" and len(parts) > 2:
                return parts[2]
            else:
                return parts[0]
        return ""
    except Exception:
        return ""


def transform_basics(basics_data: Dict) -> Dict:
    if not isinstance(basics_data, dict):
        return basics_data

    profiles = basics_data.get("profiles", [])
    transformed_profiles = []
    if isinstance(profiles, list):
        for profile in profiles:
            if isinstance(profile, dict):
                transformed_profile = profile.copy()
                url = transformed_profile.get("url", "")
                network = transformed_profile.get("network")

                if url and network is None:
                    domain = extract_domain_from_url(url)
                    network_name = get_network_name(domain)
                    if network_name:
                        transformed_profile["network"] = network_name
                        username = extract_username_from_url(url, domain)
                        if username:
                            transformed_profile["username"] = username
                transformed_profiles.append(transformed_profile)

    basics_data["profiles"] = transformed_profiles
    return basics_data


def transform_work_experience(work_list: List) -> List[Dict]:
    transformed = []
    if not isinstance(work_list, list):
        return transformed
    for item in work_list:
        if isinstance(item, dict):
            description = item.get("description", "")
            if isinstance(description, list):
                description = " ".join(description)

            transformed.append(
                {
                    "name": item.get("name", ""),
                    "position": item.get(
                        "position", item.get("type", item.get("title", ""))
                    ),
                    "url": item.get("url", None),
                    "startDate": item.get("startDate"),
                    "endDate": item.get("endDate"),
                    "summary": item.get("summary", description),
                    "highlights": item.get("highlights", []),
                }
            )
    return transformed


def transform_organizations(org_list: List) -> List[Dict]:
    transformed = []
    if not isinstance(org_list, list):
        return transformed
    for item in org_list:
        if isinstance(item, dict):
            transformed.append(
                {
                    "organization": item.get("name", ""),
                    "position": item.get("role", ""),
                    "url": item.get("url", None),
                    "startDate": None,
                    "endDate": "Present",
                    "summary": None,
                    "highlights": [],
                }
            )
    return transformed


def transform_education(edu_list: List) -> List[Dict]:
    transformed = []
    if not isinstance(edu_list, list):
        return transformed
    for item in edu_list:
        if isinstance(item, dict):
            score = item.get("score", item.get("gpa", item.get("percentage", None)))
            if score is not None:
                score = str(score)

            transformed.append(
                {
                    "institution": item.get("institution", item.get("name", "")),
                    "url": item.get("url", None),
                    "area": item.get("area", item.get("major", item.get("degree", ""))),
                    "studyType": item.get("studyType", item.get("degree", "")),
                    "startDate": item.get("startDate"),
                    "endDate": item.get("endDate"),
                    "score": score,
                    "courses": item.get("courses", []),
                }
            )
    return transformed


def transform_skills_comprehensive(parsed_data: Dict) -> List[Dict]:
    skills = []
    raw_skills = parsed_data.get("skills", [])
    if isinstance(raw_skills, list):
        for s in raw_skills:
            if isinstance(s, dict):
                skills.append({
                    "name": s.get("name", ""),
                    "level": s.get("level", None),
                    "keywords": s.get("keywords", [])
                })
            elif isinstance(s, str):
                skills.append({
                    "name": s,
                    "level": None,
                    "keywords": []
                })
    return skills


def transform_projects_comprehensive(parsed_data: Dict) -> List[Dict]:
    projects = []
    raw_projects = parsed_data.get("projects", parsed_data.get("projectsOpenSource", []))
    if isinstance(raw_projects, list):
        for p in raw_projects:
            if isinstance(p, dict):
                projects.append({
                    "name": p.get("name", ""),
                    "startDate": p.get("startDate", None),
                    "endDate": p.get("endDate", None),
                    "description": p.get("description", ""),
                    "highlights": p.get("highlights", []),
                    "url": p.get("url", None),
                    "technologies": p.get("technologies", []),
                    "skills": p.get("skills", []),
                })
    return projects


def transform_achievements(awards_data: Any) -> List[Dict]:
    transformed = []
    if isinstance(awards_data, list):
        for item in awards_data:
            if isinstance(item, dict):
                transformed.append({
                    "title": item.get("title", item.get("name", "")),
                    "date": item.get("date", None),
                    "awarder": item.get("awarder", None),
                    "summary": item.get("summary", item.get("description", None)),
                })
            elif isinstance(item, str):
                transformed.append({
                    "title": item,
                    "date": None,
                    "awarder": None,
                    "summary": item,
                })
    return transformed


def transform_parsed_data(parsed_data: Dict) -> Dict:
    """Normalize parsed section JSON into standard schema."""
    try:
        if not isinstance(parsed_data, dict):
            return parsed_data

        if "basics" in parsed_data and len(parsed_data) > 1:
            return {
                "basics": transform_basics(parsed_data.get("basics", {})),
                "work": transform_work_experience(parsed_data.get("work", parsed_data.get("work_experience", []))),
                "volunteer": transform_organizations(parsed_data.get("organizations", parsed_data.get("volunteer", []))),
                "education": transform_education(parsed_data.get("education", [])),
                "awards": transform_achievements(parsed_data.get("awards", parsed_data.get("achievements", []))),
                "certificates": parsed_data.get("certificates", []),
                "publications": parsed_data.get("publications", []),
                "skills": transform_skills_comprehensive(parsed_data),
                "languages": parsed_data.get("languages", []),
                "interests": parsed_data.get("interests", []),
                "references": parsed_data.get("references", []),
                "projects": transform_projects_comprehensive(parsed_data),
                "meta": parsed_data.get("meta", {}),
            }
        else:
            if "basics" in parsed_data:
                return {"basics": transform_basics(parsed_data.get("basics", {}))}
            elif "work" in parsed_data or "work_experience" in parsed_data:
                return {"work": transform_work_experience(parsed_data.get("work", parsed_data.get("work_experience", [])))}
            elif "education" in parsed_data:
                return {"education": transform_education(parsed_data.get("education", []))}
            elif "skills" in parsed_data:
                return {"skills": transform_skills_comprehensive(parsed_data)}
            elif "projects" in parsed_data:
                return {"projects": transform_projects_comprehensive(parsed_data)}
            elif "awards" in parsed_data:
                return {"awards": transform_achievements(parsed_data.get("awards", []))}
            return parsed_data
    except Exception as e:
        return parsed_data


def convert_json_resume_to_text(resume_data: JSONResume) -> str:
    """Format JSONResume object into human-readable text block for LLM evaluation."""
    text_parts = []

    if resume_data.basics:
        basics = resume_data.basics
        # Fairness: name, e-mail, phone and location are not sent to the scoring model
        text_parts.append("=== BASIC INFORMATION ===")
        text_parts.append(f"Website: {basics.url or 'Not provided'}")

        if basics.summary:
            text_parts.append(f"Summary: {basics.summary}")

        if basics.profiles:
            text_parts.append("Profiles:")
            for profile in basics.profiles:
                text_parts.append(f"  - {profile.network}: {profile.username or 'N/A'} ({profile.url})")

    if resume_data.work:
        text_parts.append("\n=== WORK EXPERIENCE ===")
        for i, work in enumerate(resume_data.work, 1):
            text_parts.append(f"{i}. {work.position or 'Role'} at {work.name or 'Company'}")
            text_parts.append(f"   Period: {work.startDate or 'N/A'} - {work.endDate or 'Present'}")
            if work.url:
                text_parts.append(f"   Website: {work.url}")
            if work.summary:
                text_parts.append(f"   Description: {work.summary}")
            if work.highlights:
                text_parts.append("   Key Achievements:")
                for h in work.highlights:
                    text_parts.append(f"     • {h}")

    if resume_data.education:
        text_parts.append("\n=== EDUCATION ===")
        for i, edu in enumerate(resume_data.education, 1):
            # Fairness: the institution name and the grades are not sent to the scoring model
            text_parts.append(f"{i}. {edu.studyType or 'Degree'} in {edu.area or 'Field'}")
            text_parts.append(f"   Period: {edu.startDate or 'N/A'} - {edu.endDate or 'N/A'}")
            if edu.courses:
                text_parts.append(f"   Courses: {', '.join(edu.courses)}")

    if resume_data.skills:
        text_parts.append("\n=== SKILLS ===")
        for skill in resume_data.skills:
            kw_str = f" ({', '.join(skill.keywords)})" if skill.keywords else ""
            level_str = f" [{skill.level}]" if skill.level else ""
            text_parts.append(f"• {skill.name}{level_str}{kw_str}")

    if resume_data.projects:
        text_parts.append("\n=== PROJECTS ===")
        for i, project in enumerate(resume_data.projects, 1):
            text_parts.append(f"{i}. {project.name or 'Project'}")
            if project.startDate and project.endDate:
                text_parts.append(f"   Period: {project.startDate} - {project.endDate}")
            if project.description:
                text_parts.append(f"   Description: {project.description}")
            if project.url:
                text_parts.append(f"   URL: {project.url}")
            if project.technologies:
                text_parts.append(f"   Technologies: {', '.join(project.technologies)}")
            if project.highlights:
                text_parts.append("   Highlights:")
                for h in project.highlights:
                    text_parts.append(f"     • {h}")

    if resume_data.awards:
        text_parts.append("\n=== AWARDS ===")
        for award in resume_data.awards:
            awarder = f" - {award.awarder}" if award.awarder else ""
            date_str = f" ({award.date})" if award.date else ""
            text_parts.append(f"• {award.title}{awarder}{date_str}")
            if award.summary:
                text_parts.append(f"  {award.summary}")

    if resume_data.certificates:
        text_parts.append("\n=== CERTIFICATES ===")
        for cert in resume_data.certificates:
            issuer = f" - {cert.issuer}" if cert.issuer else ""
            text_parts.append(f"• {cert.name}{issuer}")

    if resume_data.volunteer:
        text_parts.append("\n=== VOLUNTEER EXPERIENCE ===")
        for v in resume_data.volunteer:
            text_parts.append(f"• {v.position or 'Volunteer'} at {v.organization or 'Organization'}")

    return "\n".join(text_parts)


def convert_github_data_to_text(github_data: Dict[str, Any]) -> str:
    """Format GitHub profile, repository data, and README content into text block for evaluation."""
    if not github_data:
        return "\n\n=== GITHUB DATA ===\nNo GitHub profile or repository data available."

    lines = ["\n\n=== GITHUB DATA ==="]

    if "profile" in github_data and github_data["profile"]:
        p = github_data["profile"]
        lines.append("GitHub Profile:")
        lines.append(f"- Username: {p.get('username', 'N/A')}")
        lines.append(f"- Bio: {p.get('bio', 'N/A')}")  # the real name of the profile is not sent (fairness)
        lines.append(f"- Public Repositories: {p.get('public_repos', 'N/A')}")
        lines.append(f"- Followers: {p.get('followers', 'N/A')}")
        lines.append(f"- Following: {p.get('following', 'N/A')}")

    projects = github_data.get("projects", [])
    if projects:
        lines.append(f"\nGitHub Projects Selected for Evaluation ({len(projects)} repos):")
        for i, proj in enumerate(projects, 1):
            lines.append(f"\n{i}. Repository: {proj.get('name', 'N/A')}")
            lines.append(f"   Description: {proj.get('description', 'No description provided')}")
            lines.append(f"   URL: {proj.get('github_url', 'N/A')}")
            lines.append(f"   Project Type: {proj.get('project_type', 'self_project')}")
            
            details = proj.get("github_details", {})
            if details:
                lines.append(f"   Stars: {details.get('stars', 0)} | Forks: {details.get('forks', 0)} | Language: {details.get('language', 'N/A')}")
                lines.append(f"   Contributors: {details.get('contributors', 1)} | Commits by candidate: {proj.get('author_commit_count', 0)}")
            
            # Inject README.md content or alert
            readme_excerpt = proj.get("readme_content")
            if readme_excerpt and readme_excerpt.strip():
                lines.append("   README.md Analysis:")
                lines.append("   " + "-" * 40)
                # Indent readme lines
                for rline in readme_excerpt.strip().split("\n"):
                    lines.append(f"   {rline}")
                lines.append("   " + "-" * 40)
            else:
                lines.append("   README.md Analysis: [NO USEFUL README PROVIDED - Lacks documentation]")

    return "\n".join(lines)


def format_evaluation_to_csv_row(
    evaluation: Any,
    role: Any,
    candidate_name: str,
    final_score: float,
    github_url: Optional[str] = None
) -> Dict[str, Any]:
    """Convert an EvaluationData object into a flat row for CSV writing."""
    row: Dict[str, Any] = {
        "timestamp": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
        "candidate_name": candidate_name,
        "role": role.name,
        "final_score": round(final_score, 1),
        "max_score": sum(c.max for c in role.categories),
        "github_url": github_url or "N/A",
    }

    # Add each category score and evidence
    if hasattr(evaluation, "scores") and evaluation.scores:
        scores_dump = evaluation.scores.model_dump()
        for cat in role.categories:
            cat_data = scores_dump.get(cat.key, {})
            row[f"score_{cat.key}"] = cat_data.get("score", 0)
            row[f"max_{cat.key}"] = cat_data.get("max", cat.max)
            row[f"evidence_{cat.key}"] = cat_data.get("evidence", "")

    # Bonus points
    if hasattr(evaluation, "bonus_points") and evaluation.bonus_points:
        row["bonus_total"] = evaluation.bonus_points.total
        row["bonus_breakdown"] = evaluation.bonus_points.breakdown
    else:
        row["bonus_total"] = 0
        row["bonus_breakdown"] = "None"

    # Deductions
    if hasattr(evaluation, "deductions") and evaluation.deductions:
        row["deductions_total"] = evaluation.deductions.total
        row["deductions_reasons"] = evaluation.deductions.reasons
    else:
        row["deductions_total"] = 0
        row["deductions_reasons"] = "None"

    # Strengths and improvements
    if hasattr(evaluation, "key_strengths") and evaluation.key_strengths:
        row["key_strengths"] = " | ".join(evaluation.key_strengths)
    else:
        row["key_strengths"] = ""

    if hasattr(evaluation, "areas_for_improvement") and evaluation.areas_for_improvement:
        row["areas_for_improvement"] = " | ".join(evaluation.areas_for_improvement)
    else:
        row["areas_for_improvement"] = ""

    return row


def save_evaluation_to_csv(csv_path: str, evaluation_row: Dict[str, Any]) -> int:
    """Append evaluation row to CSV file on disk. Creates file with headers if missing.
    
    Returns total rows currently in CSV.
    """
    path = Path(csv_path)
    file_exists = path.is_file()

    fieldnames = list(evaluation_row.keys())

    with open(path, "a", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        if not file_exists:
            writer.writeheader()
        writer.writerow(evaluation_row)

    # Count total rows
    with open(path, "r", encoding="utf-8") as csvfile:
        reader = csv.reader(csvfile)
        total_records = max(0, sum(1 for _ in reader) - 1)

    return total_records
