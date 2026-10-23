---
id: T05
title: Repositorio SQLite del historial
status: todo
phase: 1-nucleo
depends_on: [T02]
requirements: [RF-07, RF-08, RNF-01]
estimate: 3h
tests: [tests/unit/test_sqlite_repository.py]
touches: [src/infrastructure/repositories/sqlite_analysis_repository.py]
---
# T05 - Repositorio SQLite del historial

## Objetivo

Persistir cada análisis por usuario para poder consultarlo después (RF-07, RF-08), con aislamiento entre usuarios (RNF-01) y sin guardar nunca el audio.

## Contexto

Puerto `AnalysisRepository` y dataclasses `StoredAnalysis` y `AnalysisSummary` definidos en T02. Esquema y reglas en `harness/context/02-architecture.md` (Persistencia) y `harness/context/10-module-contracts.md`. El historial debe mostrar fecha, nombre del audio y muletillas (documento de requerimientos, validación del modelado).

## Alcance

Implementar `SqliteAnalysisRepository(db_path)` con `sqlite3` de la librería estándar: tabla `analyses`, índice por usuario y fecha, bloqueo de hilos, creación de las carpetas padre del archivo, soporte de `":memory:"`.

No hacer: ORM, migraciones externas, almacenar el audio o la transcripción completa, ni exponer la conexión.

## Contrato

```python
SqliteAnalysisRepository(db_path: str)
save(user_id, filename, result: dict) -> str
get(user_id, analysis_id) -> StoredAnalysis | None
list(user_id, limit=50, offset=0) -> list[AnalysisSummary]
count(user_id) -> int
delete(user_id, analysis_id) -> bool
```

- `save` lanza `ValueError` con `user_id` vacío.
- Todas las consultas usan parámetros (`?`).
- `list` ordena por fecha descendente; en empate, por inserción más reciente primero.
- `total_muletillas` es la suma de los valores de `result["muletillas"]`; si falta o no es un diccionario, `0`. `duracion_s` y `ppm` faltantes son `None`.

## Criterios de aceptación

1. Todas las pruebas de `tests/unit/test_sqlite_repository.py` pasan, incluida la de guardado concurrente.
2. Un usuario no puede leer, listar ni borrar los análisis de otro.
3. Los datos sobreviven al cerrar y reabrir el archivo.
4. `grep -n "execute(" src/infrastructure/repositories/*.py` no muestra consultas armadas con f-strings o concatenación.

## Pruebas

```bash
python -m pytest tests/unit/test_sqlite_repository.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_sqlite_repository.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T05 done`.
- [ ] Commit(s) convencional(es) `tipo(T05): descripción`.
