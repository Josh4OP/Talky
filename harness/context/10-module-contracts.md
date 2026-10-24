# 10 - Contratos de módulo (fuente de verdad)

Este documento fija firmas y reglas de cada módulo. Si algo aquí contradice una prueba de `tests/`, gana la prueba y se corrige este archivo. Las firmas de aquí son las que importan las pruebas; los nombres internos no listados son libres.

Convenciones: código y nombres técnicos de dominio en el idioma ya usado (inglés en funciones, español en claves del resultado). Tipos modernos (`list[str]`, `X | None`). Python 3.11 o superior.

## Mapa módulo a prueba a tarea

| Módulo | Prueba | Tarea |
|---|---|---|
| `domain/entities/*`, `domain/exceptions`, `domain/interfaces/ports` | `tests/unit/test_entities.py` | T02 |
| `application/services/filler_detector` | `tests/unit/test_filler_detector.py` | T03 |
| `application/services/transcript` | `tests/unit/test_transcript.py` | T04 |
| `infrastructure/repositories/sqlite_analysis_repository` | `tests/unit/test_sqlite_repository.py` | T05 |
| `infrastructure/audio`, `infrastructure/external/groq_transcriber`, `whisper_transcriber` | `tests/ml/test_audio.py`, `tests/unit/test_groq_transcriber.py` | T06 |
| `application/routing/*` | `tests/unit/test_input_router.py`, `test_llm_router.py`, `test_transcriber_router.py` | T07 |
| `application/prompts`, `application/services/verifier`, `infrastructure/external/{json_schema,openai_compatible_llm}` | `tests/unit/test_prompts.py`, `test_verifier.py`, `test_json_schema.py`, `test_openai_compatible_llm.py` | T08 |
| `application/services/coherence`, `infrastructure/ml/sentence_embedder` | `tests/unit/test_coherence.py` | T09 |
| `infrastructure/ml/{dataset,features,event_model}` | `tests/ml/test_dataset.py`, `test_features.py`, `test_event_model.py` | T10 (aplazada, D-11) |
| `infrastructure/ml/{postprocess,event_classifier}`, `scripts/train_event_model.py` | `tests/ml/test_postprocess.py`, `test_event_classifier.py` | T11 (aplazada, D-11) |
| `application/services/event_fusion` | `tests/unit/test_event_fusion.py` | T12 |
| `application/services/metrics` | `tests/unit/test_metrics.py` | T13 |
| `config/settings`, `config/container`, `application/services/ensemble`, `application/use_cases/analyze_presentation` | `tests/unit/test_settings.py`, `tests/unit/test_container.py` | T14 |
| `presentation/app`, `presentation/routes/analysis`, `main.py` | `tests/api/test_routes.py`, `tests/e2e/test_pipeline_fake.py` | T15 |

## Dominio

### `src/domain/exceptions/__init__.py`

```python
class TalkyError(Exception)
class ConfigurationError(TalkyError, ValueError)          # configuración inválida o incompleta
class InvalidAudioError(TalkyError, ValueError)           # audio ilegible, sin voz, fuera de límites -> HTTP 422
class ProviderError(TalkyError)                           # fallo de un proveedor externo
class RateLimitedError(ProviderError)                     # 429; atributo retry_after: float | None
class AllProvidersFailedError(TalkyError, RuntimeError)   # atributo errors: dict[str, str] -> HTTP 503
```

`RateLimitedError(message="Proveedor limitado por cuota", retry_after=None)`. `AllProvidersFailedError(errors)` arma el mensaje con `nombre: error` separados por `;`.

### `src/domain/interfaces/ports.py`

```python
@dataclass Segment(start: float, end: float, text: str)
@dataclass Word(start: float, end: float, text: str)
@dataclass Transcription(text: str, segments: list[Segment], duration: float,
                         words: list[Word] = [], warnings: list[str] = [])
@dataclass StoredAnalysis(id, user_id, filename, created_at, result: dict)
@dataclass AnalysisSummary(id, filename, created_at, duracion_s: float | None, ppm: float | None, total_muletillas: int)

class Transcriber(ABC):      def transcribe(self, audio_path: str) -> Transcription
class LLMProvider(ABC):      name: str;  def complete_json(self, system: str, user: str) -> str
class TextEmbedder(ABC):     def embed(self, texts: list[str]) -> list[list[float]]
class EventClassifier(ABC):  def classify(self, audio_path: str) -> list            # list[AcousticEvent]
class AnalysisRepository(ABC):
    save(user_id, filename, result: dict) -> str
    get(user_id, analysis_id) -> StoredAnalysis | None
    list(user_id, limit=50, offset=0) -> list[AnalysisSummary]
    count(user_id) -> int
    delete(user_id, analysis_id) -> bool
```

