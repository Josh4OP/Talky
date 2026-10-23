"""T04 - Manejo de transcripciones largas (RF-05, RNF-03).

Contrato: src/application/services/transcript.py
  OMISSION_MARKER: str
  select_window(text, max_chars, head_ratio=0.6) -> tuple[str, bool]
  split_sentences(text) -> list[str]
  chunk_text(text, max_chars) -> list[str]
"""

import re

import pytest
from src.application.services.transcript import (
    OMISSION_MARKER,
    chunk_text,
    select_window,
    split_sentences,
)


def _long_text(n_words: int = 3000) -> str:
    return " ".join(f"w{i}" for i in range(n_words))


class TestSelectWindow:
    def test_short_text_is_returned_untouched(self):
        assert select_window("hola mundo", 1000) == ("hola mundo", False)

    def test_long_text_keeps_head_and_tail_within_budget(self):
        text = _long_text()
        out, truncated = select_window(text, 2000)
        assert truncated is True
        assert len(out) <= 2000
        assert OMISSION_MARKER in out
        assert out.startswith("w0 ")
        assert out.endswith(" w2999")

    def test_never_cuts_in_the_middle_of_a_word(self):
        out, _ = select_window(_long_text(), 1500)
        tokens = out.replace(OMISSION_MARKER, " ").split()
        assert all(re.fullmatch(r"w\d+", t) for t in tokens)

    def test_head_gets_more_budget_than_tail(self):
        out, _ = select_window(_long_text(), 3000, head_ratio=0.6)
        head, tail = out.split(OMISSION_MARKER)
        assert len(head) > len(tail)

    def test_exact_limit_is_not_truncated(self):
        text = "a" * 100
        assert select_window(text, 100) == (text, False)

    def test_budget_too_small_is_rejected(self):
        with pytest.raises(ValueError):
            select_window(_long_text(), 10)


class TestSplitSentences:
    def test_spanish_punctuation(self):
        assert split_sentences("Hola. ¿Cómo estás? ¡Bien! Sí...") == ["Hola.", "¿Cómo estás?", "¡Bien!", "Sí..."]

    def test_empty(self):
        assert split_sentences("") == []
        assert split_sentences("   ") == []

    def test_text_without_final_punctuation(self):
        assert split_sentences("Una frase sin punto") == ["Una frase sin punto"]


class TestChunkText:
    def test_chunks_respect_the_limit_and_keep_all_sentences(self):
        sentences = [f"Esta es la oración número {i}." for i in range(40)]
        chunks = chunk_text(" ".join(sentences), 200)
        assert len(chunks) > 1
        assert all(len(c) <= 200 for c in chunks)
        assert " ".join(chunks).split() == " ".join(sentences).split()

    def test_chunks_split_on_sentence_boundaries(self):
        chunks = chunk_text("Uno dos tres. Cuatro cinco seis. Siete ocho nueve.", 30)
        assert all(c.endswith(".") for c in chunks)

    def test_a_single_huge_sentence_is_split_by_words(self):
        chunks = chunk_text(" ".join(f"p{i}" for i in range(500)), 100)
        assert all(len(c) <= 100 for c in chunks)
        assert " ".join(chunks).split() == [f"p{i}" for i in range(500)]

    def test_short_text_is_a_single_chunk(self):
        assert chunk_text("Hola mundo.", 100) == ["Hola mundo."]

    def test_empty(self):
        assert chunk_text("", 100) == []
