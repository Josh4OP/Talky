"""Historial de análisis por usuario en SQLite."""

import json
import sqlite3
import threading
import uuid
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path

from src.domain.interfaces.ports import AnalysisRepository, AnalysisSummary, StoredAnalysis

_SCHEMA = """
CREATE TABLE IF NOT EXISTS analyses (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    filename TEXT NOT NULL,
    created_at TEXT NOT NULL,
    result_json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_analyses_user_created ON analyses (user_id, created_at);
"""
_DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"


def _is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _number_or_none(value) -> float | None:
    return float(value) if _is_number(value) else None


def _total_fillers(result: dict) -> int:
    counts = result.get("muletillas")
    if not isinstance(counts, dict):
        return 0
    return int(sum(v for v in counts.values() if _is_number(v)))


class SqliteAnalysisRepository(AnalysisRepository):
    """Repositorio SQLite seguro entre hilos; toda consulta filtra por user_id."""

    def __init__(self, db_path: str, *, clock: Callable[[], datetime] = lambda: datetime.now(timezone.utc)):
        self._clock = clock
        if db_path != ":memory:":
            Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(db_path, check_same_thread=False)
        with self._lock:
            self._conn.executescript(_SCHEMA)
            self._conn.commit()

    def save(self, user_id: str, filename: str, result: dict) -> str:
        if not user_id:
            raise ValueError("user_id no puede estar vacío")
        analysis_id = uuid.uuid4().hex
        created_at = self._clock().strftime(_DATE_FORMAT)
        payload = json.dumps(result, ensure_ascii=False)
        with self._lock:
            self._conn.execute(
                "INSERT INTO analyses (id, user_id, filename, created_at, result_json) VALUES (?, ?, ?, ?, ?)",
                (analysis_id, user_id, filename, created_at, payload),
            )
            self._conn.commit()
        return analysis_id

    def get(self, user_id: str, analysis_id: str) -> StoredAnalysis | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT id, user_id, filename, created_at, result_json FROM analyses WHERE user_id = ? AND id = ?",
                (user_id, analysis_id),
            ).fetchone()
        if row is None:
            return None
        return StoredAnalysis(id=row[0], user_id=row[1], filename=row[2], created_at=row[3], result=json.loads(row[4]))

    def list(self, user_id: str, limit: int = 50, offset: int = 0) -> list[AnalysisSummary]:
        with self._lock:
            # En empate de fecha, rowid desempata por orden de inserción.
            rows = self._conn.execute(
                "SELECT id, filename, created_at, result_json FROM analyses WHERE user_id = ? "
                "ORDER BY created_at DESC, rowid DESC LIMIT ? OFFSET ?",
                (user_id, int(limit), int(offset)),
            ).fetchall()
        summaries = []
        for analysis_id, filename, created_at, result_json in rows:
            result = json.loads(result_json)
            summaries.append(
                AnalysisSummary(
                    id=analysis_id,
                    filename=filename,
                    created_at=created_at,
                    duracion_s=_number_or_none(result.get("duracion_s")),
                    ppm=_number_or_none(result.get("ppm")),
                    total_muletillas=_total_fillers(result),
                )
            )
        return summaries

    def count(self, user_id: str) -> int:
        with self._lock:
            (n,) = self._conn.execute("SELECT COUNT(*) FROM analyses WHERE user_id = ?", (user_id,)).fetchone()
        return n

    def delete(self, user_id: str, analysis_id: str) -> bool:
        with self._lock:
            cursor = self._conn.execute("DELETE FROM analyses WHERE user_id = ? AND id = ?", (user_id, analysis_id))
            self._conn.commit()
        return cursor.rowcount > 0