Las listas por defecto de los dataclasses usan `field(default_factory=list)`.

### `src/domain/entities/analysis.py`

`Aspecto(puntaje: int 1..10, comentario: str = "")` redondea el puntaje con `round(float(v))` antes de validar. `Repeticion(Aspecto)` agrega `palabras_repetidas: list[str]`. **Nuevo:** `Evidencia(afirmacion: str, cita: str = "", verificada: bool | None = None)`. `Analisis` agrega `evidencias: list[Evidencia] = []`. `Sintesis(resumen, fortalezas, aspectos_por_mejorar, recomendaciones)` ya existe.

### `src/domain/entities/events.py`

`EVENT_LABELS = ("speech", "filler", "hum", "silence", "noise")`. `AcousticEvent(start, end, label, confidence=1.0)` es un dataclass inmutable con propiedad `duration`.

## Servicios de aplicación

### `filler_detector.py` (T03)

```python
detect_fillers(text: str) -> dict[str, int]       # ordenado de mayor a menor frecuencia
fillers_per_minute(counts: dict[str, int], duration_s: float) -> float   # redondeado a 1 decimal; 0.0 sin duración o sin conteos
```

Reglas:

- Sonidos vocales se normalizan a la clave canónica `eh` (eh, ehh, ehm, em, emm) y `mmm` (mm, mmm, hmm, hmmm). Sin distinguir mayúsculas.
- Siempre cuentan: `o sea`, `digamos`, `como que`, `en plan`, `¿no?`, `¿verdad?`.
- Contextuales (`este`, `entonces`, `bueno`, `pues`, `tipo`, `básicamente`): cuentan solo si van seguidas de pausa (coma, punto y coma, puntos suspensivos, raya) o si forman la oración completa. "Este modelo es mejor." y "Tipo de dato entero." no cuentan.
- `la verdad`: solo cuenta seguida de pausa; nunca como oración completa ni como sustantivo ("la verdad es que" sin coma no cuenta).
- Coincidencia por palabra completa: "estero" no contiene "este".
- Texto vacío devuelve `{}`.

### `transcript.py` (T04)

```python
OMISSION_MARKER = "\n[... fragmento omitido ...]\n"
select_window(text, max_chars, head_ratio=0.6) -> tuple[str, bool]
split_sentences(text) -> list[str]
chunk_text(text, max_chars) -> list[str]
```

- `select_window` devuelve `(text, False)` si cabe (el límite exacto no recorta). Si no, conserva inicio (`head_ratio` del presupuesto) y final, separados por `OMISSION_MARKER`, sin cortar palabras, con longitud total no mayor que `max_chars`. Si `max_chars` no permite ni el marcador, `ValueError`.
- `split_sentences` corta en `. ! ? …` seguidos de espacio; respeta signos de apertura españoles (`¿ ¡`); sin puntuación final devuelve la oración tal cual; vacío devuelve `[]`.
- `chunk_text` agrupa oraciones completas sin pasar de `max_chars`; una oración mayor al límite se divide por palabras; no pierde texto.

### `sqlite_analysis_repository.py` (T05)

`SqliteAnalysisRepository(db_path)` acepta `":memory:"`. Crea la tabla y el índice si no existen. Reglas:

- `save` genera `uuid4` (hex), guarda `result` como JSON y la fecha UTC con formato `%Y-%m-%dT%H:%M:%S.%fZ`. Rechaza `user_id` vacío con `ValueError`.
- `get`/`delete` devuelven `None`/`False` para ids inexistentes o de otro usuario.
- `list` devuelve `AnalysisSummary` ordenados por fecha descendente; los campos faltantes en el JSON dan `None` o `0` (`total_muletillas` = suma de los conteos de `muletillas`).
- Seguro entre hilos: una conexión con `check_same_thread=False` protegida con un `threading.Lock`. Los datos persisten tras reabrir el archivo. Crea las carpetas padre del archivo si no existen.

