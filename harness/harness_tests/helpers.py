"""Utilidades para construir tareas de prueba."""

from pathlib import Path

BODY = "\n".join(
    f"## {h}\n\ntexto\n"
    for h in (
        "Objetivo",
        "Contexto",
        "Alcance",
        "Contrato",
        "Criterios de aceptación",
        "Pruebas",
        "Definición de hecho",
    )
)


def write_task(
    directory: Path,
    task_id: str,
    *,
    title="Titulo",
    status="todo",
    depends_on=(),
    requirements=("RF-01",),
    tests=("-",),
    touches=("src/x.py",),
    phase="1",
    estimate="1h",
    name=None,
    body=BODY,
    extra="",
) -> Path:
    def lst(items):
        return "[" + ", ".join(items) + "]"

    text = (
        f"---\nid: {task_id}\ntitle: {title}\nstatus: {status}\nphase: {phase}\n"
        f"depends_on: {lst(depends_on)}\nrequirements: {lst(requirements)}\nestimate: {estimate}\n"
        f"tests: {lst(tests)}\ntouches: {lst(touches)}\n{extra}---\n{body}"
    )
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / (name or f"{task_id}-tarea.md")
    path.write_text(text, encoding="utf-8")
    return path
