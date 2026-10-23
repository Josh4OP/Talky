#!/usr/bin/env python3
"""CLI de tareas del harness.

python harness/tools/tasks.py list              # tabla de tareas y estados
python harness/tools/tasks.py next              # siguientes tareas desbloqueadas
python harness/tools/tasks.py show T05          # imprime la tarea completa
python harness/tools/tasks.py status T05 done   # cambia el estado (todo|in_progress|done|blocked)
python harness/tools/tasks.py order             # orden topológico recomendado
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from harness_lib import STATUSES, TASKS_DIR, load_tasks, next_tasks, set_status, topological_order  # noqa: E402

MARK = {"todo": "[ ]", "in_progress": "[~]", "done": "[x]", "blocked": "[!]"}


def _find(tasks, task_id):
    for t in tasks:
        if t.id.lower() == task_id.lower():
            return t
    raise SystemExit(f"No existe la tarea {task_id!r}")


def cmd_list(tasks) -> int:
    width = max((len(t.title) for t in tasks), default=10)
    for t in tasks:
        deps = ",".join(t.depends_on) or "-"
        print(
            f"{MARK.get(t.status, '[?]')} {t.id:<4} {t.title:<{width}}  {t.meta.get('estimate', ''):>5}  deps: {deps}"
        )
    done = sum(1 for t in tasks if t.status == "done")
    print(f"\n{done}/{len(tasks)} completadas")
    return 0


def cmd_next(tasks) -> int:
    ready = next_tasks(tasks)
    if not ready:
        print("No hay tareas desbloqueadas (todo terminado o bloqueado por dependencias).")
        return 0
    for t in ready:
        print(f"{t.id}  {t.title}  ({t.path.relative_to(TASKS_DIR.parents[1])})")
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    sub.add_parser("next")
    sub.add_parser("order")
    show = sub.add_parser("show")
    show.add_argument("task_id")
    st = sub.add_parser("status")
    st.add_argument("task_id")
    st.add_argument("new_status", choices=STATUSES)
    args = parser.parse_args(argv)

    tasks = load_tasks()
    if args.cmd == "list":
        return cmd_list(tasks)
    if args.cmd == "next":
        return cmd_next(tasks)
    if args.cmd == "order":
        print(" -> ".join(topological_order(tasks)))
        return 0
    if args.cmd == "show":
        print(_find(tasks, args.task_id).path.read_text(encoding="utf-8"))
        return 0
    if args.cmd == "status":
        task = _find(tasks, args.task_id)
        set_status(task.path, args.new_status)
        print(f"{task.id}: {task.status} -> {args.new_status}")
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
