"""Coherencia temática con embeddings: saltos de tema e ideas repetidas entre ventanas de oraciones."""

import math
from collections.abc import Sequence
from dataclasses import dataclass, field

from src.application.services.transcript import split_sentences
from src.domain.interfaces.ports import TextEmbedder


@dataclass
class CoherenceReport:
    windows: int
    mean_adjacent_similarity: float | None
    topic_jumps: list[int] = field(default_factory=list)
    repeated_pairs: list[tuple[int, int, float]] = field(default_factory=list)

    def to_dict(self) -> dict:
        mean = self.mean_adjacent_similarity
        return {
            "windows": self.windows,
            "mean_adjacent_similarity": round(mean, 3) if mean is not None else None,
            "topic_jumps": list(self.topic_jumps),
            "repeated_pairs": [{"a": a, "b": b, "similarity": round(s, 3)} for a, b, s in self.repeated_pairs],
        }


def cosine(a: Sequence[float], b: Sequence[float]) -> float:
    if len(a) != len(b):
        raise ValueError("los vectores deben tener la misma dimensión")
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return sum(x * y for x, y in zip(a, b)) / (norm_a * norm_b)


def make_windows(sentences: list[str], size: int) -> list[str]:
    if size <= 0:
        raise ValueError("size debe ser positivo")
    return [" ".join(sentences[i : i + size]) for i in range(0, len(sentences), size)]


def coherence_report(
    text: str,
    embedder: TextEmbedder,
    window_sentences: int = 3,
    topic_jump_threshold: float = 0.35,
    repeat_threshold: float = 0.85,
    min_gap: int = 2,
) -> CoherenceReport:
    windows = make_windows(split_sentences(text), window_sentences)
    if len(windows) < 2:
        return CoherenceReport(windows=len(windows), mean_adjacent_similarity=None)

    vectors = embedder.embed(windows)
    adjacent = [cosine(vectors[i], vectors[i + 1]) for i in range(len(vectors) - 1)]
    repeated = [
        (a, b, similarity)
        for a in range(len(vectors))
        for b in range(a + min_gap, len(vectors))
        if (similarity := cosine(vectors[a], vectors[b])) > repeat_threshold
    ]
    return CoherenceReport(
        windows=len(windows),
        mean_adjacent_similarity=sum(adjacent) / len(adjacent),
        topic_jumps=[i for i, similarity in enumerate(adjacent) if similarity < topic_jump_threshold],
        repeated_pairs=repeated,
    )
