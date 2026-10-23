"""T03 - Reglas del contrato de filler_detector que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md, sección filler_detector.py
  - Pausa: coma, punto y coma, puntos suspensivos o raya.
  - "la verdad" nunca cuenta como oración completa.
  - Variantes vocales: eh, ehh, ehm, em, emm -> "eh"; mm, mmm, hmm, hmmm -> "mmm".
"""

import pytest

from src.application.services.filler_detector import detect_fillers, fillers_per_minute


@pytest.mark.parametrize("text", ["Este; el modelo", "Este — el modelo", "Este… el modelo"])
def test_semicolon_dash_and_ellipsis_are_pauses(text):
    assert detect_fillers(text) == {"este": 1}


def test_acceptance_sentence_counts_nothing():
    text = "Entonces el resultado es bueno. Este modelo es mejor. Tipo de dato entero. Pues bien, la verdad es que sí."
    assert detect_fillers(text) == {}


def test_la_verdad_as_a_whole_sentence_is_ignored():
    assert detect_fillers("La verdad. Empecemos.") == {}


def test_all_vocal_variants_are_normalized():
    assert detect_fillers("Eh, ehh, ehm, em, emm, mm, mmm, hmm, hmmm.") == {"eh": 5, "mmm": 4}


def test_words_that_start_like_vocal_fillers_are_ignored():
    assert detect_fillers("Emma y Hemmings llegaron") == {}


def test_contextual_filler_after_question_mark_starts_a_sentence():
    assert detect_fillers("¿Listos? Bueno. Empecemos.") == {"bueno": 1}


def test_rate_is_rounded_to_one_decimal():
    assert fillers_per_minute({"eh": 1}, 7) == 8.6
