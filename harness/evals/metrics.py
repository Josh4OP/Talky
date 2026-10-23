"""Métricas de evaluación de TALKY (Python puro, sin dependencias).

wer(reference, hypothesis)                      -> tasa de error de palabras
count_prf(expected, predicted)                  -> precisión/recall/F1 sobre conteos de muletillas
interval_prf(truth, predicted, tolerance_s)     -> precisión/recall/F1 de eventos con tiempos
accuracy(pairs)                                 -> exactitud simple
"""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Iterable, Sequence


def normalize_words(text: str) -> list[str]:
    text = unicodedata.normalize("NFD", text.casefold())
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9\s]", " ", text).split()


def _edit_distance(a: Sequence[str], b: Sequence[str]) -> int:
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, start=1):
        cur = [i]
        for j, y in enumerate(b, start=1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[-1]


def wer(reference: str, hypothesis: str) -> float:
    ref, hyp = normalize_words(reference), normalize_words(hypothesis)
    if not ref:
        return 0.0 if not hyp else 1.0
    return _edit_distance(ref, hyp) / len(ref)


def _prf(tp: float, fp: float, fn: float) -> dict:
    precision = tp / (tp + fp) if (tp + fp) else (1.0 if fn == 0 else 0.0)
    recall = tp / (tp + fn) if (tp + fn) else 1.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
    return {
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
        "tp": tp,
        "fp": fp,
        "fn": fn,
    }


def count_prf(expected: dict[str, int], predicted: dict[str, int]) -> dict:
    """Compara conteos por muletilla: tp = mínimo por clave, fp = exceso, fn = faltante."""
    tp = fp = fn = 0
    for key in set(expected) | set(predicted):
        e, p = expected.get(key, 0), predicted.get(key, 0)
        tp += min(e, p)
        fp += max(0, p - e)
        fn += max(0, e - p)
    return _prf(tp, fp, fn)


def _overlaps(a: tuple[float, float], b: tuple[float, float], tolerance_s: float) -> bool:
    return a[0] - tolerance_s <= b[1] and b[0] - tolerance_s <= a[1]


def interval_prf(
    truth: Iterable[tuple[float, float, str]], predicted: Iterable[tuple[float, float, str]], tolerance_s: float = 0.25
) -> dict:
    """Empareja intervalos de la misma etiqueta (uno a uno, voraz por inicio)."""
    truth, predicted = list(truth), list(predicted)
    used: set[int] = set()
    tp = 0
    for t_start, t_end, t_label in sorted(truth):
        for i, (p_start, p_end, p_label) in enumerate(predicted):
            if i in used or p_label != t_label:
                continue
            if _overlaps((t_start, t_end), (p_start, p_end), tolerance_s):
                used.add(i)
                tp += 1
                break
    return _prf(tp, len(predicted) - tp, len(truth) - tp)


def accuracy(pairs: Iterable[tuple[object, object]]) -> float:
    pairs = list(pairs)
    return sum(1 for a, b in pairs if a == b) / len(pairs) if pairs else 0.0
