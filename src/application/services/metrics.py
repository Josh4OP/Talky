from src.domain.interfaces.ports import Segment


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