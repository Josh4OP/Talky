# Arnés de construcción de TALKY para Claude Code

Este paquete le da a Claude Code todo lo que necesita para construir TALKY bien y rápido: el contexto del proyecto, las reglas, 18 tareas con contrato, 272 pruebas de aceptación escritas de antemano, una herramienta de evaluación y comandos de trabajo. Está pensado para el MVP del lunes 26 de octubre de 2026.

TALKY analiza una exposición oral en audio y devuelve muletillas, tatareos, pausas, ritmo, organización, claridad y repetición, con fortalezas, mejoras y recomendaciones respaldadas por citas.

## Qué contiene

```
harness/
  agent/        CLAUDE.md (memoria del proyecto), rules/ (7 reglas), commands/ (4 comandos), settings.json (permisos)
  context/      13 documentos: visión, requerimientos, arquitectura, patrones agénticos, ML, Groq, API, Flutter, contratos
  prompts/      tasks/ (T01 a T18), templates/, sessions/ (arranque y reanudación), llm/ (prompts del producto)
  tests/        pruebas de aceptación y dobles (el contrato que el código debe cumplir)
  evals/        evaluación de calidad con datos propios (WER, F1 de muletillas y de eventos)
  checklists/   definición de hecho y lista de la demo
  templates/    configuración lista para el repo (pytest, ruff, requirements, CI, .env.example)
  tools/        lista de tareas, validador del arnés, instalador y empaquetador
  harness_tests/ pruebas del propio arnés
```

## Inicio rápido

1. Copia esta carpeta a la raíz del repositorio de TALKY con el nombre `harness/`.
2. Instala:

   ```bash
   python harness/tools/install.py        # o: bash harness/install.sh
   python -m venv .venv && source .venv/bin/activate    # en Windows: .venv\Scripts\activate
   pip install -r requirements-dev.txt
   ```

   El instalador copia `CLAUDE.md`, `.claude/` (comandos y permisos), `tests/`, `evals/`, `pytest.ini`, `ruff.toml`, `requirements*.txt`, `.env.example`, el flujo de CI y agrega al `.gitignore` lo necesario. No pisa archivos existentes (usa `--force` para sobrescribir) y se puede ejecutar varias veces.
3. Verifica el arnés: `python harness/tools/check_harness.py` debe decir "Harness consistente.".
4. Abre Claude Code en la raíz del repositorio y pega el prompt de `harness/prompts/sessions/00-kickoff.md`.
5. Pide una tarea a la vez: "Haz la tarea T02". Sigue el orden de `python harness/tools/tasks.py next`.

## Cómo está pensado

- Un solo agente, tareas pequeñas, pruebas primero. Las 272 pruebas de `tests/` definen el comportamiento exacto de cada módulo; el agente no las debilita.
- `CLAUDE.md` es corto y operativo (flujo, reglas de capas, límites). El detalle vive en `context/` y se lee bajo demanda.
- Las tareas no se asignan a personas; se toman por orden de dependencias. Después de T02 hay siete tareas independientes que pueden avanzar en paralelo en ramas distintas.
- Arquitectura del producto: pipeline híbrido en capas con puertos y adaptadores. Patrones agénticos del producto: encadenamiento, enrutamiento, paralelización, evaluador (verificador de citas) y juez. No hay agentes autónomos. Ver `context/03-agentic-patterns.md`.
- Todo lo opcional (clasificador acústico, embeddings, verificador) se enciende con banderas y degrada con elegancia.

## Comandos de Claude Code incluidos

| Comando | Qué hace |
|---|---|
| `/next-task [Txx]` | Elige la siguiente tarea desbloqueada, la lee, corre sus pruebas en rojo y propone un plan |
| `/verify [Txx]` | Pruebas de la tarea, suite completa, ruff, reglas de capas, higiene y alcance |
| `/review` | Revisión crítica del diff contra contratos, privacidad y calidad |
| `/status` | Avance, pruebas, riesgos de plazo y siguiente paso |

## Herramientas

```bash
python harness/tools/tasks.py list|next|show T05|status T05 done|order
python harness/tools/check_harness.py        # valida enlaces, tareas, dependencias, pruebas y sintaxis
python harness/tools/make_zip.py             # genera harness.zip
python -m pytest harness/harness_tests -q    # pruebas del propio arnés
python evals/run_eval.py --help              # evaluación (tras instalar)
```

## Estado de validación

- Las pruebas de aceptación se validaron contra una implementación de referencia privada del arnés: 272 pruebas en verde, deterministas en dos corridas. Esa implementación no se incluye para que el agente construya el código; se puede entregar aparte si el equipo quiere compararla.
- `check_harness.py` y las pruebas de `harness_tests/` validan la coherencia del paquete en cada cambio.
- Las pruebas no llaman a la red ni descargan modelos. Los proveedores reales (Groq, faster-whisper, sentence-transformers) se prueban a mano con el procedimiento de cada tarea.

## Lo que el arnés no puede garantizar

- Que los modelos y límites gratuitos de Groq sigan vigentes: se documentan con fecha y deben revisarse en la consola antes de la demo.
- La calidad del clasificador acústico: depende de los datos que grabe el equipo (T17).
- Que el prompt y los umbrales sean óptimos: se ajustan con datos reales.

## Mantener el arnés

Si cambias un contrato, actualiza en este orden: la prueba, `context/10-module-contracts.md`, la tarea y, si afecta la API, `context/07-api-contract.md`. Luego corre `python harness/tools/check_harness.py` y `python -m pytest harness/harness_tests -q`.
