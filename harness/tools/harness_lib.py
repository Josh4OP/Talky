"""Biblioteca mínima del harness: lectura de tareas y utilidades de grafo.

Sin dependencias externas (no usa PyYAML) para que funcione en cualquier entorno.
Formato del front matter de una tarea: líneas `clave: valor`; las listas van en línea: `[a, b]`.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

HARNESS_ROOT = Path(__file__).resolve().parents[1]
TASKS_DIR = HARNESS_ROOT / "prompts" / "tasks"

STATUSES = ("todo", "in_progress", "done", "blocked")
REQUIRED_KEYS = ("id", "title", "status", "phase", "depends_on", "requirements", "estimate", "tests", "touches")
REQUIRED_HEADINGS = (
    "Objetivo",
    "Contexto",
    "Alcance",
    "Contrato",
    "Criterios de aceptación",
    "Pruebas",
    "Definición de hecho",
)
VALID_REQUIREMENTS = {f"RF-{i:02d}" for i in range(1, 12)} | {f"RNF-{i:02d}" for i in range(1, 5)} | {"-"}
_FRONT = re.compile(r"\A---\n(.*?)\n---\n", re.S)


@dataclass
class Task:
    path: Path
    meta: dict
    body: str
    errors: list[str] = field(default_factory=list)

    @property
    def id(self) -> str:
        return self.meta.get("id", "")

    @property
    def status(self) -> str:
        return self.meta.get("status", "")

    @property
    def title(self) -> str:
        return self.meta.get("title", "")

    @property
    def depends_on(self) -> list[str]:
        return list(self.meta.get("depends_on", []))


def _parse_value(raw: str):
    raw = raw.strip()
    if raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        return [item.strip().strip("'\"") for item in inner.split(",") if item.strip()] if inner else []
    return raw.strip("'\"")


def parse_task(path: Path) -> Task:
    text = path.read_text(encoding="utf-8")
    m = _FRONT.match(text)
    if not m:
        return Task(path, {}, text, ["falta el front matter (--- ... ---)"])
    meta: dict = {}
    errors: list[str] = []
    for n, line in enumerate(m.group(1).splitlines(), start=1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            errors.append(f"front matter línea {n}: se esperaba 'clave: valor'")
            continue
        key, value = line.split(":", 1)
        meta[key.strip()] = _parse_value(value)
    return Task(path, meta, text[m.end() :], errors)


def load_tasks(tasks_dir: Path = TASKS_DIR) -> list[Task]:
    return sorted((parse_task(p) for p in Path(tasks_dir).glob("T*.md")), key=lambda t: t.path.name)


def headings(body: str) -> list[str]:
    return [m.group(1).strip() for m in re.finditer(r"^##\s+(.+)$", body, flags=re.M)]


def find_cycle(tasks: list[Task]) -> list[str] | None:
    """Devuelve un ciclo de dependencias (lista de ids) o None."""
    graph = {t.id: t.depends_on for t in tasks}
    state: dict[str, int] = {}
    stack: list[str] = []

    def visit(node: str) -> list[str] | None:
        state[node] = 1
        stack.append(node)
        for dep in graph.get(node, []):
            if dep not in graph:
                continue
            if state.get(dep) == 1:
                return stack[stack.index(dep) :] + [dep]
            if state.get(dep) is None:
                cycle = visit(dep)
                if cycle:
                    return cycle
        stack.pop()
        state[node] = 2
        return None

    for node in graph:
        if state.get(node) is None:
            cycle = visit(node)
            if cycle:
                return cycle
    return None


def topological_order(tasks: list[Task]) -> list[str]:
    cycle = find_cycle(tasks)
    if cycle:
        raise ValueError("ciclo de dependencias: " + " -> ".join(cycle))
    graph = {t.id: t.depends_on for t in tasks}
    order: list[str] = []
    seen: set[str] = set()

    def visit(node: str):
        if node in seen or node not in graph:
            return
        seen.add(node)
        for dep in sorted(graph[node]):
            visit(dep)
        order.append(node)

    for node in sorted(graph):
        visit(node)
    return order


def next_tasks(tasks: list[Task]) -> list[Task]:
    """Tareas `todo` cuyas dependencias están todas `done`, en orden de id."""
    done = {t.id for t in tasks if t.status == "done"}
    return [t for t in tasks if t.status == "todo" and all(d in done for d in t.depends_on)]


def set_status(path: Path, new_status: str) -> None:
    if new_status not in STATUSES:
        raise ValueError(f"estado inválido {new_status!r}; usa uno de {STATUSES}")
    text = path.read_text(encoding="utf-8")
    if not _FRONT.match(text):
        raise ValueError(f"{path.name}: sin front matter")
    new_text, n = re.subn(r"^status:.*$", f"status: {new_status}", text, count=1, flags=re.M)
    if n != 1:
        raise ValueError(f"{path.name}: no se encontró la línea 'status:'")
    path.write_text(new_text, encoding="utf-8")
