"""Scoring engine orchestrating role loading, prompt compilation, LLM evaluation, and rubric calculations."""

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

from core.config import settings, DEFAULT_MODEL, MODEL_PARAMETERS, BASE_DIR
from core.llm import initialize_llm_provider, extract_json_from_response
from core.templates import TemplateManager
from data.transform import convert_json_resume_to_text, convert_github_data_to_text
from models.evaluation import build_evaluation_model
from models.resume import JSONResume

logger = logging.getLogger("sap_evaluator.scoring_engine")


@dataclass(frozen=True)
class Category:
    """Scoring category metadata and maximum weight."""
    key: str
    label: str
    max: int
    icon: str = "•"


@dataclass(frozen=True)
class Role:
    """Fully loaded evaluation role rubric."""
    name: str
    position_title: str
    categories: List[Category]
    bonus_max: int
    min_final_score: int
    max_final_score: int
    criteria_source: str
    system_message_source: str


def list_available_roles(roles_dir: Optional[Path] = None) -> List[str]:
    """Return all available role names found in the roles directory."""
    r_dir = roles_dir or (BASE_DIR / "roles")
    if not r_dir.is_dir():
        return []
    return sorted(p.name for p in r_dir.iterdir() if (p / "role.json").is_file())


def load_role(name: str, roles_dir: Optional[Path] = None) -> Role:
    """Load role configuration and Jinja templates from disk."""
    r_dir = roles_dir or (BASE_DIR / "roles")
    role_path = r_dir / name
    manifest_path = role_path / "role.json"
    criteria_path = role_path / "criteria.jinja"
    system_message_path = role_path / "system_message.jinja"

    if not manifest_path.is_file():
        available = ", ".join(list_available_roles(r_dir)) or "none"
        raise ValueError(f"Unknown role '{name}'. Available roles: {available}")

    for p in (criteria_path, system_message_path):
        if not p.is_file():
            raise ValueError(f"Role '{name}' is missing required template: {p.name}")

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as e:
        raise ValueError(f"Role '{name}' has invalid role.json: {e}") from e

    categories = [
        Category(
            key=c["key"],
            label=c.get("label", c["key"].title()),
            max=int(c.get("max", 25)),
            icon=c.get("icon", "•")
        )
        for c in manifest.get("categories", [])
    ]

    return Role(
        name=name,
        position_title=manifest.get("position_title", "Software Engineering Intern"),
        categories=categories,
        bonus_max=int(manifest.get("bonus_max", 20)),
        min_final_score=int(manifest.get("min_final_score", 0)),
        max_final_score=int(manifest.get("max_final_score", 120)),
        criteria_source=criteria_path.read_text(encoding="utf-8"),
        system_message_source=system_message_path.read_text(encoding="utf-8"),
    )


