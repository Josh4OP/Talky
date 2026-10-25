"""T12 - Reglas de la fusión que las pruebas de aceptación no fijan.

Contrato (harness/context/10-module-contracts.md, sección event_fusion.py):
  - Un evento se empareja con la palabra más cercana dentro de la tolerancia; cada palabra y cada evento, una vez.
  - Emparejados: texto = clave canónica de la palabra. Solo acústico: texto = "[acustico]".
  - Un evento cuenta si confidence >= min_confidence (el límite exacto entra).
  - Los tatareos se reportan aparte, ordenados por inicio, y nunca se emparejan con palabras.
  - FillerHit es inmutable y to_dict redondea los tiempos a 3 decimales.
  - vocal_filler_key (filler_detector) normaliza las variantes a "eh" o "mmm" y devuelve None para lo demás.
"""

import dataclasses

import pytest

from src.application.services.event_fusion import ACOUSTIC_TEXT, FillerHit, fuse_fillers
from src.application.services.filler_detector import vocal_filler_key
from src.domain.entities.events import AcousticEvent
from src.domain.interfaces.ports import Word


def W(text, start, end):
    return Word(start=start, end=end, text=text)


def E(label, start, end, conf=0.9):
    return AcousticEvent(start=start, end=end, label=label, confidence=conf)


def test_event_pairs_with_the_nearest_word():
    words = [W("eh", 1.0, 1.2), W("eh", 1.5, 1.7)]
    r = fuse_fillers(words, [E("filler", 1.55, 1.75)])
    assert [(h.start, h.source) for h in r.fillers] == [(1.0, "asr"), (1.5, "both")]


def test_a_word_matches_at_most_one_event():
    r = fuse_fillers([W("eh", 2.0, 2.2)], [E("filler", 1.9, 2.1), E("filler", 2.15, 2.4)])
    assert sorted(h.source for h in r.fillers) == ["acoustic", "both"]


def test_acoustic_only_hit_uses_the_acoustic_marker():
    r = fuse_fillers([], [E("filler", 3.0, 3.4)])
    assert r.fillers[0].texto == ACOUSTIC_TEXT == "[acustico]"


def test_matched_hit_keeps_the_canonical_word_key():
    r = fuse_fillers([W("Ehm...", 1.0, 1.3)], [E("filler", 1.0, 1.3)])
    assert (r.fillers[0].texto, r.fillers[0].source) == ("eh", "both")


def test_confidence_exactly_at_the_minimum_counts():
    r = fuse_fillers([], [E("filler", 1.0, 1.2, 0.6), E("hum", 2.0, 3.0, 0.6)], min_confidence=0.6)
    assert (len(r.fillers), len(r.hums)) == (1, 1)


def test_gap_exactly_at_the_tolerance_still_matches():
    r = fuse_fillers([W("eh", 1.0, 1.2)], [E("filler", 1.7, 1.9)], tolerance_s=0.5)
    assert [h.source for h in r.fillers] == ["both"]


def test_overlapping_intervals_match_even_with_zero_tolerance():
    r = fuse_fillers([W("mmm", 1.0, 1.5)], [E("filler", 1.2, 1.4)], tolerance_s=0.0)
    assert [(h.source, h.start, h.end) for h in r.fillers] == [("both", 1.0, 1.5)]


def test_hums_are_sorted_by_start_and_never_paired_with_words():
    r = fuse_fillers([W("mmm", 4.0, 4.5)], [E("hum", 9.0, 9.5), E("hum", 4.0, 4.5)])
    assert [h.start for h in r.hums] == [4.0, 9.0]
    assert [h.source for h in r.fillers] == ["asr"]


def test_empty_inputs_give_an_empty_result():
    r = fuse_fillers([], [])
    assert (r.fillers, r.hums) == ([], [])


def test_to_dict_rounds_times_and_keeps_contract_keys():
    hit = FillerHit(1.23456, 2.0004, "eh", "asr", "media")
    assert hit.to_dict() == {"start": 1.235, "end": 2.0, "texto": "eh", "source": "asr", "confianza": "media"}


def test_filler_hit_is_immutable():
    hit = FillerHit(1.0, 1.2, "eh", "asr", "media")
    with pytest.raises(dataclasses.FrozenInstanceError):
        hit.texto = "mmm"


@pytest.mark.parametrize(
    ("token", "key"),
    [("eh", "eh"), ("Ehh,", "eh"), ("ehm", "eh"), ("em", "eh"), ("emm...", "eh"),
     ("mm", "mmm"), ("Mmm", "mmm"), ("hmm", "mmm"), ("hmmm.", "mmm")],
)  # fmt: skip
def test_vocal_filler_key_normalizes_variants(token, key):
    assert vocal_filler_key(token) == key


@pytest.mark.parametrize("token", ["este", "o sea", "", "m", "hm", "prehistoria", "emma"])
def test_vocal_filler_key_rejects_other_words(token):
    assert vocal_filler_key(token) is None
