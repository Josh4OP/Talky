"""Detección de muletillas en la transcripción, distinguiendo el uso como relleno del uso legítimo."""

import re
from collections import Counter

# Clave canónica -> variantes del sonido (eh, ehh, ehm, em, emm / mm, mmm, hmm, hmmm).
VOCAL_FILLERS = {
    "eh": r"e+h+m*|e+m+",
    "mmm": r"h*m{2,}",
}
ALWAYS_FILLERS = ("o sea", "digamos", "como que", "en plan")
TAG_QUESTIONS = ("¿no?", "¿verdad?")
# Solo cuentan seguidas de pausa o como oración completa ("Este modelo..." no es muletilla).
CONTEXTUAL_FILLERS = ("este", "entonces", "bueno", "pues", "tipo", "básicamente")
# Solo cuentan seguidas de pausa ("la verdad es que" no es muletilla).
PAUSE_ONLY_FILLERS = ("la verdad",)

_PAUSE = re.compile(r"\s*(?:,|;|\.\.\.|…|—|–)")
_SENTENCE_END = re.compile(r"\s*(?:[.!?…]|$)")
_SENTENCE_OPENERS = " \t\n¿¡\"'«"
_SENTENCE_CLOSERS = ".!?…"
_VOCAL_TOKENS = {key: re.compile(variants) for key, variants in VOCAL_FILLERS.items()}
_EDGE_PUNCTUATION = re.compile(r"^\W+|\W+$")


def vocal_filler_key(token: str) -> str | None:
    """Clave canónica ("eh" o "mmm") si la palabra suelta es una muletilla vocal; si no, None."""
    word = _EDGE_PUNCTUATION.sub("", token.lower())
    return next((key for key, pattern in _VOCAL_TOKENS.items() if pattern.fullmatch(word)), None)


def _phrase_pattern(phrase: str) -> re.Pattern[str]:
    return re.compile(r"\b" + r"\s+".join(re.escape(w) for w in phrase.split()) + r"\b")


def _tag_pattern(tag: str) -> re.Pattern[str]:
    return re.compile(r"¿\s*" + re.escape(tag.strip("¿?")) + r"\s*\?")


def _followed_by_pause(text: str, end: int) -> bool:
    return _PAUSE.match(text, end) is not None


def _starts_sentence(text: str, start: int) -> bool:
    i = start
    while i > 0 and text[i - 1] in _SENTENCE_OPENERS:
        i -= 1
    return i == 0 or text[i - 1] in _SENTENCE_CLOSERS


def _is_whole_sentence(text: str, start: int, end: int) -> bool:
    return _starts_sentence(text, start) and _SENTENCE_END.match(text, end) is not None


def detect_fillers(text: str) -> dict[str, int]:
    t = text.lower()
    counts: Counter[str] = Counter()

    for key, variants in VOCAL_FILLERS.items():
        counts[key] += len(re.findall(rf"\b(?:{variants})\b", t))
    for phrase in ALWAYS_FILLERS:
        counts[phrase] += len(_phrase_pattern(phrase).findall(t))
    for tag in TAG_QUESTIONS:
        counts[tag] += len(_tag_pattern(tag).findall(t))
    for phrase in CONTEXTUAL_FILLERS:
        for m in _phrase_pattern(phrase).finditer(t):
            if _followed_by_pause(t, m.end()) or _is_whole_sentence(t, m.start(), m.end()):
                counts[phrase] += 1
    for phrase in PAUSE_ONLY_FILLERS:
        counts[phrase] += sum(_followed_by_pause(t, m.end()) for m in _phrase_pattern(phrase).finditer(t))

    return {k: n for k, n in counts.most_common() if n > 0}


def fillers_per_minute(counts: dict[str, int], duration_s: float) -> float:
    total = sum(counts.values())
    if duration_s <= 0 or total == 0:
        return 0.0
    return round(total * 60 / duration_s, 1)
