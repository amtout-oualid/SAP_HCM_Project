"""Resume parser that extracts structured JSONResume sections from Markdown via LLM calls."""

import json
import logging
import time
from typing import Dict, Optional, Any

from core.config import DEFAULT_MODEL, MODEL_PARAMETERS
from core.llm import initialize_llm_provider, extract_json_from_response
from core.templates import TemplateManager
from data.transform import transform_parsed_data
from models.resume import (
    JSONResume,
    Basics,
    BasicsSection,
    WorkSection,
    EducationSection,
    SkillsSection,
    ProjectsSection,
    AwardsSection,
)

logger = logging.getLogger("sap_evaluator.resume_parser")


class ResumeParser:
    """Extracts structured resume sections into JSONResume using structured LLM calls."""

    def __init__(self, model_name: Optional[str] = None):
        self.model_name = model_name or DEFAULT_MODEL
        self.template_manager = TemplateManager()
        self.provider = initialize_llm_provider(self.model_name)
        self.model_params = MODEL_PARAMETERS.get(self.model_name, {"temperature": 0.1, "top_p": 0.9})

    def _call_llm_for_section(
        self, section_name: str, text_content: str, prompt: str, return_model: Any = None
    ) -> Optional[Dict[str, Any]]:
        try:
            start_time = time.time()
            logger.debug(f"Extracting {section_name} section using {self.model_name}...")

            section_system_message = self.template_manager.render_template(
                "system_message", section_name_param=section_name
            )
            if not section_system_message:
                logger.error(f"Failed to render system message template for {section_name}")
                return None

            chat_params = {
                "model": self.model_name,
                "messages": [
                    {"role": "system", "content": section_system_message},
                    {"role": "user", "content": prompt},
                ],
                "options": {
                    "temperature": self.model_params.get("temperature", 0.1),
                    "top_p": self.model_params.get("top_p", 0.9),
                },
            }

            kwargs = {}
            if return_model:
                kwargs["format"] = return_model.model_json_schema()

            response = self.provider.chat(**chat_params, **kwargs)
            response_text = response["message"]["content"]

            try:
                response_text = extract_json_from_response(response_text)
                parsed_data = json.loads(response_text)
                transformed_data = transform_parsed_data(parsed_data)
                
                elapsed = time.time() - start_time
                logger.debug(f"Extracted {section_name} in {elapsed:.2f}s")
                return transformed_data

            except json.JSONDecodeError as e:
                logger.error(f"Error parsing JSON for {section_name}: {e}. Raw response: {response_text}")
                return None

        except Exception as e:
            logger.error(f"LLM extraction error for {section_name}: {e}")
            return None

    def extract_basics(self, text_content: str) -> Optional[Dict[str, Any]]:
        prompt = self.template_manager.render_template("basics", text_content=text_content)
        return self._call_llm_for_section("basics", text_content, prompt or "", BasicsSection)

    def extract_work(self, text_content: str) -> Optional[Dict[str, Any]]:
        prompt = self.template_manager.render_template("work", text_content=text_content)
        return self._call_llm_for_section("work", text_content, prompt or "", WorkSection)

    def extract_education(self, text_content: str) -> Optional[Dict[str, Any]]:
        prompt = self.template_manager.render_template("education", text_content=text_content)
        return self._call_llm_for_section("education", text_content, prompt or "", EducationSection)

    def extract_skills(self, text_content: str) -> Optional[Dict[str, Any]]:
        prompt = self.template_manager.render_template("skills", text_content=text_content)
        return self._call_llm_for_section("skills", text_content, prompt or "", SkillsSection)

    def extract_projects(self, text_content: str) -> Optional[Dict[str, Any]]:
        prompt = self.template_manager.render_template("projects", text_content=text_content)
        return self._call_llm_for_section("projects", text_content, prompt or "", ProjectsSection)

    def extract_awards(self, text_content: str) -> Optional[Dict[str, Any]]:
        prompt = self.template_manager.render_template("awards", text_content=text_content)
        return self._call_llm_for_section("awards", text_content, prompt or "", AwardsSection)

    def parse_resume(self, markdown_text: str) -> JSONResume:
        """Execute parallel/sequential section extraction and return complete JSONResume."""
        logger.info(f"Beginning 6-section LLM extraction on resume text ({len(markdown_text)} chars)...")
        start_time = time.time()

        complete_dict: Dict[str, Any] = {
            "basics": None,
            "work": None,
            "volunteer": None,
            "education": None,
            "awards": None,
            "certificates": None,
            "publications": None,
            "skills": None,
            "languages": None,
            "interests": None,
            "references": None,
            "projects": None,
        }

        extractors = [
            ("basics", self.extract_basics),
            ("work", self.extract_work),
            ("education", self.extract_education),
            ("skills", self.extract_skills),
            ("projects", self.extract_projects),
            ("awards", self.extract_awards),
        ]

        for section_name, fn in extractors:
            data = fn(markdown_text)
            if data is None:
                logger.warning(f"Retrying section '{section_name}' extraction...")
                data = fn(markdown_text)

            if data and isinstance(data, dict):
                complete_dict.update(data)
            elif data is None and section_name == "basics":
                # Basics is essential; if failed, synthesize minimal name
                logger.warning("Basics extraction returned None, generating fallback")
                complete_dict["basics"] = {"name": "Candidate"}

        if complete_dict.get("basics") and isinstance(complete_dict["basics"], dict):
            try:
                complete_dict["basics"] = Basics(**complete_dict["basics"])
            except Exception as e:
                logger.error(f"Error instantiating Basics model: {e}")
                complete_dict["basics"] = Basics(name=complete_dict["basics"].get("name", "Candidate"))
        elif not complete_dict.get("basics"):
            complete_dict["basics"] = Basics(name="Candidate")

        json_resume = JSONResume(**complete_dict)
        logger.info(f"Resume extraction complete in {time.time() - start_time:.2f}s")
        return json_resume
