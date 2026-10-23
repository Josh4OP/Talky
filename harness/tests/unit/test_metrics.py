"""T13 - Métricas de ritmo y pausas (RF-09 propuesto, entrevista: "duración y ritmo").

Contrato: src/application/services/metrics.py
  words_per_minute(text, duration_s) -> float                       (ya existe)
  pause_stats(segments, min_gap=1.5) -> dict                        (ya existe)
  pause_stats_from_words(words, duration_s, min_gap=1.0) -> dict
        {"pausas_largas", "segundos_en_pausas", "pausa_maxima_s", "pausas_por_minuto"}
  rhythm_profile(words, duration_s, window_s=30.0) -> list[float]   # palabras/min por ventana
"""

import pytest

from src.application.services.metrics import (
    pause_stats,
    pause_stats_from_words,
    rhythm_profile,
    words_per_minute,
)
from src.domain.interfaces.ports import Segment, Word


class TestExisting:
    def test_words_per_minute(self):
        assert words_per_minute("a b c d", 120) == 2.0
        assert words_per_minute("a b c d", 0) == 0.0

    def test_pause_stats_from_segments(self):
        segs = [Segment(0, 2, "a"), Segment(4, 5, "b"), Segment(5.5, 6, "c")]
        assert pause_stats(segs, min_gap=1.5) == {"pausas_largas": 1, "segundos_en_pausas": 2.0}


class TestPauseStatsFromWords:
    def _words(self):
        # huecos entre palabras: 0.2, 1.5, 0.3, 2.5
        return [Word(0.0, 0.5, "a"), Word(0.7, 1.0, "b"), Word(2.5, 3.0, "c"), Word(3.3, 3.6, "d"), Word(6.1, 6.5, "e")]

    def test_counts_only_long_pauses(self):
        s = pause_stats_from_words(self._words(), duration_s=120, min_gap=1.0)
        assert s["pausas_largas"] == 2
        assert s["segundos_en_pausas"] == pytest.approx(4.0)
        assert s["pausa_maxima_s"] == pytest.approx(2.5)
        assert s["pausas_por_minuto"] == pytest.approx(1.0)

    def test_threshold_is_configurable(self):
        assert pause_stats_from_words(self._words(), 120, min_gap=2.0)["pausas_largas"] == 1

    def test_no_words(self):
        s = pause_stats_from_words([], duration_s=60)
        assert s == {"pausas_largas": 0, "segundos_en_pausas": 0.0, "pausa_maxima_s": 0.0, "pausas_por_minuto": 0.0}


class TestRhythmProfile:
    def test_words_per_minute_per_window(self):
        words = [Word(i, i + 0.5, "x") for i in range(30)]  # 30 palabras en [0, 30)
        words += [Word(30 + i * 0.5, 30.4 + i * 0.5, "y") for i in range(60)]  # 60 palabras en [30, 60)
        assert rhythm_profile(words, duration_s=60, window_s=30) == [60.0, 120.0]

    def test_last_partial_window_is_scaled_to_its_real_length(self):
        words = [Word(60 + i, 60.5 + i, "z") for i in range(15)]  # 15 palabras en [60, 75)
        profile = rhythm_profile(words, duration_s=75, window_s=30)
        assert profile == [0.0, 0.0, 60.0]

    def test_no_words(self):
        assert rhythm_profile([], duration_s=60, window_s=30) == [0.0, 0.0]

    def test_zero_duration(self):
        assert rhythm_profile([], duration_s=0) == []
