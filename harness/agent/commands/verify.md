---
description: Verifica el trabajo actual (pruebas de la tarea, suite completa, estilo y reglas de capas)
allowed-tools: Bash(python -m pytest:*), Bash(ruff:*), Bash(python harness/tools/tasks.py:*), Bash(python harness/tools/check_harness.py:*), Bash(grep:*), Bash(git status:*), Bash(git diff:*), Read, Grep
---

Verifica el estado actual del trabajo. Argumento opcional: identificador de tarea ($ARGUMENTS); si falta, usa la tarea `in_progress`.

Ejecuta, en este orden, y reporta cada resultado con una línea:

1. Pruebas de la tarea: los archivos del campo `tests:` de la tarea (`python -m pytest <archivos> -q`).
2. Suite completa: `python -m pytest -q`. Debe estar sin regresiones.
3. Estilo: `ruff check .` y `ruff format --check .`.
4. Reglas de capas:
   - `grep -rnE "^(from|import) (fastapi|openai|sklearn|librosa|av|faster_whisper|sqlite3|sentence_transformers)" src/domain src/application`
   - `grep -rn "src.infrastructure" src/domain src/application src/presentation`
   Ambos deben salir vacíos.
5. Higiene: `git status` sin audios, `.env`, `*.db` ni modelos en el área de cambios.
6. Alcance: `git diff --stat` solo con archivos de `touches:` o que la tarea justifique. Señala cualquier otro archivo.
7. Pruebas intactas: confirma que `tests/fakes.py`, `tests/conftest.py` y las pruebas de otras tareas no fueron modificadas.

Termina con un veredicto: LISTO o NO LISTO, y la lista de lo que falta. Si todo está en verde, recuerda que falta `/review` antes del commit final. No arregles nada en este comando salvo que el usuario lo pida.