### `audio.py` (T06)

```python
AudioInfo                               # se importa de application/routing/input_router.py
load_audio(path) -> np.ndarray          # float32, mono, 16 kHz, [-1, 1]
probe_audio(path) -> AudioInfo          # rms_dbfs con piso en -120.0
compress_for_upload(path) -> str        # FLAC 16 kHz mono en un archivo temporal; el llamador lo borra
```

Archivo ilegible: `InvalidAudioError`. Usa PyAV (`av`), no ffmpeg por subproceso.

### `groq_transcriber.py` y `whisper_transcriber.py` (T06)

`GroqTranscriber(client, model="whisper-large-v3", language="es", prompt=DEFAULT_PROMPT)`. Llama `client.audio.transcriptions.create` con `response_format="verbose_json"`, `timestamp_granularities=["word", "segment"]`, `temperature=0`, `language`, `prompt`. Convierte la respuesta a `Transcription` con `words`. Errores HTTP: 429 a `RateLimitedError` (con `retry_after` si viene), 400 o 413 a `InvalidAudioError`, cualquier otro a `ProviderError`.

`WhisperTranscriber(model_size="small", language="es")` usa `load_audio` de `audio.py`, `word_timestamps=True`, `vad_filter=True` y el prompt de muletillas; llena `words`. Es lo único que importa `faster_whisper`, y lo hace de forma perezosa.

### Enrutadores (T07)

`input_router.py`:

```python
AudioInfo(duration_s, size_bytes, rms_dbfs=None)
RoutingSettings(groq_enabled=False, groq_max_bytes=25*1024*1024, min_duration_s=5.0,
                max_duration_s=2700.0, quiet_dbfs=-45.0, groq_remaining_audio_s=None)
RoutingDecision(transcriber: str, compress: bool=False, warnings: list[str]=[], reject_code=None, reject_reason=None)
route_input(info, settings) -> RoutingDecision
```

Orden de reglas: rechazar si es más corto que el mínimo (`too_short`) o más largo que el máximo (`too_long`); elegir `groq` si está habilitado, si no `local`; si la cuota restante de audio de Groq es menor que la duración, pasar a `local` con aviso; avisar si `rms_dbfs < quiet_dbfs`; comprimir solo si el elegido es `groq` y `size_bytes > groq_max_bytes`.

`llm_router.py`: `LLMRouter(providers, cooldown_s=60.0, clock=time.monotonic)` es un `LLMProvider` con `name == "router"`. Prueba proveedores en orden; los que están en enfriamiento se saltan (quedan en el diccionario de errores como "en enfriamiento por límite de cuota"); un `RateLimitedError` activa el enfriamiento (usa `retry_after` si viene, si no `cooldown_s`); otros errores solo pasan al siguiente. Si todos fallan: `AllProvidersFailedError` con el error de cada uno. Sin proveedores: `ValueError`.

`transcriber_router.py`: `FallbackTranscriber`, `RoutedTranscriber`, `LazyTranscriber` según `tests/unit/test_transcriber_router.py` (docstring de la prueba). Resumen: `InvalidAudioError` nunca reintenta; el respaldo agrega advertencia con la palabra "respaldo"; `RoutedTranscriber` rechaza con `InvalidAudioError` antes de llamar a ningún transcriptor; comprime y borra el temporal; al menos un transcriptor o `ValueError`.

### `prompts.py`, `verifier.py`, `json_schema.py`, `openai_compatible_llm.py` (T08)

- `prompts.py`: `ANALYSIS_SYSTEM`, `JUDGE_SYSTEM` (empieza con "Eres un editor") y `build_user_message(objective, transcript, truncated)`. Texto de referencia en `prompts/llm/`.
- `verifier.py`: `normalize(text)` (minúsculas, sin tildes, sin puntuación, espacios colapsados); `quote_in_transcript(quote, transcript, min_ratio=0.85)` (coincidencia exacta normalizada o aproximada por ventana deslizante de palabras con `difflib.SequenceMatcher`; rechaza citas vacías o de menos de 3 palabras); `verify_evidences(evidencias, transcript)` devuelve copias con `verificada` True o False; `drop_unverified` conserva solo las evidencias con `verificada is True` (descarta `False` y `None`); `verification_rate` devuelve `verificadas / total` o `None` si la lista está vacía.
- `json_schema.strict_json_schema(Modelo)`: `model_json_schema()` con `$ref` resueltos en línea, `additionalProperties: false` y todas las propiedades en `required` en cada objeto.
- `OpenAICompatibleLLM(name, base_url, api_key, model, timeout=90, max_retries=4, json_schema=None, client=None)`: ver `tests/unit/test_openai_compatible_llm.py`. Con `client` inyectado no crea uno real. Traduce 429 a `RateLimitedError`, 400 dispara la cadena de degradación de `response_format`, resto de errores de API a `ProviderError`.

