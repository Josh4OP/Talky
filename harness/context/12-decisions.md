# 12 - Decisiones de diseño

Formato: contexto, decisión, consecuencias. Una decisión se cambia agregando una nueva entrada que la reemplace, no borrando la anterior.

## D-01: Pipeline híbrido en lugar de sistema multiagente autónomo

- Contexto: el equipo pensó en un "sistema multiagéntico". El flujo de TALKY es siempre el mismo.
- Decisión: workflows con enrutamiento, paralelización y evaluador. Sin agentes con bucle de herramientas.
- Consecuencias: menor costo y latencia, comportamiento predecible y fácil de probar. Se cumple la idea de "combinar varias técnicas" sin autonomía innecesaria.

## D-02: Whisper en Groq con respaldo local

- Contexto: Whisper local `small` en CPU es lento; Groq ofrece `whisper-large-v3` gratis con cuota.
- Decisión: Groq primero, `faster-whisper` local como respaldo, elegido por reglas (`route_input`) y por fallos.
- Consecuencias: rapidez en la demo y resiliencia si se agota la cuota. Hay que mencionar la salida del audio a un tercero.

## D-03: Random Forest sobre rasgos acústicos para eventos

- Contexto: Whisper omite o "limpia" muletillas vocales y tatareos. Un compañero propuso Random Forest.
- Decisión: clasificador por ventanas de 0.5 s con MFCC y rasgos de tono, entrenado con datos propios.
- Consecuencias: entrena en segundos sin GPU, es explicable (importancia de rasgos) y se evalúa por hablante. Puede tener poco rendimiento con pocos datos; por eso es opcional y se mide.

## D-04: Embeddings de texto para coherencia

- Contexto: pedir al LLM que detecte saltos de tema e ideas repetidas cuesta tokens y varía.
- Decisión: MiniLM multilingüe local y similitud coseno entre ventanas de 3 oraciones.
- Consecuencias: cálculo barato y determinista; el LLM recibe el resultado como dato.

## D-05: Verificador de citas sin LLM

- Contexto: los LLM inventan afirmaciones.
- Decisión: cada afirmación debe traer una cita textual; se acepta si su texto normalizado aparece en la transcripción (coincidencia aproximada con razón mínima 0.85).
- Consecuencias: menos alucinaciones, métrica de calidad (`verificacion.tasa`). Puede descartar citas legítimas por diferencias de transcripción; se ajusta el umbral con datos.

## D-06: Identidad por cabecera `X-User-Id`

- Contexto: RNF-01 pide privacidad; autenticación completa no cabe en el plazo.
- Decisión: identificador declarado por el cliente, validado por regex, usado para aislar datos.
- Consecuencias: cumple el aislamiento lógico pero no es autenticación. Se declara como limitación y como trabajo futuro (JWT).

## D-07: SQLite sin ORM

- Contexto: un solo servidor, datos pequeños, plazo corto.
- Decisión: `sqlite3` de la librería estándar detrás del puerto `AnalysisRepository`.
- Consecuencias: cero dependencias; cambiar a PostgreSQL implica escribir otro adaptador.

## D-08: Un agente de código con pruebas de aceptación previas

- Contexto: se quiere acelerar la construcción con Claude Code sin perder control.
- Decisión: un solo agente, tareas pequeñas con contrato, pruebas escritas antes, reglas en `CLAUDE.md`.
- Consecuencias: el agente no puede "declarar victoria" sin pruebas en verde. Las pruebas se validaron contra una implementación de referencia privada del arnés.

## D-09: Degradación elegante antes que fallo

- Contexto: cuotas gratuitas y modelos opcionales fallan.
- Decisión: las etapas opcionales se aíslan con `try/except` y registran un aviso.
- Consecuencias: la API casi siempre devuelve algo útil; los avisos deben mostrarse al usuario.

## D-10: Clave de configuración única por entorno

- Contexto: `main.py` original leía variables sueltas.
- Decisión: `Settings.from_env` tipado y validado, `create_app(container)` y `build_container(...)` con inyección.
- Consecuencias: la aplicación es probable sin red; los valores inválidos fallan al arrancar con mensajes claros.

## D-11: El clasificador acústico queda fuera del MVP (mejora futura)

- Fecha: 2026-10-23. Complementa D-03, que sigue siendo el diseño para cuando se retome.
- Contexto: el clasificador (T10, T11) necesita datos propios grabados y etiquetados a mano por cada integrante (al menos 3 hablantes y 150 ventanas por clase minoritaria) y unas 9 h de desarrollo, más la recolección de T17. Con la entrega el lunes 26 de octubre, ese tiempo pone en riesgo el camino que lleva a la demo (T13, T14, T15, T16). Sin el clasificador, las muletillas que Whisper sí transcribe se siguen detectando con `filler_detector` (T03).
- Decisión: T10 y T11 pasan a estado `blocked` como mejora futura y no se entregan en el MVP. Se conservan el puerto `EventClassifier`, la etapa opcional del caso de uso, la bandera `ENABLE_EVENT_CLASSIFIER` (apagada) y la fusión de T12, porque las pruebas de contrato de T14 y T15 las cubren con un clasificador falso. T17 se reduce a medir el detector de muletillas, la transcripción y el verificador de citas. Las pruebas de `tests/ml/` de T10 y T11 se excluyen de la recolección en `tests/ml/conftest.py` mientras dure el aplazamiento; no se borran ni se modifican.
- Consecuencias: el MVP no detecta tatareos ni las muletillas vocales que Whisper omite; `eventos_acusticos` es `null` en el resultado. El informe presenta el clasificador como trabajo futuro con su diseño (`context/04-ml-design.md`, sección 1). Para retomarlo: quitar la exclusión de `tests/ml/conftest.py`, pasar T10 y T11 a `todo`, devolver a T17 su dependencia de T11 y su alcance acústico, y grabar los datos.
