"""T10 - Extracción de características acústicas por ventana.

Contrato: src/infrastructure/ml/features.py   (requiere numpy y librosa)
  FEATURE_DIM: int
  extract_features(samples, sr=16000) -> np.ndarray      # shape (FEATURE_DIM,), finito, determinista
  frame_signal(samples, sr, win_s, hop_s) -> list[tuple[float, float, np.ndarray]]
     - ventanas que empiezan en k*hop_s
     - se conserva la ventana si contiene al menos la mitad de audio real; la última se rellena con ceros
Sugerencia de características: MFCC (media y desviación), energía RMS, cruces por cero,
centroide y planitud espectral, variación del tono (yin). Ver context/04-ml-design.md.
"""

import pytest

np = pytest.importorskip("numpy")
pytest.importorskip("librosa")

from src.infrastructure.ml.features import FEATURE_DIM, extract_features, frame_signal  # noqa: E402

SR = 16000


def _silence(n, rng):
    return rng.normal(0, 1e-4, n).astype(np.float32)


def _voiced(n, rng, f0=130.0):
    t = np.arange(n) / SR
    sig = sum(np.sin(2 * np.pi * f0 * k * t) / k for k in range(1, 7)) * 0.2
    return (sig + rng.normal(0, 1e-3, n)).astype(np.float32)


def _noise(n, rng):
    return rng.normal(0, 0.2, n).astype(np.float32)


@pytest.fixture
def rng():
    return np.random.default_rng(0)


def test_shape_and_finiteness(rng):
    for make in (_silence, _voiced, _noise):
        f = extract_features(make(SR // 2, rng), SR)
        assert f.shape == (FEATURE_DIM,)
        assert np.all(np.isfinite(f))


def test_is_deterministic(rng):
    x = _voiced(SR // 2, rng)
    assert np.array_equal(extract_features(x, SR), extract_features(x.copy(), SR))


def test_very_short_input_is_padded(rng):
    f = extract_features(_voiced(100, rng), SR)
    assert f.shape == (FEATURE_DIM,) and np.all(np.isfinite(f))


def test_silence_voice_and_noise_are_distinguishable(rng):
    s, v, n = (extract_features(m(SR // 2, rng), SR) for m in (_silence, _voiced, _noise))
    assert not np.allclose(s, v) and not np.allclose(v, n) and not np.allclose(s, n)


class TestFrameSignal:
    def test_exact_multiple(self):
        frames = frame_signal(np.zeros(int(3.5 * SR), dtype=np.float32), SR, 0.5, 0.5)
        assert len(frames) == 7
        assert frames[0][:2] == (0.0, 0.5) and frames[-1][:2] == (3.0, 3.5)
        assert all(len(f[2]) == SR // 2 for f in frames)

    def test_small_remainder_is_dropped(self):
        assert len(frame_signal(np.zeros(int(1.2 * SR), dtype=np.float32), SR, 0.5, 0.5)) == 2

    def test_large_remainder_is_padded(self):
        frames = frame_signal(np.ones(int(1.3 * SR), dtype=np.float32), SR, 0.5, 0.5)
        assert len(frames) == 3
        assert len(frames[-1][2]) == SR // 2
        assert frames[-1][2][-1] == 0.0  # relleno

    def test_empty_signal(self):
        assert frame_signal(np.zeros(0, dtype=np.float32), SR, 0.5, 0.5) == []

    def test_overlapping_windows(self):
        frames = frame_signal(np.zeros(SR * 2, dtype=np.float32), SR, 1.0, 0.5)
        assert [round(f[0], 2) for f in frames] == [0.0, 0.5, 1.0, 1.5]
