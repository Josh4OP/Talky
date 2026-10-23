---
description: Resume el avance del proyecto, lo que sigue y los riesgos para la entrega
allowed-tools: Bash(python harness/tools/tasks.py:*), Bash(python -m pytest:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Read
---

Entrega un estado breve del proyecto, útil para decidir el siguiente paso.

1. `python harness/tools/tasks.py list` para el avance por tarea.
2. `python -m pytest -q --tb=no` para el conteo de pruebas pasadas y fallidas, agrupando los fallos por tarea según el campo `tests:` (lee las tareas con `tasks.py show`).
3. `git branch --show-current`, `git status --short` y las últimas confirmaciones (`git log --oneline -10`).
4. Fecha límite: lunes 26 de octubre de 2026. Calcula los días restantes con la fecha de hoy y compara con las tareas que faltan, usando el orden de recorte de `harness/prompts/README.md` si el plazo está en riesgo.

Salida (máximo 15 líneas):

- Avance: N de M tareas hechas; la tarea actual.
- Pruebas: pasan X, fallan Y (tareas afectadas).
- Siguiente: la próxima tarea desbloqueada y por qué.
- Riesgos: de plazo, de cuota o de datos, solo si existen.
- Decisión que necesita una persona, si la hay.
