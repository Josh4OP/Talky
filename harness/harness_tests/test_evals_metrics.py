import metrics
import pytest


def test_wer_identical_is_zero():
    assert metrics.wer("hola mundo", "Hola, mundo!") == 0.0


def test_wer_ignores_accents_and_case():
    assert metrics.wer("Éste es un cambio", "este es un cambio") == 0.0


def test_wer_counts_substitution_deletion_insertion():
    assert metrics.wer("a b c d", "a x c d") == pytest.approx(0.25)
    assert metrics.wer("a b c d", "a b c") == pytest.approx(0.25)
    assert metrics.wer("a b c d", "a b c d e") == pytest.approx(0.25)


def test_wer_empty_reference():
    assert metrics.wer("", "") == 0.0
    assert metrics.wer("", "algo") == 1.0


def test_count_prf_perfect():
    r = metrics.count_prf({"eh": 2, "mmm": 1}, {"eh": 2, "mmm": 1})
    assert (r["precision"], r["recall"], r["f1"]) == (1.0, 1.0, 1.0)


def test_count_prf_mixed():
    r = metrics.count_prf({"eh": 3, "o sea": 1}, {"eh": 2, "este": 1})
    assert (r["tp"], r["fp"], r["fn"]) == (2, 1, 2)
    assert r["precision"] == pytest.approx(2 / 3, abs=1e-4)
    assert r["recall"] == pytest.approx(0.5)


def test_count_prf_nothing_expected_nothing_found_is_perfect():
    assert metrics.count_prf({}, {})["f1"] == 1.0


def test_count_prf_nothing_found_but_expected_is_zero():
    r = metrics.count_prf({"eh": 1}, {})
    assert r["recall"] == 0.0 and r["f1"] == 0.0


def test_interval_prf_matches_with_tolerance():
    truth = [(1.0, 1.5, "filler"), (5.0, 6.0, "hum")]
    pred = [(1.1, 1.6, "filler"), (5.2, 5.9, "hum")]
    assert metrics.interval_prf(truth, pred)["f1"] == 1.0


def test_interval_prf_label_must_match():
    r = metrics.interval_prf([(1.0, 1.5, "filler")], [(1.0, 1.5, "hum")])
    assert (r["tp"], r["fp"], r["fn"]) == (0, 1, 1)


def test_interval_prf_one_to_one_matching():
    truth = [(1.0, 1.5, "filler")]
    pred = [(1.0, 1.4, "filler"), (1.1, 1.5, "filler")]
    r = metrics.interval_prf(truth, pred)
    assert (r["tp"], r["fp"], r["fn"]) == (1, 1, 0)


def test_interval_prf_far_apart_does_not_match():
    r = metrics.interval_prf([(1.0, 1.5, "filler")], [(9.0, 9.5, "filler")], tolerance_s=0.25)
    assert r["tp"] == 0


def test_accuracy():
    assert metrics.accuracy([(1, 1), (1, 2), ("a", "a"), ("a", "b")]) == 0.5
    assert metrics.accuracy([]) == 0.0
