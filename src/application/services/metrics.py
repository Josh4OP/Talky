"""Métricas objetivas de ritmo y pausas a partir de la transcripción."""

import math

from src.domain.interfaces.ports import Segment, Word

# Los tiempos llegan como floats; redondear evita que una pausa de exactamente min_gap quede en 0.9999999.
_TIME_DECIMALS = 6


def words_per_minute(text: str, duration_s: float) -> float:
    if not duration_s:
        return 0.0
    return round(len(text.split()) / (duration_s / 60), 1)


def pause_stats(segments: list[Segment], min_gap: float = 1.5) -> dict:
    gaps = [b.start - a.end for a, b in zip(segments, segments[1:])]
    long_gaps = [g for g in gaps if g >= min_gap]
    return {
        "pausas_largas": len(long_gaps),
        "segundos_en_pausas": round(sum(long_gaps), 1),
    }


def _word_gaps(words: list[Word]) -> list[float]:
    return [max(round(b.start - a.end, _TIME_DECIMALS), 0.0) for a, b in zip(words, words[1:])]


def pause_stats_from_words(words: list[Word], duration_s: float, min_gap: float = 1.0) -> dict:
    gaps = _word_gaps(words)
    long_gaps = [g for g in gaps if g >= min_gap]
    per_minute = len(long_gaps) / (duration_s / 60) if duration_s > 0 else 0.0
    return {
        "pausas_largas": len(long_gaps),
        "segundos_en_pausas": round(sum(long_gaps), 2),
        "pausa_maxima_s": round(max(gaps, default=0.0), 2),
        "pausas_por_minuto": round(per_minute, 2),
    }


def rhythm_profile(words: list[Word], duration_s: float, window_s: float = 30.0) -> list[float]:
    if duration_s <= 0:
        return []
    if window_s <= 0:
        raise ValueError("window_s debe ser positivo")
    n_windows = math.ceil(round(duration_s / window_s, _TIME_DECIMALS))
    counts = [0] * n_windows
    for word in words:
        index = min(max(int(word.start // window_s), 0), n_windows - 1)
        counts[index] += 1
    profile = []
    for i, count in enumerate(counts):
        length = min(window_s, duration_s - i * window_s)
        profile.append(round(count * 60 / length, 1))
    return profile
