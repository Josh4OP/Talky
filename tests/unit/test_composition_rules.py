"""T14 - Reglas de configuración, contenedor, ensamble y caso de uso que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md (Configuración, ensemble.py, analyze_presentation.py),
context/07-api-contract.md y la tarea T14.
  - Settings no muestra claves en repr, conserva valores por defecto con VAR= y valida rangos.
  - Contenedor: TRANSCRIBER=local sin faster-whisper es ConfigurationError; con Groq y sin faster-whisper avisa que
    no hay respaldo; embeddings sin librería y clasificador sin módulo (aplazado, D-11) degradan con aviso;
    esquema estricto solo para Groq gpt-oss/qwen y distinto para analista y juez.
  - Ensamble: orden de modelos_usados = orden de proveedores; reintento solo por JSON inválido; el juez solo ve
    evidencias verificadas; sin verificador, verificada es None; menos de min_ok respuestas es AllProvidersFailedError.
  - Caso de uso: sin voz es InvalidAudioError; sin palabras, pausas por segmentos y ritmo vacío; las advertencias del
    transcriptor llegan al resultado; transcripción larga se recorta y se marca.
"""

import dataclasses
import json
import threading

import pytest
from fakes import INVENTED_QUOTE, FakeLLM, FakeTranscriber, analysis_payload, sample_transcription

from src.application.services.ensemble import EnsembleAnalyzer
from src.application.use_cases.analyze_presentation import AnalyzePresentation
from src.config import container as container_module
from src.config.container import build_container
from src.config.settings import Settings
from src.domain.exceptions import AllProvidersFailedError, ConfigurationError, InvalidAudioError, RateLimitedError
from src.domain.interfaces.ports import LLMProvider, Segment, Transcription


def _settings(tmp_path, **values):
    return dataclasses.replace(Settings(), db_path=str(tmp_path / "t.db"), **values)


# --------------------------------------------------------------------------- Settings
def test_settings_repr_hides_api_keys():
    s = Settings.from_env({"GROQ_API_KEY": "gsk_secreta", "GEMINI_API_KEY": "gem_secreta"})
    assert "secreta" not in repr(s)
    assert all("secreta" not in repr(spec) for spec in s.llm_provider_specs())


def test_empty_variables_keep_their_defaults():
    s = Settings.from_env({"MAX_UPLOAD_MB": "", "WHISPER_MODEL": "  ", "JUDGE_PROVIDER": ""})
    assert (s.max_upload_mb, s.whisper_model, s.judge_provider) == (100, "small", "gemini")


@pytest.mark.parametrize("env", [{"MIN_MODELS_OK": "0"}, {"MAX_DURATION_S": "-5"}])
def test_non_positive_numbers_are_rejected(env):
    with pytest.raises(ValueError, match=next(iter(env))):
        Settings.from_env(env)


def test_min_duration_must_be_below_max():
    with pytest.raises(ValueError, match="MIN_DURATION_S"):
        Settings.from_env({"MIN_DURATION_S": "60", "MAX_DURATION_S": "30"})


# --------------------------------------------------------------------------- Contenedor
def test_local_mode_without_faster_whisper_is_a_configuration_error(tmp_path, monkeypatch):
    monkeypatch.setattr(container_module, "_available", lambda module: False)
    with pytest.raises(ConfigurationError, match="faster-whisper"):
        build_container(_settings(tmp_path, transcriber="local"), llm_providers=[FakeLLM("a")])


def test_groq_without_local_fallback_warns(tmp_path, monkeypatch):
    monkeypatch.setattr(container_module, "_available", lambda module: False)
    c = build_container(_settings(tmp_path, groq_api_key="k"), llm_providers=[FakeLLM("a")])
    assert any("respaldo" in w for w in c.warnings)


def test_no_transcriber_at_all_is_a_configuration_error(tmp_path, monkeypatch):
    monkeypatch.setattr(container_module, "_available", lambda module: False)
    with pytest.raises(ConfigurationError, match="GROQ_API_KEY"):
        build_container(_settings(tmp_path), llm_providers=[FakeLLM("a")])


def test_embeddings_without_library_degrade_with_a_warning(tmp_path, monkeypatch):
    monkeypatch.setattr(container_module, "_available", lambda module: module != "sentence_transformers")
    c = build_container(
        _settings(tmp_path, enable_text_embeddings=True), transcriber=FakeTranscriber(), llm_providers=[FakeLLM("a")]
    )
    assert c.use_case.embedder is None
    assert any("coherencia" in w.lower() for w in c.warnings)


def test_deferred_event_classifier_degrades_even_if_a_model_file_exists(tmp_path):
    model = tmp_path / "event_classifier.joblib"
    model.write_bytes(b"no es un modelo")
    cfg = _settings(tmp_path, enable_event_classifier=True, event_model_path=str(model))
    c = build_container(cfg, transcriber=FakeTranscriber(), llm_providers=[FakeLLM("a")])
    assert c.use_case.event_classifier is None
    assert any("evento" in w.lower() for w in c.warnings)


