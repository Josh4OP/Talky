"""El harness real que se entrega debe pasar su propia validación (integración)."""

import check_harness as ch
import harness_lib as lib
from conftest import ROOT


def test_real_harness_is_consistent():
    assert ch.check(ROOT) == []


def test_real_tasks_form_a_valid_dag_and_start_at_t01():
    tasks = lib.load_tasks(ROOT / "prompts" / "tasks")
    assert tasks and tasks[0].id == "T01"
    order = lib.topological_order(tasks)
    assert len(order) == len(tasks)
    assert [t.id for t in tasks if not t.depends_on] == ["T01"]


def test_real_tasks_always_have_a_way_forward():
    tasks = lib.load_tasks(ROOT / "prompts" / "tasks")
    pending = [t for t in tasks if t.status not in ("done", "blocked")]
    in_progress = [t for t in tasks if t.status == "in_progress"]
    assert not pending or in_progress or lib.next_tasks(tasks)


def test_every_acceptance_test_file_is_covered_by_some_task():
    tasks = lib.load_tasks(ROOT / "prompts" / "tasks")
    referenced = {t for task in tasks for t in task.meta["tests"]}
    on_disk = {p.relative_to(ROOT).as_posix() for p in (ROOT / "tests").rglob("test_*.py")}
    assert on_disk <= referenced
