"""T13 - Reglas de métricas por palabra que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md, sección metrics.py, y criterios de la tarea T13
  - Una pausa exactamente igual a min_gap cuenta como larga, aunque la resta de floats dé 0.9999999.
  - Palabras solapadas no producen pausas negativas.
  - Con duration_s <= 0, pausas_por_minuto es 0.0.
  - rhythm_profile no crea una ventana extra por error de redondeo, asigna a la última ventana las palabras
    que pasan de la duración y rechaza ventanas no positivas.
"""

import pytest

from src.application.services.metrics import pause_stats_from_words, rhythm_profile
from src.domain.interfaces.ports import Word


def test_gap_equal_to_min_gap_counts_despite_float_error():
    assert 1.4 - 0.4 < 1.0  # 0.9999999999999999 en float
    words = [Word(0.0, 0.4, "a"), Word(1.4, 1.8, "b")]
    assert pause_stats_from_words(words, 60, min_gap=1.0)["pausas_largas"] == 1


def test_overlapping_words_do_not_create_negative_pauses():
    words = [Word(0.0, 1.0, "a"), Word(0.8, 1.2, "b")]
    s = pause_stats_from_words(words, 60)
    assert (s["pausas_largas"], s["pausa_maxima_s"]) == (0, 0.0)


def test_zero_duration_gives_zero_rate_but_still_counts_pauses():
    words = [Word(0.0, 0.5, "a"), Word(3.0, 3.5, "b")]
    s = pause_stats_from_words(words, 0)
    assert (s["pausas_largas"], s["pausas_por_minuto"]) == (1, 0.0)


def test_rounding_noise_in_duration_does_not_add_a_window():
    assert len(rhythm_profile([Word(0, 0.5, "a")], duration_s=60.0000001, window_s=30)) == 2


def test_words_past_the_duration_go_to_the_last_window():
    words = [Word(10, 10.5, "a"), Word(61, 61.5, "b")]
    assert rhythm_profile(words, duration_s=60, window_s=30) == [2.0, 2.0]


def test_non_positive_window_is_rejected():
    with pytest.raises(ValueError):
        rhythm_profile([], duration_s=60, window_s=0)
