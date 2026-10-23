---
id: T04
title: Manejo de transcripciones largas
status: todo
phase: 1-nucleo
depends_on: [T02]
requirements: [RF-05, RNF-03]
estimate: 2h
tests: [tests/unit/test_transcript.py]
touches: [src/application/services/transcript.py]
---
# T04 - Manejo de transcripciones largas

## Objetivo

Evitar que una exposición larga desborde el límite de tokens del LLM sin perder la conclusión: conservar inicio y final, partir en oraciones y en fragmentos.

## Contexto

El caso de uso original recorta con `text[:max_chars]`, que elimina justo el final, donde está la conclusión. Los modelos gratuitos de Groq tienen un tope de 8 000 tokens por minuto (`harness/context/05-llm-and-groq.md`). `split_sentences` también lo usa la coherencia con embeddings (T09).

## Alcance

Crear `src/application/services/transcript.py` con `OMISSION_MARKER`, `select_window`, `split_sentences` y `chunk_text`. Python puro, sin dependencias.

No hacer: contar tokens reales (se aproxima con caracteres), ni resumir con un LLM.

## Contrato

```python
OMISSION_MARKER = "\n[... fragmento omitido ...]\n"
select_window(text: str, max_chars: int, head_ratio: float = 0.6) -> tuple[str, bool]
split_sentences(text: str) -> list[str]
chunk_text(text: str, max_chars: int) -> list[str]
```

Detalle en `harness/context/10-module-contracts.md`, sección `transcript.py`. El resultado de `select_window` nunca excede `max_chars` y nunca corta una palabra.

## Criterios de aceptación

1. Todas las pruebas de `tests/unit/test_transcript.py` pasan.
2. Un texto de 50 000 caracteres con `max_chars=12000` devuelve un texto de 12 000 caracteres o menos que empieza y termina con contenido original y contiene el marcador.
3. `split_sentences("¿Cómo estás? Bien. Gracias!")` devuelve tres oraciones.

## Pruebas

```bash
python -m pytest tests/unit/test_transcript.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_transcript.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T04 done`.
- [ ] Commit(s) convencional(es) `tipo(T04): descripción`.
