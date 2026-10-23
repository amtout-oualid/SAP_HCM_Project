"""Template manager for rendering prompt templates via Jinja2."""

import logging
from pathlib import Path
from typing import Any, Dict, Optional
from jinja2 import Environment, FileSystemLoader, select_autoescape

from core.config import BASE_DIR, settings

logger = logging.getLogger("sap_evaluator.templates")


class TemplateManager:
    """Manages loading and rendering of prompt templates."""

    def __init__(self, templates_dir: Optional[Path] = None):
        self.templates_dir = templates_dir or (BASE_DIR / "prompts" / "templates")
        
        if not self.templates_dir.is_dir():
            logger.warning(f"Templates directory not found at {self.templates_dir}")

        self.env = Environment(
            loader=FileSystemLoader(str(self.templates_dir)),
            autoescape=select_autoescape(default=False),
            trim_blocks=True,
            lstrip_blocks=True,
        )

    def render_template(self, template_name: str, **kwargs: Any) -> Optional[str]:
        """Render a template from the templates directory.
        
        Appends .jinja extension if not provided.
        """
        if not template_name.endswith(".jinja"):
            template_filename = f"{template_name}.jinja"
        else:
            template_filename = template_name

        try:
            template = self.env.get_template(template_filename)
            return template.render(**kwargs)
        except Exception as e:
            logger.error(f"Error rendering template '{template_filename}': {e}")
            return None

    def render_string(self, template_str: str, **kwargs: Any) -> str:
        """Render an in-memory Jinja2 template string."""
        try:
            template = self.env.from_string(template_str)
            return template.render(**kwargs)
        except Exception as e:
            logger.error(f"Error rendering template string: {e}")
            raise
