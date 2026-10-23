---
id: T06
title: Utilidades de audio y transcriptores (Groq y local)
status: todo
phase: 1-nucleo
depends_on: [T02, T07]
requirements: [RF-03, RNF-03, RNF-04]
estimate: 4h
tests: [tests/ml/test_audio.py, tests/unit/test_groq_transcriber.py]
touches: [src/infrastructure/audio.py, src/infrastructure/external/groq_transcriber.py, src/infrastructure/external/whisper_transcriber.py]
---
# T06 - Utilidades de audio y transcriptores (Groq y local)

## Objetivo

Tener una sola forma de leer audio (mono, 16 kHz) y dos transcriptores que devuelvan palabras con marcas de tiempo: Whisper `large-v3` vía Groq (rápido) y faster-whisper local (respaldo).

## Contexto

`WhisperTranscriber._load_audio` ya lee audio con PyAV; se mueve a `audio.py` para compartirlo con el clasificador acústico (T11) y el enrutador de entrada (T07). Datos de Groq (formatos, límite de 25 MB, prompt de hasta 224 tokens, cuotas) en `harness/context/05-llm-and-groq.md`.

## Alcance

1. `src/infrastructure/audio.py`: `load_audio`, `probe_audio`, `compress_for_upload` con PyAV. `AudioInfo` se importa de `src/application/routing/input_router.py` (T07); es la única excepción permitida a la regla de que infraestructura solo importa dominio, porque es un tipo de datos puro.
2. `groq_transcriber.py`: `GroqTranscriber` con `verbose_json`, marcas por palabra y por segmento, `temperature=0`, el prompt de muletillas y traducción de errores HTTP a excepciones del dominio. Recibe el cliente por inyección.
3. `whisper_transcriber.py`: usar `load_audio`, pedir `word_timestamps=True` y devolver `words`. Importar `faster_whisper` de forma perezosa dentro de `__init__`.

No hacer: llamadas reales a la red en pruebas, guardar audio comprimido, usar `subprocess` con ffmpeg.

## Contrato

```python
load_audio(path) -> np.ndarray                 # float32, mono, 16 kHz, [-1, 1]
probe_audio(path) -> AudioInfo                 # duration_s, size_bytes, rms_dbfs (piso -120.0)
compress_for_upload(path) -> str               # FLAC 16 kHz mono temporal; el llamador lo borra
GroqTranscriber(client, model="whisper-large-v3", language="es", prompt=DEFAULT_PROMPT)
```

Errores: archivo ilegible a `InvalidAudioError`; HTTP 429 a `RateLimitedError` (con `retry_after` de la cabecera `retry-after`), 400 y 413 a `InvalidAudioError`, resto a `ProviderError`. Detalle en `harness/context/10-module-contracts.md`.

## Criterios de aceptación

1. Las pruebas de `tests/ml/test_audio.py` y `tests/unit/test_groq_transcriber.py` pasan.
2. `import src.infrastructure.external.whisper_transcriber` no importa `faster_whisper` hasta crear la instancia.
3. Prueba manual (opcional, fuera de la suite): con una grabación real y `GROQ_API_KEY`, `GroqTranscriber` devuelve texto, `words` no vacío y `duration` coherente.

## Pruebas

```bash
python -m pytest tests/ml/test_audio.py tests/unit/test_groq_transcriber.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/ml/test_audio.py tests/unit/test_groq_transcriber.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T06 done`.
- [ ] Commit(s) convencional(es) `tipo(T06): descripción`.
