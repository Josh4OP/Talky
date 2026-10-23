"""T07/T08 - Adaptador OpenAI-compatible: esquema estricto, respaldo y traducción de errores.

Contrato: src/infrastructure/external/openai_compatible_llm.py
  OpenAICompatibleLLM(name, base_url, api_key, model, timeout=90, max_retries=4,
                      json_schema: dict | None = None, client=None)
  - Con json_schema pide response_format={"type": "json_schema", "json_schema": {"name", "strict": True, "schema"}}.
  - Si el servidor responde 400 reintenta con {"type": "json_object"} y, de nuevo 400, sin response_format.
  - 429 -> RateLimitedError (con retry_after si viene el header), otras fallas de API -> ProviderError.
"""

import json
from types import SimpleNamespace

import pytest

openai = pytest.importorskip("openai")
httpx = pytest.importorskip("httpx")

from src.domain.exceptions import ProviderError, RateLimitedError  # noqa: E402
from src.infrastructure.external.openai_compatible_llm import OpenAICompatibleLLM  # noqa: E402


def _http_response(status, headers=None):
    return httpx.Response(status, headers=headers or {}, request=httpx.Request("POST", "http://test"))


class _Completions:
    def __init__(self, behaviours):
        self.behaviours = list(behaviours)
        self.calls = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        behaviour = self.behaviours.pop(0)
        if isinstance(behaviour, Exception):
            raise behaviour
        return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=behaviour))])


def _llm(behaviours, **kw):
    completions = _Completions(behaviours)
    client = SimpleNamespace(chat=SimpleNamespace(completions=completions))
    llm = OpenAICompatibleLLM("test", "http://x", "key", "model-x", client=client, **kw)
    return llm, completions


def _bad_request():
    return openai.BadRequestError("schema no soportado", response=_http_response(400), body=None)


def test_plain_json_object_mode_by_default():
    llm, completions = _llm(['{"ok": true}'])
    assert json.loads(llm.complete_json("sys", "usr")) == {"ok": True}
    assert completions.calls[0]["response_format"] == {"type": "json_object"}


def test_strict_json_schema_when_provided():
    schema = {
        "type": "object",
        "properties": {"a": {"type": "string"}},
        "required": ["a"],
        "additionalProperties": False,
    }
    llm, completions = _llm(['{"a": "x"}'], json_schema=schema)
    llm.complete_json("sys", "usr")
    rf = completions.calls[0]["response_format"]
    assert rf["type"] == "json_schema"
    assert rf["json_schema"]["strict"] is True
    assert rf["json_schema"]["schema"] == schema


def test_falls_back_when_the_server_rejects_the_format():
    schema = {"type": "object", "properties": {}, "required": [], "additionalProperties": False}
    llm, completions = _llm([_bad_request(), _bad_request(), '{"ok": 1}'], json_schema=schema)
    assert llm.complete_json("sys", "usr") == '{"ok": 1}'
    formats = [c.get("response_format", {}).get("type") for c in completions.calls]
    assert formats == ["json_schema", "json_object", None]


def test_empty_response_is_an_error():
    llm, _ = _llm([""])
    with pytest.raises(ProviderError):
        llm.complete_json("sys", "usr")


def test_rate_limit_is_translated_with_retry_after():
    err = openai.RateLimitError("429", response=_http_response(429, {"retry-after": "12"}), body=None)
    llm, _ = _llm([err])
    with pytest.raises(RateLimitedError) as exc:
        llm.complete_json("sys", "usr")
    assert exc.value.retry_after == 12.0


def test_other_api_errors_become_provider_errors():
    err = openai.InternalServerError("500", response=_http_response(500), body=None)
    llm, _ = _llm([err])
    with pytest.raises(ProviderError):
        llm.complete_json("sys", "usr")