class ScoringEngine:
    """Evaluates candidate resume and enriched GitHub data against target role criteria."""

    def __init__(self, role_name: Optional[str] = None, model_name: Optional[str] = None):
        self.role_name = role_name or settings.DEFAULT_ROLE
        self.role = load_role(self.role_name)
        self.model_name = model_name or DEFAULT_MODEL
        self.template_manager = TemplateManager()
        self.provider = initialize_llm_provider(self.model_name)
        self.model_params = MODEL_PARAMETERS.get(self.model_name, {"temperature": 0.1, "top_p": 0.9})
        self.evaluation_model = build_evaluation_model(self.role)

    def evaluate(
        self,
        resume: JSONResume,
        github_data: Optional[Dict[str, Any]] = None,
        offer_info: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Perform evaluation and calculate score metrics.

        Returns:
            Dictionary containing final score, recommendation, and detailed breakdown.
        """
        # 1. Format text representations
        resume_text = convert_json_resume_to_text(resume)
        github_text = convert_github_data_to_text(github_data or {})

        offer_block = ""
        if offer_info and offer_info.strip():
            offer_block = (
                "=== TARGET JOB OFFER / POSITION SPECIFICATIONS ===\n"
                f"{offer_info.strip()}\n\n"
            )

        combined_text = f"{offer_block}{resume_text}\n{github_text}"

        # 2. Render evaluation criteria and system message prompts
        full_prompt = self.template_manager.render_string(
            self.role.criteria_source, text_content=combined_text
        )
        system_message = self.template_manager.render_string(
            self.role.system_message_source
        )

        # 3. Call LLM with strict structured JSON schema
        chat_params = {
            "model": self.model_name,
            "messages": [
                {"role": "system", "content": system_message},
                {"role": "user", "content": full_prompt},
            ],
            "options": {
                "temperature": self.model_params.get("temperature", 0.1),
                "top_p": self.model_params.get("top_p", 0.9),
            },
        }

        kwargs = {"format": self.evaluation_model.model_json_schema()}
        logger.info(f"Dispatching evaluation to LLM ({self.model_name}) with role '{self.role.name}'...")
        response = self.provider.chat(**chat_params, **kwargs)

        response_text = extract_json_from_response(response["message"]["content"])
        try:
            evaluation_dict = json.loads(response_text)
            evaluation_data = self.evaluation_model(**evaluation_dict)
        except Exception as e:
            logger.error(f"Failed to validate LLM evaluation response: {e}. Raw: {response_text}")
            raise ValueError(f"LLM returned invalid evaluation structure: {e}") from e

        # 4. Calculate final score according to rubric formula
        score_details = self._compute_score(evaluation_data)

        candidate_name = resume.basics.name if resume.basics and resume.basics.name else "Candidate"

        return {
            "candidate_name": candidate_name,
            "role": self.role.name,
            "final_score": score_details["final_score"],
            "max_score": score_details["max_score"],
            "percentage": score_details["percentage"],
            "recommendation": score_details["recommendation"],
            "scores": evaluation_dict.get("scores", {}),
            "bonus_points": evaluation_dict.get("bonus_points", {"total": 0, "breakdown": "None"}),
            "deductions": evaluation_dict.get("deductions", {"total": 0, "reasons": "None"}),
            "key_strengths": evaluation_dict.get("key_strengths", []),
            "areas_for_improvement": evaluation_dict.get("areas_for_improvement", []),
            "raw_evaluation": evaluation_data,
        }

    def _compute_score(self, evaluation_data: Any) -> Dict[str, Any]:
        """Compute total score, cap bounds, and recommendation."""
        base_score = 0.0
        max_score = sum(cat.max for cat in self.role.categories)

        if hasattr(evaluation_data, "scores") and evaluation_data.scores:
            scores_dict = evaluation_data.scores.model_dump()
            for cat in self.role.categories:
                cat_score_data = scores_dict.get(cat.key, {})
                awarded = float(cat_score_data.get("score", 0.0))
                # Ensure category score does not exceed its maximum
                base_score += min(awarded, float(cat.max))

        # Add bonus points (capped at role.bonus_max)
        bonus_points = 0.0
        if hasattr(evaluation_data, "bonus_points") and evaluation_data.bonus_points:
            bonus_points = min(float(evaluation_data.bonus_points.total), float(self.role.bonus_max))

        # Subtract deductions
        deductions = 0.0
        if hasattr(evaluation_data, "deductions") and evaluation_data.deductions:
            deductions = float(evaluation_data.deductions.total)

        final_score = base_score + bonus_points - deductions
        max_possible = max_score + self.role.bonus_max
        final_score = max(float(self.role.min_final_score), min(final_score, float(max_possible)))

        percentage = round((final_score / max_score) * 100.0, 1) if max_score > 0 else 0.0

        # Recommendation logic
        if percentage >= 80.0:
            recommendation = "STRONG_HIRE"
        elif percentage >= 65.0:
            recommendation = "HIRE"
        elif percentage >= 50.0:
            recommendation = "CONSIDER"
        else:
            recommendation = "DO_NOT_HIRE"

        return {
            "final_score": round(final_score, 1),
            "max_score": max_score,
            "percentage": percentage,
            "recommendation": recommendation,
        }