### `coherence.py` y `sentence_embedder.py` (T09)

Ver docstring de `tests/unit/test_coherence.py`. `SentenceTransformerEmbedder(model_name)` implementa `TextEmbedder`, importa `sentence_transformers` de forma perezosa y normaliza los vectores (`normalize_embeddings=True`) devolviendo listas de floats.

### `event_fusion.py` (T12)

```python
FillerHit(start, end, texto, source, confianza)    # to_dict()
FusionResult(fillers: list[FillerHit], hums: list[AcousticEvent])
fuse_fillers(words, events, tolerance_s=0.5, min_confidence=0.6) -> FusionResult
```

Reglas: de `words` solo cuentan los tokens que normalizan a `eh` o `mmm`; de `events` solo `filler` y `hum` con `confidence >= min_confidence`. Un evento se empareja con la palabra más cercana dentro de la tolerancia, y cada palabra con un solo evento. Emparejados: `source="both"`, `confianza="alta"`, tiempos de la palabra. Solo ASR: `source="asr"`, `confianza="media"`. Solo acústico: `source="acoustic"`, `confianza="media"`, `texto="[acustico]"` (no se sabe qué sonido fue). Emparejados: los tiempos son la unión de palabra y evento. `texto` en los demás casos es la clave canónica (`eh` o `mmm`). Resultado ordenado por inicio.

### `metrics.py` (T13)

Ver docstring de `tests/unit/test_metrics.py`. `pause_stats_from_words(words, duration_s, min_gap=1.0)` mide huecos entre palabras consecutivas: `pausas_largas` cuenta los huecos mayores o iguales a `min_gap`, `segundos_en_pausas` los suma (2 decimales), `pausa_maxima_s` es el mayor hueco de todos (0.0 sin huecos) y `pausas_por_minuto` se redondea a 2 decimales. `rhythm_profile(words, duration_s, window_s=30.0)` cuenta palabras por ventana y las lleva a palabras por minuto; la última ventana parcial se escala por su duración real.

### `ensemble.py` (T14)

`EnsembleAnalyzer(providers, judge=None, min_ok=1)` y `analyze(system, user, objective_data="", transcript=None, verify=True) -> dict`. Devuelve las claves `modelos_usados`, `modelos_fallidos`, `puntajes`, `sintesis`, `evidencias`, `verificacion`, `por_modelo`. Cada analista se reintenta una vez si el JSON es inválido; se ejecutan en paralelo; el orden de `modelos_usados` sigue el orden de los proveedores; con menos de `min_ok` respuestas se lanza `RuntimeError` (`AllProvidersFailedError` es subclase). Con `verify=True` y `transcript`, las evidencias de cada modelo se verifican y se descartan las no verificadas antes de calcular `evidencias` (deduplicadas por cita normalizada) y `verificacion = {"tasa", "descartadas"}`. El juez solo se llama con 2 o más resultados; si falla, unión simple. El prompt del juez es `JUDGE_SYSTEM`.

### `analyze_presentation.py` (T14)

`AnalyzePresentation(transcriber, ensemble, *, max_chars=12000, embedder=None, event_classifier=None, verify=True).execute(audio_path) -> dict`. Orden: transcribir; si no hay texto, `InvalidAudioError("No se detectó voz en el audio")`; muletillas; ritmo y pausas (por palabras si existen, si no por segmentos); coherencia (opcional, con `try/except` y advertencia); eventos acústicos y fusión (opcional, con `try/except` y advertencia); `select_window`; línea de datos objetivos; ensamble; resultado con las claves del contrato HTTP (`context/07-api-contract.md`), sin `id` ni `creado_en`.

## Infraestructura de ML

