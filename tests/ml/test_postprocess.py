"""T11 - Posprocesado de predicciones por ventana a eventos (Python puro).

Contrato: src/infrastructure/ml/postprocess.py
  WindowPrediction(start, end, label, confidence)
  merge_predictions(preds, max_gap_s=0.05, min_duration_s=0.0) -> list[AcousticEvent]
  - Ordena por inicio; une ventanas consecutivas con la misma etiqueta si el hueco <= max_gap_s.
  - La confianza del evento es el promedio ponderado por duración.
  - Descarta eventos con duración < min_duration_s.
"""

import pytest
from src.domain.entities.events import AcousticEvent
from src.infrastructure.ml.postprocess import WindowPrediction as P
from src.infrastructure.ml.postprocess import merge_predictions


def test_merges_consecutive_windows_with_the_same_label():
    preds = [
        P(0.0, 0.5, "filler", 0.8),
        P(0.5, 1.0, "filler", 0.6),
        P(1.0, 1.5, "speech", 0.9),
        P(1.5, 2.0, "filler", 0.7),
    ]
    events = merge_predictions(preds)
    assert [(e.start, e.end, e.label) for e in events] == [
        (0.0, 1.0, "filler"),
        (1.0, 1.5, "speech"),
        (1.5, 2.0, "filler"),
    ]
    assert events[0].confidence == pytest.approx(0.7)
    assert all(isinstance(e, AcousticEvent) for e in events)


def test_min_duration_filters_short_events():
    preds = [
        P(0.0, 0.5, "filler", 0.8),
        P(0.5, 1.0, "filler", 0.6),
        P(1.0, 1.5, "speech", 0.9),
        P(1.5, 2.0, "filler", 0.7),
    ]
    events = merge_predictions(preds, min_duration_s=0.6)
    assert [(e.start, e.end) for e in events] == [(0.0, 1.0)]


def test_gap_tolerance():
    preds = [P(0.0, 0.5, "hum", 0.9), P(0.52, 1.0, "hum", 0.9)]
    assert len(merge_predictions(preds, max_gap_s=0.05)) == 1
    far = [P(0.0, 0.5, "hum", 0.9), P(0.7, 1.2, "hum", 0.9)]
    assert len(merge_predictions(far, max_gap_s=0.05)) == 2


def test_input_does_not_need_to_be_sorted():
    preds = [P(0.5, 1.0, "noise", 0.5), P(0.0, 0.5, "noise", 0.5)]
    events = merge_predictions(preds)
    assert [(e.start, e.end) for e in events] == [(0.0, 1.0)]


def test_empty():
    assert merge_predictions([]) == []
