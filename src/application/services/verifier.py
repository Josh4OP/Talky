"""Verificador de evidencias: cada cita del LLM debe existir en la transcripción (sin LLM)."""

import re
import unicodedata
from difflib import SequenceMatcher

from src.domain.entities.analysis import Evidencia

MIN_QUOTE_WORDS = 3
_NON_WORD = re.compile(r"[\W_]+")


def normalize(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text.lower())
    without_accents = "".join(c for c in decomposed if not unicodedata.combining(c))
    return _NON_WORD.sub(" ", without_accents).strip()


def _fuzzy_match(quote_words: list[str], transcript_words: list[str], min_ratio: float) -> bool:
    matcher = SequenceMatcher(autojunk=False)
    matcher.set_seq2(" ".join(quote_words))
    n = len(quote_words)
    # Ventanas de n-1 a n+1 palabras toleran una palabra de más o de menos del reconocedor.
    for size in (n, n - 1, n + 1):
        for start in range(len(transcript_words) - size + 1):
            matcher.set_seq1(" ".join(transcript_words[start : start + size]))
            if (
                matcher.real_quick_ratio() >= min_ratio
                and matcher.quick_ratio() >= min_ratio
                and matcher.ratio() >= min_ratio
            ):
                return True
    return False


def quote_in_transcript(quote: str, transcript: str, min_ratio: float = 0.85) -> bool:
    quote_words = normalize(quote).split()
    transcript_words = normalize(transcript).split()
    if len(quote_words) < MIN_QUOTE_WORDS or not transcript_words:
        return False
    if f" {' '.join(quote_words)} " in f" {' '.join(transcript_words)} ":
        return True
    return _fuzzy_match(quote_words, transcript_words, min_ratio)


def verify_evidences(evidencias: list[Evidencia], transcript: str) -> list[Evidencia]:
    return [e.model_copy(update={"verificada": quote_in_transcript(e.cita, transcript)}) for e in evidencias]


def drop_unverified(evidencias: list[Evidencia]) -> list[Evidencia]:
    return [e for e in evidencias if e.verificada is True]


def verification_rate(evidencias: list[Evidencia]) -> float | None:
    if not evidencias:
        return None
    return sum(e.verificada is True for e in evidencias) / len(evidencias)
