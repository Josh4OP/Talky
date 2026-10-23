---
id: T10
title: Datos, características y modelo Random Forest
status: todo
phase: 2-inteligencia
depends_on: [T02]
requirements: [RF-10]
estimate: 5h
tests: [tests/ml/test_dataset.py, tests/ml/test_features.py, tests/ml/test_event_model.py]
touches: [src/infrastructure/ml/__init__.py, src/infrastructure/ml/dataset.py, src/infrastructure/ml/features.py, src/infrastructure/ml/event_model.py]
---
# T10 - Datos, características y modelo Random Forest

## Objetivo

Construir las piezas del clasificador acústico: leer etiquetas de Audacity y convertirlas en ventanas etiquetadas, extraer características acústicas por ventana y entrenar, guardar y cargar un Random Forest.

## Contexto

Diseño completo en `harness/context/04-ml-design.md` y reglas en `harness/agent/rules/ml-guidelines.md`. Un compañero propuso Random Forest: es explicable, entrena en segundos y funciona con pocos datos. Las pruebas usan señales sintéticas, no necesitan datos reales.

## Alcance

1. `dataset.py` (Python puro): `LabelSpan`, `LabeledWindow`, `parse_audacity_labels`, `windows_from_labels`, `leave_one_speaker_out`.
2. `features.py` (numpy y librosa): `FEATURE_DIM`, `extract_features`, `frame_signal`. Características sugeridas: media y desviación de MFCC 1 a 13, RMS, cruces por cero, centroide y planitud espectral, variación del tono (yin).
3. `event_model.py` (scikit-learn y joblib): `train_event_model`, `EventModel` con `classes_`, `predict`, `save`, `load`.

No hacer: redes neuronales, GPU, optimización de hiperparámetros (queda para T17), dependencias fuera de `requirements-ml.txt`.

## Contrato

Ver `harness/context/10-module-contracts.md`, secciones `dataset.py`, `features.py` y `event_model.py`. Puntos finos:

- `extract_features` devuelve siempre valores finitos y es determinista, también para silencio digital y ventanas de menos de 50 ms.
- `train_event_model` usa `RandomForestClassifier(n_estimators=200, class_weight="balanced", random_state=seed)`.
- `EventModel.load` verifica que el modelo guardado tenga `n_features_in_ == FEATURE_DIM` y lanza `ValueError` con un mensaje claro si no coincide.
- Importar librerías pesadas dentro de las funciones donde se usan para que `import src.infrastructure.ml.dataset` funcione sin numpy.

## Criterios de aceptación

1. Las tres pruebas pasan.
2. `python -c "import src.infrastructure.ml.dataset"` funciona en un entorno sin librosa.
3. El modelo guardado y vuelto a cargar predice igual que el original.

## Pruebas

```bash
python -m pytest tests/ml/test_dataset.py tests/ml/test_features.py tests/ml/test_event_model.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde: `python -m pytest tests/ml/test_dataset.py tests/ml/test_features.py tests/ml/test_event_model.py -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T10 done`.
- [ ] Commit(s) convencional(es) `tipo(T10): descripción`.
