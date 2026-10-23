"""Health check and role catalog endpoints."""

from fastapi import APIRouter
from core.config import settings, DEFAULT_MODEL
from models.request import HealthResponse, RoleListResponse, RoleInfo
from services.scoring_engine import list_available_roles, load_role

router = APIRouter(tags=["System"])


@router.get("/health", response_model=HealthResponse)
def health_check():
    """System health check and runtime configuration status."""
    return HealthResponse(
        status="healthy",
        version="1.0.0",
        service="sap-evaluator-api",
        default_model=DEFAULT_MODEL,
        default_role=settings.DEFAULT_ROLE,
    )


@router.get("/roles", response_model=RoleListResponse)
def get_available_roles():
    """List all available scoring rubrics and role definitions."""
    roles = []
    for r_name in list_available_roles():
        try:
            r = load_role(r_name)
            roles.append(
                RoleInfo(
                    name=r.name,
                    position_title=r.position_title,
                    categories=[
                        {"key": c.key, "label": c.label, "max": c.max, "icon": c.icon}
                        for c in r.categories
                    ],
                    bonus_max=r.bonus_max,
                    max_final_score=r.max_final_score,
                )
            )
        except Exception:
            continue
    return RoleListResponse(available_roles=roles)
