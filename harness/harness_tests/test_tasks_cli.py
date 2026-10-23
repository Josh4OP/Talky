import harness_lib
import pytest
import tasks as cli
from helpers import write_task


@pytest.fixture
def tasks_dir(tmp_path, monkeypatch):
    d = tmp_path / "prompts" / "tasks"
    write_task(d, "T01", title="Base", status="done")
    write_task(d, "T02", title="Segunda", depends_on=["T01"])
    write_task(d, "T03", title="Tercera", depends_on=["T02"])
    monkeypatch.setattr(cli, "TASKS_DIR", d)
    monkeypatch.setattr(harness_lib, "TASKS_DIR", d)
    monkeypatch.setattr(cli, "load_tasks", lambda: harness_lib.load_tasks(d))
    return d


def test_list_shows_progress(tasks_dir, capsys):
    assert cli.main(["list"]) == 0
    out = capsys.readouterr().out
    assert "[x] T01" in out and "[ ] T02" in out and "1/3 completadas" in out


def test_next_shows_only_unblocked(tasks_dir, capsys):
    cli.main(["next"])
    out = capsys.readouterr().out
    assert "T02" in out and "T03" not in out


def test_next_when_nothing_ready(tasks_dir, capsys):
    harness_lib.set_status(tasks_dir / "T01-tarea.md", "blocked")
    harness_lib.set_status(tasks_dir / "T02-tarea.md", "blocked")
    cli.main(["next"])
    assert "No hay tareas" in capsys.readouterr().out


def test_status_updates_file(tasks_dir, capsys):
    cli.main(["status", "T02", "in_progress"])
    assert "status: in_progress" in (tasks_dir / "T02-tarea.md").read_text(encoding="utf-8")
    assert "todo -> in_progress" in capsys.readouterr().out


def test_status_rejects_unknown_state(tasks_dir):
    with pytest.raises(SystemExit):
        cli.main(["status", "T02", "hecho"])


def test_show_unknown_task_exits(tasks_dir):
    with pytest.raises(SystemExit):
        cli.main(["show", "T99"])


def test_show_prints_full_task(tasks_dir, capsys):
    cli.main(["show", "t02"])
    assert "id: T02" in capsys.readouterr().out


def test_order_prints_arrow_chain(tasks_dir, capsys):
    cli.main(["order"])
    assert capsys.readouterr().out.strip() == "T01 -> T02 -> T03"
