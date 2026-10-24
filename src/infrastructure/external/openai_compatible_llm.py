"""Adaptador para APIs compatibles con OpenAI (Groq, Gemini, Ollama) con salida JSON."""

import logging

from openai import APIError, BadRequestError, OpenAI, RateLimitError

from src.domain.exceptions import ProviderError, RateLimitedError
from src.domain.interfaces.ports import LLMProvider

logger = logging.getLogger("talky.llm")

_JSON_OBJECT = {"type": "json_object"}


def _retry_after(error: RateLimitError) -> float | None:
    try:
        return float(error.response.headers.get("retry-after"))
    except (AttributeError, TypeError, ValueError):
        return None


class OpenAICompatibleLLM(LLMProvider):
    """Pide JSON estricto si hay esquema y degrada a json_object y luego a sin formato ante un 400."""

    def __init__(
        self,
        name: str,
        base_url: str,
        api_key: str,
        model: str,
        timeout: float = 90,
        max_retries: int = 4,
        json_schema: dict | None = None,
        client=None,
    ):
        self.name = name
        self.model = model
        self._json_schema = json_schema
        self.client = client or OpenAI(base_url=base_url, api_key=api_key, timeout=timeout, max_retries=max_retries)

    def _response_formats(self) -> list[dict | None]:
        formats: list[dict | None] = [_JSON_OBJECT, None]
        if self._json_schema is not None:
            strict = {"name": "respuesta", "strict": True, "schema": self._json_schema}
            formats.insert(0, {"type": "json_schema", "json_schema": strict})
        return formats

    def _create(self, system: str, user: str):
        messages = [{"role": "system", "content": system}, {"role": "user", "content": user}]
        formats = self._response_formats()
        for attempt, response_format in enumerate(formats, start=1):
            kwargs = {"model": self.model, "messages": messages, "temperature": 0.3}
            if response_format is not None:
                kwargs["response_format"] = response_format
            try:
                return self.client.chat.completions.create(**kwargs)
            except BadRequestError as e:
                if attempt == len(formats):
                    raise ProviderError(f"{self.name} rechazó la petición (HTTP 400)") from e
                logger.info("%s no aceptó el formato de respuesta; se degrada al siguiente", self.name)
            except RateLimitError as e:
                raise RateLimitedError(f"{self.name} limitado por cuota", retry_after=_retry_after(e)) from e
            except APIError as e:
                raise ProviderError(f"{self.name} falló ({type(e).__name__})") from e

    def complete_json(self, system: str, user: str) -> str:
        response = self._create(system, user)
        try:
            content = response.choices[0].message.content
        except (AttributeError, IndexError) as e:
            raise ProviderError(f"{self.name} devolvió una respuesta sin contenido") from e
        if not content or not content.strip():
            raise ProviderError(f"{self.name} devolvió una respuesta vacía")
        return content
