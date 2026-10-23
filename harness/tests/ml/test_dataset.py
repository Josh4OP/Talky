"""T10 - Herramientas de datos para el clasificador de eventos acústicos (Python puro).

Contrato: src/infrastructure/ml/dataset.py
  LabelSpan(start, end, label)
  LabeledWindow(start, end, label)
  parse_audacity_labels(text) -> list[LabelSpan]
  windows_from_labels(spans, duration_s, win_s=1.0, hop_s=0.5, min_overlap=0.6,
                      default_label="speech") -> list[LabeledWindow]
  leave_one_speaker_out(speakers) -> list[tuple[list[int], list[int], str]]

Convención de etiquetado: en Audacity solo se marcan los eventos especiales
(filler, hum, silence, noise). Lo que no está marcado cuenta como `speech`.
"""

import pytest

from src.infrastructure.ml.dataset import (
    LabeledWindow,
    LabelSpan,
    leave_one_speaker_out,
    parse_audacity_labels,
    windows_from_labels,
)


class TestParseAudacityLabels:
    def test_parses_tab_separated_lines(self):
        text = "1.500000\t2.250000\tfiller\n10.0\t12.5\thum\n"
        assert parse_audacity_labels(text) == [LabelSpan(1.5, 2.25, "filler"), LabelSpan(10.0, 12.5, "hum")]

    def test_ignores_blank_lines_and_spectral_lines(self):
        text = "\n1.0\t2.0\tnoise\n\\\t100.0\t4000.0\n"
        assert parse_audacity_labels(text) == [LabelSpan(1.0, 2.0, "noise")]

    def test_labels_are_case_insensitive(self):
        assert parse_audacity_labels("1\t2\tFiller")[0].label == "filler"

    def test_unknown_label_reports_the_line(self):
        with pytest.raises(ValueError, match="línea 2"):
            parse_audacity_labels("1\t2\tfiller\n3\t4\tgrito")

    def test_end_must_be_after_start(self):
        with pytest.raises(ValueError):
            parse_audacity_labels("2.0\t1.0\tfiller")


class TestWindowsFromLabels:
    def test_labels_unlabeled_time_as_speech_and_drops_ambiguous_windows(self):
        spans = [LabelSpan(1.0, 2.0, "filler")]
        windows = windows_from_labels(spans, duration_s=4.0, win_s=1.0, hop_s=0.5)
        assert windows == [
            LabeledWindow(0.0, 1.0, "speech"),
            LabeledWindow(1.0, 2.0, "filler"),
            LabeledWindow(2.0, 3.0, "speech"),
            LabeledWindow(2.5, 3.5, "speech"),
            LabeledWindow(3.0, 4.0, "speech"),
        ]

    def test_only_full_windows_are_produced(self):
        windows = windows_from_labels([], duration_s=2.2, win_s=1.0, hop_s=1.0)
        assert [(w.start, w.end) for w in windows] == [(0.0, 1.0), (1.0, 2.0)]

    def test_audio_shorter_than_one_window(self):
        assert windows_from_labels([], duration_s=0.5, win_s=1.0, hop_s=0.5) == []

    def test_min_overlap_is_configurable(self):
        spans = [LabelSpan(0.0, 0.8, "hum")]
        strict = windows_from_labels(spans, 1.0, win_s=1.0, hop_s=1.0, min_overlap=0.9)
        loose = windows_from_labels(spans, 1.0, win_s=1.0, hop_s=1.0, min_overlap=0.7)
        assert strict == []
        assert loose == [LabeledWindow(0.0, 1.0, "hum")]

    @pytest.mark.parametrize("win,hop", [(0, 0.5), (1.0, 0), (-1, 1)])
    def test_invalid_sizes(self, win, hop):
        with pytest.raises(ValueError):
            windows_from_labels([], 5.0, win_s=win, hop_s=hop)


class TestLeaveOneSpeakerOut:
    def test_one_fold_per_speaker(self):
        folds = leave_one_speaker_out(["ana", "ana", "beto", "carla", "beto"])
        assert [f[2] for f in folds] == ["ana", "beto", "carla"]
        train, test, speaker = folds[1]
        assert speaker == "beto"
        assert test == [2, 4]
        assert train == [0, 1, 3]

    def test_train_and_test_never_share_a_speaker(self):
        speakers = ["a", "b", "a", "c", "b", "c"]
        for train, test, held_out in leave_one_speaker_out(speakers):
            assert {speakers[i] for i in test} == {held_out}
            assert held_out not in {speakers[i] for i in train}

    def test_needs_at_least_two_speakers(self):
        with pytest.raises(ValueError):
            leave_one_speaker_out(["ana", "ana"])
