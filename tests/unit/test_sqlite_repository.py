"""T05 - Persistencia SQLite del historial (RF-07, RF-08, RNF-01).

Contrato: src/infrastructure/repositories/sqlite_analysis_repository.py
  SqliteAnalysisRepository(db_path)            # acepta ":memory:"
  save(user_id, filename, result: dict) -> str                       # id (uuid4 hex o str(uuid4))
  get(user_id, analysis_id) -> StoredAnalysis | None                 # None si no existe o es de otro usuario
  list(user_id, limit=50, offset=0) -> list[AnalysisSummary]         # más recientes primero
  count(user_id) -> int
  delete(user_id, analysis_id) -> bool
Puerto y dataclasses: src/domain/interfaces/ports.py
  StoredAnalysis(id, user_id, filename, created_at, result)
  AnalysisSummary(id, filename, created_at, duracion_s, ppm, total_muletillas)
Reglas: nunca se guarda el audio; los resultados se aíslan por user_id; hilos seguros.
"""

import threading

import pytest
from src.infrastructure.repositories.sqlite_analysis_repository import SqliteAnalysisRepository

from src.domain.interfaces.ports import AnalysisSummary, StoredAnalysis

RESULT = {
    "duracion_s": 61.5,
    "ppm": 120.0,
    "muletillas": {"eh": 3, "o sea": 2},
    "sintesis": {"resumen": "Muy bien, ¿no? Añadan más ejemplos."},
}


@pytest.fixture
def repo(tmp_path):
    return SqliteAnalysisRepository(str(tmp_path / "talky.db"))


def test_save_and_get_roundtrip(repo):
    aid = repo.save("ana", "charla.mp3", RESULT)
    stored = repo.get("ana", aid)
    assert isinstance(stored, StoredAnalysis)
    assert (stored.id, stored.user_id, stored.filename) == (aid, "ana", "charla.mp3")
    assert stored.result == RESULT  # unicode intacto
    assert stored.created_at.endswith("Z") or "+" in stored.created_at  # ISO-8601 en UTC


def test_results_are_isolated_per_user(repo):
    aid = repo.save("ana", "a.mp3", RESULT)
    assert repo.get("beto", aid) is None
    assert repo.delete("beto", aid) is False
    assert repo.count("beto") == 0
    assert repo.get("ana", aid) is not None


def test_list_returns_summaries_most_recent_first(repo):
    ids = [repo.save("ana", f"f{i}.mp3", {**RESULT, "ppm": 100.0 + i}) for i in range(3)]
    items = repo.list("ana")
    assert all(isinstance(i, AnalysisSummary) for i in items)
    assert [i.id for i in items] == list(reversed(ids))
    first = items[0]
    assert (first.filename, first.duracion_s, first.ppm, first.total_muletillas) == ("f2.mp3", 61.5, 102.0, 5)


def test_pagination(repo):
    ids = [repo.save("ana", f"f{i}.mp3", RESULT) for i in range(5)]
    page = repo.list("ana", limit=2, offset=1)
    assert [i.id for i in page] == [ids[3], ids[2]]
    assert repo.count("ana") == 5


def test_summary_tolerates_missing_fields(repo):
    repo.save("ana", "x.mp3", {})
    s = repo.list("ana")[0]
    assert (s.duracion_s, s.ppm, s.total_muletillas) == (None, None, 0)


def test_delete(repo):
    aid = repo.save("ana", "a.mp3", RESULT)
    assert repo.delete("ana", aid) is True
    assert repo.get("ana", aid) is None
    assert repo.delete("ana", aid) is False


def test_data_survives_reopening_the_database(tmp_path):
    path = str(tmp_path / "persist.db")
    aid = SqliteAnalysisRepository(path).save("ana", "a.mp3", RESULT)
    assert SqliteAnalysisRepository(path).get("ana", aid).result == RESULT


def test_in_memory_database(tmp_path):
    repo = SqliteAnalysisRepository(":memory:")
    aid = repo.save("ana", "a.mp3", RESULT)
    assert repo.get("ana", aid).filename == "a.mp3"


def test_empty_user_is_rejected(repo):
    with pytest.raises(ValueError):
        repo.save("", "a.mp3", RESULT)


def test_concurrent_saves_are_safe(repo):
    def work():
        for i in range(5):
            repo.save("ana", f"{threading.get_ident()}-{i}.mp3", RESULT)

    threads = [threading.Thread(target=work) for _ in range(8)]
    [t.start() for t in threads]
    [t.join() for t in threads]
    assert repo.count("ana") == 40
