---
id: T14
title: Configuración, composición, ensamble y caso de uso v2
status: done
phase: 3-integracion
depends_on: [T03, T04, T05, T06, T07, T08, T09, T12, T13]
requirements: [RF-04, RF-05, RF-06, RF-09, RF-10, RNF-03]
estimate: 6h
tests: [tests/unit/test_settings.py, tests/unit/test_container.py, tests/unit/test_composition_rules.py]
touches: [src/config/settings.py, src/config/container.py, src/application/services/ensemble.py, src/application/use_cases/analyze_presentation.py]
---
# T14 - Configuración, composición, ensamble y caso de uso v2

## Objetivo

Unir todo: configuración tipada, raíz de composición con banderas y degradación elegante, ensamble con verificación de citas y evidencias, y el caso de uso que orquesta el pipeline completo.

## Contexto

Arquitectura y degradación en `harness/context/02-architecture.md`. Variables de entorno en `harness/context/05-llm-and-groq.md`. El `main.py` original construye todo al importar y no se puede probar; la raíz de composición lo reemplaza (T15 cierra el arranque). El ensamble y el caso de uso actuales ya funcionan: se extienden, no se reescriben desde cero.

## Alcance

1. `settings.py`: `Settings` (dataclass inmutable), `Settings.from_env`, `llm_provider_specs`, `ProviderConfig`, `ENDPOINTS`, validación con mensajes que nombran la variable.
2. `container.py`: `Container`, `select_judge`, `build_container(settings, *, transcriber, llm_providers, embedder, event_classifier, repository)`. Instancias separadas de analista y juez por proveedor (cada una con su esquema estricto cuando aplique). El juez se envuelve en `LLMRouter`. Cliente de Groq para Whisper con `max_retries=1`.
3. `ensemble.py`: `analyze(system, user, objective_data, transcript, verify)` con verificación de evidencias, `evidencias` deduplicadas, `verificacion`, y `modelos_fallidos`. El prompt del juez viene de `prompts.JUDGE_SYSTEM`.
4. `analyze_presentation.py`: `AnalyzePresentation(transcriber, ensemble, *, max_chars, embedder, event_classifier, verify)` con las etapas opcionales aisladas por `try/except`, `select_window`, muletillas, ritmo, pausas, coherencia, eventos y fusión.

Clasificador acústico aplazado (decisión D-11): T10 y T11 no existen en el MVP, así que `src/infrastructure/ml/event_classifier.py` no está. El contenedor solo intenta construir el clasificador real si `ENABLE_EVENT_CLASSIFIER=true`, con importación perezosa; si falta el módulo o el modelo, deja `event_classifier=None` y agrega una advertencia que contenga "evento". La etapa del caso de uso se conserva intacta para cuando se retome.

No hacer: leer `os.environ` fuera de `Settings.from_env`, instanciar adaptadores fuera del contenedor, ni importar `sklearn`, `librosa` o `sentence_transformers` al nivel de módulo.

## Contrato

Ver `harness/context/10-module-contracts.md`, secciones Configuración, `ensemble.py` y `analyze_presentation.py`, y los docstrings de `tests/unit/test_settings.py` y `tests/unit/test_container.py`. El formato del resultado final está en `harness/context/07-api-contract.md`.

Reglas del contenedor:

- Bandera apagada: la etapa es `None`, aunque se haya pasado un doble.
- Bandera encendida y modelo o librería ausentes: etapa omitida y warning en `Container.warnings`.
- Sin proveedores LLM: `ConfigurationError`.
- `TRANSCRIBER=groq` sin `GROQ_API_KEY`: `ConfigurationError`.
- Un doble pasado por argumento reemplaza siempre la construcción real.

## Criterios de aceptación

1. Las pruebas de configuración y contenedor pasan.
2. Con dobles, `container.use_case.execute(ruta_wav)` devuelve las claves del contrato HTTP (sin `id` ni `creado_en`).
3. Un analista que falla queda en `modelos_fallidos` y el resto responde.
4. Si falla el embedder o el clasificador, el resultado incluye una advertencia y el análisis continúa.
5. Con citas inventadas, `verificacion.descartadas` las cuenta y no aparecen en `evidencias`.

## Pruebas

```bash
python -m pytest tests/unit/test_settings.py tests/unit/test_container.py -q
```

Las pruebas del pipeline completo con HTTP están en T15 (`tests/e2e/test_pipeline_fake.py`); conviene correrlas al terminar esta tarea para adelantar errores, aunque dependan de la aplicación.

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_settings.py tests/unit/test_container.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T14 done`.
- [ ] Commit(s) convencional(es) `tipo(T14): descripción`.
