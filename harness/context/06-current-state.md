# 06 - Estado actual del repositorio

Repositorio: https://github.com/Josh4OP/Talky (rama principal; un commit: "Feature: added the agent and finish de api V1"). Auditoría hecha antes de preparar este arnés.

## Lo que ya funciona

| Pieza | Archivo | Estado |
|---|---|---|
| Entidades de análisis | `src/domain/entities/analysis.py` | Modelos pydantic `Aspecto`, `Repeticion`, `Analisis`, `Sintesis`. Falta `Evidencia` |
| Puertos | `src/domain/interfaces/ports.py` | Solo `Segment`, `Transcription`, `Transcriber`, `LLMProvider`. Falta `Word`, embeddings, eventos, repositorio |
| Ensamble | `src/application/services/ensemble.py` | Paralelo, mediana de puntajes, desacuerdo, juez con respaldo a unión simple. Sin verificador ni evidencias |
| Muletillas | `src/application/services/filler_detector.py` | Conteo por listas; cuenta "este", "pues" y "tipo" aunque no sean muletillas |
| Métricas | `src/application/services/metrics.py` | `words_per_minute`, `pause_stats` (por segmentos) |
| Caso de uso | `src/application/use_cases/analyze_presentation.py` | Orquesta lo anterior; recorta con `[:max_chars]` |
| LLM | `src/infrastructure/external/openai_compatible_llm.py` | Cliente OpenAI-compatible simple |
| Whisper local | `src/infrastructure/external/whisper_transcriber.py` | faster-whisper `small`, prompt de muletillas, `_load_audio` con PyAV; sin timestamps por palabra |
| API | `src/presentation/routes/analysis.py` | `POST /analyses` sin identidad, sin historial; límite 100 MB revisado después de copiar el archivo |
| Arranque | `main.py` | Construye todo al importar; no hay `create_app`; usa `load_dotenv` |

## Lo que falta o está mal

1. Sin pruebas automáticas (`test_gemini.py` y `test_groq.py` son scripts manuales en la raíz).
2. `requirements.txt` vacío y README con plantillas sin completar.
3. `main.py` ejecuta todo al importar, lo que impide probar la aplicación.
4. Sin historial, sin identidad de usuario, sin persistencia (RF-07, RF-08, RNF-01 incumplidos).
5. Detector de muletillas con falsos positivos (ver ejemplo en `tests/unit/test_filler_detector.py`).
6. Recorte de transcripciones cortando el final, donde suele estar la conclusión.
7. Whisper solo local: lento en CPU y sin respaldo/enrutamiento.
8. Sin verificación de lo que afirma el LLM.
9. Sin ML propio, sin embeddings.
10. Sin app Flutter.
11. Carpetas vacías: `infrastructure/database`, `infrastructure/repositories`, `presentation/controllers`, `presentation/dto`, `shared/*`, `config`. Se usan solo las necesarias; las vacías con solo `__init__.py` se pueden dejar.

## Qué se conserva y qué se reemplaza

Se conserva la estructura en capas, los modelos pydantic de análisis, el ensamble (se extiende) y el adaptador OpenAI-compatible (se extiende). Se reemplazan `main.py`, el detector de muletillas y la ruta de análisis. Se agregan el resto de los módulos de `10-module-contracts.md`.

## Riesgos conocidos

| Riesgo | Mitigación |
|---|---|
| Cuotas gratuitas cambian o se agotan en la demo | Respaldo local, caché de resultados de demo en SQLite, ensayo previo (`checklists/demo-monday.md`) |
| Pocos datos para el clasificador acústico | Posicionarlo como prueba de concepto medida con leave-one-speaker-out; la app funciona sin él |
| Whisper local lento en máquinas sin GPU | `small` con `int8`; usar Groq en la demo |
| Plazo corto (hasta el lunes 26 de octubre de 2026) | Orden de recorte en `prompts/README.md` |
