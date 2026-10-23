"""Configuración común de pytest para TALKY.

- `pytest.ini` (en la raíz del repo) define `pythonpath = .`, así que `import src...` funciona.
- pytest agrega `tests/` al sys.path, por lo que `import fakes` también funciona.
- Ningún test usa red, claves reales ni modelos pesados.
"""

from __future__ import annotations

import dataclasses
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import fakes  # noqa: E402  (después de ajustar sys.path)

_ENV_KEYS = [
    "GROQ_API_KEY",
    "GROQ_MODEL",
    "GEMINI_API_KEY",
    "GEMINI_MODEL",
    "OLLAMA_MODEL",
    "JUDGE_PROVIDER",
    "MIN_MODELS_OK",
    "TRANSCRIBER",
    "WHISPER_MODEL",
    "DB_PATH",
    "ENABLE_EVENT_CLASSIFIER",
    "ENABLE_TEXT_EMBEDDINGS",
    "ENABLE_VERIFIER",
    "CORS_ORIGINS",
]


@pytest.fixture(autouse=True)
def _isolate_env(monkeypatch):
    """Evita que las claves del desarrollador se filtren a las pruebas."""
    for key in _ENV_KEYS:
        monkeypatch.delenv(key, raising=False)


@pytest.fixture
def sample_transcription():
    return fakes.sample_transcription()


@pytest.fixture
def wav_bytes():
    return fakes.make_wav_bytes(1.0)


@pytest.fixture
def make_container(tmp_path):
    """Fábrica de contenedores con dobles. Requiere T14 (src.config.container)."""
    from src.config.container import build_container
    from src.config.settings import Settings

    def _make(*, settings: dict | None = None, transcriber=None, providers=None, embedder=None, event_classifier=None):
        values = {"db_path": str(tmp_path / "api-test.db")}
        if embedder is not None:
            values["enable_text_embeddings"] = True
        if event_classifier is not None:
            values["enable_event_classifier"] = True
        values.update(settings or {})
        cfg = dataclasses.replace(Settings(), **values)
        return build_container(
            cfg,
            transcriber=transcriber or fakes.FakeTranscriber(),
            llm_providers=providers if providers is not None else [fakes.FakeLLM("a"), fakes.FakeLLM("b")],
            embedder=embedder,
            event_classifier=event_classifier,
        )

    return _make


@pytest.fixture
def client_factory(make_container):
    """Devuelve (TestClient, container). Requiere fastapi y httpx."""
    pytest.importorskip("fastapi")
    pytest.importorskip("httpx")
    pytest.importorskip("multipart")
    from fastapi.testclient import TestClient

    from src.presentation.app import create_app

    def _make(**kwargs):
        container = make_container(**kwargs)
        return TestClient(create_app(container)), container

    return _make
