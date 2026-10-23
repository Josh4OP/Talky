"""T04 - Reglas del contrato de transcript que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md, sección transcript.py
  - select_window nunca corta palabras ni pierde una palabra completa en el borde del recorte,
    sea cual sea el separador (espacio, salto de línea, tabulación).
  - Criterios de aceptación 2 y 3 de la tarea T04.
  - chunk_text rechaza límites no positivos y parte por caracteres una palabra mayor al límite.
"""

import pytest

from src.application.services.transcript import OMISSION_MARKER, chunk_text, select_window, split_sentences


def _words(n: int) -> list[str]:
    return [f"w{i}" for i in range(n)]


@pytest.mark.parametrize("max_chars", range(len(OMISSION_MARKER) + 1, 120))
def test_window_keeps_whole_words_from_both_ends_for_every_budget(max_chars):
    words = _words(40)
    out, truncated = select_window(" ".join(words), max_chars)
    head, tail = out.split(OMISSION_MARKER)
    assert truncated and len(out) <= max_chars
    assert head.split() == words[: len(head.split())]
    assert tail.split() == (words[-len(tail.split()) :] if tail.split() else [])


def test_newlines_and_tabs_count_as_word_separators():
    words = _words(400)
    text = "\n".join("\t".join(words[i : i + 5]) for i in range(0, 400, 5))
    out, _ = select_window(text, 300)
    head, tail = out.split(OMISSION_MARKER)
    assert head.split() == words[: len(head.split())]
    assert tail.split() == words[-len(tail.split()) :]


def test_fifty_thousand_chars_fit_in_twelve_thousand():
    text = " ".join(f"palabra{i}" for i in range(6000))[:50000].rsplit(" ", 1)[0]
    out, truncated = select_window(text, 12000)
    head, tail = out.split(OMISSION_MARKER)
    assert truncated and len(out) <= 12000
    assert text.startswith(head) and text.endswith(tail)


def test_three_sentences_with_spanish_and_plain_marks():
    assert split_sentences("¿Cómo estás? Bien. Gracias!") == ["¿Cómo estás?", "Bien.", "Gracias!"]


def test_chunk_text_rejects_non_positive_limit():
    with pytest.raises(ValueError):
        chunk_text("Hola.", 0)


def test_word_longer_than_the_limit_is_split_without_losing_characters():
    chunks = chunk_text("x" * 25 + " fin.", 10)
    assert all(len(c) <= 10 for c in chunks)
    assert "".join(chunks).replace(" ", "") == "x" * 25 + "fin."
