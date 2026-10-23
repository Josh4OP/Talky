"""T06 - Reglas de audio.py que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md, sección audio.py
  - compress_for_upload produce FLAC 16 kHz mono y no deja temporales si el archivo es ilegible.
  - probe_audio mide por bloques lo mismo que se obtiene del audio completo.
  - Un archivo inexistente es InvalidAudioError.
"""

import math
import os
import struct
import tempfile
import wave

import pytest

np = pytest.importorskip("numpy")
av = pytest.importorskip("av")

from src.domain.exceptions import InvalidAudioError  # noqa: E402
from src.infrastructure.audio import compress_for_upload, load_audio, probe_audio  # noqa: E402


def _write_sine(path, seconds=1.0, sr=44100, channels=2, amp=0.3):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = b"".join(
            struct.pack("<h", int(amp * 32767 * math.sin(2 * math.pi * 440 * i / sr))) * channels
            for i in range(int(seconds * sr))
        )
        w.writeframes(frames)


def test_compressed_file_is_flac_16k_mono(tmp_path):
    p = tmp_path / "big.wav"
    _write_sine(p, seconds=1.0)
    out = compress_for_upload(str(p))
    try:
        with av.open(out) as container:
            stream = container.streams.audio[0]
            assert (container.format.name, stream.codec_context.name) == ("flac", "flac")
            assert (stream.sample_rate, stream.channels) == (16000, 1)
    finally:
        os.remove(out)


def test_failed_compression_leaves_no_temporary_file(tmp_path, monkeypatch):
    temp_dir = tmp_path / "tmp"
    temp_dir.mkdir()
    monkeypatch.setattr(tempfile, "tempdir", str(temp_dir))
    bad = tmp_path / "basura.wav"
    bad.write_bytes(b"\x00\x01" * 1024)
    with pytest.raises(InvalidAudioError):
        compress_for_upload(str(bad))
    assert list(temp_dir.iterdir()) == []


def test_streamed_rms_matches_the_full_signal(tmp_path):
    p = tmp_path / "s.wav"
    _write_sine(p, seconds=2.0, sr=22050, channels=2, amp=0.5)
    x = load_audio(str(p)).astype(np.float64)
    info = probe_audio(str(p))
    assert info.rms_dbfs == pytest.approx(20 * math.log10(math.sqrt(np.mean(x**2))), abs=1e-6)
    assert info.duration_s == pytest.approx(len(x) / 16000)


def test_missing_file_is_invalid_audio(tmp_path):
    with pytest.raises(InvalidAudioError):
        probe_audio(str(tmp_path / "no-existe.wav"))
