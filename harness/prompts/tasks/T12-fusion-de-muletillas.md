---
id: T12
title: Fusión de muletillas: palabras de Whisper y eventos acústicos
status: todo
phase: 2-inteligencia
depends_on: [T02, T03]
requirements: [RF-04, RF-10]
estimate: 3h
tests: [tests/unit/test_event_fusion.py]
touches: [src/application/services/event_fusion.py]
---
# T12 - Fusión de muletillas: palabras de Whisper y eventos acústicos

## Objetivo

Combinar lo que Whisper transcribió como "eh" o "mmm" con lo que el clasificador acústico detectó, asignando confianza alta cuando ambos coinciden y reportando los tatareos aparte.

## Contexto

Diseño en `harness/context/04-ml-design.md`, sección 2. Whisper omite muchas muletillas vocales; el clasificador no sabe qué sonido fue. Juntos dan mejor cobertura y se puede medir cuánto aporta cada fuente (T17). Las muletillas de varias palabras las cubre `filler_detector` (T03) sobre el texto.

## Alcance

Crear `event_fusion.py` con `FillerHit`, `FusionResult` y `fuse_fillers`. Servicio puro. Normaliza los tokens de Whisper con las mismas reglas que `filler_detector` para vocales (`eh`, `mmm`); si conviene, expón desde `filler_detector` una función auxiliar compartida en lugar de duplicar expresiones regulares.

No hacer: llamar al clasificador desde aquí (recibe eventos ya calculados), ni tocar `Transcription`.

## Contrato

```python
fuse_fillers(words, events, tolerance_s=0.5, min_confidence=0.6) -> FusionResult
FusionResult(fillers: list[FillerHit], hums: list[AcousticEvent])
FillerHit(start, end, texto, source, confianza).to_dict()
```

Reglas de emparejamiento y valores de `source`, `confianza` y `texto` en `harness/context/10-module-contracts.md`, sección `event_fusion.py`.

## Criterios de aceptación

1. Las 10 pruebas pasan.
2. Un evento acústico se empareja con una sola palabra y viceversa.
3. Eventos con confianza menor al mínimo no producen muletillas ni tatareos.
4. El resultado sale ordenado por tiempo de inicio.

## Pruebas

```bash
python -m pytest tests/unit/test_event_fusion.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_event_fusion.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T12 done`.
- [ ] Commit(s) convencional(es) `tipo(T12): descripción`.
