---
description: Elige la siguiente tarea desbloqueada, la lee y prepara el plan de trabajo
allowed-tools: Bash(python harness/tools/tasks.py:*), Bash(python -m pytest:*), Bash(git:*), Read, Grep, Glob
---

Prepara el inicio de la siguiente tarea de TALKY. Argumento opcional: identificador de tarea ($ARGUMENTS), por ejemplo `T05`. Si no hay argumento, elige la primera tarea desbloqueada.

Pasos:

1. Ejecuta `python harness/tools/tasks.py list` y `python harness/tools/tasks.py next` para ver el estado.
2. Determina la tarea: la del argumento (verifica que sus dependencias estén en `done`; si no, dilo y detente) o la primera de `next`.
3. Lee la tarea completa con `python harness/tools/tasks.py show <ID>`.
4. Lee solo los contratos que la tarea cita (`harness/context/10-module-contracts.md` y los documentos enlazados) y los archivos de prueba declarados en `tests:`.
5. Revisa el código existente que la tarea toca (`touches:`).
6. Ejecuta las pruebas declaradas y confirma que fallan por la razón esperada.
7. Presenta un plan de 3 a 7 pasos con los archivos que vas a crear o modificar, el orden, y cualquier duda real sobre el contrato. Pregunta solo si una duda cambia el resultado.
8. Marca la tarea `in_progress` y crea la rama `feat/<ID>-<descripcion-corta>`.

No escribas código de producción en este comando: solo prepara y propone el plan.
