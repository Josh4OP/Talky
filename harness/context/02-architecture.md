# 02 - Arquitectura del producto

TALKY es un pipeline híbrido de procesamiento de audio y lenguaje, con una API FastAPI y un cliente Flutter. No es un sistema multiagente autónomo (ver `03-agentic-patterns.md`).

## Estilo

Arquitectura en capas con puertos y adaptadores (hexagonal). Las dependencias apuntan hacia adentro:

```
presentation  ->  application  ->  domain  <-  infrastructure
                       ^                             ^
                       +------- config/container ----+   (raíz de composición)
```

| Capa | Carpeta | Responsabilidad | Puede importar |
|---|---|---|---|
| Dominio | `src/domain/` | Entidades, puertos (interfaces), excepciones. Sin I/O. | Solo librería estándar y pydantic |
| Aplicación | `src/application/` | Casos de uso, servicios puros, enrutadores, prompts | `domain` |
| Infraestructura | `src/infrastructure/` | Adaptadores: Groq, Whisper, PyAV, scikit-learn, SQLite | `domain`, librerías externas y el tipo `AudioInfo` de `application/routing/input_router.py` |
| Presentación | `src/presentation/` | FastAPI: rutas, validación HTTP, mapeo de errores | `application`, `domain` |
| Configuración | `src/config/` | `Settings` y `container` (única capa que conoce todo) | todas |

Regla dura: `application` y `domain` no importan `infrastructure`, `fastapi`, `openai`, `sklearn`, `librosa`, `av` ni `sqlite3`. Se verifica en `harness/checklists/definition-of-done.md`.

## Flujo de una petición

```
Flutter  --POST /analyses (audio + X-User-Id)-->  FastAPI
                                                    |
                                          1. validar extensión y tamaño (streaming a archivo temporal)
                                                    |
                                          2. RoutedTranscriber
                                             probe_audio -> route_input (reglas)
                                             rechaza (corto/largo) | comprime si > 25 MB
                                             Groq whisper-large-v3  --falla/429-->  Whisper local (faster-whisper small)
                                                    |       Transcription(text, segments, words, duration, warnings)
                                                    |
                 +----------------------------------+-----------------------------------+
                 |                                  |                                   |
        3a. Muletillas por texto            3b. Ritmo y pausas                  3c. Eventos acústicos (opcional)
        detect_fillers                      pause_stats_from_words              EventClassifier.classify(audio)
                 |                          rhythm_profile                      fuse_fillers(words, eventos)
                 |                                  |                                   |
                 +----------------------------------+-----------------------------------+
                                                    |
                                          4. Coherencia con embeddings (opcional)
                                             saltos de tema, ideas repetidas
                                                    |
                                          5. select_window (si la transcripción es larga)
                                                    |
                                          6. EnsembleAnalyzer (en paralelo)
                                             N analistas (LLMRouter con respaldo y enfriamiento)
                                             verificador de citas (sin LLM) -> descarta lo no respaldado
                                             juez (otro LLMProvider) -> síntesis
                                                    |
                                          7. SqliteAnalysisRepository.save (nunca el audio)
                                                    |
Flutter  <---------------- 201 + JSON del análisis ---+
```

El audio se borra siempre (bloque `finally`). La transcripción completa no se guarda; el resultado guarda solo métricas, síntesis y citas.

## Piezas clave

### Puertos (en `src/domain/interfaces/ports.py`)

`Transcriber`, `LLMProvider`, `TextEmbedder`, `EventClassifier`, `AnalysisRepository`, más los dataclasses `Segment`, `Word`, `Transcription`, `StoredAnalysis`, `AnalysisSummary`. Cada adaptador implementa un puerto; cada servicio recibe puertos por constructor. Esto permite probar todo con dobles (`tests/fakes.py`) sin red ni modelos.

### Enrutadores (en `src/application/routing/`)

Reglas explícitas, no ML:

