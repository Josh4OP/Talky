import install as inst
import make_zip
from conftest import ROOT


def make_repo(tmp_path):
    repo = tmp_path / "repo"
    repo.mkdir()
    (repo / ".gitignore").write_text(".env\n*.wav\n", encoding="utf-8")
    return repo


def test_install_copies_expected_files(tmp_path):
    repo = make_repo(tmp_path)
    report = inst.install(ROOT, repo)
    for rel in (
        "CLAUDE.md",
        ".claude/settings.json",
        ".claude/commands/verify.md",
        "tests/conftest.py",
        "tests/fakes.py",
        "evals/run_eval.py",
        "evals/metrics.py",
        "pytest.ini",
        "ruff.toml",
        "requirements.txt",
        "requirements-dev.txt",
        ".env.example",
        "Makefile",
        ".github/workflows/ci.yml",
    ):
        assert (repo / rel).is_file(), rel
    assert "CLAUDE.md" in report["copied"]
    assert (repo / "models").is_dir()


def test_install_does_not_copy_pycache(tmp_path):
    repo = make_repo(tmp_path)
    inst.install(ROOT, repo)
    assert not list(repo.rglob("__pycache__"))
    assert not list(repo.rglob("*.pyc"))


def test_install_is_idempotent_and_does_not_overwrite(tmp_path):
    repo = make_repo(tmp_path)
    inst.install(ROOT, repo)
    (repo / "CLAUDE.md").write_text("mío", encoding="utf-8")
    second = inst.install(ROOT, repo)
    assert second["copied"] == []
    assert "CLAUDE.md" in second["skipped"]
    assert (repo / "CLAUDE.md").read_text(encoding="utf-8") == "mío"


def test_empty_existing_file_counts_as_absent(tmp_path):
    repo = make_repo(tmp_path)
    (repo / "requirements.txt").write_text("", encoding="utf-8")
    (repo / "pytest.ini").write_text("[pytest]\n", encoding="utf-8")
    report = inst.install(ROOT, repo)
    assert "requirements.txt" in report["copied"]
    assert "pytest.ini" in report["skipped"]
    assert "fastapi" in (repo / "requirements.txt").read_text(encoding="utf-8")


def test_force_overwrites(tmp_path):
    repo = make_repo(tmp_path)
    inst.install(ROOT, repo)
    (repo / "CLAUDE.md").write_text("mío", encoding="utf-8")
    inst.install(ROOT, repo, force=True)
    assert (repo / "CLAUDE.md").read_text(encoding="utf-8") != "mío"


def test_dry_run_writes_nothing(tmp_path):
    repo = make_repo(tmp_path)
    report = inst.install(ROOT, repo, dry_run=True)
    assert report["copied"]
    assert not (repo / "CLAUDE.md").exists()
    assert (repo / ".gitignore").read_text(encoding="utf-8") == ".env\n*.wav\n"


def test_gitignore_only_gets_missing_lines(tmp_path):
    repo = make_repo(tmp_path)
    inst.install(ROOT, repo)
    text = (repo / ".gitignore").read_text(encoding="utf-8")
    assert text.count(".env\n") >= 1 and text.splitlines().count(".env") == 1
    assert text.splitlines().count("*.wav") == 1
    assert "models/*.joblib" in text
    inst.install(ROOT, repo)
    assert (repo / ".gitignore").read_text(encoding="utf-8") == text


def test_gitignore_is_created_when_missing(tmp_path):
    repo = tmp_path / "r"
    repo.mkdir()
    inst.install(ROOT, repo)
    assert "evals/dataset/audio/" in (repo / ".gitignore").read_text(encoding="utf-8")


def test_refuses_to_install_into_harness_itself(capsys):
    assert inst.main(["--repo", str(ROOT)]) == 2


def test_zip_has_single_top_folder_and_no_junk(tmp_path):
    root = tmp_path / "h"
    for rel, data in {
        "agent/CLAUDE.md": "x",
        "tools/a.py": "x",
        "tools/__pycache__/a.pyc": "x",
        ".env": "k",
        "evals/results/r.json": "{}",
        "evals/dataset/audio/a.wav": "x",
        "models/m.joblib": "x",
    }.items():
        f = root / rel
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(data, encoding="utf-8")
    out = tmp_path / "out" / "h.zip"
    names = make_zip.build_zip(root, out)
    assert sorted(names) == ["harness/agent/CLAUDE.md", "harness/tools/a.py"]
    assert out.is_file()
