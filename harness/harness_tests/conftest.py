"""Rutas para importar las herramientas del harness (tools/ y evals/) sin instalarlas."""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for sub in ("tools", "evals"):
    p = str(ROOT / sub)
    if p not in sys.path:
        sys.path.insert(0, p)
