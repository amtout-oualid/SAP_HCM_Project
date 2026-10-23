"""Configuration loader and settings management for SAP Evaluator Microservice."""

import json
import os
from pathlib import Path
from typing import Dict, Any, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent

# Load environment variables
class Settings(BaseSettings):
    """Application settings with environment variable override."""
    
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    ENVIRONMENT: str = "development"
    LOG_LEVEL: str = "INFO"
    
    # Evaluation defaults
    DEFAULT_MODEL: str = "gpt-4o-mini"
    DEFAULT_ROLE: str = "software_engineering_intern"
    
    # API Keys
    GITHUB_TOKEN: Optional[str] = None
    GEMINI_API_KEY: Optional[str] = None
    ANTHROPIC_API_KEY: Optional[str] = None
    OPENAI_API_KEY: Optional[str] = None
    
    # Paths
    CSV_EXPORT_PATH: str = "evaluations.csv"
    PROVIDERS_FILE: Path = BASE_DIR / "providers.json"
    ROLES_DIR: Path = BASE_DIR / "roles"
    PROMPTS_DIR: Path = BASE_DIR / "prompts" / "templates"
    
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()

# Load providers.json
_providers_path = settings.PROVIDERS_FILE if settings.PROVIDERS_FILE.is_file() else (BASE_DIR / "providers.json")
if _providers_path.is_file():
    with open(_providers_path, "r", encoding="utf-8") as f:
        _providers_config = json.load(f)
else:
    _providers_config = {"default_model": settings.DEFAULT_MODEL, "providers": {}}

DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", _providers_config.get("default_model", settings.DEFAULT_MODEL))

# Flat model -> {temperature, top_p} map
MODEL_PARAMETERS: Dict[str, Dict[str, float]] = {
    model: {k: v for k, v in params.items() if k in ("temperature", "top_p")}
    for provider in _providers_config.get("providers", {}).values()
    for model, params in provider.get("models", {}).items()
}


def provider_for(model_name: str) -> Dict[str, Any]:
    """Resolve provider configuration for a model name.
    
    Returns:
        Dict with base_url, api_key, structured_output, extra_body.
    Raises:
        ValueError if the model is unknown or required API key is missing.
    """
    providers = _providers_config.get("providers", {})
    for name, prov in providers.items():
        if model_name not in prov.get("models", {}):
            continue
            
        api_key_env = prov.get("api_key_env")
        api_key = os.getenv(api_key_env) if api_key_env else None
        
        # Check settings object if not in os.environ
        if api_key_env and not api_key:
            api_key = getattr(settings, api_key_env, None)
            
        if api_key_env and not api_key:
            raise ValueError(
                f"Model '{model_name}' uses provider '{name}', which requires "
                f"environment variable '{api_key_env}', but it is unset in .env or environment."
            )
            
        extra_body = {
            **prov.get("extra_body", {}),
            **prov["models"][model_name].get("extra_body", {}),
        }
        
        return {
            "name": name,
            "base_url": prov["base_url"].rstrip("/"),
            "api_key": api_key,
            "structured_output": prov.get("structured_output", "json_schema"),
            "extra_body": extra_body,
        }

    available = ", ".join(sorted(MODEL_PARAMETERS.keys())) if MODEL_PARAMETERS else "none loaded"
    raise ValueError(f"Unknown model '{model_name}'. Available models: {available}")
