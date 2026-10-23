---
id: T17
title: Datos propios, entrenamiento y evaluación medible
status: todo
phase: 4-cliente-y-calidad
depends_on: [T11, T15]
requirements: [RF-04, RF-10, RNF-03]
estimate: 8h
tests: [-]
touches: [docs/evaluacion.md, src/application/services/filler_detector.py, evals/dataset/manifest.json, models/]
---
# T17 - Datos propios, entrenamiento y evaluación medible

## Objetivo

Convertir el sistema en algo medible: grabar y etiquetar un conjunto de datos propio, entrenar el clasificador acústico, evaluar cada técnica contra una línea base y dejar las tablas que alimentan el informe.

## Contexto

Guía de grabación y etiquetado en `evals/README.md`. Diseño y métricas en `harness/context/04-ml-design.md`. Reglas de datos en `harness/agent/rules/ml-guidelines.md`. Los audios son datos personales: no se suben al repositorio y se usan con permiso de quien habla. El harness de evaluación (`evals/run_eval.py`, `evals/metrics.py`) ya existe y tiene sus pruebas.

## Alcance

1. Recolección (humana, el agente prepara y revisa): el equipo graba entre 10 y 15 clips de 30 a 60 segundos por persona con muletillas, tatareos y pausas a propósito; se etiquetan en Audacity y se guardan en `evals/dataset/audio/` (ignorada por git). El agente valida con un script que cada audio tiene su archivo de etiquetas y que las etiquetas son válidas.
2. Manifiesto: crear `evals/dataset/manifest.json` con transcripción literal y conteo esperado de muletillas por clip.
3. Entrenar con `scripts/train_event_model.py`; guardar el modelo en `models/event_classifier.joblib` (no versionado) y registrar el informe leave-one-speaker-out.
4. Medir y comparar, con `evals/run_eval.py`:
   - Detector de muletillas por texto: versión original por conteo contra la versión contextual (F1).
   - Transcripción con y sin prompt de muletillas; Groq `large-v3` contra Whisper local `small` (WER, tiempo, muletillas conservadas).
   - Clasificador acústico: Random Forest contra una línea base de regresión logística (F1 por clase, F1 de eventos).
   - Aporte de la fusión: muletillas encontradas por Whisper solo, por el clasificador solo y por ambos.
   - Tasa de verificación de citas por modelo en 5 análisis reales.
5. Ajustar con datos (listas de muletillas contextuales, umbrales de coherencia y de confianza) y volver a medir.
6. Documentar todo en `docs/evaluacion.md`: tabla por experimento con fecha, datos, configuración, métricas y conclusión en una frase; límites del estudio (cantidad de hablantes, ruido).

No hacer: afirmar mejoras sin medirlas, publicar audios, o entrenar sobre el conjunto de prueba.

## Contrato

- Etiquetas válidas: `speech`, `filler`, `hum`, `silence`, `noise` (lo no marcado es `speech`).
- El hablante de cada clip es el prefijo del nombre del archivo antes del primer `-`.
- Resultados de evaluación en `evals/results/` (JSON y Markdown); la versión resumida va a `docs/evaluacion.md`.
- Si hay menos de 3 hablantes o menos de 150 ventanas en una clase minoritaria, el clasificador se reporta como prueba de concepto y su bandera queda apagada por defecto.

## Criterios de aceptación

1. `docs/evaluacion.md` contiene al menos cuatro tablas comparativas con números reales de los datos del equipo.
2. El clasificador entrenado detecta muletillas en una grabación nueva (no usada en el entrenamiento) y esto se refleja en `eventos_acusticos` de la API con `ENABLE_EVENT_CLASSIFIER=true`.
3. Se reporta F1 por clase con validación dejando un hablante fuera, no con división aleatoria.
4. Ningún audio ni modelo entrenado está en el árbol de git (`git status` limpio de binarios).

## Pruebas

Las pruebas de aceptación no cubren esta tarea; su verificación es la corrida de evaluación y la lectura crítica de `docs/evaluacion.md`.

```bash
python evals/run_eval.py --mode text --manifest evals/dataset/manifest.json
python evals/run_eval.py --mode transcribe --transcriber groq --manifest evals/dataset/manifest.json
python evals/run_eval.py --mode events --event-model models/event_classifier.joblib --manifest evals/dataset/manifest.json
```

## Definición de hecho

- [ ] Verificación de la tarea: `python evals/run_eval.py --mode text --manifest evals/dataset/manifest.json`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T17 done`.
- [ ] Commit(s) convencional(es) `tipo(T17): descripción`.
