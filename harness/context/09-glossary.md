# 09 - Glosario

| Término | Significado en TALKY |
|---|---|
| Muletilla | Palabra o sonido de relleno que se repite al hablar ("eh", "o sea", "este"). |
| Muletilla vocal | Sonido sin significado: "eh", "ehm", "mmm". Whisper tiende a omitirlos. |
| Muletilla contextual | Palabra que a veces es muletilla y a veces no ("este", "entonces", "bueno"). Solo cuenta si va seguida de pausa o es toda la oración. |
| Tatareo (hum) | Sonido tonal sin palabras mientras el hablante piensa. |
| Ritmo | Palabras por minuto (ppm), también por ventanas de 30 s. |
| Pausa larga | Silencio entre palabras de al menos 1 s (por palabras) o 1.5 s (por segmentos). |
| ASR | Reconocimiento automático de voz (Whisper). |
| WER | Tasa de error de palabras: (sustituciones + borrados + inserciones) / palabras de referencia. |
| VAD | Detección de actividad de voz. |
| MFCC | Coeficientes cepstrales en la escala mel; describen el timbre de un sonido. |
| Random Forest | Conjunto de árboles de decisión; aquí clasifica ventanas de audio. |
| Embedding | Vector numérico que representa el significado de un texto. |
| Similitud coseno | Medida de cercanía entre dos embeddings, de -1 a 1. |
| Ventana (audio) | Fragmento de 0.5 s clasificado como `speech`, `filler`, `hum`, `silence` o `noise`. |
| Ventana (texto) | Grupo de 3 oraciones consecutivas usado para medir coherencia. |
| Salto de tema | Cambio brusco de significado entre ventanas adyacentes. |
| Idea repetida | Dos ventanas lejanas con significado casi igual. |
| Analista | LLM que produce un análisis completo de la exposición. |
| Juez | LLM que sintetiza los análisis de los analistas. |
| Ensamble | Conjunto de analistas más verificador y juez. |
| Evidencia | Afirmación del LLM acompañada de una cita textual. |
| Verificador | Servicio sin LLM que comprueba que la cita exista en la transcripción. |
| Enrutador | Componente que elige entre alternativas con reglas (transcriptor, proveedor). |
| Enfriamiento (cooldown) | Tiempo durante el cual un proveedor que devolvió 429 no se vuelve a usar. |
| Degradación elegante | Seguir funcionando con menos funciones cuando algo falla, avisando en `advertencias`. |
| Puerto | Interfaz abstracta de la capa de dominio. |
| Adaptador | Implementación concreta de un puerto en infraestructura. |
| Raíz de composición | Único lugar donde se crean y conectan los adaptadores (`config/container.py`). |
| Arnés (harness) | Este conjunto de reglas, tareas, pruebas y herramientas que guía al agente de código. |
| Prueba de aceptación | Prueba escrita antes del código que define el contrato de un módulo. |
| MVP | Producto mínimo viable: lo que se entrega el lunes 26 de octubre de 2026. |
| RF / RNF | Requerimiento funcional / no funcional. |
| LOSO | Validación dejando un hablante fuera (leave-one-speaker-out). |
