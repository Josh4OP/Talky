"""T09 - Coherencia con embeddings de texto (RF-05).

Contrato: src/application/services/coherence.py
  cosine(a, b) -> float                               # 0.0 si algún vector es cero
  make_windows(sentences, size) -> list[str]          # ventanas NO solapadas de `size` oraciones
  coherence_report(text, embedder, window_sentences=3, topic_jump_threshold=0.35,
                   repeat_threshold=0.85, min_gap=2) -> CoherenceReport
  CoherenceReport(windows, mean_adjacent_similarity, topic_jumps, repeated_pairs)
     .to_dict() -> {"windows", "mean_adjacent_similarity", "topic_jumps",
                    "repeated_pairs": [{"a", "b", "similarity"}]}
  - Un solo llamado por lote: embedder.embed(list_of_window_texts).
  - Con menos de 2 ventanas NO se llama al embedder y mean_adjacent_similarity es None.
Puerto: src/domain/interfaces/ports.py -> TextEmbedder.embed(texts) -> list[list[float]]
"""

import pytest
from fakes import ScriptedEmbedder
from src.application.services.coherence import coherence_report, cosine, make_windows

TWELVE = " ".join(f"Oración número {i}." for i in range(12))


class TestCosine:
    def test_identical_and_orthogonal(self):
        assert cosine([1, 0], [1, 0]) == pytest.approx(1.0)
        assert cosine([1, 0], [0, 1]) == pytest.approx(0.0)

    def test_zero_vector(self):
        assert cosine([0, 0], [1, 0]) == 0.0


class TestMakeWindows:
    def test_non_overlapping_windows(self):
        assert make_windows(["a.", "b.", "c.", "d.", "e."], 2) == ["a. b.", "c. d.", "e."]

    def test_empty(self):
        assert make_windows([], 3) == []


class TestCoherenceReport:
    def test_coherent_speech_has_no_jumps_or_repeats(self):
        emb = ScriptedEmbedder([[1, 0], [0.8, 0.6], [0.6, 0.8], [0, 1]])
        r = coherence_report(TWELVE, emb)
        assert r.windows == 4
        assert r.topic_jumps == []
        assert r.repeated_pairs == []
        assert r.mean_adjacent_similarity == pytest.approx((0.8 + 0.96 + 0.8) / 3)

    def test_jumps_and_repeated_ideas(self):
        emb = ScriptedEmbedder([[1, 0], [0, 1], [1, 0], [0, 1]])
        r = coherence_report(TWELVE, emb)
        assert r.topic_jumps == [0, 1, 2]
        assert [(a, b) for a, b, _ in r.repeated_pairs] == [(0, 2), (1, 3)]
        assert all(sim == pytest.approx(1.0) for _, _, sim in r.repeated_pairs)
        assert r.mean_adjacent_similarity == pytest.approx(0.0)

    def test_single_batch_call(self):
        emb = ScriptedEmbedder([[1, 0], [0, 1], [1, 0], [0, 1]])
        coherence_report(TWELVE, emb)
        assert emb.calls == [4]

    def test_thresholds_are_configurable(self):
        emb = ScriptedEmbedder([[1, 0], [0.8, 0.6], [0.6, 0.8], [0, 1]])
        r = coherence_report(TWELVE, emb, topic_jump_threshold=0.99)
        assert r.topic_jumps == [0, 1, 2]

    def test_adjacent_windows_are_never_reported_as_repeats(self):
        emb = ScriptedEmbedder([[1, 0], [1, 0], [0, 1], [0, 1]])
        r = coherence_report(TWELVE, emb)
        assert [(a, b) for a, b, _ in r.repeated_pairs] == []

    def test_too_short_text_does_not_call_the_embedder(self):
        emb = ScriptedEmbedder([[1, 0]])
        r = coherence_report("Una sola oración. Y otra más.", emb)
        assert r.windows == 1
        assert r.mean_adjacent_similarity is None
        assert emb.calls == []

    def test_to_dict(self):
        emb = ScriptedEmbedder([[1, 0], [0, 1], [1, 0], [0, 1]])
        d = coherence_report(TWELVE, emb).to_dict()
        assert set(d) == {"windows", "mean_adjacent_similarity", "topic_jumps", "repeated_pairs"}
        assert d["repeated_pairs"][0] == {"a": 0, "b": 2, "similarity": pytest.approx(1.0)}
