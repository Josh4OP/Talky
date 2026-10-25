"""Raíz de composición: el único módulo que conoce todos los adaptadores y los ensambla."""

import importlib
import importlib.util
import logging
from dataclasses import dataclass, field
from pathlib import Path

from src.application.routing.input_router import RoutingSettings
from src.application.routing.llm_router import LLMRouter
from src.application.routing.transcriber_router import LazyTranscriber, RoutedTranscriber
from src.application.services.ensemble import EnsembleAnalyzer
from src.application.use_cases.analyze_presentation import AnalyzePresentation
from src.config.settings import ENDPOINTS, ProviderConfig, Settings
from src.domain.entities.analysis import Analisis, Sintesis
from src.domain.exceptions import ConfigurationError
from src.domain.interfaces.ports import (
    AnalysisRepository,
    EventClassifier,
    LLMProvider,
    TextEmbedder,
    TokenService,
    Transcriber,
)

logger = logging.getLogger("talky.config")

# Pocos reintentos: un 429 debe llegar pronto al enrutador para probar otro proveedor.
_LLM_MAX_RETRIES = 2
_WHISPER_MAX_RETRIES = 1
_GROQ_UPLOAD_LIMIT = 25 * 1024 * 1024
_STRICT_MODEL_MARKERS = ("gpt-oss", "qwen")
# Se valida aquí, antes de importar PyJWT, para que el error de configuración sea claro aunque falte la librería.
_MIN_JWT_SECRET_CHARS = 32

NO_LLM = (
    "No hay ningún LLM configurado. Define GROQ_API_KEY y GROQ_MODEL (o GEMINI_API_KEY y GEMINI_MODEL, u OLLAMA_MODEL)."
)
GROQ_KEY_REQUIRED = "TRANSCRIBER=groq requiere GROQ_API_KEY."
LOCAL_REQUIRED = "TRANSCRIBER=local requiere faster-whisper: instala requirements-local.txt."
NO_TRANSCRIBER = (
    "No hay transcriptor disponible: define GROQ_API_KEY o instala faster-whisper (requirements-local.txt)."
)
NO_LOCAL_FALLBACK = (
    "La transcripción local de respaldo no está disponible (falta faster-whisper); si Groq falla, el análisis no podrá "
    "completarse."
)
NO_EMBEDDINGS = (
    "La coherencia temática está desactivada: falta sentence-transformers (instala requirements-embeddings.txt)."
)
NO_EVENT_MODEL = "El análisis de eventos acústicos está desactivado: no se encontró el modelo entrenado."
JWT_SECRET_REQUIRED = f"AUTH_MODE=jwt requiere JWT_SECRET de al menos {_MIN_JWT_SECRET_CHARS} caracteres."
NO_EVENT_CLASSIFIER = (
    "El análisis de eventos acústicos está desactivado: el clasificador no está disponible en esta versión."
)


@dataclass
class Container:
    settings: Settings
    use_case: AnalyzePresentation
    repository: AnalysisRepository
    warnings: list[str] = field(default_factory=list)
    token_service: TokenService | None = None


def select_judge(providers: list[LLMProvider], name: str) -> LLMProvider:
    """Proveedor con ese nombre exacto, o cuyo nombre antes de ":" coincide; si no hay, el primero."""
    exact = next((p for p in providers if p.name == name), None)
    if exact is not None:
        return exact
    return next((p for p in providers if p.name.split(":", 1)[0] == name), providers[0])


def _available(module: str) -> bool:
    return importlib.util.find_spec(module) is not None


def _uses_strict_schema(spec: ProviderConfig) -> bool:
    return spec.name.split(":", 1)[0] == "groq" and any(m in spec.model for m in _STRICT_MODEL_MARKERS)


def _real_llms(settings: Settings) -> tuple[list[LLMProvider], list[LLMProvider]]:
    """Dos instancias por proveedor, una por rol, porque analista y juez usan esquemas distintos."""
    from src.infrastructure.external.json_schema import strict_json_schema
    from src.infrastructure.external.openai_compatible_llm import OpenAICompatibleLLM

    analysts, judges = [], []
    for spec in settings.llm_provider_specs():
        strict = _uses_strict_schema(spec)
        for output_model, target in ((Analisis, analysts), (Sintesis, judges)):
            target.append(
                OpenAICompatibleLLM(
                    spec.name,
                    spec.base_url,
                    spec.api_key,
                    spec.model,
                    max_retries=_LLM_MAX_RETRIES,
                    json_schema=strict_json_schema(output_model) if strict else None,
                )
            )
    return analysts, judges


def _ensemble(settings: Settings, llm_providers: list[LLMProvider] | None) -> EnsembleAnalyzer:
    if llm_providers is not None:
        analysts, judges = list(llm_providers), list(llm_providers)
    else:
        analysts, judges = _real_llms(settings)
    if not analysts:
        raise ConfigurationError(NO_LLM)
    judge = select_judge(judges, settings.judge_provider)
    router = LLMRouter([judge, *(j for j in judges if j is not judge)])
    return EnsembleAnalyzer(analysts, judge=router, min_ok=settings.min_models_ok)


