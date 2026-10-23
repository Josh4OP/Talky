"""T11 - Clasificador de eventos de extremo a extremo con señales sintéticas.

Contrato: src/infrastructure/ml/event_classifier.py   (requiere numpy, librosa, scikit-learn)
  SklearnEventClassifier(model, *, win_s=0.5, min_duration_s=0.0, max_gap_s=0.05, loader=None)
  .classify(audio_path) -> list[AcousticEvent]
  - `loader(path) -> np.ndarray` (float32, mono, 16 kHz). Por defecto: infrastructure.audio.load_audio.
  - Ventanas contiguas (hop = win), predicción por ventana, luego merge_predictions.
Este test entrena con tres tipos de señal sintética (silencio, voz armónica, ruido) y comprueba
que la cadena completa features -> RandomForest -> eventos funciona sin datos reales.
"""

import wave

import pytest

np = pytest.importorskip("numpy")
pytest.importorskip("librosa")
pytest.importorskip("sklearn")

from src.domain.entities.events import AcousticEvent  # noqa: E402
from src.domain.interfaces.ports import EventClassifier  # noqa: E402
from src.infrastructure.ml.event_classifier import SklearnEventClassifier  # noqa: E402
from src.infrastructure.ml.event_model import train_event_model  # noqa: E402
from src.infrastructure.ml.features import extract_features  # noqa: E402

SR = 16000
WIN = 0.5


def _silence(n, rng):
    return rng.normal(0, 1e-4, n)


def _voiced(n, rng):
    f0 = rng.uniform(110, 160)
    t = np.arange(n) / SR
    return sum(np.sin(2 * np.pi * f0 * k * t) / k for k in range(1, 7)) * 0.2 + rng.normal(0, 1e-3, n)


def _noise(n, rng):
    return rng.normal(0, 0.2, n)


def _wav_loader(path):
    with wave.open(path, "rb") as w:
        raw = w.readframes(w.getnframes())
    return np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0


def _write_wav(path, signal):
    pcm = (np.clip(signal, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


@pytest.fixture(scope="module")
def model():
    rng = np.random.default_rng(0)
    n = int(WIN * SR)
    X, y = [], []
    for make, label in ((_silence, "silence"), (_voiced, "filler"), (_noise, "noise")):
        for _ in range(40):
            X.append(extract_features(make(n, rng).astype(np.float32), SR))
            y.append(label)
    return train_event_model(np.vstack(X), y, seed=0)


def test_is_an_event_classifier(model):
    assert isinstance(SklearnEventClassifier(model, loader=_wav_loader), EventClassifier)


def test_detects_the_sequence_of_sounds(model, tmp_path):
    rng = np.random.default_rng(1)
    audio = np.concatenate([_silence(SR, rng), _voiced(int(1.5 * SR), rng), _noise(SR, rng)])
    path = tmp_path / "mix.wav"
    _write_wav(path, audio)

    events = SklearnEventClassifier(model, win_s=WIN, loader=_wav_loader).classify(str(path))

    assert [e.label for e in events] == ["silence", "filler", "noise"]
    assert events[0].end == pytest.approx(1.0, abs=0.1)
    assert events[1].end == pytest.approx(2.5, abs=0.1)
    assert events[2].end == pytest.approx(3.5, abs=0.1)
    assert all(isinstance(e, AcousticEvent) and 0.0 < e.confidence <= 1.0 for e in events)


def test_audio_shorter_than_half_a_window_returns_nothing(model, tmp_path):
    path = tmp_path / "tiny.wav"
    _write_wav(path, np.zeros(int(0.1 * SR)))
    assert SklearnEventClassifier(model, win_s=WIN, loader=_wav_loader).classify(str(path)) == []
