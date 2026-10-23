"""Recorte y partición de transcripciones largas sin perder la conclusión ni cortar palabras."""

import re

OMISSION_MARKER = "\n[... fragmento omitido ...]\n"

_SENTENCE_BREAK = re.compile(r"(?<=[.!?…])\s+")


def _head_without_partial_word(text: str, budget: int) -> str:
    head = text[:budget]
    if head and not head[-1].isspace() and budget < len(text) and not text[budget].isspace():
        parts = head.rsplit(None, 1)
        head = parts[0] if len(parts) == 2 else ""
    return head.rstrip()


def _tail_without_partial_word(text: str, budget: int) -> str:
    if budget <= 0:
        return ""
    start = len(text) - budget
    tail = text[start:]
    if start > 0 and not text[start - 1].isspace() and not tail[0].isspace():
        parts = tail.split(None, 1)
        tail = parts[1] if len(parts) == 2 else ""
    return tail.lstrip()


def select_window(text: str, max_chars: int, head_ratio: float = 0.6) -> tuple[str, bool]:
    if len(text) <= max_chars:
        return text, False
    budget = max_chars - len(OMISSION_MARKER)
    if budget <= 0:
        raise ValueError(f"max_chars={max_chars} no alcanza ni para el marcador de omisión")
    head_budget = int(budget * head_ratio)
    head = _head_without_partial_word(text, head_budget)
    tail = _tail_without_partial_word(text, budget - head_budget)
    return head + OMISSION_MARKER + tail, True


def split_sentences(text: str) -> list[str]:
    return [s for s in _SENTENCE_BREAK.split(text.strip()) if s]


def _split_long_sentence(sentence: str, max_chars: int) -> list[str]:
    pieces: list[str] = []
    for word in sentence.split():
        # Una palabra más larga que el límite solo puede partirse por caracteres.
        while len(word) > max_chars:
            pieces.append(word[:max_chars])
            word = word[max_chars:]
        if pieces and len(pieces[-1]) + 1 + len(word) <= max_chars:
            pieces[-1] += " " + word
        else:
            pieces.append(word)
    return pieces


def chunk_text(text: str, max_chars: int) -> list[str]:
    if max_chars <= 0:
        raise ValueError("max_chars debe ser positivo")
    chunks: list[str] = []
    for sentence in split_sentences(text):
        pieces = [sentence] if len(sentence) <= max_chars else _split_long_sentence(sentence, max_chars)
        for piece in pieces:
            if chunks and len(chunks[-1]) + 1 + len(piece) <= max_chars:
                chunks[-1] += " " + piece
            else:
                chunks.append(piece)
    return chunks
