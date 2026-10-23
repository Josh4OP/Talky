---
id: T02
title: Base de dominio: puertos, entidades y excepciones
status: done
phase: 0-base
depends_on: [T01]
requirements: [RF-05, RF-10]
estimate: 2h
tests: [tests/unit/test_entities.py]
touches: [src/domain/interfaces/ports.py, src/domain/entities/analysis.py, src/domain/entities/events.py, src/domain/exceptions/__init__.py, src/domain/entities/ensemble.py]
---
# T02 - Base de dominio: puertos, entidades y excepciones

## Objetivo

Completar la capa de dominio con todo lo que las demás tareas necesitan importar: puertos, dataclasses, entidades de evidencia y eventos acústicos, y la jerarquía de excepciones. Es la base de la que depende todo; debe quedar pequeña, sin I/O y bien tipada.

## Contexto

`tests/conftest.py` y `tests/fakes.py` importan `Word` desde `src.domain.interfaces.ports`; sin esta tarea ninguna prueba se puede recoger. Contratos en `harness/context/10-module-contracts.md`, sección Dominio.

El repositorio contiene `src/domain/entities/ensemble.py`, una copia antigua de `EnsembleAnalyzer` con su propio `JUDGE_SYSTEM`. El ensamble vigente está en `src/application/services/ensemble.py`. Verifica con `grep -rn "entities.ensemble" .` que nada la importa y elimínala con `git rm`.

## Alcance

1. `ports.py`: agregar `Word`; ampliar `Transcription` con `words` y `warnings` (con `field(default_factory=list)`, sin romper la construcción posicional existente `Transcription(text, segments, duration)`); agregar `StoredAnalysis`, `AnalysisSummary`, y los puertos `TextEmbedder`, `EventClassifier`, `AnalysisRepository`.
2. `entities/analysis.py`: agregar `Evidencia` y el campo `evidencias` en `Analisis`.
3. `entities/events.py`: crear `EVENT_LABELS` y `AcousticEvent` (inmutable, con `duration`).
4. `exceptions/__init__.py`: jerarquía completa del contrato.
5. Eliminar `entities/ensemble.py` si nada la usa.

No hacer: lógica de negocio, imports de librerías externas distintas de pydantic, cambios en `src/application`.

## Contrato

Ver `harness/context/10-module-contracts.md`, sección Dominio. Puntos finos:

- `Aspecto` redondea el puntaje antes de validar el rango (`7.4` pasa a `7`; `11` falla).
- `Evidencia.verificada` es `None` hasta que el verificador la evalúe.
- `AcousticEvent` es `frozen=True` e igualable.
- `AllProvidersFailedError` es `RuntimeError` (mapea a HTTP 503) e `InvalidAudioError` y `ConfigurationError` son `ValueError` (mapean a 422 y a error de arranque).

## Criterios de aceptación

1. `tests/unit/test_entities.py` pasa por completo.
2. `python -m pytest --collect-only -q` ya recoge todas las pruebas sin errores de importación en `conftest.py`.
3. `import src.domain.interfaces.ports` no importa nada fuera de la librería estándar.
4. El caso de uso existente sigue funcionando con `Transcription(text, segments, duration)` sin argumentos nuevos.

## Pruebas

```bash
python -m pytest tests/unit/test_entities.py -q
python -m pytest --collect-only -q | tail -3
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_entities.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T02 done`.
- [ ] Commit(s) convencional(es) `tipo(T02): descripción`.
