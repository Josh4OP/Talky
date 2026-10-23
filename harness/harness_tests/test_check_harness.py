"""Pruebas de check_harness sobre mini-harness sintéticos."""

import check_harness as ch
from helpers import write_task


def make_root(tmp_path, tasks=(("T01", {}),)):
    root = tmp_path / "h"
    for rel in ch.REQUIRED_FILES:
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("# ok\n" if rel.endswith(".md") else "", encoding="utf-8")
    for rel in ch.REQUIRED_DIRS:
        (root / rel).mkdir(parents=True, exist_ok=True)
    for tid, kw in tasks:
        write_task(root / "prompts" / "tasks", tid, **kw)
    (root / "agent" / "CLAUDE.md").write_text("# Claude\n", encoding="utf-8")
    return root


def problems(root):
    return ch.check(root)


def test_clean_harness_has_no_problems(tmp_path):
    root = make_root(tmp_path)
    # los .py vacíos compilan; las pruebas de tests/ no existen en el mini harness
    assert problems(root) == []


def test_missing_required_file_is_reported(tmp_path):
    root = make_root(tmp_path)
    (root / "README.md").unlink()
    assert any("README.md" in p for p in problems(root))


def test_broken_link_is_reported(tmp_path):
    root = make_root(tmp_path)
    (root / "context" / "00-overview.md").write_text("[x](no-existe.md)\n", encoding="utf-8")
    assert any("enlace roto" in p for p in problems(root))


def test_links_with_anchor_and_http_are_ok(tmp_path):
    root = make_root(tmp_path)
    (root / "context" / "00-overview.md").write_text(
        "[a](01-requirements.md#algo) [b](https://x.org) [c](#local)\n", encoding="utf-8"
    )
    assert problems(root) == []


def test_emoji_is_reported(tmp_path):
    root = make_root(tmp_path)
    (root / "context" / "00-overview.md").write_text("hola \U0001f680\n", encoding="utf-8")
    assert any("emojis" in p for p in problems(root))


def test_claude_import_must_exist_and_use_harness_prefix(tmp_path):
    root = make_root(tmp_path)
    (root / "agent" / "CLAUDE.md").write_text(
        "@harness/context/00-overview.md\n@harness/context/nope.md\n@otro/ruta.md\n", encoding="utf-8"
    )
    ps = problems(root)
    assert any("import roto @harness/context/nope.md" in p for p in ps)
    assert any("debe empezar con harness/" in p for p in ps)
    assert not any("00-overview" in p for p in ps)


def test_task_missing_heading_and_bad_status(tmp_path):
    root = make_root(tmp_path, tasks=[("T01", {"status": "hecho", "body": "## Objetivo\n"})])
    ps = problems(root)
    assert any("estado inválido" in p for p in ps)
    assert any("falta la sección '## Contrato'" in p for p in ps)


def test_task_dependency_unknown_and_cycle(tmp_path):
    root = make_root(
        tmp_path,
        tasks=[("T01", {"depends_on": ["T99"]}), ("T02", {"depends_on": ["T03"]}), ("T03", {"depends_on": ["T02"]})],
    )
    ps = problems(root)
    assert any("inexistente (T99)" in p for p in ps)
    assert any("ciclo de dependencias" in p for p in ps)


def test_task_unknown_requirement_and_missing_test(tmp_path):
    root = make_root(tmp_path, tasks=[("T01", {"requirements": ["RF-99"], "tests": ["tests/unit/test_nada.py"]})])
    ps = problems(root)
    assert any("requerimiento desconocido (RF-99)" in p for p in ps)
    assert any("la prueba declarada no existe" in p for p in ps)


def test_filename_must_start_with_id(tmp_path):
    root = make_root(tmp_path, tasks=[("T01", {"name": "T02-raro.md"})])
    assert any("debe empezar con 'T01-'" in p for p in problems(root))


def test_duplicate_ids(tmp_path):
    root = make_root(tmp_path, tasks=[("T01", {}), ("T01", {"name": "T01-otra.md"})])
    assert any("duplicado" in p for p in problems(root))


def test_orphan_acceptance_test_is_reported(tmp_path):
    root = make_root(tmp_path)
    (root / "tests" / "unit").mkdir(parents=True)
    (root / "tests" / "unit" / "test_huerfano.py").write_text("def test_x(): pass\n", encoding="utf-8")
    assert any("no pertenece a ninguna tarea" in p for p in problems(root))


def test_referenced_test_is_not_orphan(tmp_path):
    root = make_root(tmp_path, tasks=[("T01", {"tests": ["tests/unit/test_ok.py"]})])
    (root / "tests" / "unit").mkdir(parents=True)
    (root / "tests" / "unit" / "test_ok.py").write_text("def test_x(): pass\n", encoding="utf-8")
    assert problems(root) == []


def test_syntax_error_is_reported(tmp_path):
    root = make_root(tmp_path)
    (root / "tools" / "roto.py").write_text("def (:\n", encoding="utf-8")
    assert any("error de sintaxis" in p for p in problems(root))


def test_main_exit_codes(tmp_path, capsys):
    root = make_root(tmp_path)
    assert ch.main(["--root", str(root)]) == 0
    (root / "README.md").unlink()
    assert ch.main(["--root", str(root)]) == 1
    assert "problema(s)" in capsys.readouterr().out
