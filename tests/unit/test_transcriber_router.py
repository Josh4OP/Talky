"""T07 - Transcriptores compuestos: respaldo (Groq -> local) y enrutado por reglas.

Contrato: src/application/routing/transcriber_router.py
  FallbackTranscriber(primary, secondary)   # es un Transcriber
  - Si primary falla (RateLimitedError, ProviderError o cualquier Exception) usa secondary.
  - Si primary lanza InvalidAudioError NO hay respaldo: el archivo es el problema.
  - Si ambos fallan lanza AllProvidersFailedError con los dos errores.

  RoutedTranscriber(groq, local, settings: RoutingSettings, probe, compressor=None)   # es un Transcriber
  - probe(path) -> AudioInfo; aplica route_input(); si hay reject_code lanza InvalidAudioError
    SIN llamar a ningún transcriptor.
  - Usa groq si la decisión lo indica y existe; si groq falla por cuota/proveedor usa local y agrega
    una advertencia que contiene "respaldo". Las advertencias de la decisión se copian a
    Transcription.warnings.
  - Si la decisión pide comprimir y hay compressor, transcribe el archivo comprimido y lo borra después.
  - Se necesita al menos un transcriptor (si ambos son None: ValueError).

  LazyTranscriber(factory)    # construye el transcriptor real en el primer uso (una sola vez)
"""

import os

import pytest
from fakes import FakeTranscriber, sample_transcription
from src.application.routing.input_router import AudioInfo, RoutingSettings
from src.application.routing.transcriber_router import (
    FallbackTranscriber,
    LazyTranscriber,
    RoutedTranscriber,
)

from src.domain.exceptions import (
    AllProvidersFailedError,
    InvalidAudioError,
    ProviderError,
    RateLimitedError,
)
from src.domain.interfaces.ports import Transcriber


def test_is_a_transcriber():
    assert isinstance(FallbackTranscriber(FakeTranscriber(), FakeTranscriber()), Transcriber)


def test_uses_primary_when_it_works():
    primary, secondary = FakeTranscriber(), FakeTranscriber()
    FallbackTranscriber(primary, secondary).transcribe("a.wav")
    assert primary.paths == ["a.wav"] and secondary.paths == []


@pytest.mark.parametrize("error", [RateLimitedError(), ProviderError("caído"), RuntimeError("inesperado")])
def test_falls_back_to_secondary(error):
    primary = FakeTranscriber(error=error)
    secondary = FakeTranscriber(sample_transcription())
    result = FallbackTranscriber(primary, secondary).transcribe("a.wav")
    assert result.text == sample_transcription().text
    assert secondary.paths == ["a.wav"]


def test_invalid_audio_is_not_retried():
    primary = FakeTranscriber(error=InvalidAudioError("archivo corrupto"))
    secondary = FakeTranscriber()
    with pytest.raises(InvalidAudioError):
        FallbackTranscriber(primary, secondary).transcribe("a.wav")
    assert secondary.paths == []


def test_both_failing_reports_both_errors():
    primary = FakeTranscriber(error=ProviderError("groq caído"))
    secondary = FakeTranscriber(error=ProviderError("local caído"))
    with pytest.raises(AllProvidersFailedError) as exc:
        FallbackTranscriber(primary, secondary).transcribe("a.wav")
    assert len(exc.value.errors) == 2


# --------------------------------------------------------------------------- #
# RoutedTranscriber
# --------------------------------------------------------------------------- #
MB = 1024 * 1024


def _probe(duration=600.0, size=5 * MB, rms=None):
    return lambda path: AudioInfo(duration_s=duration, size_bytes=size, rms_dbfs=rms)


def _routed(groq, local, *, probe=None, compressor=None, **settings):
    cfg = RoutingSettings(groq_enabled=groq is not None, **settings)
    return RoutedTranscriber(groq, local, cfg, probe or _probe(), compressor=compressor)


def test_routed_prefers_groq():
    groq, local = FakeTranscriber(), FakeTranscriber()
    _routed(groq, local).transcribe("a.wav")
    assert groq.paths == ["a.wav"] and local.paths == []


def test_routed_rejects_before_calling_anyone():
    groq, local = FakeTranscriber(), FakeTranscriber()
    with pytest.raises(InvalidAudioError):
        _routed(groq, local, probe=_probe(duration=2.0)).transcribe("a.wav")
    assert groq.paths == [] and local.paths == []


def test_routed_uses_local_when_groq_quota_is_exhausted():
    groq, local = FakeTranscriber(), FakeTranscriber()
    result = _routed(groq, local, groq_remaining_audio_s=10).transcribe("a.wav")
    assert groq.paths == [] and local.paths == ["a.wav"]
    assert any("cuota" in w.lower() for w in result.warnings)


def test_routed_falls_back_to_local_when_groq_is_rate_limited():
    groq = FakeTranscriber(error=RateLimitedError())
    local = FakeTranscriber()
    result = _routed(groq, local).transcribe("a.wav")
    assert local.paths == ["a.wav"]
    assert any("respaldo" in w.lower() for w in result.warnings)


def test_routed_does_not_retry_invalid_audio_on_local():
    groq = FakeTranscriber(error=InvalidAudioError("corrupto"))
    local = FakeTranscriber()
    with pytest.raises(InvalidAudioError):
        _routed(groq, local).transcribe("a.wav")
    assert local.paths == []


def test_routed_without_groq_uses_local():
    local = FakeTranscriber()
    _routed(None, local).transcribe("a.wav")
    assert local.paths == ["a.wav"]


def test_routed_without_any_transcriber_is_a_programming_error():
    with pytest.raises(ValueError):
        _routed(None, None)


def test_routed_copies_decision_warnings():
    result = _routed(FakeTranscriber(), None, probe=_probe(rms=-55.0)).transcribe("a.wav")
    assert any("bajo" in w.lower() for w in result.warnings)


def test_routed_compresses_big_files_and_cleans_up(tmp_path):
    compressed = tmp_path / "small.flac"
    compressed.write_bytes(b"x")
    seen = []
    groq = FakeTranscriber()

    def compressor(path):
        seen.append(path)
        return str(compressed)

    _routed(groq, None, probe=_probe(size=40 * MB), compressor=compressor).transcribe("big.wav")
    assert seen == ["big.wav"]
    assert groq.paths == [str(compressed)]
    assert not os.path.exists(compressed)


# --------------------------------------------------------------------------- #
# LazyTranscriber
# --------------------------------------------------------------------------- #
def test_lazy_transcriber_builds_once_on_first_use():
    built = []
    inner = FakeTranscriber()

    def factory():
        built.append(1)
        return inner

    lazy = LazyTranscriber(factory)
    assert built == []
    lazy.transcribe("a.wav")
    lazy.transcribe("b.wav")
    assert built == [1]
    assert inner.paths == ["a.wav", "b.wav"]
    assert isinstance(lazy, Transcriber)
