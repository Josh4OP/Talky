"""T06 - Adaptador de transcripción con Groq (Whisper).

Contrato: src/infrastructure/external/groq_transcriber.py
  GroqTranscriber(client, model="whisper-large-v3", language="es", prompt=DEFAULT_PROMPT)
  - `client` es un cliente compatible con OpenAI: client.audio.transcriptions.create(**kwargs)
  - Pide verbose_json con timestamps por palabra y por segmento, temperature=0.
  - Traduce errores HTTP: 429 -> RateLimitedError, 400/413 -> InvalidAudioError, resto -> ProviderError.
"""

from types import SimpleNamespace

import pytest

from src.domain.exceptions import InvalidAudioError, ProviderError, RateLimitedError
from src.domain.interfaces.ports import Transcriber
from src.infrastructure.external.groq_transcriber import DEFAULT_PROMPT, GroqTranscriber


class _Transcriptions:
    def __init__(self, response=None, error=None):
        self.response = response
        self.error = error
        self.kwargs = None

    def create(self, **kwargs):
        self.kwargs = kwargs
        if self.error:
            raise self.error
        return self.response


def _client(response=None, error=None):
    transcriptions = _Transcriptions(response, error)
    return SimpleNamespace(audio=SimpleNamespace(transcriptions=transcriptions)), transcriptions


def _response(**overrides):
    base = dict(
        text="  Eh, hola a todos.  ",
        duration=4.2,
        segments=[SimpleNamespace(start=0.0, end=2.0, text=" Eh, hola a todos. ")],
        words=[
            SimpleNamespace(word=" Eh,", start=0.1, end=0.4),
            SimpleNamespace(word="hola", start=0.6, end=0.9),
        ],
    )
    base.update(overrides)
    return SimpleNamespace(**base)


@pytest.fixture
def audio_file(tmp_path):
    path = tmp_path / "charla.wav"
    path.write_bytes(b"RIFF....fake")
    return str(path)


class _HttpError(Exception):
    def __init__(self, status_code, headers=None):
        super().__init__(f"HTTP {status_code}")
        self.status_code = status_code
        self.response = SimpleNamespace(headers=headers or {})


def test_is_a_transcriber():
    client, _ = _client(_response())
    assert isinstance(GroqTranscriber(client), Transcriber)


def test_maps_the_response(audio_file):
    client, _ = _client(_response())
    result = GroqTranscriber(client).transcribe(audio_file)
    assert result.text == "Eh, hola a todos."
    assert result.duration == 4.2
    assert [(s.start, s.end, s.text) for s in result.segments] == [(0.0, 2.0, "Eh, hola a todos.")]
    assert [(w.text, w.start, w.end) for w in result.words] == [("Eh,", 0.1, 0.4), ("hola", 0.6, 0.9)]


def test_request_parameters(audio_file):
    client, transcriptions = _client(_response())
    GroqTranscriber(client, model="whisper-large-v3", language="es").transcribe(audio_file)
    kwargs = transcriptions.kwargs
    assert kwargs["model"] == "whisper-large-v3"
    assert kwargs["language"] == "es"
    assert kwargs["response_format"] == "verbose_json"
    assert set(kwargs["timestamp_granularities"]) == {"word", "segment"}
    assert kwargs["temperature"] == 0
    assert kwargs["file"] is not None


def test_default_prompt_biases_towards_fillers_and_fits_the_limit(audio_file):
    client, transcriptions = _client(_response())
    GroqTranscriber(client).transcribe(audio_file)
    assert transcriptions.kwargs["prompt"] == DEFAULT_PROMPT
    assert "eh" in DEFAULT_PROMPT.lower() and "mmm" in DEFAULT_PROMPT.lower()
    assert len(DEFAULT_PROMPT.split()) <= 100  # Groq admite 224 tokens; margen holgado


def test_missing_words_and_duration_are_tolerated(audio_file):
    client, _ = _client(_response(words=None, duration=None))
    result = GroqTranscriber(client).transcribe(audio_file)
    assert result.words == []
    assert result.duration == 2.0  # se deduce del fin del último segmento


@pytest.mark.parametrize(
    "status,expected",
    [(429, RateLimitedError), (400, InvalidAudioError), (413, InvalidAudioError), (500, ProviderError)],
)
def test_http_errors_are_translated(audio_file, status, expected):
    client, _ = _client(error=_HttpError(status))
    with pytest.raises(expected):
        GroqTranscriber(client).transcribe(audio_file)


def test_retry_after_header_is_propagated(audio_file):
    client, _ = _client(error=_HttpError(429, headers={"retry-after": "30"}))
    with pytest.raises(RateLimitedError) as exc:
        GroqTranscriber(client).transcribe(audio_file)
    assert exc.value.retry_after == 30.0
