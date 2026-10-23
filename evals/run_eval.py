#!/usr/bin/env python3
"""Harness de evaluación: mide la calidad real del pipeline y deja números para el informe.

Modos (--mode):
  text        Detector de muletillas sobre la transcripción de referencia (no necesita audio ni red).
  transcribe  Transcribe cada audio (--transcriber groq|local), mide WER y muletillas contra lo esperado.
  events      Clasificador de eventos acústicos (--event-model RUTA) contra los eventos etiquetados.

Ejemplos (desde la raíz del repo, con harness/ instalado):
  python evals/run_eval.py --mode text --manifest evals/dataset/manifest.json
  python evals/run_eval.py --mode transcribe --transcriber groq --manifest ...
  python evals/run_eval.py --mode events --event-model models/event_classifier.joblib --manifest ...

Salida: tabla en consola + JSON y Markdown en evals/results/ (carpeta ignorada por git).
El formato del manifiesto está en evals/README.md.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import metrics  # noqa: E402


def load_manifest(path: Path) -> list[dict]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    entries = data["entries"] if isinstance(data, dict) else data
    for i, e in enumerate(entries):
        if "id" not in e:
            raise ValueError(f"entrada {i}: falta 'id'")
    return entries


def _macro(rows: list[dict], key: str) -> float | None:
    values = [r[key] for r in rows if r.get(key) is not None]
    return round(sum(values) / len(values), 4) if values else None


def run_text_mode(entries: list[dict], detect) -> dict:
    """`detect(text) -> dict[str, int]` (normalmente src.application.services.filler_detector.detect_fillers)."""
    rows = []
    for e in entries:
        if "reference_transcript" not in e or "expected_fillers" not in e:
            continue
        prf = metrics.count_prf(e["expected_fillers"], detect(e["reference_transcript"]))
        rows.append({"id": e["id"], "precision": prf["precision"], "recall": prf["recall"], "f1": prf["f1"]})
    return {"mode": "text", "rows": rows, "summary": {k: _macro(rows, k) for k in ("precision", "recall", "f1")}}


def run_transcribe_mode(entries: list[dict], transcribe, detect, base: Path) -> dict:
    """`transcribe(path) -> Transcription` con .text y .duration."""
    rows = []
    for e in entries:
        if "audio" not in e:
            continue
        started = time.perf_counter()
        tr = transcribe(str(base / e["audio"]))
        elapsed = time.perf_counter() - started
        row = {
            "id": e["id"],
            "segundos": round(elapsed, 2),
            "duracion_audio_s": round(tr.duration, 2),
            "wer": None,
            "precision": None,
            "recall": None,
            "f1": None,
        }
        if e.get("reference_transcript"):
            row["wer"] = round(metrics.wer(e["reference_transcript"], tr.text), 4)
        if e.get("expected_fillers") is not None:
            prf = metrics.count_prf(e["expected_fillers"], detect(tr.text))
            row.update({k: prf[k] for k in ("precision", "recall", "f1")})
        rows.append(row)
    return {
        "mode": "transcribe",
        "rows": rows,
        "summary": {k: _macro(rows, k) for k in ("wer", "precision", "recall", "f1", "segundos")},
    }


def run_events_mode(entries: list[dict], classify, base: Path, tolerance_s: float = 0.25) -> dict:
    """`classify(path) -> list[AcousticEvent]`. Solo se comparan las etiquetas presentes en el manifiesto."""
    rows = []
    for e in entries:
        if "audio" not in e or "events" not in e:
            continue
        truth = [(s, t, label) for s, t, label in e["events"]]
        labels = {label for _, _, label in truth}
        predicted = [(ev.start, ev.end, ev.label) for ev in classify(str(base / e["audio"])) if ev.label in labels]
        prf = metrics.interval_prf(truth, predicted, tolerance_s)
        rows.append({"id": e["id"], "speaker": e.get("speaker"), **{k: prf[k] for k in ("precision", "recall", "f1")}})
    return {"mode": "events", "rows": rows, "summary": {k: _macro(rows, k) for k in ("precision", "recall", "f1")}}


def to_markdown(report: dict) -> str:
    rows = report["rows"]
    if not rows:
        return f"# Evaluación ({report['mode']})\n\nSin filas: revisa el manifiesto.\n"
    cols = list(rows[0])
    lines = [f"# Evaluación ({report['mode']})", "", "| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for r in rows:
        lines.append("| " + " | ".join("-" if r[c] is None else str(r[c]) for c in cols) + " |")
    lines += ["", "Resumen (promedio): " + ", ".join(f"{k}={v}" for k, v in report["summary"].items())]
    return "\n".join(lines) + "\n"


def _build_transcriber(kind: str):
    import os

    if kind == "groq":
        from openai import OpenAI
        from src.infrastructure.external.groq_transcriber import GroqTranscriber

        client = OpenAI(base_url="https://api.groq.com/openai/v1", api_key=os.environ["GROQ_API_KEY"])
        return GroqTranscriber(client, model=os.getenv("GROQ_WHISPER_MODEL", "whisper-large-v3"))
    from src.infrastructure.external.whisper_transcriber import WhisperTranscriber

    return WhisperTranscriber(os.getenv("WHISPER_MODEL", "small"))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mode", choices=["text", "transcribe", "events"], required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--transcriber", choices=["groq", "local"], default="groq")
    parser.add_argument("--event-model", default="models/event_classifier.joblib")
    parser.add_argument("--tolerance", type=float, default=0.25)
    parser.add_argument("--out", default="evals/results")
    args = parser.parse_args(argv)

    sys.path.insert(0, str(Path.cwd()))  # permite importar `src` desde la raíz del repo
    manifest = Path(args.manifest)
    entries = load_manifest(manifest)
    base = manifest.parent

    from src.application.services.filler_detector import detect_fillers

    if args.mode == "text":
        report = run_text_mode(entries, detect_fillers)
    elif args.mode == "transcribe":
        report = run_transcribe_mode(entries, _build_transcriber(args.transcriber).transcribe, detect_fillers, base)
    else:
        from src.infrastructure.ml.event_classifier import SklearnEventClassifier
        from src.infrastructure.ml.event_model import EventModel

        classifier = SklearnEventClassifier(EventModel.load(args.event_model))
        report = run_events_mode(entries, classifier.classify, base, args.tolerance)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    (out_dir / f"{args.mode}-{stamp}.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    md = to_markdown(report)
    (out_dir / f"{args.mode}-{stamp}.md").write_text(md, encoding="utf-8")
    print(md)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
