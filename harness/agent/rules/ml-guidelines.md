# Regla: machine learning

Contexto en `harness/context/04-ml-design.md`.

## Principios

1. Línea base primero. Toda técnica de ML se compara contra algo más simple (detector por conteo, regresión logística, reglas) y se mide.
2. Validación honesta. El clasificador acústico se evalúa dejando un hablante fuera (`leave_one_speaker_out`). Nunca con una división aleatoria de ventanas.
3. Métricas por clase (precisión, recall, F1) y matriz de confusión. La exactitud global engaña porque `speech` domina.
4. Determinismo: `random_state=42` en modelos, semillas fijas en divisiones, sin dependencia de orden de archivos (ordena los listados).
5. El ML es opcional en producción: si falta el modelo, la aplicación funciona sin él y lo avisa.

## Datos

- Los audios son datos personales: no se suben al repositorio (`evals/dataset/audio/` está ignorado). Solo se usan con permiso de quien habla.
- Etiquetado en Audacity con el formato de `parse_audacity_labels`. Convención: solo se marcan `filler`, `hum`, `silence`, `noise`; lo no marcado es `speech`.
- Registra cuántos clips, hablantes y ventanas por clase hay. Con menos de 3 hablantes o 150 ventanas en una clase minoritaria, el resultado se reporta como prueba de concepto.
- Desbalance: `class_weight="balanced"`; no sobremuestrees antes de dividir.

## Características

- Las características son deterministas y finitas. Silencio digital, ventanas cortas y audios mono sin energía no producen `NaN` ni `inf`.
- Una ventana de inferencia usa el mismo tamaño que la de entrenamiento (`win_s=0.5`).
- Si cambias las características, cambia el nombre/versión del modelo guardado y reentrena; un modelo viejo con características nuevas debe fallar de forma clara al cargarse (verifica `FEATURE_DIM`).

## Modelos preentrenados

- Whisper y MiniLM se usan tal cual. No se afinan en el MVP.
- Los pesos se descargan en el primer uso; en pruebas siempre se sustituyen por dobles.
- Documenta nombre y versión del modelo en el resultado cuando afecte la interpretación (`modelos_usados`).

## Reporte para el informe

Cada experimento deja una tabla en `docs/evaluacion.md` con: fecha, datos usados, configuración, métricas y conclusión en una frase. Lo que no está medido no se afirma.