def _groq_transcriber(settings: Settings) -> Transcriber:
    from openai import OpenAI

    from src.infrastructure.external.groq_transcriber import GroqTranscriber

    client = OpenAI(base_url=ENDPOINTS["groq"], api_key=settings.groq_api_key, max_retries=_WHISPER_MAX_RETRIES)
    return GroqTranscriber(client, model=settings.groq_whisper_model)


def _local_transcriber(settings: Settings) -> Transcriber:
    from src.infrastructure.external.whisper_transcriber import WhisperTranscriber

    # El modelo pesa cientos de MB: se carga en la primera petición que lo necesite, no al arrancar.
    return LazyTranscriber(lambda: WhisperTranscriber(settings.whisper_model))


def _transcriber(settings: Settings, warnings: list[str]) -> Transcriber:
    from src.infrastructure.audio import compress_for_upload, probe_audio

    mode = settings.transcriber
    if mode == "groq" and not settings.groq_enabled:
        raise ConfigurationError(GROQ_KEY_REQUIRED)
    if mode == "local" and not _available("faster_whisper"):
        raise ConfigurationError(LOCAL_REQUIRED)

    groq = _groq_transcriber(settings) if mode in ("auto", "groq") and settings.groq_enabled else None
    local = None
    if mode in ("auto", "local"):
        if _available("faster_whisper"):
            local = _local_transcriber(settings)
        elif groq is not None:
            warnings.append(NO_LOCAL_FALLBACK)
    if groq is None and local is None:
        raise ConfigurationError(NO_TRANSCRIBER)

    routing = RoutingSettings(
        groq_enabled=groq is not None,
        groq_max_bytes=_GROQ_UPLOAD_LIMIT,
        min_duration_s=settings.min_duration_s,
        max_duration_s=settings.max_duration_s,
    )
    return RoutedTranscriber(groq, local, routing, probe_audio, compressor=compress_for_upload)


def _embedder(settings: Settings, provided: TextEmbedder | None, warnings: list[str]) -> TextEmbedder | None:
    if not settings.enable_text_embeddings:
        return None
    if provided is not None:
        return provided
    if not _available("sentence_transformers"):
        warnings.append(NO_EMBEDDINGS)
        return None
    from src.infrastructure.ml.sentence_embedder import SentenceTransformerEmbedder

    return SentenceTransformerEmbedder(settings.embedding_model)


def _event_classifier(
    settings: Settings, provided: EventClassifier | None, warnings: list[str]
) -> EventClassifier | None:
    if not settings.enable_event_classifier:
        return None
    if provided is not None:
        return provided
    if not Path(settings.event_model_path).is_file():
        warnings.append(NO_EVENT_MODEL)
        return None
    # T10 y T11 están aplazadas (decisión D-11): sin esos módulos la etapa se omite con un aviso.
    try:
        classifier_module = importlib.import_module("src.infrastructure.ml.event_classifier")
        model_module = importlib.import_module("src.infrastructure.ml.event_model")
        model = model_module.EventModel.load(settings.event_model_path)
        return classifier_module.SklearnEventClassifier(model)
    except Exception as e:  # noqa: BLE001
        logger.warning("No se pudo cargar el clasificador de eventos (%s)", type(e).__name__)
        warnings.append(NO_EVENT_CLASSIFIER)
        return None


def _repository(settings: Settings, provided: AnalysisRepository | None) -> AnalysisRepository:
    if provided is not None:
        return provided
    from src.infrastructure.repositories.sqlite_analysis_repository import SqliteAnalysisRepository

    return SqliteAnalysisRepository(settings.db_path)


def _token_service(settings: Settings, provided: TokenService | None) -> TokenService | None:
    if settings.auth_mode != "jwt":
        return None
    if provided is not None:
        return provided
    if len(settings.jwt_secret) < _MIN_JWT_SECRET_CHARS:
        raise ConfigurationError(JWT_SECRET_REQUIRED)
    from src.infrastructure.security.jwt_tokens import JwtTokenService

    return JwtTokenService(settings.jwt_secret, settings.jwt_ttl_days * 86400)


def build_container(
    settings: Settings,
    *,
    transcriber: Transcriber | None = None,
    llm_providers: list[LLMProvider] | None = None,
    embedder: TextEmbedder | None = None,
    event_classifier: EventClassifier | None = None,
    repository: AnalysisRepository | None = None,
    token_service: TokenService | None = None,
) -> Container:
    warnings: list[str] = []
    tokens = _token_service(settings, token_service)
    ensemble = _ensemble(settings, llm_providers)
    use_case = AnalyzePresentation(
        transcriber if transcriber is not None else _transcriber(settings, warnings),
        ensemble,
        max_chars=settings.max_transcript_chars,
        embedder=_embedder(settings, embedder, warnings),
        event_classifier=_event_classifier(settings, event_classifier, warnings),
        verify=settings.enable_verifier,
    )
    for warning in warnings:
        logger.warning(warning)
    return Container(settings, use_case, _repository(settings, repository), warnings, tokens)
