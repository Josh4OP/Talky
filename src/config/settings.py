"""Configuración tipada de TALKY: el único lugar que lee variables de entorno."""

import os
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field, fields

ENDPOINTS = {
    "groq": "https://api.groq.com/openai/v1",
    "gemini": "https://generativelanguage.googleapis.com/v1beta/openai/",
    "ollama": "http://localhost:11434/v1",
}
TRANSCRIBER_MODES = ("auto", "groq", "local")
AUTH_MODES = ("header", "jwt")
_TRUE = {"true", "1", "yes", "on"}
_FALSE = {"false", "0", "no", "off", ""}


@dataclass(frozen=True)
class ProviderConfig:
    name: str
    base_url: str
    api_key: str = field(repr=False)
    model: str


def _bool(var: str, raw: str) -> bool:
    value = raw.strip().lower()
    if value in _TRUE:
        return True
    if value in _FALSE:
        return False
    raise ValueError(f"{var} debe ser true o false (se recibió {raw!r})")


def _number(cast: Callable[[str], float]) -> Callable[[str, str], float]:
    def parse(var: str, raw: str) -> float:
        try:
            value = cast(raw.strip())
        except ValueError:
            raise ValueError(f"{var} debe ser un número (se recibió {raw!r})") from None
        if value <= 0:
            raise ValueError(f"{var} debe ser mayor que cero (se recibió {raw!r})")
        return value

    return parse


def _text(var: str, raw: str) -> str:
    return raw.strip()


def _choice(options: tuple[str, ...]) -> Callable[[str, str], str]:
    def parse(var: str, raw: str) -> str:
        value = raw.strip().lower()
        if value not in options:
            raise ValueError(f"{var} debe ser uno de {', '.join(options)} (se recibió {raw!r})")
        return value

    return parse


def _origins(var: str, raw: str) -> tuple[str, ...]:
    return tuple(o.strip() for o in raw.split(",") if o.strip())


def _models(raw: str) -> list[str]:
    return [m.strip() for m in raw.split(",") if m.strip()]


@dataclass(frozen=True)
class Settings:
    groq_api_key: str = field(default="", repr=False)
    groq_model: str = ""
    gemini_api_key: str = field(default="", repr=False)
    gemini_model: str = ""
    ollama_model: str = ""
    judge_provider: str = "gemini"
    min_models_ok: int = 1
    transcriber: str = "auto"
    whisper_model: str = "small"
    groq_whisper_model: str = "whisper-large-v3"
    max_transcript_chars: int = 12000
    db_path: str = "talky.db"
    max_upload_mb: int = 100
    max_duration_s: float = 2700.0
    min_duration_s: float = 5.0
    enable_verifier: bool = True
    enable_text_embeddings: bool = False
    embedding_model: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    enable_event_classifier: bool = False
    event_model_path: str = "models/event_classifier.joblib"
    cors_origins: tuple[str, ...] = ("*",)
    auth_mode: str = "header"
    jwt_secret: str = field(default="", repr=False)
    jwt_ttl_days: int = 30

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> "Settings":
        source = os.environ if env is None else env
        values = {}
        for f in fields(cls):
            var = f.name.upper()
            raw = source.get(var)
            if raw is None:
                continue
            parse = _PARSERS[f.name]
            # Una variable vacía (VAR=) en texto o números conserva el valor por defecto; en banderas es false.
            if not raw.strip() and parse is not _bool:
                continue
            values[f.name] = parse(var, raw)
        settings = cls(**values)
        if settings.min_duration_s >= settings.max_duration_s:
            raise ValueError("MIN_DURATION_S debe ser menor que MAX_DURATION_S")
        return settings

    @property
    def groq_enabled(self) -> bool:
        return bool(self.groq_api_key)

    def llm_provider_specs(self) -> list[ProviderConfig]:
        specs: list[ProviderConfig] = []
        if self.groq_api_key:
            specs += _specs_for("groq", self.groq_api_key, _models(self.groq_model))
        if self.gemini_api_key:
            specs += _specs_for("gemini", self.gemini_api_key, _models(self.gemini_model))
        specs += _specs_for("ollama", "ollama", _models(self.ollama_model))
        return specs


def _specs_for(provider: str, api_key: str, models: list[str]) -> list[ProviderConfig]:
    def name(model: str) -> str:
        return provider if len(models) == 1 else f"{provider}:{model}"

    return [ProviderConfig(name(m), ENDPOINTS[provider], api_key, m) for m in models]


_PARSERS: dict[str, Callable[[str, str], object]] = {
    "groq_api_key": _text,
    "groq_model": _text,
    "gemini_api_key": _text,
    "gemini_model": _text,
    "ollama_model": _text,
    "judge_provider": _text,
    "min_models_ok": _number(int),
    "transcriber": _choice(TRANSCRIBER_MODES),
    "whisper_model": _text,
    "groq_whisper_model": _text,
    "max_transcript_chars": _number(int),
    "db_path": _text,
    "max_upload_mb": _number(int),
    "max_duration_s": _number(float),
    "min_duration_s": _number(float),
    "enable_verifier": _bool,
    "enable_text_embeddings": _bool,
    "embedding_model": _text,
    "enable_event_classifier": _bool,
    "event_model_path": _text,
    "cors_origins": _origins,
    "auth_mode": _choice(AUTH_MODES),
    "jwt_secret": _text,
    "jwt_ttl_days": _number(int),
}
