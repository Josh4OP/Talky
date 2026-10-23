---
id: T01
title: Preparar el repositorio y el entorno
status: in_progress
phase: 0-base
depends_on: []
requirements: [-]
estimate: 2h
tests: [-]
touches: [requirements.txt, requirements-local.txt, requirements-ml.txt, requirements-embeddings.txt, requirements-dev.txt, pytest.ini, ruff.toml, .env.example, .gitignore, .github/workflows/ci.yml, README.md, scripts/manual/]
---
# T01 - Preparar el repositorio y el entorno

## Objetivo

Dejar el repositorio listo para trabajar con el arnés: dependencias declaradas, pruebas descubribles, estilo configurado, integración continua y un README honesto. Esta tarea no cambia comportamiento de la aplicación.

## Contexto

Estado inicial en `harness/context/06-current-state.md`: `requirements.txt` está vacío, no hay pruebas ni configuración de estilo, el README conserva plantillas sin completar y `test_gemini.py` y `test_groq.py` son scripts manuales en la raíz que `pytest` intentaría recoger.

El arnés se copia al repositorio en la carpeta `harness/` y `bash harness/install.sh` coloca `CLAUDE.md`, los comandos, los permisos, `tests/`, `evals/` y las plantillas de configuración. Las plantillas viven en `harness/templates/`.

## Alcance

Hacer:

1. Ejecutar `bash harness/install.sh` (idempotente) y revisar lo que copió: `CLAUDE.md` en la raíz, `.claude/commands/`, `.claude/settings.json`, `tests/`, `evals/`, `pytest.ini`, `ruff.toml`, `requirements*.txt`, `.env.example`, `.github/workflows/ci.yml`.
2. Crear el entorno virtual e instalar `requirements-dev.txt`.
3. Mover `test_gemini.py` y `test_groq.py` a `scripts/manual/` (con `git mv`) y confirmar que ningún `import` las necesita.
4. Añadir al `.gitignore` las entradas de `harness/templates/gitignore.additions` que falten (`models/*.joblib`, `*.db`, `evals/results/`, `evals/dataset/audio/`, `mobile/build/`, `.pytest_cache/`, `.ruff_cache/`).
5. Aplicar `ruff check --fix` y `ruff format` al código existente en un commit aparte con el mensaje `chore(T01): aplica formato inicial`. No cambies lógica.
6. Reescribir `README.md` con: descripción, requisitos de Python, instalación, variables de entorno (`.env.example`), cómo correr pruebas, cómo arrancar el servidor y un aviso de privacidad (el audio se envía a Groq para transcribirse y TALKY no lo guarda). Conserva las secciones de equipo y metodología del README original.
7. Confirmar que la integración continua (`.github/workflows/ci.yml`) instala dependencias de desarrollo y corre `ruff` y `pytest`.

No hacer: tocar `src/` más allá del formato, borrar pruebas del arnés, agregar dependencias que no estén en las plantillas.

## Contrato

- `requirements.txt` (núcleo): fastapi, uvicorn, python-multipart, pydantic 2, openai, python-dotenv, numpy, av.
- `requirements-local.txt`: faster-whisper (respaldo de transcripción).
- `requirements-ml.txt`: scikit-learn, librosa, joblib.
- `requirements-embeddings.txt`: sentence-transformers.
- `requirements-dev.txt`: incluye núcleo y ML, más pytest, httpx y ruff.
- `pytest.ini`: `pythonpath = .`, `testpaths = tests`.
- Python 3.11 o superior.

## Criterios de aceptación

1. `python -m venv .venv && pip install -r requirements-dev.txt` termina sin errores en un entorno limpio.
2. `python -m pytest --collect-only -q` falla únicamente con `ImportError: cannot import name 'Word' from 'src.domain.interfaces.ports'` (viene de `tests/fakes.py`; lo resuelve T02). Cualquier otro error de recolección o de configuración de `pytest` es un defecto de esta tarea.
3. `ruff check .` y `ruff format --check .` salen limpios.
4. Ningún script manual se recoge como prueba.
5. `python harness/tools/check_harness.py` imprime "Harness consistente.".
6. El README no tiene marcadores `[...]` pendientes en las secciones técnicas.

## Pruebas

No hay pruebas propias. Verificación:

```bash
python -m pytest --collect-only -q 2>&1 | tail -5     # solo debe fallar por 'Word' (se resuelve en T02)
ruff check . && ruff format --check .
python harness/tools/check_harness.py
```

## Definición de hecho

- [ ] Verificación de la tarea: `python -m pytest --collect-only -q 2>&1 | tail -5`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T01 done`.
- [ ] Commit(s) convencional(es) `tipo(T01): descripción`.