def test_strict_schema_only_for_groq_gpt_oss_and_qwen_with_one_schema_per_role(tmp_path):
    cfg = _settings(tmp_path, groq_api_key="k", groq_model="openai/gpt-oss-20b, llama-3.3", ollama_model="qwen3")
    c = build_container(cfg, transcriber=FakeTranscriber())
    analysts = {p.name: p for p in c.use_case.ensemble.providers}
    assert analysts["groq:openai/gpt-oss-20b"]._json_schema["properties"].keys() >= {"organizacion", "evidencias"}
    assert analysts["groq:llama-3.3"]._json_schema is None
    assert analysts["ollama"]._json_schema is None
    judge_schemas = [
        p._json_schema for p in c.use_case.ensemble.judge._providers if p.name == "groq:openai/gpt-oss-20b"
    ]
    assert set(judge_schemas[0]["properties"]) == {"resumen", "fortalezas", "aspectos_por_mejorar", "recomendaciones"}


# --------------------------------------------------------------------------- Ensamble
class _GatedLLM(LLMProvider):
    """Responde solo cuando otro proveedor ya terminó, para invertir el orden de llegada."""

    def __init__(self, name, wait_for: threading.Event | None = None, done: threading.Event | None = None):
        self.name = name
        self.wait_for = wait_for
        self.done = done

    def complete_json(self, system, user):
        if self.wait_for is not None:
            assert self.wait_for.wait(timeout=5)
        if self.done is not None:
            self.done.set()
        return json.dumps(analysis_payload(), ensure_ascii=False)


def test_models_are_reported_in_provider_order_not_arrival_order():
    b_done = threading.Event()
    providers = [_GatedLLM("a", wait_for=b_done), _GatedLLM("b", done=b_done)]
    assert EnsembleAnalyzer(providers).analyze("s", "u")["modelos_usados"] == ["a", "b"]


class _ScriptedLLM(LLMProvider):
    def __init__(self, name, replies):
        self.name = name
        self.replies = list(replies)
        self.calls = 0

    def complete_json(self, system, user):
        self.calls += 1
        reply = self.replies.pop(0)
        if isinstance(reply, Exception):
            raise reply
        return reply


def test_invalid_json_is_retried_once():
    llm = _ScriptedLLM("a", ["no es json", json.dumps(analysis_payload())])
    assert EnsembleAnalyzer([llm]).analyze("s", "u")["modelos_usados"] == ["a"]
    assert llm.calls == 2


def test_rate_limits_are_not_retried():
    llm = _ScriptedLLM("a", [RateLimitedError(), json.dumps(analysis_payload())])
    result = EnsembleAnalyzer([llm, FakeLLM("b")]).analyze("s", "u")
    assert (llm.calls, list(result["modelos_fallidos"])) == (1, ["a"])


class _RecordingJudge(LLMProvider):
    name = "juez"

    def __init__(self):
        self.users = []

    def complete_json(self, system, user):
        self.users.append(user)
        return json.dumps({"resumen": "ok", "fortalezas": [], "aspectos_por_mejorar": [], "recomendaciones": []})


def test_judge_only_sees_verified_evidence():
    judge = _RecordingJudge()
    EnsembleAnalyzer([FakeLLM("a"), FakeLLM("b")], judge=judge).analyze(
        "s", "u", transcript=sample_transcription().text
    )
    assert INVENTED_QUOTE not in judge.users[0]


def test_without_verifier_model_claims_about_verification_are_cleared():
    payload = analysis_payload([{"afirmacion": "x", "cita": INVENTED_QUOTE, "verificada": True}])
    result = EnsembleAnalyzer([FakeLLM("a", analysis=payload)]).analyze("s", "u", transcript="texto", verify=False)
    assert [e["verificada"] for e in result["evidencias"]] == [None]
    assert result["verificacion"] is None


def test_fewer_answers_than_min_ok_is_all_providers_failed():
    providers = [FakeLLM("a"), FakeLLM("b", fail_analysis=RuntimeError("caído"))]
    with pytest.raises(AllProvidersFailedError) as exc:
        EnsembleAnalyzer(providers, min_ok=2).analyze("s", "u")
    assert "b" in exc.value.errors


# --------------------------------------------------------------------------- Caso de uso
def _use_case(transcription, **kw):
    return AnalyzePresentation(FakeTranscriber(transcription), EnsembleAnalyzer([FakeLLM("a")]), **kw)


def test_blank_transcription_is_invalid_audio():
    with pytest.raises(InvalidAudioError):
        _use_case(Transcription(text="   ", segments=[], duration=3.0)).execute("a.wav")


def test_without_words_pauses_use_segments_and_rhythm_is_empty():
    segments = [Segment(0.0, 2.0, "Hola a todos."), Segment(3.6, 6.0, "Eh, empecemos.")]
    result = _use_case(Transcription("Hola a todos. Eh, empecemos.", segments, 6.0)).execute("a.wav")
    assert result["ritmo"] == []
    assert result["pausas"]["pausas_largas"] == 1


def test_transcriber_warnings_reach_the_result():
    tr = dataclasses.replace(sample_transcription(), warnings=["Se usó el transcriptor de respaldo."])
    assert _use_case(tr).execute("a.wav")["advertencias"] == ["Se usó el transcriptor de respaldo."]


def test_long_transcripts_are_windowed_and_flagged():
    assert _use_case(sample_transcription(), max_chars=200).execute("a.wav")["transcripcion_recortada"] is True
