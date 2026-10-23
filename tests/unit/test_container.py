"""T14 - Raíz de composición: ensambla casos de uso y degrada con elegancia.

Contrato: src/config/container.py
  build_container(settings, *, transcriber=None, llm_providers=None, embedder=None,
                  event_classifier=None, repository=None) -> Container
  Container(settings, use_case, repository, warnings: list[str])
  select_judge(providers, name) -> LLMProvider       # coincide con name exacto o con el prefijo antes de ":"
Reglas:
  - Los argumentos `*` reemplazan la construcción real (así se prueba sin red ni modelos).
  - Las banderas ENABLE_* deciden si una etapa opcional participa: bandera apagada => None.
  - Bandera encendida pero el modelo/archivo no está => la etapa se omite y se agrega un warning.
  - Sin proveedores LLM => ConfigurationError.
  - El juez es un LLMRouter: si el juez falla, responde otro proveedor.
"""

import dataclasses

import pytest
from fakes import FakeEventClassifier, FakeLLM, FakeTranscriber, ScriptedEmbedder
from src.application.routing.llm_router import LLMRouter
from src.config.container import Container, build_container, select_judge
from src.config.settings import Settings

from src.application.use_cases.analyze_presentation import AnalyzePresentation
from src.domain.exceptions import ConfigurationError


def _build(tmp_path, settings=None, **kw):
    cfg = dataclasses.replace(Settings(), db_path=str(tmp_path / "c.db"), **(settings or {}))
    kw.setdefault("transcriber", FakeTranscriber())
    kw.setdefault("llm_providers", [FakeLLM("a"), FakeLLM("b")])
    return build_container(cfg, **kw)


def test_builds_a_container_with_overrides(tmp_path):
    c = _build(tmp_path)
    assert isinstance(c, Container)
    assert isinstance(c.use_case, AnalyzePresentation)
    assert c.repository is not None
    assert c.warnings == []


def test_disabled_flags_ignore_provided_optional_stages(tmp_path):
    c = _build(tmp_path, embedder=ScriptedEmbedder([[1, 0]]), event_classifier=FakeEventClassifier())
    assert c.use_case.embedder is None
    assert c.use_case.event_classifier is None


def test_enabled_flags_use_provided_stages(tmp_path):
    emb, clf = ScriptedEmbedder([[1, 0]]), FakeEventClassifier()
    c = _build(
        tmp_path, {"enable_text_embeddings": True, "enable_event_classifier": True}, embedder=emb, event_classifier=clf
    )
    assert c.use_case.embedder is emb
    assert c.use_case.event_classifier is clf


def test_missing_event_model_degrades_with_a_warning(tmp_path):
    c = _build(tmp_path, {"enable_event_classifier": True, "event_model_path": str(tmp_path / "no-existe.joblib")})
    assert c.use_case.event_classifier is None
    assert any("evento" in w.lower() for w in c.warnings)


def test_no_providers_is_a_configuration_error(tmp_path):
    with pytest.raises(ConfigurationError):
        _build(tmp_path, llm_providers=[])


def test_configuration_error_is_a_value_error():
    assert issubclass(ConfigurationError, ValueError)


def test_groq_transcriber_mode_without_key_is_a_configuration_error(tmp_path):
    cfg = dataclasses.replace(Settings(), db_path=str(tmp_path / "c.db"), transcriber="groq")
    with pytest.raises(ConfigurationError, match="GROQ_API_KEY"):
        build_container(cfg, llm_providers=[FakeLLM("a")])


class TestSelectJudge:
    def test_exact_name(self):
        a, b = FakeLLM("groq"), FakeLLM("gemini")
        assert select_judge([a, b], "gemini") is b

    def test_prefix_before_colon(self):
        a, b = FakeLLM("groq:openai/gpt-oss-120b"), FakeLLM("gemini")
        assert select_judge([b, a], "groq") is a

    def test_falls_back_to_the_first_provider(self):
        a, b = FakeLLM("a"), FakeLLM("b")
        assert select_judge([a, b], "inexistente") is a


def test_judge_is_wrapped_in_a_router(tmp_path):
    c = _build(tmp_path)
    assert isinstance(c.use_case.ensemble.judge, LLMRouter)
