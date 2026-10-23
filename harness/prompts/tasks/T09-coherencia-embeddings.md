---
id: T09
title: Coherencia temática con embeddings de texto
status: todo
phase: 2-inteligencia
depends_on: [T02, T04]
requirements: [RF-05]
estimate: 4h
tests: [tests/unit/test_coherence.py]
touches: [src/application/services/coherence.py, src/infrastructure/ml/sentence_embedder.py]
---
# T09 - Coherencia temática con embeddings de texto

## Objetivo

Medir sin gastar tokens de LLM si la exposición mantiene el hilo: saltos de tema e ideas repetidas, usando embeddings de texto locales. El resultado alimenta el análisis (dato objetivo) y la repetición de ideas (RF-05).

## Contexto

Diseño en `harness/context/04-ml-design.md`, sección 3. El puerto `TextEmbedder` está en el dominio (T02); `split_sentences` viene de T04. El modelo `paraphrase-multilingual-MiniLM-L12-v2` corre en CPU y se carga en el primer uso. Es una etapa opcional (`ENABLE_TEXT_EMBEDDINGS`).

## Alcance

1. `coherence.py` (servicio puro): `cosine`, `make_windows`, `coherence_report`, `CoherenceReport.to_dict`. Una sola llamada al embedder por reporte.
2. `sentence_embedder.py`: `SentenceTransformerEmbedder`, con carga perezosa protegida por bloqueo y vectores normalizados.

No hacer: importar `sentence_transformers` fuera de `sentence_embedder.py` ni al nivel del módulo, ni cachear embeddings en disco.

## Contrato

```python
cosine(a, b) -> float
make_windows(sentences, size) -> list[str]
coherence_report(text, embedder, window_sentences=3, topic_jump_threshold=0.35,
                 repeat_threshold=0.85, min_gap=2) -> CoherenceReport
CoherenceReport(windows, mean_adjacent_similarity, topic_jumps, repeated_pairs).to_dict()
SentenceTransformerEmbedder(model_name=...).embed(texts) -> list[list[float]]
```

`topic_jumps` es la lista de índices `i` con salto entre la ventana `i` y la `i+1`; `repeated_pairs` son tuplas `(a, b, similitud)` con `b - a >= min_gap`. Con menos de 2 ventanas no se llama al embedder y `mean_adjacent_similarity` es `None`.

## Criterios de aceptación

1. Las pruebas de `tests/unit/test_coherence.py` pasan sin descargar ningún modelo.
2. Prueba manual (opcional): con `sentence-transformers` instalado, `SentenceTransformerEmbedder().embed(["hola", "buenos días"])` devuelve dos vectores de la misma longitud y norma cercana a 1.
3. `import src.application.services.coherence` no importa `numpy` ni `sentence_transformers` (usa solo Python).

## Pruebas

```bash
python -m pytest tests/unit/test_coherence.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_coherence.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T09 done`.
- [ ] Commit(s) convencional(es) `tipo(T09): descripción`.
