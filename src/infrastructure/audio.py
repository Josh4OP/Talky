"""Lectura, medición y compresión de audio con PyAV (mono, 16 kHz)."""

import math
import tempfile
from collections.abc import Iterator
from pathlib import Path

import av
import numpy as np

from src.application.routing.input_router import AudioInfo
from src.domain.exceptions import InvalidAudioError

SAMPLE_RATE = 16000
RMS_FLOOR_DBFS = -120.0
_UNREADABLE = "No se pudo leer el archivo de audio. Verifica que no esté dañado y que sea un formato compatible."
_DECODE_ERRORS = (av.FFmpegError, IndexError, ValueError)


def _mono_16k_frames(path: str) -> Iterator[av.AudioFrame]:
    """Decodifica por bloques para no cargar exposiciones largas completas en memoria."""
    try:
        container = av.open(path)
    except _DECODE_ERRORS as e:
        raise InvalidAudioError(_UNREADABLE) from e
    resampler = av.AudioResampler(format="s16", layout="mono", rate=SAMPLE_RATE)
    produced = False
    try:
        for frame in container.decode(audio=0):
            for out in resampler.resample(frame):
                produced = True
                yield out
        for out in resampler.resample(None):
            produced = True
            yield out
    except _DECODE_ERRORS as e:
        raise InvalidAudioError(_UNREADABLE) from e
    finally:
        container.close()
    if not produced:
        raise InvalidAudioError(_UNREADABLE)


def _to_float(frame: av.AudioFrame) -> np.ndarray:
    return frame.to_ndarray().reshape(-1).astype(np.float32) / 32768.0


def load_audio(path: str) -> np.ndarray:
    return np.concatenate([_to_float(f) for f in _mono_16k_frames(path)])


def probe_audio(path: str) -> AudioInfo:
    n_samples = 0
    sum_squares = 0.0
    for frame in _mono_16k_frames(path):
        samples = _to_float(frame).astype(np.float64)
        n_samples += samples.size
        sum_squares += float(np.dot(samples, samples))
    rms = math.sqrt(sum_squares / n_samples) if n_samples else 0.0
    rms_dbfs = max(20 * math.log10(rms), RMS_FLOOR_DBFS) if rms > 0 else RMS_FLOOR_DBFS
    return AudioInfo(duration_s=n_samples / SAMPLE_RATE, size_bytes=Path(path).stat().st_size, rms_dbfs=rms_dbfs)


def compress_for_upload(path: str) -> str:
    """Escribe una copia FLAC 16 kHz mono en un temporal y devuelve su ruta; el llamador la borra."""
    with tempfile.NamedTemporaryFile(suffix=".flac", delete=False) as tmp:
        out_path = tmp.name
    try:
        with av.open(out_path, "w", format="flac") as output:
            stream = output.add_stream("flac", rate=SAMPLE_RATE, layout="mono")
            for frame in _mono_16k_frames(path):
                frame.pts = None
                output.mux(stream.encode(frame))
            output.mux(stream.encode(None))
    except BaseException:
        Path(out_path).unlink(missing_ok=True)
        raise
    return out_path
