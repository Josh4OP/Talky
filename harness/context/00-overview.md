# 00 - Visión general de TALKY

Lee este archivo primero. Es el mapa del proyecto; los demás documentos de `context/` profundizan cada tema.

## Qué es TALKY

TALKY es un asistente que escucha una exposición oral grabada (un archivo de audio) y devuelve retroalimentación útil: muletillas, tatareos, pausas, ritmo, organización, claridad y repetición de ideas, con fortalezas, aspectos por mejorar y recomendaciones. Nace en el curso de Ingeniería de Software de la Universidad Tecnológica de Bolívar (UTB), periodo 2026-20, profesor Aisner José Marrugo Juliao.

Usuarios principales: estudiantes universitarios que preparan exposiciones, sustentaciones o entrevistas. Interesados indirectos: docentes.

## Meta de esta etapa

Entregar un MVP el lunes 26 de octubre de 2026. El MVP debe:

1. Funcionar de punta a punta: subir audio, ver el análisis, consultar el historial.
2. Ser barato: cero costo con los planes gratuitos de Groq y modelos locales.
3. Ser medible: cada técnica de IA tiene una métrica y una comparación contra una línea base, para el informe.
4. Ser defendible: arquitectura en capas, pruebas automáticas y decisiones documentadas.

## Qué se construye (alcance del MVP)

| Bloque | Qué hace | Tarea |
|---|---|---|
| Núcleo | Subir audio, validar, transcribir con Whisper (Groq con respaldo local), ritmo y pausas | T05, T06, T07, T13 |
| Muletillas contextuales | Distinguir "este" muletilla de "este" demostrativo, contar por minuto | T03 |
| Análisis con LLM | Varios modelos gratuitos de Groq opinan en paralelo y un juez los sintetiza | T08, T14 |
| Verificador de citas | Cada afirmación del LLM debe traer una cita textual que exista en la transcripción; si no, se descarta | T08 |
| Coherencia con embeddings | Saltos de tema e ideas repetidas, medidos con embeddings de texto | T09 |
| Clasificador acústico | Random Forest sobre MFCC y rasgos de tono para detectar muletillas vocales y tatareos que Whisper no transcribe. **Aplazado: fuera del MVP, mejora futura (D-11)** | T10, T11 |
| Fusión | Combinar lo que oyó Whisper con lo que detectó el clasificador. Se mantiene; sin clasificador, la etapa no se ejecuta | T12 |
| API | FastAPI con historial por usuario | T14, T15 |
| App | Flutter: subir, ver resultados, historial | T16 |
| Evaluación | Harness de métricas y dataset propio (sin el clasificador acústico) | T17 |
| Cierre | Documentación, demo, endurecimiento | T18 |

Fuera del MVP (no construir): autenticación real con contraseñas, pagos, streaming en tiempo real, análisis de video o de diapositivas, diarización de varios hablantes, apps nativas distintas de Flutter, despliegue en producción con balanceo, y el clasificador acústico de eventos (T10, T11), aplazado como mejora futura el 2026-10-23 (D-11).

## Cómo se organiza el trabajo

- Una tarea por rama y por pull request. Las tareas están en `prompts/tasks/` y se ordenan por dependencias (`python harness/tools/tasks.py next`).
- Las tareas no se asignan a personas; se toman por orden de dependencias. Quien tenga disponibilidad toma la siguiente tarea desbloqueada.
- Las pruebas de aceptación de `tests/` ya están escritas y definen el contrato. El trabajo es hacerlas pasar sin debilitarlas.
- Las reglas del agente están en `agent/CLAUDE.md` y `agent/rules/`.

## Mapa de documentos

| Archivo | Contenido |
|---|---|
| [01-requirements.md](01-requirements.md) | Requerimientos oficiales RF/RNF y su trazabilidad |
| [02-architecture.md](02-architecture.md) | Arquitectura del producto: capas, flujo, puertos, degradación |
| [03-agentic-patterns.md](03-agentic-patterns.md) | Patrones agénticos usados y rechazados, y cómo se construye el proyecto con un agente |
| [04-ml-design.md](04-ml-design.md) | Clasificador acústico, embeddings, evaluación |
| [05-llm-and-groq.md](05-llm-and-groq.md) | Modelos, límites gratuitos, salida estructurada, prompts |
| [06-current-state.md](06-current-state.md) | Auditoría del repositorio antes de empezar |
| [07-api-contract.md](07-api-contract.md) | Contrato HTTP v1 |
| [08-flutter-app.md](08-flutter-app.md) | Especificación de la app |
| [09-glossary.md](09-glossary.md) | Términos |
| [10-module-contracts.md](10-module-contracts.md) | Firmas y reglas de cada módulo (fuente de verdad) |
| [11-references.md](11-references.md) | Documentación externa |
| [12-decisions.md](12-decisions.md) | Decisiones de diseño y sus razones |
