---
id: T15
title: API v1: aplicación FastAPI, rutas e historial
status: done
phase: 3-integracion
depends_on: [T14]
requirements: [RF-01, RF-02, RF-07, RF-08, RNF-01, RNF-04]
estimate: 4h
tests: [tests/api/test_routes.py, tests/e2e/test_pipeline_fake.py, tests/api/test_routes_rules.py]
touches: [src/presentation/app.py, src/presentation/routes/analysis.py, main.py]
---
# T15 - API v1: aplicación FastAPI, rutas e historial

## Objetivo

Exponer el pipeline como API HTTP v1 con identidad por usuario, historial y manejo claro de errores, de modo que la app Flutter y la demo funcionen de punta a punta.

## Contexto

Contrato HTTP en `harness/context/07-api-contract.md`. Reglas de privacidad en `harness/agent/rules/security-privacy.md`. La ruta actual no tiene identidad ni historial y revisa el tamaño después de copiar el archivo completo.

## Alcance

1. `routes/analysis.py`: `build_router(container)` con `POST /analyses`, `GET /analyses`, `GET /analyses/{id}`, `DELETE /analyses/{id}`. Identidad con `X-User-Id` validado. Escritura del archivo temporal por bloques de 1 MB contando bytes (413 al superar el límite) y borrado en `finally`.
2. `app.py`: `create_app(container)` con título "TALKY", CORS con `settings.cors_origins`, el router y `GET /health`.
3. `main.py`: `app = create_app(build_container(Settings.from_env()))`. Cargar `.env` con `python-dotenv` solo si está instalado. Nada más al importar.

No hacer: autenticación con contraseñas, guardar el audio, devolver la transcripción completa, ni cambiar los nombres de las claves del resultado.

## Contrato

Códigos: 201, 400 (extensión o identidad inválidas), 401 (sin identidad), 404 (inexistente o de otro usuario), 413, 422 (`InvalidAudioError` y `ValueError`), 503 (`RuntimeError`, incluye `AllProvidersFailedError`). Mensajes en español. Paginación `limit` 1 a 100 (por defecto 20) y `offset` mayor o igual a 0.

La respuesta de `POST` y `GET /{id}` es el resultado del caso de uso más `id` y `creado_en`.

## Criterios de aceptación

1. Las 17 pruebas de `tests/api/test_routes.py` y las 9 de `tests/e2e/test_pipeline_fake.py` pasan.
2. `uvicorn main:app` arranca con un `.env` válido y `GET /docs` muestra los cuatro endpoints.
3. Prueba manual con una grabación real (opcional, fuera de la suite): `curl -H "X-User-Id: demo" -F file=@clase.m4a http://localhost:8000/analyses` devuelve 201 con puntajes y muletillas.
4. El archivo temporal desaparece tras cada petición, también con error.

## Pruebas

```bash
python -m pytest tests/api tests/e2e -q
python -m pytest -q          # suite completa: debe quedar toda en verde
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/api/test_routes.py tests/e2e/test_pipeline_fake.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] La suite completa de aceptación de `tests/` está en verde; es el hito de backend del MVP.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T15 done`.
- [ ] Commit(s) convencional(es) `tipo(T15): descripción`.