- `route_input`: decide transcriptor, compresión y rechazo según duración, tamaño, volumen y cuota restante.
- `LLMRouter`: lista de proveedores con respaldo; ante 429 pone el proveedor en enfriamiento.
- `FallbackTranscriber` y `RoutedTranscriber`: Groq primero, local como respaldo; error de audio inválido no se reintenta.

### Servicios puros (en `src/application/services/`)

`filler_detector`, `metrics`, `transcript`, `coherence`, `event_fusion`, `verifier`, `ensemble`. Sin I/O; reciben datos y devuelven datos. Son la parte más fácil de probar y la que más puntúa en la calidad del código.

### Caso de uso

`AnalyzePresentation.execute(audio_path) -> dict` orquesta los servicios. Cada etapa opcional (coherencia, eventos acústicos, verificación) está envuelta en `try/except` que agrega un texto a `advertencias` y sigue.

### Raíz de composición

`build_container(settings, *, transcriber, llm_providers, embedder, event_classifier, repository)` construye todo. Los argumentos con nombre sustituyen la construcción real, así las pruebas no tocan la red. Las banderas `ENABLE_*` encienden o apagan etapas opcionales. Si una bandera está encendida pero falta el modelo o la librería, la etapa se omite y se agrega un warning (degradación elegante).

## Degradación elegante

| Falla | Comportamiento |
|---|---|
| Groq Whisper devuelve 429 o error | Se usa Whisper local; advertencia con la palabra "respaldo" |
| Un LLM analista falla | Los demás siguen; queda en `modelos_fallidos`; error 503 solo si responden menos de `MIN_MODELS_OK` |
| El juez falla | `LLMRouter` prueba otro proveedor; si todos fallan, unión simple de las listas |
| Falta el modelo del clasificador acústico | `eventos_acusticos` es `null` y hay una advertencia |
| Falta `sentence-transformers` | `coherencia` es `null` y hay una advertencia |
| El verificador no encuentra citas válidas | Se descartan las evidencias; `verificacion.tasa` baja; el análisis no se cae |

## Concurrencia y rendimiento

- Los analistas LLM se llaman en paralelo con `ThreadPoolExecutor` (las llamadas son I/O).
- FastAPI ejecuta las rutas síncronas en un pool de hilos; no se usa `async` en el caso de uso.
- SQLite con una conexión por llamada y bloqueo de escritura (hilos seguros).
- Whisper local y el modelo de embeddings se cargan una sola vez (`LazyTranscriber`, singleton en el contenedor).

## Persistencia

SQLite, una tabla `analyses(id, user_id, filename, created_at, result_json)`. `result_json` es el diccionario completo del análisis. Índice por `(user_id, created_at)`; la lista ordena por fecha descendente. No hay ORM. El archivo se define con `DB_PATH`.

## Estructura de carpetas objetivo

```
src/
  domain/{entities,interfaces,exceptions}/
  application/
    prompts.py
    routing/{input_router,llm_router,transcriber_router}.py
    services/{filler_detector,metrics,transcript,coherence,event_fusion,verifier,ensemble}.py
    use_cases/analyze_presentation.py
  infrastructure/
    audio.py
    external/{openai_compatible_llm,groq_transcriber,whisper_transcriber,json_schema}.py
    ml/{dataset,features,event_model,postprocess,event_classifier,sentence_embedder}.py
    repositories/sqlite_analysis_repository.py
  presentation/{app.py,routes/analysis.py}
  config/{settings.py,container.py}
main.py                   # uvicorn: app = create_app(build_container(Settings.from_env()))
scripts/                  # train_event_model.py y utilidades manuales
models/                   # event_classifier.joblib (no versionado)
mobile/                   # app Flutter
tests/  evals/  harness/
```

## Seguridad y privacidad (resumen)

Ver `agent/rules/security-privacy.md`. Puntos de arquitectura: identidad por cabecera `X-User-Id` validada con regex (suficiente para el MVP, se declara como limitación), consultas siempre filtradas por usuario, sin logs con contenido de transcripciones, claves solo por entorno.
