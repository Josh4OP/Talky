---
id: T13
title: Métricas de ritmo y pausas por palabra
status: done
phase: 2-inteligencia
depends_on: [T02]
requirements: [RF-09, RNF-03]
estimate: 2h
tests: [tests/unit/test_metrics.py, tests/unit/test_metrics_rules.py]
touches: [src/application/services/metrics.py]
---
# T13 - Métricas de ritmo y pausas por palabra

## Objetivo

Medir ritmo y pausas con las marcas de tiempo por palabra (más precisas que las de segmento) y ofrecer un perfil de ritmo en el tiempo, porque en la entrevista el usuario pidió saber si la duración y el ritmo fueron adecuados.

## Contexto

`metrics.py` ya tiene `words_per_minute` y `pause_stats` (por segmentos); se conservan para el caso en que el transcriptor no entregue palabras. Contrato en `harness/context/10-module-contracts.md`, sección `metrics.py`.

## Alcance

Agregar `pause_stats_from_words` y `rhythm_profile` a `src/application/services/metrics.py`. Python puro. No cambiar el comportamiento de las funciones existentes.

## Contrato

```python
pause_stats_from_words(words, duration_s, min_gap=1.0) -> dict   # pausas_largas, segundos_en_pausas, pausa_maxima_s, pausas_por_minuto
rhythm_profile(words, duration_s, window_s=30.0) -> list[float]   # palabras por minuto por ventana
```

La última ventana parcial se escala por su duración real. Con `duration_s <= 0`, `rhythm_profile` devuelve `[]` y `pausas_por_minuto` es `0.0`.

## Criterios de aceptación

1. Las 9 pruebas de `tests/unit/test_metrics.py` pasan.
2. Una pausa exactamente igual a `min_gap` cuenta como larga.
3. Sin palabras, `pause_stats_from_words` devuelve ceros y no falla.

## Pruebas

```bash
python -m pytest tests/unit/test_metrics.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_metrics.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T13 done`.
- [ ] Commit(s) convencional(es) `tipo(T13): descripción`.
