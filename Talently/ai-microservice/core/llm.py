"""LLM provider interface and response cleaning utilities."""

import json
import logging
import random
import time
from typing import Any, Dict, List, Optional, Protocol, runtime_checkable
import requests

from core.config import provider_for

logger = logging.getLogger("sap_evaluator.llm")


@runtime_checkable
class LLMProvider(Protocol):
    """Protocol for LLM providers."""

    def chat(
        self,
        model: str,
        messages: List[Dict[str, str]],
        options: Optional[Dict[str, Any]] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """Send a chat completion request to the LLM provider."""
        ...


def extract_json_from_response(response_text: str) -> str:
    """Extract clean JSON content from model responses.
    
    Handles markdown code blocks (```json ... ```), <think>...</think> reasoning tags,
    and outer whitespace or commentary.
    """
    response_text = response_text.strip()
    
    # Strip DeepSeek or Qwen reasoning tokens if present
    if "<think>" in response_text:
        think_start = response_text.find("<think>")
        think_end = response_text.find("</think>")
        if think_start != -1 and think_end != -1:
            response_text = response_text[:think_start] + response_text[think_end + 8:]
            response_text = response_text.strip()

    # Remove markdown code fence if wrapped
    if response_text.startswith("```json"):
        response_text = response_text[7:]
    elif response_text.startswith("```"):
        response_text = response_text[3:]
        
    if response_text.endswith("```"):
        response_text = response_text[:-3]
        
    response_text = response_text.strip()

    # Find boundaries of first '{' and last '}' if extra preamble is present
    json_start = response_text.find("{")
    json_end = response_text.rfind("}")
    if json_start != -1 and json_end != -1 and json_end > json_start:
        return response_text[json_start : json_end + 1]

    # Alternatively check for array bracket '[' and ']'
    arr_start = response_text.find("[")
    arr_end = response_text.rfind("]")
    if arr_start != -1 and arr_end != -1 and arr_end > arr_start:
        return response_text[arr_start : arr_end + 1]

    return response_text


class OpenAICompatibleProvider:
    """Generic OpenAI-chat-compatible LLM client.

    Compatible with Ollama (/v1), Google Gemini (/v1beta/openai), Anthropic (/v1 via adapter),
    OpenAI, Groq, and other OpenAI-compatible endpoints.
    """

    def __init__(
        self,
        base_url: str,
        api_key: Optional[str] = None,
        structured_output: str = "json_schema",
        extra_body: Optional[Dict[str, Any]] = None,
    ):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.structured_output = structured_output
        self.extra_body = extra_body or {}

    def chat(
        self,
        model: str,
        messages: List[Dict[str, str]],
        options: Optional[Dict[str, Any]] = None,
        **kwargs
    ) -> Dict[str, Any]:
        options = options or {}
        body: Dict[str, Any] = {"model": model, "messages": messages, "stream": False}
        
        if "temperature" in options:
            body["temperature"] = options["temperature"]
        if "top_p" in options:
            body["top_p"] = options["top_p"]

        # Structured output format translation
        if "format" in kwargs and self.structured_output != "none":
            schema = kwargs["format"]
            if self.structured_output == "json_schema":
                body["response_format"] = {
                    "type": "json_schema",
                    "json_schema": {"name": "response", "schema": schema},
                }
            elif self.structured_output == "json_object":
                body["response_format"] = {"type": "json_object"}

        body.update(self.extra_body)

        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        url = f"{self.base_url}/chat/completions"

        MAX_RETRIES = 5
        BASE_DELAY = 2.0
        MAX_DELAY = 60.0
        RETRYABLE_SERVER_ERRORS = {429, 500, 502, 503, 504}

        for attempt in range(MAX_RETRIES):
            try:
                response = requests.post(url, json=body, headers=headers, timeout=180)
            except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as conn_err:
                if attempt < MAX_RETRIES - 1:
                    sleep_time = min(BASE_DELAY * (2 ** attempt), MAX_DELAY) + random.uniform(0.5, 1.5)
                    logger.warning(
                        f"Network error on attempt {attempt + 1}/{MAX_RETRIES}: {conn_err}. "
                        f"Retrying in {sleep_time:.1f}s..."
                    )
                    time.sleep(sleep_time)
                    continue
                raise

            if response.status_code in RETRYABLE_SERVER_ERRORS and attempt < MAX_RETRIES - 1:
                retry_after = response.headers.get("Retry-After")
                exp_delay = min(BASE_DELAY * (2 ** attempt), MAX_DELAY)
                delay = float(retry_after) if retry_after and retry_after.isdigit() else exp_delay
                sleep_time = round(delay * random.uniform(0.9, 1.3), 2)
                logger.warning(
                    f"HTTP {response.status_code} hit on attempt {attempt + 1}/{MAX_RETRIES}. "
                    f"Retrying in {sleep_time}s..."
                )
                time.sleep(sleep_time)
                continue

            response.raise_for_status()
            data = response.json()
            try:
                content = data["choices"][0]["message"]["content"]
            except (KeyError, IndexError, TypeError) as parse_err:
                raise ValueError(f"Unexpected response shape from {url}: {data}") from parse_err

            return {"message": {"role": "assistant", "content": content}}

        raise RuntimeError(f"Failed to obtain chat completion from {url} after {MAX_RETRIES} attempts.")


def initialize_llm_provider(model_name: str) -> OpenAICompatibleProvider:
    """Initialize an OpenAI-compatible LLM client for the requested model."""
    cfg = provider_for(model_name)
    logger.info(f"Initialized LLM provider '{cfg['name']}' ({cfg['base_url']}) for model '{model_name}'")
    return OpenAICompatibleProvider(
        base_url=cfg["base_url"],
        api_key=cfg["api_key"],
        structured_output=cfg["structured_output"],
        extra_body=cfg["extra_body"],
    )
