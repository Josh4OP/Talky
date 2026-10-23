"""Entidades de dominio: análisis, evidencias y eventos acústicos (T08, T11, T12)."""

import pytest
from fakes import analysis_payload
from pydantic import ValidationError

from src.domain.entities.analysis import Analisis, Aspecto, Evidencia
from src.domain.entities.events import EVENT_LABELS, AcousticEvent


def test_scores_are_rounded_and_bounded():
    assert Aspecto(puntaje=7.6, comentario="").puntaje == 8
    with pytest.raises(ValidationError):
        Aspecto(puntaje=11)
    with pytest.raises(ValidationError):
        Aspecto(puntaje=0)


def test_analysis_without_evidences_is_still_valid():
    payload = analysis_payload()
    payload.pop("evidencias")
    assert Analisis.model_validate(payload).evidencias == []


def test_analysis_parses_evidences():
    a = Analisis.model_validate(analysis_payload())
    assert len(a.evidencias) == 2
    assert a.evidencias[0].verificada is None


def test_evidence_defaults():
    e = Evidencia(afirmacion="algo")
    assert e.cita == "" and e.verificada is None


def test_event_labels_and_duration():
    assert set(EVENT_LABELS) == {"speech", "filler", "hum", "silence", "noise"}
    ev = AcousticEvent(start=1.0, end=2.5, label="hum", confidence=0.7)
    assert ev.duration == pytest.approx(1.5)


def test_event_is_immutable():
    ev = AcousticEvent(start=0, end=1, label="filler")
    with pytest.raises(Exception):
        ev.start = 5
