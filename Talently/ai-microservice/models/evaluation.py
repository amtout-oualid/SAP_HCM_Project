"""Pydantic models for evaluation rubrics, scores, and LLM structured output."""

from typing import List, Type, Dict, Any, Optional
from pydantic import BaseModel, Field, create_model


class CategoryScore(BaseModel):
    """Score awarded for a specific category along with supporting evidence."""
    score: float = Field(ge=0, description="Score achieved in this category")
    max: int = Field(gt=0, description="Maximum possible score in this category")
    evidence: str = Field(min_length=1, description="Concrete evidence extracted from resume/GitHub")


class Deductions(BaseModel):
    """Penalties applied to candidate score (stored positive, subtracted from total)."""
    total: float = Field(
        default=0.0,
        ge=0,
        description="Total deduction points (applied as negative to final score)",
    )
    reasons: str = Field(
        default="None",
        description="Detailed rationale for each deduction (e.g. missing README, tutorial projects)",
    )


class BonusPoints(BaseModel):
    """Extra credits for exceptional achievements (hackathons, GSoC, open source, startups)."""
    total: float = Field(
        default=0.0,
        ge=0,
        description="Total bonus points awarded",
    )
    breakdown: str = Field(
        default="None",
        description="Breakdown of bonus point sources",
    )


def build_scores_model(categories: List[Any]) -> Type[BaseModel]:
    """Dynamically build a Scores model matching the exact category keys of a role."""
    fields = {category.key: (CategoryScore, ...) for category in categories}
    return create_model("Scores", **fields)


def build_evaluation_model(role: Any) -> Type[BaseModel]:
    """Dynamically build the full EvaluationData model for a role.
    
    Enforces category schema, bonus point cap, deductions, and list constraints.
    """
    scores_model = build_scores_model(role.categories)

    bonus_model = create_model(
        "RoleBonusPoints",
        total=(
            float,
            Field(ge=0, le=role.bonus_max, description="Total bonus points"),
        ),
        breakdown=(str, Field(description="Breakdown of bonus points")),
    )

    return create_model(
        "EvaluationData",
        scores=(scores_model, ...),
        bonus_points=(bonus_model, ...),
        deductions=(Deductions, ...),
        key_strengths=(List[str], Field(min_length=0, max_length=5)),
        areas_for_improvement=(List[str], Field(min_length=0, max_length=5)),
    )
