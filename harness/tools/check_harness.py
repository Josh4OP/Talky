#!/usr/bin/env python3
"""Valida la coherencia interna del harness. Sale con código 1 si encuentra problemas.

Comprobaciones:
  1. Archivos y carpetas obligatorios.
  2. Imports `@harness/...` de CLAUDE.md y enlaces relativos de todos los .md.
  3. Tareas: front matter, ids, estados, dependencias (sin ciclos), secciones obligatorias,
     requerimientos válidos y rutas de pruebas existentes.
  4. Cada archivo de pruebas de aceptación pertenece al menos a una tarea.
  5. Sin emojis en la documentación (preferencia del equipo).
  6. Todo el Python del harness compila.

Uso:  python tools/check_harness.py [--root RUTA]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import harness_lib as lib  # noqa: E402

REQUIRED_FILES = [
    "README.md",
    "install.sh",
    "Makefile",
    "agent/CLAUDE.md",
    "agent/settings.json",
    "agent/rules/architecture.md",
    "agent/rules/python-style.md",
    "agent/rules/testing.md",
    "agent/rules/git-workflow.md",
    "agent/rules/security-privacy.md",
    "agent/rules/ml-guidelines.md",
    "agent/rules/llm-prompting.md",
    "agent/commands/next-task.md",
    "agent/commands/verify.md",
    "agent/commands/review.md",
    "agent/commands/status.md",
    "context/00-overview.md",
    "context/01-requirements.md",
    "context/02-architecture.md",
    "context/03-agentic-patterns.md",
    "context/04-ml-design.md",
    "context/05-llm-and-groq.md",
    "context/06-current-state.md",
    "context/07-api-contract.md",
    "context/08-flutter-app.md",
    "context/09-glossary.md",
    "context/10-module-contracts.md",
    "context/11-references.md",
    "prompts/README.md",
    "prompts/sessions/00-kickoff.md",
    "prompts/templates/task.md",
    "prompts/llm/analysis_system.es.md",
    "prompts/llm/judge_system.es.md",
    "tests/conftest.py",
    "tests/fakes.py",
    "evals/README.md",
    "evals/metrics.py",
    "evals/run_eval.py",
    "evals/dataset/manifest.example.json",
    "tools/harness_lib.py",
    "tools/tasks.py",
    "tools/check_harness.py",
    "tools/install.py",
    "tools/make_zip.py",
    "templates/pytest.ini",
    "templates/ruff.toml",
    "templates/requirements.txt",
    "templates/requirements-dev.txt",
    "templates/env.example",
    "templates/gitignore.additions",
    "templates/Makefile.repo",
    "templates/github/ci.yml",
    "prompts/templates/bugfix.md",
    "prompts/templates/review.md",
    "prompts/sessions/01-resume.md",
    "context/12-decisions.md",
    "checklists/definition-of-done.md",
    "checklists/demo-monday.md",
]
REQUIRED_DIRS = ["agent", "context", "prompts/tasks", "tests", "evals", "tools", "harness_tests", "checklists"]
LINK_RE = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)\)")
IMPORT_RE = re.compile(r"^@(\S+)\s*$", re.M)
EMOJI_RE = re.compile("[\U0001f300-\U0001faff\U00002600-\U000027bf\U0001f000-\U0001f2ff\U00002b50\U00002b55\U0000fe0f]")


def check(root: Path) -> list[str]:
    problems: list[str] = []

    for rel in REQUIRED_FILES:
        if not (root / rel).is_file():
            problems.append(f"falta el archivo obligatorio: {rel}")
    for rel in REQUIRED_DIRS:
        if not (root / rel).is_dir():
            problems.append(f"falta la carpeta obligatoria: {rel}")

    md_files = sorted(p for p in root.rglob("*.md") if "node_modules" not in p.parts)
    for md in md_files:
        text = md.read_text(encoding="utf-8")
        rel = md.relative_to(root)
        if EMOJI_RE.search(text):
            problems.append(f"{rel}: contiene emojis (el equipo pidió no usarlos)")
        for target in LINK_RE.findall(text):
            if re.match(r"^(https?:|mailto:|#)", target):
                continue
            path = target.split("#", 1)[0]
            if path and not (md.parent / path).exists():
                problems.append(f"{rel}: enlace roto -> {target}")

    claude = root / "agent" / "CLAUDE.md"
    if claude.is_file():
        for imp in IMPORT_RE.findall(claude.read_text(encoding="utf-8")):
            if not imp.startswith("harness/"):
                problems.append(f"agent/CLAUDE.md: el import @{imp} debe empezar con harness/")
                continue
            if not (root / imp[len("harness/") :]).exists():
                problems.append(f"agent/CLAUDE.md: import roto @{imp}")

    tasks = lib.load_tasks(root / "prompts" / "tasks")
    if not tasks:
        problems.append("prompts/tasks: no hay tareas")
    ids = [t.id for t in tasks]
    for dup in {i for i in ids if ids.count(i) > 1}:
        problems.append(f"id de tarea duplicado: {dup}")
    known = set(ids)
    test_files = {p.relative_to(root).as_posix() for p in (root / "tests").rglob("test_*.py")}
    referenced: set[str] = set()
    for t in tasks:
        name = t.path.name
        for err in t.errors:
            problems.append(f"{name}: {err}")
        for key in lib.REQUIRED_KEYS:
            if key not in t.meta:
                problems.append(f"{name}: falta la clave '{key}' en el front matter")
        if t.id and not name.startswith(t.id + "-"):
            problems.append(f"{name}: el nombre del archivo debe empezar con '{t.id}-'")
        if t.status and t.status not in lib.STATUSES:
            problems.append(f"{name}: estado inválido '{t.status}'")
        for dep in t.depends_on:
            if dep not in known:
                problems.append(f"{name}: depende de una tarea inexistente ({dep})")
        for req in t.meta.get("requirements", []):
            if req not in lib.VALID_REQUIREMENTS:
                problems.append(f"{name}: requerimiento desconocido ({req})")
        for test in t.meta.get("tests", []):
            referenced.add(test)
            if test != "-" and not (root / test).is_file():
                problems.append(f"{name}: la prueba declarada no existe ({test})")
        present = lib.headings(t.body)
        for h in lib.REQUIRED_HEADINGS:
            if h not in present:
                problems.append(f"{name}: falta la sección '## {h}'")
    cycle = lib.find_cycle(tasks)
    if cycle:
        problems.append("ciclo de dependencias: " + " -> ".join(cycle))
    for tf in sorted(test_files - referenced):
        problems.append(f"la prueba {tf} no pertenece a ninguna tarea")

    for py in sorted(root.rglob("*.py")):
        if "__pycache__" in py.parts:
            continue
        try:
            compile(py.read_text(encoding="utf-8"), str(py), "exec")
        except SyntaxError as e:
            problems.append(f"{py.relative_to(root)}: error de sintaxis ({e.msg}, línea {e.lineno})")

    return problems


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=str(lib.HARNESS_ROOT))
    args = parser.parse_args(argv)
    problems = check(Path(args.root).resolve())
    if problems:
        print(f"{len(problems)} problema(s) en el harness:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print("Harness consistente.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
