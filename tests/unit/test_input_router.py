"""T07 - Enrutador de entrada por reglas (sin ML).

Contrato: src/application/routing/input_router.py
  AudioInfo(duration_s, size_bytes, rms_dbfs=None)
  RoutingSettings(groq_enabled=False, groq_max_bytes=25*1024*1024, min_duration_s=5.0,
                  max_duration_s=2700.0, quiet_dbfs=-45.0, groq_remaining_audio_s=None)
  RoutingDecision(transcriber, compress, warnings, reject_code, reject_reason)
  route_input(info, settings) -> RoutingDecision
"""

import pytest
from src.application.routing.input_router import AudioInfo, RoutingSettings, route_input

MB = 1024 * 1024


def _settings(**kw):
    return RoutingSettings(groq_enabled=True, **kw)


def test_happy_path_prefers_groq():
    d = route_input(AudioInfo(duration_s=600, size_bytes=5 * MB), _settings())
    assert d.transcriber == "groq"
    assert d.compress is False
    assert d.warnings == []
    assert d.reject_code is None and d.reject_reason is None


def test_without_groq_uses_local():
    d = route_input(AudioInfo(duration_s=600, size_bytes=5 * MB), RoutingSettings(groq_enabled=False))
    assert d.transcriber == "local"
    assert d.compress is False


def test_big_file_is_compressed_for_groq():
    d = route_input(AudioInfo(duration_s=1200, size_bytes=40 * MB), _settings())
    assert d.transcriber == "groq"
    assert d.compress is True


def test_big_file_is_not_compressed_for_local():
    d = route_input(AudioInfo(duration_s=1200, size_bytes=40 * MB), RoutingSettings(groq_enabled=False))
    assert d.transcriber == "local"
    assert d.compress is False


def test_too_short_is_rejected():
    d = route_input(AudioInfo(duration_s=2.0, size_bytes=MB), _settings())
    assert d.reject_code == "too_short"
    assert d.reject_reason


def test_too_long_is_rejected():
    d = route_input(AudioInfo(duration_s=3000, size_bytes=MB), _settings())
    assert d.reject_code == "too_long"


@pytest.mark.parametrize("duration", [5.0, 2700.0])
def test_limits_are_inclusive(duration):
    d = route_input(AudioInfo(duration_s=duration, size_bytes=MB), _settings())
    assert d.reject_code is None


def test_exhausted_groq_quota_falls_back_to_local_with_warning():
    d = route_input(AudioInfo(duration_s=600, size_bytes=MB), _settings(groq_remaining_audio_s=100))
    assert d.transcriber == "local"
    assert any("cuota" in w.lower() for w in d.warnings)


def test_enough_groq_quota_keeps_groq():
    d = route_input(AudioInfo(duration_s=600, size_bytes=MB), _settings(groq_remaining_audio_s=5000))
    assert d.transcriber == "groq"


def test_quiet_audio_adds_a_warning_but_is_accepted():
    d = route_input(AudioInfo(duration_s=600, size_bytes=MB, rms_dbfs=-50.0), _settings())
    assert d.reject_code is None
    assert any("bajo" in w.lower() for w in d.warnings)


def test_unknown_level_adds_no_warning():
    d = route_input(AudioInfo(duration_s=600, size_bytes=MB, rms_dbfs=None), _settings())
    assert d.warnings == []
