# Evaluación de TALKY

Esta carpeta es el harness de evaluación: mide con números qué tan bien funciona el pipeline. Esos números son el material del informe (comparaciones antes y después, línea base contra mejora).

## Qué se mide

| Modo | Pregunta que responde | Necesita |
|---|---|---|
| `text` | ¿El detector de muletillas acierta sobre una transcripción perfecta? | Solo el manifiesto |
| `transcribe` | ¿Cuánto error de palabras (WER) tiene el transcriptor y cuántas muletillas conserva? | Audios y clave de Groq o Whisper local |
| `events` | ¿El clasificador acústico encuentra las muletillas vocales y tarareos? | Audios con eventos etiquetados y un modelo entrenado |

Métricas (en `metrics.py`, probadas en `harness_tests/`):
- **WER**: errores de palabras sobre palabras de referencia (0 es perfecto).
- **Precisión, recall y F1 de muletillas**: se comparan conteos por muletilla contra los esperados.
- **Precisión, recall y F1 de eventos**: se emparejan intervalos de la misma etiqueta con una tolerancia en segundos.

## Manifiesto

Copia `dataset/manifest.example.json` como `dataset/manifest.json`. Cada entrada:

| Campo | Obligatorio | Descripción |
|---|---|---|
| `id` | sí | Identificador único, por ejemplo `ana-01-expo-clima` |
| `speaker` | recomendado | Hablante; se usa para validar dejando un hablante fuera |
| `audio` | para `transcribe` y `events` | Ruta relativa al manifiesto |
| `reference_transcript` | para `text` y WER | Transcripción verbatim hecha a mano, con las muletillas |
| `expected_fillers` | para muletillas | Conteo esperado, con las mismas claves que `detect_fillers` (`eh`, `mmm`, `o sea`, `entonces`, ...) |
| `events` | para `events` | Lista de `[inicio_s, fin_s, etiqueta]`, con etiqueta `filler` o `hum` |

## Cómo grabar y etiquetar (guía rápida)

1. Cada integrante graba entre 10 y 15 clips de 30 a 60 segundos: habla normal, con muletillas a propósito, con tarareos, con pausas largas. Formato WAV o M4A.
2. Nombra los archivos `hablante-NN.wav` y guárdalos en `dataset/audio/` (esa carpeta no se sube a git).
3. Abre cada clip en Audacity y crea una pista de etiquetas (Ctrl+B sobre la selección). Marca solo los eventos especiales con el texto `filler`, `hum`, `silence` o `noise`. Lo no marcado cuenta como `speech`.
4. Exporta las etiquetas (Archivo, Exportar, Exportar etiquetas) como `hablante-NN.txt` junto al audio. El entrenamiento las lee con `parse_audacity_labels`.
5. Escribe la transcripción literal y el conteo esperado de muletillas en el manifiesto.

Los audios son datos personales: no se suben al repositorio y se usan solo con permiso de quien habla.

## Uso

Desde la raíz del repo, con el arnés instalado (`bash harness/install.sh` copia `evals/` a la raíz del repo):

```bash
python evals/run_eval.py --mode text --manifest evals/dataset/manifest.json
python evals/run_eval.py --mode transcribe --transcriber groq --manifest evals/dataset/manifest.json
python evals/run_eval.py --mode events --event-model models/event_classifier.joblib --manifest evals/dataset/manifest.json
```

Los resultados quedan en `evals/results/` como JSON y Markdown.

## Qué comparar en el informe

- Whisper con y sin prompt de muletillas.
- `small` local contra `large-v3` en Groq (WER, tiempo, muletillas conservadas).
- Detector de muletillas anterior (conteo simple) contra el contextual.
- Clasificador de eventos con características clásicas contra embeddings, siempre con validación dejando un hablante fuera.
