"""T12 - Fusión de muletillas: palabras de Whisper + eventos acústicos.

Contrato: src/application/services/event_fusion.py
  fuse_fillers(words, events, tolerance_s=0.5, min_confidence=0.6) -> FusionResult
  FusionResult(fillers: list[FillerHit], hums: list[AcousticEvent])
  FillerHit(start, end, texto, source, confianza)
     source    in {"asr", "acoustic", "both"}
     confianza in {"alta", "media"}   ("alta" solo si ambas fuentes coinciden)
Entidad: src/domain/entities/events.py -> AcousticEvent(start, end, label, confidence=1.0)
Alcance: solo muletillas vocales de UNA palabra (eh, ehm, mmm, hmm). "o sea" lo cubre filler_detector.
"""

from src.application.services.event_fusion import fuse_fillers
from src.domain.entities.events import AcousticEvent

from src.domain.interfaces.ports import Word


def W(text, start, end):
    return Word(start=start, end=end, text=text)


def E(label, start, end, conf=0.9):
    return AcousticEvent(start=start, end=end, label=label, confidence=conf)


def test_asr_and_acoustic_agreement_has_high_confidence():
    r = fuse_fillers([W("Eh,", 1.0, 1.3)], [E("filler", 0.9, 1.4)])
    assert len(r.fillers) == 1
    hit = r.fillers[0]
    assert (hit.source, hit.confianza) == ("both", "alta")
    assert (hit.start, hit.end) == (0.9, 1.4)  # unión de ambos intervalos


def test_asr_only():
    r = fuse_fillers([W("mmm...", 2.0, 2.4)], [])
    hit = r.fillers[0]
    assert (hit.source, hit.confianza, hit.texto) == ("asr", "media", "mmm")


def test_acoustic_only_above_min_confidence():
    r = fuse_fillers([], [E("filler", 3.0, 3.5, 0.8)])
    hit = r.fillers[0]
    assert (hit.source, hit.confianza) == ("acoustic", "media")


def test_acoustic_below_min_confidence_is_dropped():
    assert fuse_fillers([], [E("filler", 3.0, 3.5, 0.4)]).fillers == []


def test_tolerance_controls_matching():
    words, events = [W("eh", 5.0, 5.2)], [E("filler", 5.6, 5.9)]
    assert [h.source for h in fuse_fillers(words, events, tolerance_s=0.5).fillers] == ["both"]
    separate = fuse_fillers(words, events, tolerance_s=0.1).fillers
    assert sorted(h.source for h in separate) == ["acoustic", "asr"]


def test_one_event_matches_at_most_one_word():
    words = [W("eh", 1.0, 1.2), W("eh", 1.25, 1.4)]
    r = fuse_fillers(words, [E("filler", 0.95, 1.45)])
    assert sorted(h.source for h in r.fillers) == ["asr", "both"]


def test_hums_are_reported_separately():
    r = fuse_fillers([], [E("hum", 7.0, 8.0, 0.9), E("hum", 9.0, 9.5, 0.3)])
    assert r.fillers == []
    assert [(h.start, h.end) for h in r.hums] == [(7.0, 8.0)]  # el de baja confianza se descarta


def test_other_labels_and_regular_words_are_ignored():
    words = [W("hola", 0.0, 0.3), W("o", 0.4, 0.5), W("sea", 0.5, 0.7)]
    events = [E("speech", 0.0, 1.0), E("silence", 1.0, 2.0), E("noise", 2.0, 3.0)]
    r = fuse_fillers(words, events)
    assert r.fillers == [] and r.hums == []


def test_tokens_are_normalized_before_checking():
    words = [
        W("Eh,", 0.0, 0.2),
        W("Ehhh", 1.0, 1.3),
        W("mmmm...", 2.0, 2.4),
        W("Hmm.", 3.0, 3.3),
        W("prehistoria", 4.0, 4.5),
    ]
    texts = [h.texto for h in fuse_fillers(words, []).fillers]
    assert texts == ["eh", "eh", "mmm", "mmm"]


def test_results_are_sorted_by_start_time():
    words = [W("eh", 5.0, 5.2)]
    events = [E("filler", 1.0, 1.4, 0.9)]
    starts = [h.start for h in fuse_fillers(words, events).fillers]
    assert starts == sorted(starts) == [1.0, 5.0]
