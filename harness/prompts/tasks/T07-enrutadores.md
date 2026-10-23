---
id: T07
title: Enrutadores: entrada, LLM y transcriptor
status: done
phase: 1-nucleo
depends_on: [T02]
requirements: [RF-02, RF-03, RNF-03]
estimate: 4h
tests: [tests/unit/test_input_router.py, tests/unit/test_llm_router.py, tests/unit/test_transcriber_router.py, tests/unit/test_routing_rules.py]
touches: [src/application/routing/__init__.py, src/application/routing/input_router.py, src/application/routing/llm_router.py, src/application/routing/transcriber_router.py]
---
# T07 - Enrutadores: entrada, LLM y transcriptor

## Objetivo

Implementar el patrón de enrutamiento del producto: reglas explícitas que deciden qué transcriptor usar y si comprimir o rechazar, un enrutador de LLM con respaldo y enfriamiento ante 429, y transcriptores compuestos con respaldo.

## Contexto

Es la parte "arquitectura de enrutamiento" que pidió el equipo, hecha con reglas y no con ML (decisión D-01 en `harness/context/12-decisions.md`). Cuotas gratuitas de Groq en `harness/context/05-llm-and-groq.md`: un 429 debe llegar pronto al enrutador para que pruebe otro proveedor y deje enfriar el limitado. Patrones en `harness/context/03-agentic-patterns.md`.

## Alcance

Crear los tres módulos en `src/application/routing/`:

1. `input_router.py`: `AudioInfo`, `RoutingSettings`, `RoutingDecision`, `route_input`. Función pura.
2. `llm_router.py`: `LLMRouter`, que es un `LLMProvider` (`name == "router"`). Reloj inyectable para probar el enfriamiento sin esperar.
3. `transcriber_router.py`: `FallbackTranscriber`, `RoutedTranscriber`, `LazyTranscriber`.

No hacer: llamadas de red, lectura de archivos de audio (el `probe` y el `compressor` se inyectan), ni estado global.

## Contrato

Firmas y reglas en `harness/context/10-module-contracts.md`, sección Enrutadores, y en las docstrings de las tres pruebas. Puntos finos:

- `route_input` valida duración antes que cualquier otra regla; rechaza con `reject_code` `too_short` o `too_long` y un mensaje en español.
- `LLMRouter` no reintenta al proveedor limitado dentro de su enfriamiento; usa `retry_after` si viene, si no `cooldown_s`; con todos fallando lanza `AllProvidersFailedError` con el error de cada proveedor.
- `FallbackTranscriber` no usa respaldo ante `InvalidAudioError`.
- `RoutedTranscriber` borra el archivo comprimido incluso si la transcripción falla.
- `LazyTranscriber` construye el real una sola vez, también con hilos concurrentes.

## Criterios de aceptación

1. Las tres pruebas de enrutadores pasan.
2. Ninguna importa `openai`, `av` ni `faster_whisper`.
3. Las advertencias de enrutamiento llegan a `Transcription.warnings`.

## Pruebas

```bash
python -m pytest tests/unit/test_input_router.py tests/unit/test_llm_router.py tests/unit/test_transcriber_router.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_input_router.py tests/unit/test_llm_router.py tests/unit/test_transcriber_router.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T07 done`.
- [ ] Commit(s) convencional(es) `tipo(T07): descripción`.
