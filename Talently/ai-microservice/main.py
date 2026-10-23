"""Main FastAPI application entry point for SAP Intern Evaluator Microservice."""

import logging
import sys
import time
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import settings
from routers.health import router as health_router
from routers.evaluate import router as evaluate_router

# Configure root logger
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s (%(filename)s:%(lineno)d): %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)

logger = logging.getLogger("sap_evaluator.main")

# Initialize FastAPI app
app = FastAPI(
    title="SAP Intern Candidate Evaluator API",
    version="1.0.0",
    description=(
        "Production-ready FastAPI microservice for automated candidate evaluation. "
        "Accepts Google Drive resume links (PDF, DOCX, TXT, MD), enriches candidate metrics "
        "via GitHub profile and README documentation quality analysis, applies dynamic role scoring, "
        "and serves evaluation scores directly to SAP RAP applications and REST consumers."
    ),
    docs_url="/docs",
    redoc_url="/redoc",
)

# Enable CORS for SAP BTP, SAP Fiori, and web frontends
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log incoming request method, path, and duration."""
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    logger.info(
        f"{request.method} {request.url.path} completed in {duration:.3f}s with status {response.status_code}"
    )
    return response


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Catch unhandled exceptions and return structured JSON."""
    logger.error(f"Unhandled exception on {request.method} {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "status": "error",
            "error_code": "INTERNAL_SERVER_ERROR",
            "message": "An unexpected error occurred during evaluation processing.",
            "details": str(exc),
        },
    )


# Register routers
app.include_router(health_router)
app.include_router(evaluate_router)


@app.get("/", tags=["System"])
def root():
    """Root redirect / information endpoint."""
    return {
        "service": "SAP Candidate Evaluator Microservice",
        "version": "1.0.0",
        "documentation": "/docs",
        "health": "/health",
        "endpoints": {
            "evaluate_score_for_rap": "POST /evaluate/score",
            "evaluate_full_breakdown": "POST /evaluate/full",
            "evaluate_and_export_csv": "POST /evaluate/csv",
            "evaluate_file_upload": "POST /evaluate/upload",
            "catalog_roles": "GET /roles",
        },
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=True)
