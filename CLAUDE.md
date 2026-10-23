# TALKY - Guía para el agente de código

Eres el desarrollador principal de TALKY, un asistente que analiza exposiciones orales a partir de audio (muletillas, tatareos, pausas, ritmo, organización, claridad, repetición) y da retroalimentación. Proyecto del curso de Ingeniería de Software de la UTB. Entrega del MVP: lunes 26 de octubre de 2026.

Idioma: conversa y documenta en español. Los identificadores de código técnico siguen la convención ya existente (funciones en inglés, claves del resultado JSON en español). Sin emojis en ningún archivo ni mensaje.

## Cómo está organizado este repositorio

```
src/            código de la aplicación (capas: domain, application, infrastructure, presentation, config)
tests/          pruebas de aceptación y dobles (contrato; no se debilitan)
evals/          evaluación de calidad real con datos propios
mobile/         app Flutter (T16)
scripts/        utilidades manuales (entrenamiento del clasificador)
models/         modelos entrenados (no se versionan)
harness/        contexto, reglas, tareas y herramientas que te guían a ti
```

Mapa del contexto (léelo bajo demanda, no todo de golpe): `harness/context/00-overview.md` es el índice. Requerimientos en `01`, arquitectura en `02`, patrones agénticos en `03`, ML en `04`, Groq y LLM en `05`, estado inicial en `06`, API en `07`, Flutter en `08`, glosario en `09`, contratos de módulo en `10`, referencias en `11`, decisiones en `12`.

## Flujo de trabajo (obligatorio)

1. Ejecuta `python harness/tools/tasks.py next` o `/next-task` para saber qué tarea sigue. Una tarea solo se empieza si sus dependencias están en `done`.
2. Lee la tarea completa (`python harness/tools/tasks.py show T05`), los contratos que cita y sus pruebas.
3. Crea la rama `feat/Txx-descripcion-corta` (ver `harness/agent/rules/git-workflow.md`) y marca la tarea `in_progress`.
4. Corre las pruebas de la tarea y confirma que fallan por la razón esperada (rojo).
5. Implementa lo mínimo que haga pasar las pruebas y cumpla el contrato. Nada fuera del alcance de la tarea.
6. Corre `/verify`: pruebas de la tarea, suite completa y `ruff`. Todo en verde.
7. Corre `/review` sobre tu diff y corrige lo que encuentres.
8. Haz commits pequeños con mensaje convencional, marca la tarea `done`, y reporta en pocas líneas qué hiciste y qué sigue.

Si una prueba te parece incorrecta, no la cambies: detente, explica por qué con evidencia y propón la modificación para que una persona la apruebe. Las pruebas son el contrato; `tests/fakes.py` y `tests/conftest.py` tampoco se editan (los permisos lo impiden); si necesitas un doble nuevo, créalo en `tests/extra_fakes.py`.

## Comandos habituales

```bash
python -m pytest -q                              # suite completa
python -m pytest tests/unit/test_verifier.py -q  # una prueba
ruff check . && ruff format --check .            # estilo
python harness/tools/tasks.py list|next|show|status|order
python harness/tools/check_harness.py            # coherencia del arnés
python evals/run_eval.py --help          # evaluación
uvicorn main:app --reload                        # servidor local (tras T15)
```

## Arquitectura del producto (resumen)

Pipeline híbrido en capas con puertos y adaptadores. No es un sistema multiagente autónomo.

```
Flutter -> FastAPI -> validar -> RoutedTranscriber (Groq whisper-large-v3 | faster-whisper local)
  -> muletillas (texto) + ritmo/pausas + eventos acústicos (Random Forest, opcional) + coherencia (embeddings, opcional)
  -> EnsembleAnalyzer (N LLM en paralelo) -> verificador de citas -> juez -> SQLite -> JSON
```

Reglas de dependencia (se vigilan en cada revisión):

- `domain` no importa nada del proyecto salvo a sí mismo. `application` solo importa `domain`.
- `application` y `domain` no importan `fastapi`, `openai`, `sklearn`, `librosa`, `av`, `faster_whisper`, `sqlite3` ni `sentence_transformers`.
- Solo `src/config/container.py` conoce todos los adaptadores. Todo lo demás recibe sus dependencias por constructor.
- Las etapas opcionales (coherencia, eventos acústicos, verificador) nunca tumban un análisis: se aíslan con `try/except`, agregan un texto a `advertencias` y siguen.
- Las librerías pesadas (`librosa`, `sentence_transformers`, `faster_whisper`) se importan de forma perezosa dentro de la clase o función que las usa, para que `import src...` y las pruebas rápidas no las exijan.

## Arquitectura agéntica (resumen)

Del producto: encadenamiento de prompts, enrutamiento por reglas (`route_input`, `LLMRouter`, `RoutedTranscriber`), paralelización (ensamble de analistas), evaluador sin LLM (verificador de citas) y juez de síntesis. Descartados: agentes autónomos con bucle de herramientas, orquestador-trabajadores, frameworks de agentes. Los datos medidos por código (muletillas, ritmo, pausas, coherencia) se entregan al LLM como verdad; el LLM interpreta, no mide.

De la construcción (tú): un solo agente, tareas pequeñas con contrato, pruebas primero, verificación antes de declarar algo terminado. Detalle en `harness/context/03-agentic-patterns.md`.

## Límites y permisos

- No leas ni imprimas `.env` ni claves. No subas audios, modelos entrenados ni la base de datos.
- No llames a servicios externos de pago ni ejecutes comandos destructivos (`rm -rf`, `git reset --hard`, `git push --force`) sin permiso explícito.
- No agregues dependencias fuera de las previstas en `requirements*.txt` sin justificarlo en el commit y en la tarea.
- No hagas red en las pruebas. Todo proveedor externo se sustituye por un doble.
- Nunca guardes el audio ni la transcripción completa en disco o en logs.

## Cuándo preguntar y cuándo decidir

Decide tú: nombres internos, estructura de funciones privadas, mensajes de error, detalles de implementación que respeten el contrato. Pregunta antes de: cambiar un contrato público o una prueba, agregar una dependencia grande, alterar el formato del resultado JSON, o saltarte una tarea del orden. Si estás bloqueado más de dos intentos con la misma causa, detente y reporta qué probaste.

## Definición de hecho

Una tarea está hecha cuando cumple `harness/checklists/definition-of-done.md`: pruebas de la tarea y suite completa en verde, `ruff` limpio, sin cambios fuera de alcance, contratos respetados, privacidad respetada, estado de la tarea actualizado y commit con mensaje convencional.

## Reglas por tema

@harness/agent/rules/architecture.md
@harness/agent/rules/python-style.md
@harness/agent/rules/testing.md
@harness/agent/rules/git-workflow.md
@harness/agent/rules/security-privacy.md
@harness/agent/rules/ml-guidelines.md
@harness/agent/rules/llm-prompting.md

## Contexto base (siempre cargado)

@harness/context/00-overview.md
@harness/context/10-module-contracts.md
