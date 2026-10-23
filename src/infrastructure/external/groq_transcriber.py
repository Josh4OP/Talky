"""Transcripción con Whisper en Groq mediante un cliente compatible con OpenAI."""

import logging

from src.domain.exceptions import InvalidAudioError, ProviderError, RateLimitedError
from src.domain.interfaces.ports import Segment, Transcriber, Transcription, Word

logger = logging.getLogger("talky.transcription")

# Sesga a Whisper a escribir las muletillas en vez de omitirlas (Groq admite hasta 224 tokens).
DEFAULT_PROMPT = "Eh, bueno, o sea, mmm, este... digamos que, como que, ¿no? Entonces, eh..."


def _field(obj, name: str):
    return obj.get(name) if isinstance(obj, dict) else getattr(obj, name, None)


def _retry_after(error: Exception) -> float | None:
    headers = getattr(getattr(error, "response", None), "headers", None) or {}
    try:
        return float(headers.get("retry-after"))
    except (TypeError, ValueError):
        return None


def _translate_error(error: Exception) -> Exception:
    status = getattr(error, "status_code", None)
    if status == 429:
        return RateLimitedError("Groq limitó la transcripción por cuota", retry_after=_retry_after(error))
    if status == 413:
        return InvalidAudioError("El audio es demasiado grande para el servicio de transcripción.")
    if status == 400:
        return InvalidAudioError("El servicio de transcripción rechazó el audio por formato o contenido no válido.")
    return ProviderError(f"Groq no pudo transcribir el audio (HTTP {status})" if status else "Groq no respondió")


def _to_transcription(response) -> Transcription:
    segments = [
        Segment(float(_field(s, "start")), float(_field(s, "end")), (_field(s, "text") or "").strip())
        for s in _field(response, "segments") or []
    ]
    words = [
        Word(float(_field(w, "start")), float(_field(w, "end")), (_field(w, "word") or "").strip())
        for w in _field(response, "words") or []
    ]
    duration = _field(response, "duration")
    if duration is None:
        duration = segments[-1].end if segments else 0.0
    return Transcription(
        text=(_field(response, "text") or "").strip(),
        segments=segments,
        duration=float(duration),
        words=words,
    )


class GroqTranscriber(Transcriber):
    """Whisper large-v3 en Groq; el cliente se inyecta para poder probarlo sin red."""

    def __init__(self, client, model: str = "whisper-large-v3", language: str = "es", prompt: str = DEFAULT_PROMPT):
        self._client = client
        self._model = model
        self._language = language
        self._prompt = prompt

    def transcribe(self, audio_path: str) -> Transcription:
        with open(audio_path, "rb") as audio:
            try:
                response = self._client.audio.transcriptions.create(
                    file=audio,
                    model=self._model,
                    language=self._language,
                    prompt=self._prompt,
                    response_format="verbose_json",
                    timestamp_granularities=["word", "segment"],
                    temperature=0,
                )
            except Exception as e:  # noqa: BLE001
                logger.warning("Groq falló al transcribir (%s)", type(e).__name__)
                raise _translate_error(e) from e
        return _to_transcription(response)
