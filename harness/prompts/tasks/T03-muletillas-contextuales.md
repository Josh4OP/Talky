---
id: T03
title: Detector de muletillas con contexto
status: done
phase: 1-nucleo
depends_on: [T02]
requirements: [RF-04]
estimate: 3h
tests: [tests/unit/test_filler_detector.py, tests/unit/test_filler_detector_rules.py]
touches: [src/application/services/filler_detector.py]
---
# T03 - Detector de muletillas con contexto

## Objetivo

Reemplazar el conteo ingenuo de muletillas por un detector que distingue el uso legítimo del uso como relleno, y calcular muletillas por minuto. Es la métrica más visible para el usuario (RF-04).

## Contexto

El detector actual cuenta "este", "pues", "tipo" y "entonces" en cualquier posición, así que "Este modelo es mejor" y "Tipo de dato entero" se cuentan como muletillas. Las reglas nuevas están en `harness/context/10-module-contracts.md` (sección `filler_detector.py`) y en `harness/context/09-glossary.md`.

Whisper transcribe con puntuación, y esa puntuación (comas, puntos suspensivos) es la señal de pausa que el detector aprovecha.

## Alcance

Reescribir `src/application/services/filler_detector.py` manteniendo el nombre público `detect_fillers` y agregando `fillers_per_minute`.

Clasificación:

1. Sonidos vocales (`eh`, `ehm`, `mmm`, `hmm`) con normalización a claves canónicas `eh` y `mmm`.
2. Marcadores siempre muletilla: `o sea`, `digamos`, `como que`, `en plan`, `¿no?`, `¿verdad?`.
3. Contextuales: `este`, `entonces`, `bueno`, `pues`, `tipo`, `básicamente`; cuentan solo seguidas de pausa o como oración completa.
4. `la verdad`: solo seguida de pausa.

Sugerencia: expresiones regulares con límites de palabra y comprobación del texto que sigue y que precede a cada coincidencia. Sin dependencias externas. Mantén las listas como constantes del módulo para poder ajustarlas con datos reales en T17.

No hacer: usar un LLM, depender de la transcripción por palabras, ni cambiar el formato de retorno (diccionario ordenado de mayor a menor).

## Contrato

```python
detect_fillers(text: str) -> dict[str, int]
fillers_per_minute(counts: dict[str, int], duration_s: float) -> float
```

Reglas completas en `harness/context/10-module-contracts.md`. `fillers_per_minute` redondea a 1 decimal y devuelve `0.0` si no hay duración o no hay conteos.

## Criterios de aceptación

1. Todas las pruebas de `tests/unit/test_filler_detector.py` pasan.
2. El texto "Entonces el resultado es bueno. Este modelo es mejor. Tipo de dato entero. Pues bien, la verdad es que sí." no cuenta "este", "tipo" ni "bueno" (solo "pues" seguido de coma).
3. Sin coincidencias dentro de otras palabras ("estero", "pueso").
4. Orden del diccionario: mayor a menor frecuencia.

## Pruebas

```bash
python -m pytest tests/unit/test_filler_detector.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_filler_detector.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T03 done`.
- [ ] Commit(s) convencional(es) `tipo(T03): descripción`.
