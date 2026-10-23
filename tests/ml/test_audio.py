"""T06 - Utilidades de audio (PyAV).

Contrato: src/infrastructure/audio.py   (requiere numpy y av)
  load_audio(path) -> np.ndarray                 # float32, mono, 16 kHz, rango [-1, 1]
  probe_audio(path) -> AudioInfo                 # duration_s, size_bytes, rms_dbfs (piso -120.0)
  compress_for_upload(path) -> str               # ruta de un archivo temporal 16 kHz mono más liviano
Errores: archivo ilegible -> InvalidAudioError.
"""

import math
import os
import struct
import wave

import pytest

np = pytest.importorskip("numpy")
pytest.importorskip("av")

from src.application.routing.input_router import AudioInfo  # noqa: E402
from src.infrastructure.audio import compress_for_upload, load_audio, probe_audio  # noqa: E402

from src.domain.exceptions import InvalidAudioError  # noqa: E402


def _write_sine(path, seconds=1.0, sr=44100, channels=2, amp=0.3, freq=440.0):
    n = int(seconds * sr)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for i in range(n):
            v = int(amp * 32767 * math.sin(2 * math.pi * freq * i / sr))
            frames += struct.pack("<h", v) * channels
        w.writeframes(bytes(frames))


def test_load_audio_resamples_to_16k_mono(tmp_path):
    p = tmp_path / "s.wav"
    _write_sine(p, seconds=1.0, sr=44100, channels=2)
    x = load_audio(str(p))
    assert x.dtype == np.float32 and x.ndim == 1
    assert abs(len(x) - 16000) < 400
    assert np.abs(x).max() <= 1.0


def test_probe_audio(tmp_path):
    p = tmp_path / "s.wav"
    _write_sine(p, seconds=2.0, sr=16000, channels=1, amp=0.3)
    info = probe_audio(str(p))
    assert isinstance(info, AudioInfo)
    assert info.duration_s == pytest.approx(2.0, abs=0.1)
    assert info.size_bytes == os.path.getsize(p)
    assert info.rms_dbfs == pytest.approx(-13.5, abs=1.0)


def test_probe_of_digital_silence_has_a_floor(tmp_path):
    p = tmp_path / "z.wav"
    _write_sine(p, seconds=1.0, sr=16000, channels=1, amp=0.0)
    assert probe_audio(str(p)).rms_dbfs == -120.0


def test_unreadable_files_raise_invalid_audio(tmp_path):
    p = tmp_path / "basura.wav"
    p.write_bytes(os.urandom(2048))
    with pytest.raises(InvalidAudioError):
        load_audio(str(p))
    with pytest.raises(InvalidAudioError):
        probe_audio(str(p))


def test_compress_for_upload_makes_a_smaller_16k_mono_file(tmp_path):
    p = tmp_path / "big.wav"
    _write_sine(p, seconds=3.0, sr=44100, channels=2)
    out = compress_for_upload(str(p))
    try:
        assert os.path.exists(out) and out != str(p)
        assert os.path.getsize(out) < os.path.getsize(p)
        assert abs(len(load_audio(out)) - 3 * 16000) < 1600
    finally:
        if os.path.exists(out):
            os.remove(out)