> Los contratos de `dataset.py`, `features.py`, `event_model.py`, `postprocess.py` y `event_classifier.py` (T10, T11) están aplazados: fuera del MVP, mejora futura (D-11). Se conservan para retomarlos; sus pruebas están excluidas de la recolección en `tests/ml/conftest.py`.

### `dataset.py` (T10)

Ver docstring de `tests/ml/test_dataset.py`. `parse_audacity_labels` lee líneas `inicio<TAB>fin<TAB>etiqueta` (ignora líneas vacías y las que empiezan con `\`, que Audacity usa para el rango de frecuencias; pasa la etiqueta a minúsculas; lanza `ValueError` con el número de línea si faltan columnas, la etiqueta no está en `EVENT_LABELS` o el fin no es mayor que el inicio). `windows_from_labels` genera solo ventanas completas dentro de la duración (`start + win_s <= duration_s`); el tiempo sin etiqueta cuenta como `default_label`; cada ventana toma la etiqueta con mayor traslape y se descarta si esa etiqueta cubre menos de `min_overlap` de la ventana; `win_s` o `hop_s` no positivos lanzan `ValueError`. `leave_one_speaker_out(speakers)` devuelve, por cada hablante único en orden alfabético, `(índices_entrenamiento, índices_prueba, hablante)` y lanza `ValueError` con menos de 2 hablantes.

### `features.py` (T10)

`FEATURE_DIM: int`; `extract_features(samples, sr=16000) -> np.ndarray` de forma `(FEATURE_DIM,)`, finito y determinista, también con silencio digital o ventanas muy cortas; `frame_signal(samples, sr, win_s, hop_s)` devuelve `(inicio, fin, ventana)` con ventanas que empiezan en `k*hop_s`, conservando solo las que tienen al menos la mitad de audio real y rellenando con ceros la última.

### `event_model.py` (T10)

`train_event_model(X, y, seed=42, n_estimators=200) -> EventModel`. `EventModel.classes_` (ordenadas), `predict(X) -> list[(etiqueta, confianza)]` con confianza igual a la probabilidad máxima, `save(path)`, `load(path)` (clase método; `FileNotFoundError` si no existe). Una sola clase en `y` lanza `ValueError`.

### `postprocess.py` y `event_classifier.py` (T11)

Ver docstrings de las pruebas. `SklearnEventClassifier(model, *, win_s=0.5, min_duration_s=0.0, max_gap_s=0.05, loader=None).classify(audio_path)`. `scripts/train_event_model.py` argumentos: `--data DIR` (pares `nombre.wav` + `nombre.txt` de etiquetas; el hablante es el prefijo antes del primer `-` del nombre), `--out RUTA` (por defecto `models/event_classifier.joblib`), `--win 0.5 --hop 0.25`. Imprime el informe leave-one-speaker-out (precisión, recall, F1 por clase y matriz de confusión) y guarda el modelo final entrenado con todos los datos.

## Configuración

### `settings.py` y `container.py` (T14)

Variables y valores por defecto: `context/05-llm-and-groq.md`, sección Variables de entorno. Reglas de `llm_provider_specs()`: un proveedor por cada modelo de `GROQ_MODEL` si hay clave; nombre `groq` si hay un solo modelo, `groq:<modelo>` si hay varios; igual para Gemini; `ollama` si `OLLAMA_MODEL`. Endpoints en `ENDPOINTS`. Contenedor: ver docstring de `tests/unit/test_container.py` y `context/02-architecture.md`. Modelos estrictos solo para proveedores `groq` cuyo modelo contiene `gpt-oss` o `qwen`.

## Presentación

### `app.py` y `routes/analysis.py` (T15)

`create_app(container) -> FastAPI`: título "TALKY", CORS con `settings.cors_origins`, router de análisis, `GET /health`. `main.py` expone `app = create_app(build_container(Settings.from_env()))` sin ejecutar nada pesado al importar más allá de eso, cargando `.env` con `python-dotenv` solo si está instalado. Mapeo de errores en `context/07-api-contract.md`. El archivo se escribe a un temporal por bloques de 1 MB contando bytes (413 si pasa del límite) y siempre se borra en `finally`.

## Dobles de prueba

`tests/fakes.py` y `tests/conftest.py` son parte del contrato: no se modifican para que una implementación pase. Si hace falta un doble nuevo, se crea en `tests/extra_fakes.py` sin alterar los existentes.
