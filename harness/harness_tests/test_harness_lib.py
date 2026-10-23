import harness_lib as lib
import pytest
from helpers import write_task


def test_parse_task_reads_front_matter_and_lists(tmp_path):
    p = write_task(tmp_path, "T01", depends_on=["T00", "T02"], requirements=["RF-01", "RNF-02"])
    t = lib.parse_task(p)
    assert t.id == "T01" and t.status == "todo"
    assert t.depends_on == ["T00", "T02"]
    assert t.meta["requirements"] == ["RF-01", "RNF-02"]
    assert t.errors == []


def test_parse_task_empty_list(tmp_path):
    t = lib.parse_task(write_task(tmp_path, "T01", depends_on=[]))
    assert t.depends_on == []


def test_parse_task_without_front_matter_reports_error(tmp_path):
    p = tmp_path / "T01-x.md"
    p.write_text("# sin front matter\n", encoding="utf-8")
    t = lib.parse_task(p)
    assert t.errors and t.meta == {}


def test_parse_task_bad_line_reports_error(tmp_path):
    p = tmp_path / "T01-x.md"
    p.write_text("---\nid: T01\nlinea rota\n---\ncuerpo\n", encoding="utf-8")
    assert any("clave: valor" in e for e in lib.parse_task(p).errors)


def test_headings_lists_h2_only(tmp_path):
    t = lib.parse_task(write_task(tmp_path, "T01"))
    assert lib.headings(t.body) == list(lib.REQUIRED_HEADINGS)


def test_load_tasks_sorted_by_filename(tmp_path):
    write_task(tmp_path, "T02")
    write_task(tmp_path, "T01")
    assert [t.id for t in lib.load_tasks(tmp_path)] == ["T01", "T02"]


def test_next_tasks_requires_done_dependencies(tmp_path):
    write_task(tmp_path, "T01", status="done")
    write_task(tmp_path, "T02", depends_on=["T01"])
    write_task(tmp_path, "T03", depends_on=["T02"])
    write_task(tmp_path, "T04", status="in_progress")
    assert [t.id for t in lib.next_tasks(lib.load_tasks(tmp_path))] == ["T02"]


def test_find_cycle_detects_and_none_otherwise(tmp_path):
    write_task(tmp_path, "T01", depends_on=["T02"])
    write_task(tmp_path, "T02", depends_on=["T01"])
    cycle = lib.find_cycle(lib.load_tasks(tmp_path))
    assert cycle and cycle[0] == cycle[-1]

    ok = tmp_path / "ok"
    write_task(ok, "T01")
    write_task(ok, "T02", depends_on=["T01"])
    assert lib.find_cycle(lib.load_tasks(ok)) is None


def test_find_cycle_ignores_unknown_dependency(tmp_path):
    write_task(tmp_path, "T01", depends_on=["T99"])
    assert lib.find_cycle(lib.load_tasks(tmp_path)) is None


def test_topological_order_respects_dependencies(tmp_path):
    write_task(tmp_path, "T01", depends_on=["T03"])
    write_task(tmp_path, "T02", depends_on=["T01"])
    write_task(tmp_path, "T03")
    order = lib.topological_order(lib.load_tasks(tmp_path))
    assert order.index("T03") < order.index("T01") < order.index("T02")


def test_topological_order_raises_on_cycle(tmp_path):
    write_task(tmp_path, "T01", depends_on=["T02"])
    write_task(tmp_path, "T02", depends_on=["T01"])
    with pytest.raises(ValueError, match="ciclo"):
        lib.topological_order(lib.load_tasks(tmp_path))


def test_set_status_rewrites_only_status_line(tmp_path):
    p = write_task(tmp_path, "T01", title="Un titulo")
    before = p.read_text(encoding="utf-8")
    lib.set_status(p, "done")
    after = p.read_text(encoding="utf-8")
    assert "status: done" in after
    assert after.replace("status: done", "status: todo") == before


def test_set_status_rejects_invalid_value(tmp_path):
    p = write_task(tmp_path, "T01")
    with pytest.raises(ValueError):
        lib.set_status(p, "terminado")
