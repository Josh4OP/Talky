"""T14 - Configuración tipada y banderas de funciones.

Contrato: src/config/settings.py
  Settings (dataclass inmutable, todos los campos con valor por defecto)
  Settings.from_env(env: Mapping[str, str] | None = None) -> Settings   # None -> os.environ
  Settings.groq_enabled -> bool
  Settings.llm_provider_specs() -> list[ProviderConfig(name, base_url, api_key, model)]
Variables de entorno: ver context/10-module-contracts.md (sección Settings).
"""

import dataclasses

import pytest
from src.config.settings import Settings


def test_defaults_match_from_empty_env():
    assert Settings() == Settings.from_env({})


def test_documented_defaults():
    s = Settings()
    assert s.transcriber == "auto"
    assert s.whisper_model == "small"
    assert s.groq_whisper_model == "whisper-large-v3"
    assert s.max_transcript_chars == 12000
    assert s.db_path == "talky.db"
    assert s.max_upload_mb == 100
    assert s.max_duration_s == 2700.0
    assert s.min_duration_s == 5.0
    assert s.min_models_ok == 1
    assert s.judge_provider == "gemini"
    assert s.enable_verifier is True
    assert s.enable_event_classifier is False
    assert s.enable_text_embeddings is False
    assert s.event_model_path == "models/event_classifier.joblib"
    assert s.embedding_model == "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    assert tuple(s.cors_origins) == ("*",)


def test_settings_are_immutable():
    with pytest.raises(dataclasses.FrozenInstanceError):
        Settings().db_path = "otra.db"


@pytest.mark.parametrize("raw", ["true", "TRUE", "1", "yes", "on"])
def test_truthy_flags(raw):
    assert Settings.from_env({"ENABLE_EVENT_CLASSIFIER": raw}).enable_event_classifier is True


@pytest.mark.parametrize("raw", ["false", "0", "no", "off", ""])
def test_falsy_flags(raw):
    assert Settings.from_env({"ENABLE_VERIFIER": raw}).enable_verifier is False


def test_invalid_flag_names_the_variable():
    with pytest.raises(ValueError, match="ENABLE_TEXT_EMBEDDINGS"):
        Settings.from_env({"ENABLE_TEXT_EMBEDDINGS": "quizás"})


def test_invalid_int_names_the_variable():
    with pytest.raises(ValueError, match="MAX_UPLOAD_MB"):
        Settings.from_env({"MAX_UPLOAD_MB": "mucho"})


def test_invalid_transcriber():
    with pytest.raises(ValueError, match="TRANSCRIBER"):
        Settings.from_env({"TRANSCRIBER": "azure"})


@pytest.mark.parametrize("value", ["auto", "groq", "local"])
def test_valid_transcribers(value):
    assert Settings.from_env({"TRANSCRIBER": value}).transcriber == value


def test_cors_origins_are_split_and_stripped():
    s = Settings.from_env({"CORS_ORIGINS": "http://localhost:3000, https://talky.app "})
    assert tuple(s.cors_origins) == ("http://localhost:3000", "https://talky.app")


def test_numbers_are_parsed():
    s = Settings.from_env({"MAX_TRANSCRIPT_CHARS": "5000", "MIN_MODELS_OK": "2", "MAX_DURATION_S": "600"})
    assert (s.max_transcript_chars, s.min_models_ok, s.max_duration_s) == (5000, 2, 600.0)


class TestProviders:
    def test_no_provider_without_credentials(self):
        assert Settings.from_env({}).llm_provider_specs() == []

    def test_groq_needs_key_and_model(self):
        assert Settings.from_env({"GROQ_API_KEY": "k"}).llm_provider_specs() == []
        assert Settings.from_env({"GROQ_MODEL": "m"}).llm_provider_specs() == []

    def test_single_groq_model(self):
        specs = Settings.from_env({"GROQ_API_KEY": "k", "GROQ_MODEL": "openai/gpt-oss-120b"}).llm_provider_specs()
        assert len(specs) == 1
        spec = specs[0]
        assert (spec.name, spec.api_key, spec.model) == ("groq", "k", "openai/gpt-oss-120b")
        assert spec.base_url == "https://api.groq.com/openai/v1"

    def test_several_groq_models_become_several_providers(self):
        env = {"GROQ_API_KEY": "k", "GROQ_MODEL": "openai/gpt-oss-120b, openai/gpt-oss-20b"}
        specs = Settings.from_env(env).llm_provider_specs()
        assert [s.model for s in specs] == ["openai/gpt-oss-120b", "openai/gpt-oss-20b"]
        assert [s.name for s in specs] == ["groq:openai/gpt-oss-120b", "groq:openai/gpt-oss-20b"]

    def test_gemini_and_ollama(self):
        env = {"GEMINI_API_KEY": "g", "GEMINI_MODEL": "gemini-flash", "OLLAMA_MODEL": "llama3"}
        specs = {s.name: s for s in Settings.from_env(env).llm_provider_specs()}
        assert specs["gemini"].base_url == "https://generativelanguage.googleapis.com/v1beta/openai/"
        assert specs["ollama"].base_url == "http://localhost:11434/v1"
        assert specs["ollama"].api_key == "ollama"

    def test_groq_enabled(self):
        assert Settings.from_env({"GROQ_API_KEY": "k"}).groq_enabled is True
        assert Settings.from_env({}).groq_enabled is False
