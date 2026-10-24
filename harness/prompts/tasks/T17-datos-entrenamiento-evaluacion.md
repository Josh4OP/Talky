---
id: T17
title: Datos propios y evaluación medible
status: todo
phase: 4-cliente-y-calidad
depends_on: [T15]
requirements: [RF-04, RNF-03]
estimate: 5h
tests: [-]
touches: [docs/evaluacion.md, src/application/services/filler_detector.py, evals/dataset/manifest.json]
---
# T17 - Datos propios y evaluación medible

> **Alcance reducido para el MVP** (decisión D-11 en `harness/context/12-decisions.md`, 2026-10-23): el clasificador acústico (T10, T11) está aplazado como mejora futura. Esta tarea ya no graba datos con eventos etiquetados, no entrena modelos ni mide el clasificador o la fusión. Cuando se retome, se restauran la dependencia de T11 y los puntos acústicos (ver D-11).

## Objetivo

Convertir el sistema en algo medible: grabar un conjunto de datos propio con transcripción de referencia, evaluar cada técnica contra una línea base y dejar las tablas que alimentan el informe.

## Contexto

Guía de grabación y etiquetado en `evals/README.md`. Diseño y métricas en `harness/context/04-ml-design.md`. Reglas de datos en `harness/agent/rules/ml-guidelines.md`. Los audios son datos personales: no se suben al repositorio y se usan con permiso de quien habla. El harness de evaluación (`evals/run_eval.py`, `evals/metrics.py`) ya existe y tiene sus pruebas.

## Alcance

1. Recolección (humana, el agente prepara y revisa): el equipo graba clips de 30 a 60 segundos con muletillas y pausas a propósito y los guarda en `evals/dataset/audio/` (ignorada por git). No hace falta etiquetar eventos en Audacity mientras el clasificador esté aplazado.
2. Manifiesto: crear `evals/dataset/manifest.json` con transcripción literal y conteo esperado de muletillas por clip.
3. Medir y comparar, con `evals/run_eval.py`:
   - Detector de muletillas por texto: versión original por conteo contra la versión contextual (F1).
   - Transcripción con y sin prompt de muletillas; Groq `large-v3` contra Whisper local `small` (WER, tiempo, muletillas conservadas).
   - Tasa de verificación de citas por modelo en 5 análisis reales.
4. Ajustar con datos (listas de muletillas contextuales, umbrales de coherencia) y volver a medir.
5. Documentar todo en `docs/evaluacion.md`: tabla por experimento con fecha, datos, configuración, métricas y conclusión en una frase; límites del estudio (cantidad de hablantes, ruido). Incluir una sección breve que presente el clasificador acústico como trabajo futuro (diseño en `harness/context/04-ml-design.md`, sección 1).

No hacer: afirmar mejoras sin medirlas, publicar audios, ni implementar o entrenar el clasificador acústico (aplazado, D-11).

## Contrato

- El hablante de cada clip es el prefijo del nombre del archivo antes del primer `-`.
- Resultados de evaluación en `evals/results/` (JSON y Markdown); la versión resumida va a `docs/evaluacion.md`.
- `ENABLE_EVENT_CLASSIFIER` queda apagada en el MVP.

## Criterios de aceptación

1. `docs/evaluacion.md` contiene al menos tres tablas comparativas con números reales de los datos del equipo (detector de muletillas, transcripción y verificación de citas).
2. `docs/evaluacion.md` presenta el clasificador acústico como trabajo futuro, sin afirmar resultados que no se midieron.
3. Ningún audio está en el árbol de git (`git status` limpio de binarios).

## Pruebas

Las pruebas de aceptación no cubren esta tarea; su verificación es la corrida de evaluación y la lectura crítica de `docs/evaluacion.md`.

```bash
python evals/run_eval.py --mode text --manifest evals/dataset/manifest.json
python evals/run_eval.py --mode transcribe --transcriber groq --manifest evals/dataset/manifest.json
```

## Definición de hecho

- [ ] Verificación de la tarea: `python evals/run_eval.py --mode text --manifest evals/dataset/manifest.json`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T17 done`.
- [ ] Commit(s) convencional(es) `tipo(T17): descripción`.
