"""T08 - Reglas de prompts, verificador, esquema estricto y adaptador LLM que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md, secciones prompts.py, verifier.py, json_schema.py
y openai_compatible_llm.py; harness/agent/rules/llm-prompting.md.
  - El prompt del analista declara la transcripción como dato, no como instrucciones.
  - El mensaje de usuario sigue la forma de context/05-llm-and-groq.md.
  - El verificador tolera una palabra de más o de menos, exige 3 palabras y rechaza una cita corta con una
    palabra cambiada.
  - El esquema estricto no deja $ref ni $defs y cierra también los objetos dentro de listas.
  - El adaptador: no crea cliente si se inyecta; 429 sin cabecera da retry_after None; errores de red son
    ProviderError; si todos los formatos fallan con 400 es ProviderError; nunca registra los mensajes.
"""

import json
import logging
from types import SimpleNamespace

import pytest
from fakes import SAMPLE_TEXT

from src.application.prompts import ANALYSIS_SYSTEM, TRUNCATION_NOTICE, build_user_message
from src.application.services.verifier import normalize, quote_in_transcript
from src.domain.entities.analysis import Analisis, Sintesis

openai = pytest.importorskip("openai")
httpx = pytest.importorskip("httpx")

from src.domain.exceptions import ProviderError, RateLimitedError  # noqa: E402
from src.infrastructure.external import openai_compatible_llm  # noqa: E402
from src.infrastructure.external.json_schema import strict_json_schema  # noqa: E402
from src.infrastructure.external.openai_compatible_llm import OpenAICompatibleLLM  # noqa: E402


def test_analysis_prompt_treats_the_transcript_as_data():
    assert "no instrucciones" in ANALYSIS_SYSTEM.lower()


def test_user_message_layout():
    assert build_user_message("Ritmo: 120 ppm", "Hola.", truncated=True) == (
        f"Ritmo: 120 ppm\n\nTranscripción:\nHola.\n\n{TRUNCATION_NOTICE}"
    )


@pytest.mark.parametrize(
    "quote",
    [
        "el cambio climático afecta a todos los países del planeta mundo",  # una palabra de más
        "el cambio climático afecta a todos países del mundo",  # una palabra de menos
    ],
)
def test_one_extra_or_missing_word_is_tolerated(quote):
    assert quote_in_transcript(quote, SAMPLE_TEXT) is True


def test_three_words_are_enough_and_two_are_not():
    assert quote_in_transcript("el cambio climático", SAMPLE_TEXT) is True
    assert quote_in_transcript("cambio climático", SAMPLE_TEXT) is False


@pytest.mark.parametrize("quote", ["el cambio cultural", "hablar sobre economía", "todos los países pobres"])
def test_short_quote_with_one_wrong_word_is_rejected(quote):
    assert quote_in_transcript(quote, SAMPLE_TEXT) is False


def test_stricter_ratio_rejects_asr_variations():
    variation = "el cambio climático afectan a todos los países del mundo"
    assert quote_in_transcript(variation, SAMPLE_TEXT, min_ratio=0.999) is False


def test_normalize_folds_enye_and_symbols():
    assert normalize("Año_2026 — ¡Señor!") == "ano 2026 senor"


@pytest.mark.parametrize("model", [Analisis, Sintesis])
def test_strict_schema_has_no_references_left(model):
    text = json.dumps(strict_json_schema(model))
    assert "$ref" not in text and "$defs" not in text


def test_objects_inside_arrays_are_closed():
    items = strict_json_schema(Analisis)["properties"]["evidencias"]["items"]
    assert items["additionalProperties"] is False
    assert sorted(items["required"]) == ["afirmacion", "cita", "verificada"]


def _response(status, headers=None):
    return httpx.Response(status, headers=headers or {}, request=httpx.Request("POST", "http://test"))


def _llm(*behaviours, **kw):
    calls = []

    def create(**kwargs):
        calls.append(kwargs)
        behaviour = behaviours[len(calls) - 1]
        if isinstance(behaviour, Exception):
            raise behaviour
        return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=behaviour))])

    client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create)))
    return OpenAICompatibleLLM("test", "http://x", "key", "m", client=client, **kw), calls


def _bad_request():
    return openai.BadRequestError("400", response=_response(400), body=None)


def test_injected_client_means_no_real_client_is_built(monkeypatch):
    def fail(*args, **kwargs):
        raise AssertionError("no debe crear un cliente real")

    monkeypatch.setattr(openai_compatible_llm, "OpenAI", fail)
    llm, _ = _llm('{"ok": 1}')
    assert llm.complete_json("s", "u") == '{"ok": 1}'


def test_rate_limit_without_header_has_no_retry_after():
    llm, _ = _llm(openai.RateLimitError("429", response=_response(429), body=None))
    with pytest.raises(RateLimitedError) as exc:
        llm.complete_json("s", "u")
    assert exc.value.retry_after is None


def test_connection_errors_are_provider_errors():
    llm, _ = _llm(openai.APIConnectionError(request=httpx.Request("POST", "http://test")))
    with pytest.raises(ProviderError):
        llm.complete_json("s", "u")


def test_rejecting_every_format_is_a_provider_error():
    llm, calls = _llm(_bad_request(), _bad_request())
    with pytest.raises(ProviderError):
        llm.complete_json("s", "u")
    assert [c.get("response_format", {}).get("type") for c in calls] == ["json_object", None]


def test_whitespace_only_response_is_an_error():
    llm, _ = _llm("   \n")
    with pytest.raises(ProviderError):
        llm.complete_json("s", "u")


def test_messages_are_never_logged(caplog):
    llm, _ = _llm(_bad_request(), '{"ok": 1}')
    with caplog.at_level(logging.DEBUG, logger="talky"):
        llm.complete_json("SECRETO DEL SISTEMA", "TRANSCRIPCION PRIVADA")
    assert "SECRETO" not in caplog.text and "PRIVADA" not in caplog.text
