"""T06 - Reglas de los transcriptores que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md, sección groq_transcriber.py y whisper_transcriber.py
  - GroqTranscriber: errores sin código HTTP (red caída) son ProviderError; retry-after ilegible es None;
    acepta respuestas como diccionario; sin segmentos ni duración, la duración es 0.0.
  - WhisperTranscriber: importa faster_whisper solo al construirse, pide word_timestamps, VAD y el prompt
    de muletillas, y llena words.
"""

import math
import struct
import sys
import wave
from types import ModuleType, SimpleNamespace

import pytest

from src.domain.exceptions import ProviderError, RateLimitedError
from src.infrastructure.external.groq_transcriber import DEFAULT_PROMPT, GroqTranscriber


def _client(response=None, error=None):
    def create(**kwargs):
        if error:
            raise error
        return response

    return SimpleNamespace(audio=SimpleNamespace(transcriptions=SimpleNamespace(create=create)))


@pytest.fixture
def audio_file(tmp_path):
    path = tmp_path / "charla.wav"
    path.write_bytes(b"RIFF....fake")
    return str(path)


class _HttpError(Exception):
    def __init__(self, status_code, headers):
        super().__init__(f"HTTP {status_code}")
        self.status_code = status_code
        self.response = SimpleNamespace(headers=headers)


def test_errors_without_status_code_are_provider_errors(audio_file):
    with pytest.raises(ProviderError) as exc:
        GroqTranscriber(_client(error=ConnectionError("sin red"))).transcribe(audio_file)
    assert not isinstance(exc.value, RateLimitedError)


def test_unparseable_retry_after_is_none(audio_file):
    error = _HttpError(429, {"retry-after": "Wed, 21 Oct 2026 07:28:00 GMT"})
    with pytest.raises(RateLimitedError) as exc:
        GroqTranscriber(_client(error=error)).transcribe(audio_file)
    assert exc.value.retry_after is None


def test_dict_responses_are_accepted(audio_file):
    response = {
        "text": " Hola. ",
        "duration": 1.5,
        "segments": [{"start": 0.0, "end": 1.5, "text": " Hola. "}],
        "words": [{"word": " Hola.", "start": 0.1, "end": 0.5}],
    }
    result = GroqTranscriber(_client(response)).transcribe(audio_file)
    assert (result.text, result.duration, result.words[0].text) == ("Hola.", 1.5, "Hola.")


def test_no_segments_and_no_duration_gives_zero(audio_file):
    response = SimpleNamespace(text="", duration=None, segments=None, words=None)
    assert GroqTranscriber(_client(response)).transcribe(audio_file).duration == 0.0


def _fake_faster_whisper(calls):
    word = SimpleNamespace(start=0.1, end=0.4, word=" Eh,")
    segment = SimpleNamespace(
        start=0.0, end=1.0, text=" Eh, hola. ", words=[word, SimpleNamespace(start=0.5, end=0.9, word=" hola.")]
    )

    class WhisperModel:
        def __init__(self, size, **kwargs):
            calls.append(("init", size))

        def transcribe(self, audio, **kwargs):
            calls.append(("transcribe", kwargs))
            return iter([segment]), SimpleNamespace(duration=1.0)

    module = ModuleType("faster_whisper")
    module.WhisperModel = WhisperModel
    return module


def test_whisper_transcriber_requests_words_and_fills_them(tmp_path, monkeypatch):
    pytest.importorskip("av")
    path = tmp_path / "s.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(b"".join(struct.pack("<h", int(8000 * math.sin(i / 10))) for i in range(16000)))

    calls = []
    monkeypatch.setitem(sys.modules, "faster_whisper", _fake_faster_whisper(calls))
    from src.infrastructure.external.whisper_transcriber import WhisperTranscriber

    result = WhisperTranscriber("tiny").transcribe(str(path))
    kwargs = calls[1][1]
    assert calls[0] == ("init", "tiny")
    assert (kwargs["word_timestamps"], kwargs["vad_filter"], kwargs["initial_prompt"]) == (True, True, DEFAULT_PROMPT)
    assert [(w.text, w.start) for w in result.words] == [("Eh,", 0.1), ("hola.", 0.5)]
    assert result.text == "Eh, hola."
