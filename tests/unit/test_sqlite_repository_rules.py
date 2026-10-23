"""T05 - Reglas del contrato del repositorio SQLite que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md, sección sqlite_analysis_repository.py
  - Fecha UTC con formato %Y-%m-%dT%H:%M:%S.%fZ e id uuid4 en hexadecimal.
  - En empate de fecha, list devuelve primero la inserción más reciente.
  - list también aísla por usuario.
  - total_muletillas es 0 si "muletillas" no es un diccionario; duracion_s y ppm no numéricos son None.
  - Crea las carpetas padre del archivo si no existen.
"""

import re
import uuid
from datetime import datetime, timezone

from src.infrastructure.repositories.sqlite_analysis_repository import SqliteAnalysisRepository

FIXED = datetime(2026, 10, 26, 9, 30, 0, 123456, tzinfo=timezone.utc)


def test_created_at_is_utc_with_microseconds_and_id_is_uuid4_hex():
    repo = SqliteAnalysisRepository(":memory:", clock=lambda: FIXED)
    aid = repo.save("ana", "a.mp3", {})
    assert repo.get("ana", aid).created_at == "2026-10-26T09:30:00.123456Z"
    assert re.fullmatch(r"[0-9a-f]{32}", aid) and uuid.UUID(aid).version == 4


def test_ties_on_date_are_broken_by_most_recent_insertion():
    repo = SqliteAnalysisRepository(":memory:", clock=lambda: FIXED)
    ids = [repo.save("ana", f"f{i}.mp3", {}) for i in range(4)]
    assert [s.id for s in repo.list("ana")] == list(reversed(ids))


def test_list_is_isolated_per_user():
    repo = SqliteAnalysisRepository(":memory:")
    repo.save("ana", "a.mp3", {})
    assert repo.list("beto") == []


def test_malformed_summary_fields_degrade_to_defaults():
    repo = SqliteAnalysisRepository(":memory:")
    repo.save("ana", "a.mp3", {"muletillas": ["eh", "eh"], "duracion_s": "61", "ppm": None})
    s = repo.list("ana")[0]
    assert (s.duracion_s, s.ppm, s.total_muletillas) == (None, None, 0)


def test_unknown_id_is_none_and_not_deleted():
    repo = SqliteAnalysisRepository(":memory:")
    assert repo.get("ana", "no-existe") is None
    assert repo.delete("ana", "no-existe") is False


def test_parent_folders_are_created(tmp_path):
    path = tmp_path / "datos" / "historial" / "talky.db"
    aid = SqliteAnalysisRepository(str(path)).save("ana", "a.mp3", {})
    assert path.is_file() and SqliteAnalysisRepository(str(path)).get("ana", aid) is not None
