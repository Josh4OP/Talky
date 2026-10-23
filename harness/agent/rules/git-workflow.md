# Regla: flujo de git

## Ramas

- Una rama por tarea desde la rama principal: `feat/T05-sqlite-historial`, `fix/T08-cita-vacia`, `docs/T18-readme`.
- Nunca trabajes directamente en la rama principal. Nunca fuerces el push.

## Commits

Mensajes convencionales en español, en imperativo, con el identificador de la tarea:

```
feat(T05): agrega repositorio SQLite del historial
test(T05): cubre aislamiento por usuario
fix(T08): rechaza citas de menos de tres palabras
docs(T18): documenta cómo ejecutar la demo
refactor(T14): extrae la construcción de proveedores LLM
chore(T01): agrega ruff.toml y requirements divididos
```

- Commits pequeños que dejen la suite en verde.
- No mezcles formato masivo con cambios de lógica.
- Cuando el entorno lo pida, termina el mensaje con las líneas de atribución que indique el sistema.

## Antes de abrir un pull request

1. `/verify` en verde.
2. `/review` sin hallazgos pendientes.
3. Estado de la tarea actualizado (`python harness/tools/tasks.py status Txx done`).
4. Descripción con: qué cambia, qué contrato cumple, cómo se probó, riesgos.

## Qué nunca se commitea

`.env`, `*.db`, `models/*.joblib`, audios (`*.wav`, `*.mp3`, `*.m4a`, `*.ogg`, `*.flac`, `*.webm`), `evals/results/`, `evals/dataset/audio/`, `__pycache__/`, `.venv/`, `mobile/build/`.

## Conflictos

Rebase sobre la rama principal antes del pull request. Si hay conflictos en archivos que no tocaste, detente y pregunta.
