import json
from types import SimpleNamespace

import pytest
import run_eval


def test_load_manifest_accepts_object_and_list(tmp_path):
    p = tmp_path / "m.json"
    p.write_text(json.dumps({"entries": [{"id": "a"}]}), encoding="utf-8")
    assert run_eval.load_manifest(p) == [{"id": "a"}]
    p.write_text(json.dumps([{"id": "b"}]), encoding="utf-8")
    assert run_eval.load_manifest(p) == [{"id": "b"}]


def test_load_manifest_requires_id(tmp_path):
    p = tmp_path / "m.json"
    p.write_text(json.dumps({"entries": [{"audio": "x.wav"}]}), encoding="utf-8")
    with pytest.raises(ValueError, match="id"):
        run_eval.load_manifest(p)


def test_text_mode_scores_detector():
    entries = [
        {"id": "a", "reference_transcript": "eh hola", "expected_fillers": {"eh": 1}},
        {"id": "b", "reference_transcript": "hola", "expected_fillers": {"eh": 1}},
        {"id": "sin-esperado", "reference_transcript": "hola"},
    ]

    def detect(text):
        return {"eh": 1} if "eh" in text.split() else {}

    report = run_eval.run_text_mode(entries, detect)
    assert [r["id"] for r in report["rows"]] == ["a", "b"]
    assert report["summary"]["recall"] == pytest.approx(0.5)


def test_transcribe_mode_computes_wer_and_fillers(tmp_path):
    entries = [{"id": "a", "audio": "a.wav", "reference_transcript": "eh hola mundo", "expected_fillers": {"eh": 1}}]
    fake = lambda path: SimpleNamespace(text="eh hola mundo", duration=3.0)  # noqa: E731
    report = run_eval.run_transcribe_mode(entries, fake, lambda t: {"eh": 1}, tmp_path)
    row = report["rows"][0]
    assert row["wer"] == 0.0 and row["f1"] == 1.0 and row["duracion_audio_s"] == 3.0


def test_events_mode_only_compares_labels_present_in_truth(tmp_path):
    entries = [{"id": "a", "audio": "a.wav", "speaker": "ana", "events": [[1.0, 1.5, "filler"]]}]
    ev = lambda s, e, label: SimpleNamespace(start=s, end=e, label=label)  # noqa: E731
    classify = lambda path: [ev(1.0, 1.5, "filler"), ev(4.0, 5.0, "hum")]  # noqa: E731
    report = run_eval.run_events_mode(entries, classify, tmp_path)
    assert report["rows"][0]["f1"] == 1.0


def test_to_markdown_has_table_and_summary():
    report = {"mode": "text", "rows": [{"id": "a", "f1": 1.0, "wer": None}], "summary": {"f1": 1.0}}
    md = run_eval.to_markdown(report)
    assert "| id | f1 | wer |" in md and "| a | 1.0 | - |" in md and "f1=1.0" in md


def test_to_markdown_empty_rows():
    assert "Sin filas" in run_eval.to_markdown({"mode": "text", "rows": [], "summary": {}})


def test_example_manifest_is_valid():
    from conftest import ROOT

    entries = run_eval.load_manifest(ROOT / "evals" / "dataset" / "manifest.example.json")
    assert len(entries) >= 2
    for e in entries:
        assert {"id", "audio", "reference_transcript", "expected_fillers", "events"} <= set(e)
        for start, end, label in e["events"]:
            assert 0 <= start < end and label in {"filler", "hum"}
