# 03 - Patrones agénticos

Este documento responde dos preguntas distintas:

1. Qué patrones agénticos usa el producto TALKY y cuáles descarta.
2. Cómo se construye el proyecto con un agente de código (Claude Code), es decir, el uso de este harness.

Referencia base: "Building effective agents" de Anthropic (ver `11-references.md`). Principio: usar la solución más simple que funcione; agregar autonomía solo cuando mejora un resultado medible.

## 1. El producto: pipeline híbrido, no multiagente autónomo

TALKY usa flujos de trabajo (workflows) con pasos predefinidos. Un agente autónomo decidiría qué herramienta llamar en cada paso; aquí el camino es siempre el mismo, así que no hace falta y costaría más tokens, más latencia y menos predictibilidad.

### Patrones adoptados

| Patrón | Dónde vive | Para qué |
|---|---|---|
| Encadenamiento de prompts (prompt chaining) | `AnalyzePresentation` | Transcribir, medir, analizar, verificar, sintetizar en pasos con puertas de control entre ellos |
| Enrutamiento (routing) | `route_input`, `LLMRouter`, `RoutedTranscriber` | Elegir transcriptor, proveedor de LLM y compresión según reglas y cuota |
| Paralelización (voting / sectioning) | `EnsembleAnalyzer` | Varios modelos analizan lo mismo en paralelo; la mediana de puntajes y el desacuerdo dan confianza |
| Evaluador (evaluator) | `verifier.py` | Revisa cada afirmación del LLM contra la transcripción sin usar otro LLM |
| Juez / síntesis | `EnsembleAnalyzer._synthesize` | Un modelo une los análisis y descarta contradicciones con los datos objetivos |
| Fallback y circuit breaker simple | `LLMRouter`, `FallbackTranscriber` | Continuar cuando un proveedor falla o limita la cuota |
| Salida estructurada | `strict_json_schema`, `OpenAICompatibleLLM` | JSON garantizado en modelos que lo soportan, con degradación a `json_object` |
| Datos objetivos como verdad | `build_user_message` | El LLM recibe cifras medidas (muletillas, ritmo) y no puede contradecirlas |

### Patrones descartados (y por qué)

| Patrón | Razón |
|---|---|
| Agente autónomo con bucle de herramientas | El flujo es fijo; un bucle añade costo y variabilidad sin beneficio |
| Orquestador con trabajadores (orchestrator-workers) | Las subtareas se conocen de antemano; no hay que descubrirlas en ejecución |
| Marcos como LangChain o CrewAI | Una dependencia grande para cuatro patrones que se implementan en 300 líneas probadas |
| Memoria del agente | El historial es una tabla SQL, no memoria conversacional |
| LLM para contar muletillas o medir ritmo | Se miden con código determinista; el LLM solo interpreta |

### Qué hace "inteligente" al sistema

La parte que justifica el curso y el informe es la combinación de técnicas, cada una con su métrica:

1. Whisper con prompt de muletillas, para que no las limpie.
2. Un Random Forest sobre rasgos acústicos que detecta lo que Whisper no transcribe (tatareos, "mmm", "eh" muy cortos).
3. Fusión de ambas fuentes con confianza "alta" cuando coinciden.
4. Embeddings de texto para medir coherencia sin gastar tokens de LLM.
5. Un verificador que convierte "el modelo dice que..." en "el modelo dice que... y aquí está la cita".

## 2. La construcción: un agente de código con arnés

Aquí sí hay un agente: Claude Code, que implementa el proyecto. Se trabaja con uno solo, no con un enjambre.

### Por qué un solo agente

Las tareas son pequeñas, ordenadas por dependencias y verificables con pruebas. Varios agentes en paralelo sobre el mismo repositorio generan conflictos y exigen coordinación. Si se quiere paralelizar, se usan ramas o worktrees distintos por tarea independiente (ver el grafo en `prompts/README.md`), una sesión por tarea.

### Componentes del arnés

| Componente | Archivo o carpeta | Función |
|---|---|---|
| Memoria del proyecto | `agent/CLAUDE.md` (se copia a la raíz) | Reglas, arquitectura y flujo que el agente lee en cada sesión |
| Reglas por tema | `agent/rules/*.md` | Estilo, pruebas, git, privacidad, ML, prompts |
| Comandos | `agent/commands/*.md` | `/next-task`, `/verify`, `/review`, `/status` |
| Permisos | `agent/settings.json` | Qué puede ejecutar sin preguntar y qué tiene prohibido |
| Contexto | `context/` | Qué se construye y por qué |
| Tareas | `prompts/tasks/` | Unidades de trabajo con contrato y criterios |
| Pruebas de aceptación | `tests/` | Red de seguridad escrita antes del código |
| Evaluación | `evals/` | Mide la calidad real, no solo que el código corra |
| Herramientas | `tools/` | Lista de tareas, validador de coherencia del arnés |

### Ciclo de trabajo por tarea

```
/next-task  ->  leer tarea y contratos  ->  correr pruebas (rojo esperado)
   ->  implementar lo mínimo  ->  /verify (pruebas + ruff)  ->  /review
   ->  commit pequeño  ->  marcar tarea done  ->  siguiente
```

Reglas del ciclo:

- Las pruebas son el contrato. Si una prueba parece incorrecta, el agente se detiene, lo explica y propone un cambio; no la debilita.
- Cada tarea termina con todas sus pruebas en verde y el resto de la suite sin regresiones.
- Una tarea, un commit (o pocos), un pull request.
- Si el contexto de la sesión se agota, se retoma con `prompts/sessions/01-resume.md`.

### Qué no hace el agente sin permiso

Ejecutar comandos destructivos, leer `.env`, subir audios, cambiar el contrato de una prueba, agregar dependencias pesadas no previstas, o llamar a servicios externos de pago.
