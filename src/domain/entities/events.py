"""Eventos acústicos detectados sobre el audio."""

from dataclasses import dataclass

EVENT_LABELS = ("speech", "filler", "hum", "silence", "noise")


@dataclass(frozen=True)
class AcousticEvent:
    start: float
    end: float
    label: str
    confidence: float = 1.0

    @property
    def duration(self) -> float:
        return self.end - self.start
