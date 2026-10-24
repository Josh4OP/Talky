"""Fusión de muletillas vocales: lo que transcribió Whisper y lo que detectó el clasificador acústico."""

from dataclasses import dataclass, field

from src.application.services.filler_detector import vocal_filler_key
from src.domain.entities.events import AcousticEvent
from src.domain.interfaces.ports import Word

ACOUSTIC_TEXT = "[acustico]"


@dataclass(frozen=True)
class FillerHit:
    start: float
    end: float
    texto: str
    source: str
    confianza: str

    def to_dict(self) -> dict:
        return {
            "start": round(self.start, 3),
            "end": round(self.end, 3),
            "texto": self.texto,
            "source": self.source,
            "confianza": self.confianza,
        }


@dataclass
class FusionResult:
    fillers: list[FillerHit] = field(default_factory=list)
    hums: list[AcousticEvent] = field(default_factory=list)


def _gap(a_start: float, a_end: float, b_start: float, b_end: float) -> float:
    """Separación entre dos intervalos; 0 si se solapan."""
    return max(0.0, max(a_start, b_start) - min(a_end, b_end))


def _center_distance(word: Word, event: AcousticEvent) -> float:
    return abs((word.start + word.end) / 2 - (event.start + event.end) / 2)


def _match(words: list[tuple[Word, str]], events: list[AcousticEvent], tolerance_s: float) -> list[tuple[int, int]]:
    """Empareja primero los pares más cercanos; cada palabra y cada evento se usan una sola vez."""
    candidates = sorted(
        (_gap(w.start, w.end, e.start, e.end), _center_distance(w, e), wi, ei)
        for wi, (w, _) in enumerate(words)
        for ei, e in enumerate(events)
        if _gap(w.start, w.end, e.start, e.end) <= tolerance_s
    )
    used_words: set[int] = set()
    used_events: set[int] = set()
    pairs = []
    for _, _, wi, ei in candidates:
        if wi not in used_words and ei not in used_events:
            used_words.add(wi)
            used_events.add(ei)
            pairs.append((wi, ei))
    return pairs


def fuse_fillers(
    words: list[Word], events: list[AcousticEvent], tolerance_s: float = 0.5, min_confidence: float = 0.6
) -> FusionResult:
    asr = [(w, key) for w in words if (key := vocal_filler_key(w.text)) is not None]
    confident = [e for e in events if e.confidence >= min_confidence]
    acoustic = [e for e in confident if e.label == "filler"]
    hums = sorted((e for e in confident if e.label == "hum"), key=lambda e: e.start)

    pairs = _match(asr, acoustic, tolerance_s)
    matched_words = {wi for wi, _ in pairs}
    matched_events = {ei for _, ei in pairs}

    fillers = [
        FillerHit(
            min(asr[wi][0].start, acoustic[ei].start), max(asr[wi][0].end, acoustic[ei].end), asr[wi][1], "both", "alta"
        )
        for wi, ei in pairs
    ]
    fillers += [
        FillerHit(w.start, w.end, key, "asr", "media") for i, (w, key) in enumerate(asr) if i not in matched_words
    ]
    fillers += [
        FillerHit(e.start, e.end, ACOUSTIC_TEXT, "acoustic", "media")
        for i, e in enumerate(acoustic)
        if i not in matched_events
    ]
    return FusionResult(fillers=sorted(fillers, key=lambda h: (h.start, h.end)), hums=hums)
