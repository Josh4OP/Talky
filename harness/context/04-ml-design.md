# 04 - Diseño de machine learning

Todo el ML del MVP es clásico y barato: corre en CPU y se entrena en minutos. No hay redes neuronales entrenadas por el equipo; se reutilizan modelos preentrenados (Whisper, MiniLM) y se entrena un solo modelo propio (Random Forest).

## Mapa de técnicas

| Técnica | Qué problema resuelve | Modelo | Entrena el equipo | Costo |
|---|---|---|---|---|
| Reconocimiento de voz | Texto con marcas de tiempo por palabra | Whisper large-v3 en Groq; faster-whisper `small` local | No | Gratis (cuota) |
| Detección de voz (VAD) | Separar voz de silencio | `vad_filter` de faster-whisper (Silero) | No | Local |
| Clasificador de eventos acústicos | Muletillas vocales y tatareos que Whisper omite | Random Forest sobre rasgos | Sí | Local |
| Embeddings de texto | Coherencia, saltos de tema, ideas repetidas | `paraphrase-multilingual-MiniLM-L12-v2` | No | Local |
| Análisis semántico | Organización, claridad, recomendaciones | LLMs en Groq | No | Gratis (cuota) |

## 1. Clasificador de eventos acústicos

### Etiquetas

`speech`, `filler` (muletilla vocal: "eh", "mmm", "ehm"), `hum` (tatareo), `silence`, `noise`. Definidas en `EVENT_LABELS`.

### Pipeline

```
audio (load_audio: float32, mono, 16 kHz)
  -> frame_signal(win_s=0.5, hop_s=0.5)      ventanas contiguas en inferencia
  -> extract_features(ventana)               vector de longitud FEATURE_DIM
  -> EventModel.predict                      (etiqueta, confianza) por ventana
  -> merge_predictions(max_gap_s, min_duration_s)
  -> list[AcousticEvent(start, end, label, confidence)]
```

### Características por ventana (sugeridas)

- MFCC 1 a 13: media y desviación estándar (26 valores).
- Energía RMS (media y desviación).
- Tasa de cruces por cero.
- Centroide espectral y planitud espectral.
- Variación del tono con `librosa.yin` (los tatareos y las vocales sostenidas tienen tono estable; el habla lo cambia).

Debe ser determinista y siempre finita (sin `NaN` ni `inf`), también para silencio digital.

### Datos

Cada integrante graba clips cortos con muletillas y tatareos a propósito. Se etiquetan en Audacity (formato de etiquetas `inicio<TAB>fin<TAB>texto`). Convención: solo se marcan los eventos especiales; lo no marcado es `speech`. Para entrenamiento, `windows_from_labels(spans, duration_s, win_s=0.5, hop_s=0.25, min_overlap=0.6)` genera ventanas etiquetadas. Una ventana toma la etiqueta con mayor traslape si supera `min_overlap`; si no, queda como `speech`.

Tamaño recomendado: al menos 150 ventanas por clase minoritaria (`filler`, `hum`) y 3 o más hablantes. Con menos, se reporta como prueba de concepto.

### Entrenamiento y evaluación

- Modelo: `RandomForestClassifier(n_estimators=200, class_weight="balanced", random_state=42)`.
- Validación: dejar un hablante fuera (`leave_one_speaker_out`). Una división aleatoria por ventanas infla el resultado porque ventanas vecinas del mismo clip se parecen.
- Métricas: precisión, recall y F1 por clase (no exactitud global, porque `speech` domina), matriz de confusión, y F1 de eventos con tolerancia de 0.25 s en `evals/`.
- Comparación para el informe: RF con rasgos clásicos contra regresión logística (línea base) y, si hay tiempo, contra embeddings de audio preentrenados.
- Importancia de rasgos: `feature_importances_` para explicar qué distingue un tatareo.
- Persistencia: `joblib` en `models/event_classifier.joblib` (no se versiona; se regenera con `scripts/train_event_model.py`).

### Posprocesado

`merge_predictions` une ventanas consecutivas con la misma etiqueta, promedia la confianza ponderada por duración y descarta eventos más cortos que `min_duration_s`. Un umbral de confianza de 0.6 en la fusión evita falsos positivos.

## 2. Fusión de muletillas

`fuse_fillers(words, events)` combina dos fuentes:

- ASR: palabras que Whisper transcribió como "eh", "ehm", "mmm", "hmm".
- Acústica: eventos `filler` con confianza suficiente.

Si coinciden en el tiempo (tolerancia 0.5 s), la muletilla tiene `source="both"` y confianza `alta`. Si solo una fuente la ve, confianza `media`. Los eventos `hum` van aparte como tatareos. Las muletillas de varias palabras ("o sea", "este") las cubre `filler_detector` sobre el texto.

## 3. Coherencia con embeddings de texto

1. Dividir en oraciones y agrupar en ventanas no solapadas de 3 oraciones.
2. Una sola llamada `embedder.embed(ventanas)` para todo el texto.
3. Similitud coseno entre ventanas adyacentes: el promedio mide la coherencia local.
4. Saltos de tema: índices `i` donde la similitud entre la ventana `i` y la `i+1` es menor a 0.35.
5. Ideas repetidas: pares de ventanas no adyacentes (separadas por al menos 2) con similitud mayor a 0.85.
6. Con menos de 2 ventanas no se calcula nada y el promedio es `null`.

Los umbrales son puntos de partida; se ajustan con transcripciones reales y se documentan en el informe. El LLM recibe el conteo de saltos e ideas repetidas como dato objetivo.

## 4. Evaluación general

| Qué | Métrica | Dónde |
|---|---|---|
| Transcripción | WER, tiempo, muletillas conservadas (con y sin prompt) | `evals/run_eval.py --mode transcribe` |
| Detector de muletillas por texto | Precisión, recall, F1 de conteos | `--mode text` |
| Clasificador acústico | F1 por clase y de eventos (leave-one-speaker-out) | `--mode events` |
| Verificador | Tasa de verificación por modelo (`verificacion.tasa`) | Resultado de la API |
| Ensamble | Desacuerdo entre modelos (rango de puntajes mayor o igual a 3) | Resultado de la API |

Las comparaciones "antes y después" (por ejemplo, detector por conteo contra contextual) son el material del informe del curso.

## 5. Lo que no se hace en el MVP

Redes neuronales propias, ajuste fino de Whisper, diarización, clasificación de emociones, detección de nervios por voz. Se mencionan como trabajo futuro.
