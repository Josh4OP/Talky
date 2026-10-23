"""T07 - Reglas de los enrutadores que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md, sección Enrutadores, y puntos finos de la tarea T07
  - route_input valida la duración antes que cualquier otra regla y explica el rechazo en español.
  - RoutedTranscriber borra el comprimido aunque la transcripción falle.
  - Las advertencias de la decisión van antes que la del respaldo y no mutan la transcripción original.
  - Sin transcriptor local, una cuota agotada no puede desviar a local: se usa Groq.
  - FallbackTranscriber avisa con "respaldo"; un InvalidAudioError del secundario se propaga.
  - LazyTranscriber construye el real una sola vez con hilos concurrentes.
  - LLMRouter informa como error a los proveedores en enfriamiento.
"""

import threading

import pytest
from fakes import FakeLLM, FakeTranscriber, sample_transcription

from src.application.routing.input_router import AudioInfo, RoutingSettings, route_input
from src.application.routing.llm_router import LLMRouter
from src.application.routing.transcriber_router import FallbackTranscriber, LazyTranscriber, RoutedTranscriber
from src.domain.exceptions import AllProvidersFailedError, InvalidAudioError, ProviderError, RateLimitedError

MB = 1024 * 1024


def _probe(duration=600.0, size=5 * MB, rms=None):
    return lambda path: AudioInfo(duration_s=duration, size_bytes=size, rms_dbfs=rms)


def test_duration_is_checked_before_quota_volume_and_size():
    settings = RoutingSettings(groq_enabled=True, groq_remaining_audio_s=0)
    d = route_input(AudioInfo(duration_s=1.0, size_bytes=99 * MB, rms_dbfs=-90.0), settings)
    assert d.reject_code == "too_short"
    assert d.warnings == [] and d.compress is False


@pytest.mark.parametrize("duration,code,word", [(2.0, "too_short", "mínimo"), (3000.0, "too_long", "máximo")])
def test_rejection_reason_explains_the_limit_in_spanish(duration, code, word):
    d = route_input(AudioInfo(duration_s=duration, size_bytes=MB), RoutingSettings())
    assert (d.reject_code, word in d.reject_reason) == (code, True)


def test_compressed_file_is_deleted_even_when_transcription_fails(tmp_path):
    compressed = tmp_path / "small.flac"
    compressed.write_bytes(b"x")
    groq = FakeTranscriber(error=InvalidAudioError("corrupto"))
    routed = RoutedTranscriber(
        groq, None, RoutingSettings(groq_enabled=True), _probe(size=40 * MB), compressor=lambda p: str(compressed)
    )
    with pytest.raises(InvalidAudioError):
        routed.transcribe("big.wav")
    assert not compressed.exists()


def test_local_fallback_receives_the_original_file_not_the_compressed_one(tmp_path):
    compressed = tmp_path / "small.flac"
    compressed.write_bytes(b"x")
    groq, local = FakeTranscriber(error=RateLimitedError()), FakeTranscriber()
    routed = RoutedTranscriber(
        groq, local, RoutingSettings(groq_enabled=True), _probe(size=40 * MB), compressor=lambda p: str(compressed)
    )
    routed.transcribe("big.wav")
    assert groq.paths == [str(compressed)] and local.paths == ["big.wav"]


def test_decision_warnings_come_first_and_the_original_is_not_mutated():
    original = sample_transcription()
    local = FakeTranscriber(original)
    routed = RoutedTranscriber(
        FakeTranscriber(error=ProviderError("caído")), local, RoutingSettings(groq_enabled=True), _probe(rms=-60.0)
    )
    first = routed.transcribe("a.wav")
    second = routed.transcribe("a.wav")
    assert "bajo" in first.warnings[0].lower() and "respaldo" in first.warnings[1].lower()
    assert second.warnings == first.warnings
    assert original.warnings == []


def test_without_local_an_exhausted_quota_still_uses_groq():
    groq = FakeTranscriber()
    routed = RoutedTranscriber(groq, None, RoutingSettings(groq_enabled=True, groq_remaining_audio_s=1), _probe())
    result = routed.transcribe("a.wav")
    assert groq.paths == ["a.wav"]
    assert not any("cuota" in w.lower() for w in result.warnings)


def test_fallback_transcriber_warns_about_the_backup():
    result = FallbackTranscriber(FakeTranscriber(error=ProviderError("caído")), FakeTranscriber()).transcribe("a.wav")
    assert any("respaldo" in w.lower() for w in result.warnings)


def test_invalid_audio_from_the_secondary_is_propagated():
    primary = FakeTranscriber(error=ProviderError("caído"))
    secondary = FakeTranscriber(error=InvalidAudioError("sin voz"))
    with pytest.raises(InvalidAudioError):
        FallbackTranscriber(primary, secondary).transcribe("a.wav")


def test_lazy_transcriber_builds_once_with_concurrent_threads():
    built = []
    barrier = threading.Barrier(8)

    def factory():
        built.append(1)
        return FakeTranscriber()

    lazy = LazyTranscriber(factory)

    def work():
        barrier.wait()
        lazy.transcribe("a.wav")

    threads = [threading.Thread(target=work) for _ in range(8)]
    [t.start() for t in threads]
    [t.join() for t in threads]
    assert built == [1]


def test_cooling_down_providers_are_reported_in_the_errors():
    clock = [1000.0]
    a = FakeLLM("a", fail_analysis=RateLimitedError())
    router = LLMRouter([a], cooldown_s=60, clock=lambda: clock[0])
    with pytest.raises(AllProvidersFailedError):
        router.complete_json("s", "u")
    with pytest.raises(AllProvidersFailedError) as exc:
        router.complete_json("s", "u")
    assert "enfriamiento" in exc.value.errors["a"]
