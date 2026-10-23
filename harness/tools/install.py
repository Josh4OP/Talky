#!/usr/bin/env python3
"""Instala el arnés en un repositorio: copia las piezas que Claude Code y las herramientas esperan en la raíz.

Uso (desde la raíz del repositorio, con esta carpeta copiada como `harness/`):

    python harness/tools/install.py            # instala; no pisa archivos existentes
    python harness/tools/install.py --force    # sobrescribe lo que ya exista
    python harness/tools/install.py --dry-run  # muestra qué haría

Qué copia (origen -> destino en la raíz del repo):

    agent/CLAUDE.md               -> CLAUDE.md
    agent/commands/*.md           -> .claude/commands/
    agent/settings.json           -> .claude/settings.json
    tests/                        -> tests/
    evals/                        -> evals/
    templates/pytest.ini          -> pytest.ini
    templates/ruff.toml           -> ruff.toml
    templates/requirements*.txt   -> requirements*.txt
    templates/env.example         -> .env.example
    templates/Makefile.repo       -> Makefile
    templates/github/ci.yml       -> .github/workflows/ci.yml
    templates/gitignore.additions -> se agregan al .gitignore las líneas que falten

Es idempotente: ejecutarlo dos veces no cambia nada la segunda vez. Un archivo existente pero vacío
(como el `requirements.txt` original del proyecto) se considera ausente y se reemplaza.
Funciona en Linux, macOS y Windows (solo usa la librería estándar).
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

HARNESS = Path(__file__).resolve().parents[1]
IGNORED = {"__pycache__", ".pytest_cache", ".ruff_cache"}


def _files(path: Path):
    for p in sorted(path.rglob("*")):
        if p.is_file() and not (set(p.parts) & IGNORED) and p.suffix != ".pyc":
            yield p


def plan(harness: Path, repo: Path) -> list[tuple[Path, Path]]:
    pairs: list[tuple[Path, Path]] = [
        (harness / "agent" / "CLAUDE.md", repo / "CLAUDE.md"),
        (harness / "agent" / "settings.json", repo / ".claude" / "settings.json"),
    ]
    for md in sorted((harness / "agent" / "commands").glob("*.md")):
        pairs.append((md, repo / ".claude" / "commands" / md.name))
    for folder in ("tests", "evals"):
        for src in _files(harness / folder):
            pairs.append((src, repo / folder / src.relative_to(harness / folder)))
    templates = harness / "templates"
    mapping = {
        "pytest.ini": "pytest.ini",
        "ruff.toml": "ruff.toml",
        "env.example": ".env.example",
        "Makefile.repo": "Makefile",
        "github/ci.yml": ".github/workflows/ci.yml",
    }
    for req in sorted(templates.glob("requirements*.txt")):
        mapping[req.name] = req.name
    for src_name, dest_name in mapping.items():
        if (templates / src_name).is_file():
            pairs.append((templates / src_name, repo / dest_name))
    return pairs


def install(harness: Path, repo: Path, *, force: bool = False, dry_run: bool = False) -> dict:
    report = {"copied": [], "skipped": [], "gitignore_added": []}
    for src, dest in plan(harness, repo):
        rel = dest.relative_to(repo).as_posix()
        if dest.exists() and not force and dest.read_text(encoding="utf-8", errors="ignore").strip():
            report["skipped"].append(rel)
            continue
        report["copied"].append(rel)
        if not dry_run:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dest)

    additions = harness / "templates" / "gitignore.additions"
    if additions.is_file():
        gitignore = repo / ".gitignore"
        current = gitignore.read_text(encoding="utf-8") if gitignore.exists() else ""
        have = {line.strip() for line in current.splitlines()}
        missing = [
            ln
            for ln in additions.read_text(encoding="utf-8").splitlines()
            if ln.strip() and not ln.startswith("#") and ln.strip() not in have
        ]
        if missing:
            report["gitignore_added"] = missing
            if not dry_run:
                sep = "" if current.endswith("\n") or not current else "\n"
                gitignore.write_text(
                    current + sep + "\n# --- TALKY (arnés) ---\n" + "\n".join(missing) + "\n", encoding="utf-8"
                )
    if not dry_run:
        for folder in ("models", "scripts", "docs"):
            (repo / folder).mkdir(exist_ok=True)
    return report


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--repo", default=None, help="raíz del repositorio (por defecto, la carpeta que contiene harness/)"
    )
    parser.add_argument("--force", action="store_true", help="sobrescribe archivos existentes")
    parser.add_argument("--dry-run", action="store_true", help="no escribe nada, solo muestra el plan")
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve() if args.repo else HARNESS.parent
    if repo == HARNESS:
        print("Error: la raíz del repositorio no puede ser la propia carpeta del arnés. Usa --repo.", file=sys.stderr)
        return 2
    report = install(HARNESS, repo, force=args.force, dry_run=args.dry_run)
    prefix = "[simulación] " if args.dry_run else ""
    print(f"{prefix}Raíz del repositorio: {repo}")
    print(f"{prefix}Copiados: {len(report['copied'])}   Omitidos (ya existían): {len(report['skipped'])}")
    for rel in report["copied"]:
        print(f"  + {rel}")
    if report["skipped"]:
        print("  Omitidos (usa --force para sobrescribir):")
        for rel in report["skipped"]:
            print(f"  = {rel}")
    if report["gitignore_added"]:
        print(f"  .gitignore: {len(report['gitignore_added'])} líneas agregadas")
    print("\nSiguiente paso: python -m venv .venv, instalar requirements-dev.txt y abrir Claude Code en la raíz.")
    print("Luego pega el prompt de harness/prompts/sessions/00-kickoff.md.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
