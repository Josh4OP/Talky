import re
from collections import Counter

FILLERS = [
    "o sea", "como que", "este", "eh", "ehh", "mmm", "mm", "básicamente",
    "digamos", "entonces", "verdad", "ahí", "tipo", "bueno", "pues",
    "la verdad", "en plan", "¿no?",
]


def detect_fillers(text: str) -> dict[str, int]:
    t = text.lower()
    counts: Counter = Counter()
    for f in FILLERS:
        pattern = re.escape(f) if not f[0].isalpha() else rf"\b{re.escape(f)}\b"
        n = len(re.findall(pattern, t))
        if n:
            counts[f] = n
    return dict(counts.most_common())