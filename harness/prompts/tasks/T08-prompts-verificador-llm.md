---
id: T08
title: Prompts, verificador de citas, JSON estricto y adaptador LLM
status: done
phase: 1-nucleo
depends_on: [T02]
requirements: [RF-05, RF-06]
estimate: 5h
tests: [tests/unit/test_prompts.py, tests/unit/test_verifier.py, tests/unit/test_json_schema.py, tests/unit/test_openai_compatible_llm.py, tests/unit/test_llm_output_rules.py]
touches: [src/application/prompts.py, src/application/services/verifier.py, src/infrastructure/external/json_schema.py, src/infrastructure/external/openai_compatible_llm.py]
---
# T08 - Prompts, verificador de citas, JSON estricto y adaptador LLM

## Objetivo

Reducir las alucinaciones del LLM y hacer su salida predecible: prompts que exigen evidencia citada, un verificador que comprueba cada cita contra la transcripción (patrón evaluador, sin LLM), esquemas JSON estrictos para Groq y un adaptador OpenAI-compatible con degradación de formato y traducción de errores.

## Contexto

Texto de referencia de los prompts en `harness/prompts/llm/`. Modo estricto de Groq y límites en `harness/context/05-llm-and-groq.md`. Reglas de redacción en `harness/agent/rules/llm-prompting.md`. El adaptador actual (`openai_compatible_llm.py`) es un cliente simple sin esquema, sin traducción de errores y con reintentos por defecto.

## Alcance

1. `prompts.py`: `ANALYSIS_SYSTEM`, `JUDGE_SYSTEM`, `build_user_message`. Parte de los textos de `harness/prompts/llm/`.
2. `verifier.py`: `normalize`, `quote_in_transcript`, `verify_evidences`, `drop_unverified`, `verification_rate`. Coincidencia exacta normalizada y, si no, aproximada con `difflib` sobre ventanas deslizantes de palabras; sin dependencias nuevas.
3. `json_schema.py`: `strict_json_schema(modelo_pydantic)`.
4. `openai_compatible_llm.py`: ampliar el adaptador existente con `json_schema`, cadena de degradación (`json_schema`, `json_object`, sin formato), traducción de 429 a `RateLimitedError` y de otros errores de API a `ProviderError`, y `client` inyectable.

No hacer: usar un LLM para verificar, recortar el JSON del modelo con regex frágiles en el adaptador (eso es del ensamble), ni cambiar el esquema de `Analisis` más allá de T02.

## Contrato

Ver `harness/context/10-module-contracts.md`, sección `prompts.py`, `verifier.py`, `json_schema.py`, `openai_compatible_llm.py`. Puntos finos:

- Citas de menos de 3 palabras no se verifican (`False`), para que "sí" o "y" no valide nada.
- `verify_evidences` devuelve copias; no muta la entrada.
- El esquema estricto resuelve los `$ref`/`$defs` que pydantic genera para modelos anidados (`Analisis` contiene `Aspecto`, `Repeticion` y `Evidencia`).
- `OpenAICompatibleLLM(..., max_retries=4)` por defecto; en el contenedor se configura con pocos reintentos para que el 429 llegue al enrutador.

## Criterios de aceptación

1. Las cuatro pruebas pasan.
2. El esquema de `Analisis` y el de `Sintesis` cumplen las reglas del modo estricto (cada objeto con `additionalProperties: false` y todas sus propiedades en `required`).
3. Una cita inventada se rechaza y una cita con una variación pequeña de transcripción se acepta (razón mínima 0.85).
4. El adaptador nunca registra el contenido de los mensajes.

## Pruebas

```bash
python -m pytest tests/unit/test_prompts.py tests/unit/test_verifier.py tests/unit/test_json_schema.py tests/unit/test_openai_compatible_llm.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/unit/test_prompts.py tests/unit/test_verifier.py tests/unit/test_json_schema.py tests/unit/test_openai_compatible_llm.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T08 done`.
- [ ] Commit(s) convencional(es) `tipo(T08): descripción`.
