"""Transcriptores compuestos: respaldo, enrutado por reglas y construcción perezosa."""

import logging
import threading
from collections.abc import Callable
from dataclasses import replace
from pathlib import Path

from src.application.routing.input_router import AudioInfo, RoutingSettings, route_input
from src.domain.exceptions import AllProvidersFailedError, InvalidAudioError
from src.domain.interfaces.ports import Transcriber, Transcription

logger = logging.getLogger("talky.routing")

FALLBACK_WARNING = "El servicio de transcripción principal no respondió; se usó el transcriptor de respaldo."


def _prepend_warnings(transcription: Transcription, warnings: list[str]) -> Transcription:
    if not warnings:
        return transcription
    return replace(transcription, warnings=[*warnings, *transcription.warnings])


def _transcribe_with_fallback(
    primary: Transcriber, primary_path: str, secondary: Transcriber, secondary_path: str
) -> Transcription:
    try:
        return primary.transcribe(primary_path)
    except InvalidAudioError:
        raise
    except Exception as primary_error:  # noqa: BLE001
        logger.warning("Transcriptor principal falló (%s); se usa el respaldo", type(primary_error).__name__)
        try:
            result = secondary.transcribe(secondary_path)
        except InvalidAudioError:
            raise
        except Exception as secondary_error:  # noqa: BLE001
            errors = {"principal": str(primary_error), "respaldo": str(secondary_error)}
            raise AllProvidersFailedError(errors) from secondary_error
    return _prepend_warnings(result, [FALLBACK_WARNING])


class FallbackTranscriber(Transcriber):
    """Usa el secundario si el primario falla, salvo que el audio sea inválido."""

    def __init__(self, primary: Transcriber, secondary: Transcriber):
        self._primary = primary
        self._secondary = secondary

    def transcribe(self, audio_path: str) -> Transcription:
        return _transcribe_with_fallback(self._primary, audio_path, self._secondary, audio_path)


class RoutedTranscriber(Transcriber):
    """Aplica route_input antes de transcribir: rechaza, elige Groq o local y comprime si hace falta."""

    def __init__(
        self,
        groq: Transcriber | None,
        local: Transcriber | None,
        settings: RoutingSettings,
        probe: Callable[[str], AudioInfo],
        compressor: Callable[[str], str] | None = None,
    ):
        if groq is None and local is None:
            raise ValueError("RoutedTranscriber necesita al menos un transcriptor")
        self._groq = groq
        self._local = local
        # Las reglas solo pueden elegir un transcriptor que exista.
        self._settings = replace(
            settings,
            groq_enabled=groq is not None and (settings.groq_enabled or local is None),
            groq_remaining_audio_s=settings.groq_remaining_audio_s if local is not None else None,
        )
        self._probe = probe
        self._compressor = compressor

    def transcribe(self, audio_path: str) -> Transcription:
        decision = route_input(self._probe(audio_path), self._settings)
        if decision.reject_code is not None:
            raise InvalidAudioError(decision.reject_reason)
        if decision.transcriber == "local":
            return _prepend_warnings(self._local.transcribe(audio_path), decision.warnings)
        return _prepend_warnings(self._transcribe_with_groq(audio_path, decision.compress), decision.warnings)

    def _transcribe_with_groq(self, audio_path: str, compress: bool) -> Transcription:
        compressed = self._compressor(audio_path) if compress and self._compressor else None
        try:
            groq_path = compressed or audio_path
            if self._local is None:
                return self._groq.transcribe(groq_path)
            return _transcribe_with_fallback(self._groq, groq_path, self._local, audio_path)
        finally:
            if compressed:
                Path(compressed).unlink(missing_ok=True)


class LazyTranscriber(Transcriber):
    """Construye el transcriptor real en el primer uso, una sola vez aunque haya hilos concurrentes."""

    def __init__(self, factory: Callable[[], Transcriber]):
        self._factory = factory
        self._inner: Transcriber | None = None
        self._lock = threading.Lock()

    def _get(self) -> Transcriber:
        if self._inner is None:
            with self._lock:
                if self._inner is None:
                    self._inner = self._factory()
        return self._inner

    def transcribe(self, audio_path: str) -> Transcription:
        return self._get().transcribe(audio_path)
