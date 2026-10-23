"""T10 - Modelo Random Forest para eventos acústicos.

Contrato: src/infrastructure/ml/event_model.py   (requiere numpy, scikit-learn, joblib)
  train_event_model(X, y, seed=42, n_estimators=200) -> EventModel
  EventModel.classes_ -> list[str]                 # ordenadas
  EventModel.predict(X) -> list[tuple[str, float]] # (etiqueta, confianza en [0, 1])
  EventModel.save(path) / EventModel.load(path)    # joblib; load de un archivo inexistente -> FileNotFoundError
  - Con una sola clase en y lanza ValueError.
"""

import pytest

np = pytest.importorskip("numpy")
pytest.importorskip("sklearn")
pytest.importorskip("joblib")

from src.infrastructure.ml.event_model import EventModel, train_event_model  # noqa: E402


def _dataset(seed=0, per_class=40, dim=8):
    rng = np.random.default_rng(seed)
    centers = {"speech": 0.0, "filler": 5.0, "hum": -5.0}
    X, y = [], []
    for label, center in centers.items():
        X.append(rng.normal(center, 1.0, (per_class, dim)))
        y += [label] * per_class
    return np.vstack(X), y


def test_learns_a_separable_problem():
    X, y = _dataset(0)
    Xt, yt = _dataset(1)
    model = train_event_model(X, y)
    preds = model.predict(Xt)
    accuracy = np.mean([p[0] == t for p, t in zip(preds, yt)])
    assert accuracy >= 0.95
    assert all(0.0 <= conf <= 1.0 for _, conf in preds)


def test_classes_are_sorted():
    X, y = _dataset()
    assert train_event_model(X, y).classes_ == ["filler", "hum", "speech"]


def test_training_is_reproducible_with_the_same_seed():
    X, y = _dataset()
    a = train_event_model(X, y, seed=7).predict(X)
    b = train_event_model(X, y, seed=7).predict(X)
    assert a == b


def test_save_and_load_roundtrip(tmp_path):
    X, y = _dataset()
    model = train_event_model(X, y)
    path = tmp_path / "model.joblib"
    model.save(str(path))
    loaded = EventModel.load(str(path))
    assert loaded.classes_ == model.classes_
    assert loaded.predict(X) == model.predict(X)


def test_loading_a_missing_file():
    with pytest.raises(FileNotFoundError):
        EventModel.load("/no/existe/model.joblib")


def test_single_class_is_rejected():
    X, _ = _dataset()
    with pytest.raises(ValueError):
        train_event_model(X, ["speech"] * len(X))
