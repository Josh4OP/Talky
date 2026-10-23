# Prompts: tareas, plantillas y sesiones

Esta carpeta contiene lo que se le pide al agente de código.

```
prompts/
  tasks/       T01 a T18: una tarea por archivo, con contrato y criterios
  templates/   plantillas para tareas nuevas, correcciones y revisiones
  sessions/    prompts para abrir y reanudar sesiones de trabajo
  llm/         prompts de producto (analista y juez) que usa la aplicación
```

## Cómo se trabaja una tarea

1. `python harness/tools/tasks.py next` (o `/next-task`) para ver qué tareas están desbloqueadas.
2. Abre una sesión nueva del agente con el prompt de `sessions/00-kickoff.md` (una vez por sesión) y pide la tarea: "Haz la tarea T05".
3. El agente sigue el flujo de `CLAUDE.md`: leer, rojo, implementar, `/verify`, `/review`, commit, marcar `done`.
4. Una persona revisa el diff y el resultado de `/verify`, y fusiona.

Las tareas no están asignadas a personas. Quien tenga disponibilidad toma la siguiente tarea desbloqueada, crea su rama y la marca `in_progress` para que nadie la repita.

## Formato de una tarea

Cada archivo `Txx-nombre.md` tiene un front matter:

```
id, title, status (todo|in_progress|done|blocked), phase, depends_on, requirements,
estimate, tests, touches
```

y siete secciones: Objetivo, Contexto, Alcance, Contrato, Criterios de aceptación, Pruebas, Definición de hecho. `python harness/tools/check_harness.py` valida el formato, las dependencias y que cada prueba de `tests/` pertenezca a alguna tarea.

## Índice de tareas

| Id | Tarea | Fase | Depende de | Prueba principal | Est. |
|---|---|---|---|---|---|
| T01 | Preparar el repositorio y el entorno | 0 base | - | - | 2 h |
| T02 | Base de dominio: puertos, entidades, excepciones | 0 base | T01 | `unit/test_entities.py` | 2 h |
| T03 | Detector de muletillas con contexto | 1 núcleo | T02 | `unit/test_filler_detector.py` | 3 h |
| T04 | Manejo de transcripciones largas | 1 núcleo | T02 | `unit/test_transcript.py` | 2 h |
| T05 | Repositorio SQLite del historial | 1 núcleo | T02 | `unit/test_sqlite_repository.py` | 3 h |
| T06 | Utilidades de audio y transcriptores | 1 núcleo | T02, T07 | `ml/test_audio.py`, `unit/test_groq_transcriber.py` | 4 h |
| T07 | Enrutadores: entrada, LLM, transcriptor | 1 núcleo | T02 | tres pruebas de `unit/` | 4 h |
| T08 | Prompts, verificador, JSON estricto, adaptador LLM | 1 núcleo | T02 | cuatro pruebas de `unit/` | 5 h |
| T09 | Coherencia con embeddings de texto | 2 inteligencia | T02, T04 | `unit/test_coherence.py` | 4 h |
| T10 | Datos, características y modelo Random Forest | 2 inteligencia | T02 | tres pruebas de `ml/` | 5 h |
| T11 | Clasificador de eventos y script de entrenamiento | 2 inteligencia | T06, T10 | dos pruebas de `ml/` | 4 h |
| T12 | Fusión de muletillas | 2 inteligencia | T02, T03 | `unit/test_event_fusion.py` | 3 h |
| T13 | Métricas de ritmo y pausas por palabra | 2 inteligencia | T02 | `unit/test_metrics.py` | 2 h |
| T14 | Configuración, composición, ensamble, caso de uso | 3 integración | T03-T09, T12, T13 | `unit/test_settings.py`, `test_container.py` | 6 h |
| T15 | API v1 con historial | 3 integración | T14 | `api/test_routes.py`, `e2e/test_pipeline_fake.py` | 4 h |
| T16 | App Flutter | 4 cliente y calidad | T15 | `flutter test` | 8 h |
| T17 | Datos propios, entrenamiento y evaluación | 4 cliente y calidad | T11, T15 | `evals/` | 8 h |
| T18 | Documentación, demo y endurecimiento | 4 cliente y calidad | T16, T17 | `check_harness` y suite completa | 5 h |

Las estimaciones son para una persona asistida por el agente; sirven para ordenar, no para comprometer.

## Grafo de dependencias

```
T01 -> T02 -> T03 -----------------> T12 ---------------+
         |                                               |
         +--> T04 --> T09 ---------------------------+   |
         +--> T05 -----------------------------------+   |
         +--> T07 --> T06 --> T11 (también T10) ---+ |   |
         +--> T08 -----------------------------------+--+--> T14 --> T15 --> T16 --+--> T18
         +--> T10 --> T11 --------------------------> T17 (también T15) ---------+
         +--> T13 -----------------------------------+
```

Tareas independientes entre sí tras T02: T03, T04, T05, T07, T08, T10, T13. Se pueden trabajar en ramas paralelas con sesiones separadas (idealmente con `git worktree`). Las de la fase 3 en adelante son secuenciales.

## Plan sugerido hasta el lunes 26 de octubre de 2026

| Día | Objetivo |
|---|---|
| Jueves 22 | T01, T02 y arrancar en paralelo T03, T04, T05, T07, T08, T13 |
| Viernes 23 | Terminar fase 1 (T06) y fase 2: T09, T10, T11, T12. Empezar a grabar y etiquetar datos (parte humana de T17) |
| Sábado 24 | T14 y T15 (hito: suite de aceptación completa en verde). Empezar T16 |
| Domingo 25 | T16, T17 (entrenar y medir con los datos grabados) y T18 |
| Lunes 26 | Ensayo final con `checklists/demo-monday.md` y entrega |

## Orden de recorte si el plazo se aprieta

Se recorta de abajo hacia arriba, siempre dejando la aplicación funcionando:

1. Dockerfile y pulido de T18 (conservar README y guion de demo).
2. T17 parcial: medir solo detector de muletillas y transcripción; dejar el clasificador acústico como prueba de concepto documentada.
3. Funciones secundarias de la app (gráfico de ritmo, borrado desde el historial); conservar subir, resultados e historial.
4. T11 y T10: el clasificador acústico queda apagado (`ENABLE_EVENT_CLASSIFIER=false`); T12 se conserva porque funciona solo con palabras de Whisper.
5. T09: la coherencia queda apagada (`ENABLE_TEXT_EMBEDDINGS=false`).

No se recorta: T01 a T08, T13, T14, T15 (núcleo y API con historial) ni las pruebas.

## Cómo agregar una tarea

Copia `templates/task.md` a `tasks/T19-nombre.md`, completa el front matter y las siete secciones, declara las pruebas que la cubren y corre `python harness/tools/check_harness.py`. Para una corrección usa `templates/bugfix.md`; para pedir una revisión, `templates/review.md`.
