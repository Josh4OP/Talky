#!/usr/bin/env python3
"""Empaqueta el arnés en harness.zip (carpeta raíz `harness/` dentro del zip).

Excluye cachés, binarios compilados y resultados locales. Uso:

    python tools/make_zip.py [--out RUTA]   # por defecto ../harness.zip junto a la carpeta del arnés
"""

from __future__ import annotations

import argparse
import zipfile
from pathlib import Path

HARNESS = Path(__file__).resolve().parents[1]
EXCLUDED_DIRS = {"__pycache__", ".pytest_cache", ".ruff_cache", ".git", ".venv", "results"}
EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".joblib", ".db", ".wav", ".mp3", ".m4a", ".ogg", ".flac", ".webm"}
EXCLUDED_NAMES = {".DS_Store", "Thumbs.db", ".env"}


def collect(root: Path) -> list[Path]:
    out = []
    for p in sorted(root.rglob("*")):
        rel = p.relative_to(root)
        if not p.is_file():
            continue
        if set(rel.parts) & EXCLUDED_DIRS or p.suffix in EXCLUDED_SUFFIXES or p.name in EXCLUDED_NAMES:
            continue
        out.append(p)
    return out


def build_zip(root: Path, out: Path, top: str = "harness") -> list[str]:
    names = []
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for p in collect(root):
            arcname = f"{top}/{p.relative_to(root).as_posix()}"
            info = zipfile.ZipInfo.from_file(p, arcname)
            info.compress_type = zipfile.ZIP_DEFLATED
            zf.writestr(info, p.read_bytes())
            names.append(arcname)
    return names


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", default=str(HARNESS.parent / "harness.zip"))
    args = parser.parse_args(argv)
    names = build_zip(HARNESS, Path(args.out))
    print(f"{len(names)} archivos escritos en {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
