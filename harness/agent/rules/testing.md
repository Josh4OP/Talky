# Regla: pruebas

## Principios

1. Las pruebas de `tests/` son el contrato. No las debilites, no las borres, no las marques `skip` ni `xfail` para pasar.
2. Si una prueba parece incorrecta, detente y explica con evidencia; propón el cambio a una persona.
3. Ninguna prueba usa red, claves reales ni descarga modelos. Se usan los dobles de `tests/fakes.py`.
4. Las pruebas son deterministas: semillas fijas, relojes inyectados, sin `sleep` real.

## Estructura

```
tests/unit/   lógica pura y adaptadores con dobles
tests/ml/     audio, características y modelos (usa numpy, librosa, scikit-learn, av)
tests/api/    contrato HTTP con TestClient
tests/e2e/    pipeline completo con dobles
tests/fakes.py, tests/conftest.py   dobles y fixtures compartidos
```

## Ciclo

1. Rojo: ejecuta la prueba de la tarea y verifica que falla por la razón esperada (módulo inexistente o comportamiento ausente), no por un error de importación en `conftest.py`.
2. Verde: implementa lo mínimo.
3. Refactor con la suite completa en verde.

## Dobles disponibles (`tests/fakes.py`)

`FakeTranscriber`, `FakeLLM` (distingue al juez por "eres un editor" en el prompt de sistema), `ScriptedEmbedder`, `FakeEventClassifier`, `sample_transcription()`, `make_wav_bytes()`, `post_audio()`, `analysis_payload()`, `synthesis_payload()`, constantes `SAMPLE_TEXT`, `VALID_QUOTE`, `INVENTED_QUOTE`. Fixtures de `conftest.py`: `make_container`, `client_factory`.

## Dobles nuevos

`tests/fakes.py` y `tests/conftest.py` son solo lectura (`.claude/settings.json` bloquea su edición). Si una prueba nueva necesita un doble o una fixture distinta, créala en `tests/extra_fakes.py` o en un `conftest.py` de la subcarpeta correspondiente.

## Pruebas nuevas que escribas

Cuando agregues comportamiento que no cubren las pruebas de aceptación, agrega pruebas en el mismo directorio y con el mismo estilo (nombres en inglés descriptivo, una aserción central por prueba, docstring del módulo con el contrato). Todo archivo `test_*.py` nuevo debe declararse en el campo `tests:` de la tarea correspondiente; `python harness/tools/check_harness.py` lo exige.

## Cobertura mínima aceptable

Todo servicio de `application/services/` y todo adaptador de `infrastructure/` con lógica propia tiene al menos una prueba de camino feliz, una de borde y una de error. No se persigue un porcentaje, sino que cada regla del contrato tenga una aserción.

## Qué hacer ante una prueba intermitente

Es un defecto. Encuentra la fuente (hora, orden de diccionarios, hilos, semilla) y corrígela. No agregues reintentos.
