---
id: T11
title: Clasificador de eventos acústicos y script de entrenamiento
status: todo
phase: 2-inteligencia
depends_on: [T06, T10]
requirements: [RF-10]
estimate: 4h
tests: [tests/ml/test_postprocess.py, tests/ml/test_event_classifier.py]
touches: [src/infrastructure/ml/postprocess.py, src/infrastructure/ml/event_classifier.py, scripts/train_event_model.py]
---
# T11 - Clasificador de eventos acústicos y script de entrenamiento

## Objetivo

Unir las piezas de T10 en un adaptador que cumpla el puerto `EventClassifier`: audio a eventos con tiempos, etiqueta y confianza. Agregar el script que entrena el modelo con datos propios y reporta su calidad.

## Contexto

Pipeline en `harness/context/04-ml-design.md`, sección 1. El puerto `EventClassifier.classify(audio_path)` devuelve una lista de `AcousticEvent` (T02). Los datos reales se recolectan en T17; aquí el script debe funcionar con cualquier carpeta de pares audio y etiquetas.

## Alcance

1. `postprocess.py` (Python puro): `WindowPrediction`, `merge_predictions`.
2. `event_classifier.py`: `SklearnEventClassifier(model, *, win_s=0.5, min_duration_s=0.0, max_gap_s=0.05, loader=None)`. El `loader` por defecto es `load_audio` (T06), importado de forma perezosa.
3. `scripts/train_event_model.py`: lee `--data DIR` (pares `nombre.wav` y `nombre.txt`; hablante = prefijo del nombre antes del primer `-`), genera ventanas con `windows_from_labels(win_s=0.5, hop_s=0.25)`, imprime la evaluación dejando un hablante fuera (precisión, recall y F1 por clase, matriz de confusión) y guarda el modelo final en `--out` (por defecto `models/event_classifier.joblib`).

No hacer: entrenar dentro de la API, cargar el modelo en cada petición, versionar el modelo entrenado.

## Contrato

```python
WindowPrediction(start, end, label, confidence)
merge_predictions(preds, max_gap_s=0.05, min_duration_s=0.0) -> list[AcousticEvent]
SklearnEventClassifier(...).classify(audio_path) -> list[AcousticEvent]
```

Reglas del posprocesado en `harness/context/10-module-contracts.md`. El script termina con código distinto de cero y mensaje claro si hay menos de dos hablantes o falta una clase.

## Criterios de aceptación

1. Las pruebas de posprocesado y del clasificador pasan.
2. `python scripts/train_event_model.py --help` documenta todos los argumentos.
3. Con una carpeta sintética de ejemplo (puedes generarla con un script temporal) el script termina y escribe el modelo.
4. `SklearnEventClassifier` no recarga el modelo entre llamadas.

## Pruebas

```bash
python -m pytest tests/ml/test_postprocess.py tests/ml/test_event_classifier.py -q
python scripts/train_event_model.py --help
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/ml/test_postprocess.py tests/ml/test_event_classifier.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T11 done`.
- [ ] Commit(s) convencional(es) `tipo(T11): descripción`.
