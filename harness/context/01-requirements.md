# 01 - Requerimientos

Fuente oficial: documento "Avance Proyecto de Aula, requerimientos" del equipo (encuesta con 12 respuestas y entrevista semiestructurada). Los identificadores RF-01 a RF-08 y RNF-01 a RNF-04 son los del documento y no se renumeran. RF-09 a RF-11 son extensiones propuestas para el MVP técnico; se marcan como tales.

## Requerimientos funcionales

| ID | Nombre | Descripción | Prioridad | Criterio de aceptación |
|---|---|---|---|---|
| RF-01 | Cargar archivo de audio | El usuario carga un archivo de audio para analizar su presentación. | Alta | Un audio compatible se carga y se inicia el análisis. |
| RF-02 | Validar formato | Se valida el formato antes de analizar. | Alta | Un formato no compatible produce un mensaje claro (HTTP 400). |
| RF-03 | Transcribir audio | El contenido hablado se convierte en texto con marcas de tiempo. | Alta | Un audio válido genera una transcripción usable por el análisis. |
| RF-04 | Identificar muletillas | Se identifican las muletillas de la presentación. | Alta | El resultado lista las muletillas, su conteo y su frecuencia por minuto. |
| RF-05 | Analizar aspectos | Se analizan organización, claridad y repetición de palabras o ideas. | Alta | El resultado incluye puntajes y comentarios por aspecto, con evidencia citada. |
| RF-06 | Retroalimentación | Se generan aspectos por mejorar y recomendaciones específicas. | Alta | El resultado incluye síntesis, fortalezas, mejoras y recomendaciones. |
| RF-07 | Guardar resultado | El resultado se guarda para consultarlo después. | Alta | Tras un análisis exitoso, aparece en el historial del usuario. |
| RF-08 | Consultar historial | El usuario consulta análisis anteriores. | Alta | Muestra mejoras, fortalezas, recomendaciones, fecha, nombre del audio y muletillas. |
| RF-09 | Ritmo y duración (propuesto) | Palabras por minuto, perfil de ritmo y pausas largas. Sale de la entrevista ("duración y ritmo adecuados"). | Media | El resultado incluye `ppm`, `ritmo` y `pausas`. |
| RF-10 | Eventos acústicos (propuesto; aplazado, fuera del MVP, D-11) | Detección de muletillas vocales y tatareos con un modelo de audio. | Media | El resultado incluye `eventos_acusticos` cuando el clasificador está activo. |
| RF-11 | Aplicación móvil (propuesto) | App Flutter para subir audio, ver resultados e historial. | Media | Flujo completo desde el teléfono contra la API. |

## Requerimientos no funcionales

| ID | Nombre | Descripción | Cómo se cumple en el MVP |
|---|---|---|---|
| RNF-01 | Privacidad | Audios y resultados accesibles solo por su dueño. | El audio nunca se guarda. Cada consulta se filtra por `X-User-Id`. Ver `agent/rules/security-privacy.md`. |
| RNF-02 | Usabilidad | Interfaz clara; el usuario entiende los resultados. | App con tres pantallas, mensajes de error en español claro. |
| RNF-03 | Rendimiento | Resultados en tiempo razonable. | Groq Whisper para velocidad, análisis LLM en paralelo, ventana de transcripción para textos largos. Medido en `evals/`. |
| RNF-04 | Compatibilidad de archivos | Formatos admitidos definidos. | `.mp3 .wav .m4a .ogg .flac .webm`. Conversión a 16 kHz mono con PyAV. |

## Hallazgos de la elicitación que guían decisiones

- Los usuarios esperan que el sistema identifique muletillas, organización, claridad y repetición (RF-04, RF-05).
- Prefieren resultados ya procesados, sin pasos manuales; por eso no hay configuración en la app.
- La transcripción no tiene que mostrarse obligatoriamente al usuario. El MVP la devuelve recortada o no la devuelve; lo que se muestra son citas puntuales.
- El historial es valorado; debe mostrar fecha y nombre del audio.
- La privacidad importa; de ahí la regla de no guardar audio.
- "Ahorro de tiempo" es el factor de confianza que mencionó el entrevistado: el análisis debe terminar en menos de un minuto para audios de 5 minutos con Groq.

## Trazabilidad requerimiento a tarea

| Requerimiento | Tareas |
|---|---|
| RF-01, RF-02, RNF-04 | T06, T15 |
| RF-03 | T06, T07 |
| RF-04 | T03, T12, T17 |
| RF-05 | T04, T08, T09, T14 |
| RF-06 | T08, T14 |
| RF-07, RF-08 | T05, T15, T16 |
| RF-09 | T13 |
| RF-10 | T10, T11 (aplazadas, D-11), T12 |
| RF-11, RNF-02 | T16 |
| RNF-01 | T05, T15, T19 |
| RNF-03 | T04, T07, T17 |
