# 05 - LLM, Groq y prompts

Los datos de límites provienen de la documentación de Groq consultada para este proyecto. Los planes gratuitos cambian: antes de depender de un número, verifica en https://console.groq.com/docs/rate-limits.

## Uso de modelos

| Rol | Modelo recomendado | Proveedor | Notas |
|---|---|---|---|
| Transcripción | `whisper-large-v3` | Groq | Verbose JSON con marcas por palabra y por segmento |
| Transcripción de respaldo | `small` (faster-whisper) | Local, CPU | Más lento; se carga una sola vez |
| Analistas (2 o 3 en paralelo) | `openai/gpt-oss-20b`, `openai/gpt-oss-120b`, `qwen/qwen3-32b` o el Qwen vigente en la consola | Groq | Salida JSON estricta |
| Juez | El analista más capaz (por ejemplo gpt-oss-120b) o Gemini | Groq o Gemini | Instancia separada con su propio esquema |
| Respaldo opcional | Ollama local | Local | Solo si el equipo tiene máquina para ello |

Los identificadores exactos de modelo los define el equipo en `.env` (`GROQ_MODEL` acepta varios separados por coma). El código no los fija.

## Límites gratuitos relevantes (verificar vigencia)

| Modelo | Solicitudes por minuto | Solicitudes por día | Tokens por minuto | Tokens por día |
|---|---|---|---|---|
| gpt-oss-120b, gpt-oss-20b, Qwen (preview) | 30 | 1 000 | 8 000 | 200 000 |
| whisper-large-v3 | 20 | 2 000 | - | 7 200 s de audio por hora, 28 800 s por día |

Consecuencias para el diseño:

- Una exposición de 5 minutos son 300 s de audio. Con 28 800 s diarios caben unos 96 análisis completos por día entre todo el equipo. Suficiente para desarrollo y demo.
- Cada llamada a Whisper se cobra mínimo 10 s.
- 8 000 tokens por minuto limitan transcripciones largas. Por eso existe `select_window` (conserva inicio y final) y `MAX_TRANSCRIPT_CHARS=12000` por defecto. Con tres analistas en paralelo, cada uno consume tokens de su propio modelo, no del mismo contador.
- Carga gratuita de archivos: 25 MB. Para archivos mayores se comprime a 16 kHz mono antes de subir.
- Un 429 debe llegar rápido al enrutador: el cliente OpenAI se crea con `max_retries=1` para Whisper y el adaptador LLM traduce el 429 a `RateLimitedError` (con `retry_after`).

## Salida estructurada

Groq soporta JSON Schema estricto en algunos modelos (gpt-oss y Qwen en la documentación consultada). Reglas del modo estricto:

- Todo objeto lleva `additionalProperties: false`.
- Todas las propiedades están en `required`.
- No hay `$ref` sin resolver en la raíz.

`strict_json_schema(Modelo)` genera un esquema que cumple estas reglas a partir de un modelo pydantic. `OpenAICompatibleLLM` pide `response_format={"type":"json_schema","json_schema":{"name":...,"strict":true,"schema":...}}`; si el servidor responde 400, reintenta con `{"type":"json_object"}` y, ante un nuevo 400, sin `response_format`. El analizador JSON del ensamble tolera cercas de código y texto alrededor del JSON.

Dos esquemas distintos (analista y juez) significan dos instancias del adaptador por cada proveedor. El contenedor las construye por separado.

## Cómo se arma el mensaje al analista

`build_user_message(objective, transcript, truncated)`:

```
{objetivo}

Transcripción:
{transcripción o ventana}

[Transcripción recortada por longitud: se conservan el inicio y el final]   <- solo si se recortó
```

`objetivo` es una línea con datos medidos: duración, palabras por minuto, pausas largas, muletillas, y si hay embeddings, saltos de tema e ideas repetidas. El prompt le exige tratar esos datos como verdad.

## Prompts

Viven en código (`src/application/prompts.py`) y tienen copia de referencia en `prompts/llm/`. Reglas en `agent/rules/llm-prompting.md`. Resumen de contrato:

- Analista: JSON con `organizacion`, `claridad`, `repeticion` (con `palabras_repetidas`), `fortalezas`, `aspectos_por_mejorar`, `recomendaciones` y `evidencias`. Cada evidencia es `{afirmacion, cita}` con la cita copiada literalmente (4 a 25 palabras). No inventar.
- Juez: empieza con "Eres un editor". Recibe análisis independientes y datos objetivos; produce `{resumen, fortalezas, aspectos_por_mejorar, recomendaciones}` con máximo 5 elementos por lista y solo afirmaciones con evidencia.
- Prompt de Whisper para sesgar a escribir muletillas: "Eh, bueno, o sea, mmm, este... digamos que, como que, ¿no? Entonces, eh..." (el límite de Groq es 224 tokens).

## Variables de entorno

| Variable | Por defecto | Descripción |
|---|---|---|
| `GROQ_API_KEY` | vacío | Clave de Groq (habilita transcripción y LLM en Groq) |
| `GROQ_MODEL` | vacío | Uno o varios modelos separados por coma |
| `GEMINI_API_KEY`, `GEMINI_MODEL` | vacío | Opcional; endpoint OpenAI-compatible de Google |
| `OLLAMA_MODEL` | vacío | Opcional; modelo local |
| `JUDGE_PROVIDER` | `gemini` | Nombre del proveedor juez (`groq`, `gemini`, `ollama` o `groq:modelo`); si no existe se usa el primero |
| `MIN_MODELS_OK` | `1` | Analistas mínimos que deben responder |
| `TRANSCRIBER` | `auto` | `auto`, `groq` o `local` |
| `WHISPER_MODEL` | `small` | Tamaño de faster-whisper local |
| `GROQ_WHISPER_MODEL` | `whisper-large-v3` | Modelo Whisper en Groq |
| `MAX_TRANSCRIPT_CHARS` | `12000` | Tope de caracteres enviados al LLM |
| `DB_PATH` | `talky.db` | Archivo SQLite |
| `MAX_UPLOAD_MB` | `100` | Tamaño máximo de subida |
| `MAX_DURATION_S` | `2700` | Duración máxima (45 min) |
| `MIN_DURATION_S` | `5` | Duración mínima |
| `ENABLE_EVENT_CLASSIFIER` | `false` | Activa el clasificador acústico |
| `EVENT_MODEL_PATH` | `models/event_classifier.joblib` | Ruta del modelo |
| `ENABLE_TEXT_EMBEDDINGS` | `false` | Activa la coherencia con embeddings |
| `EMBEDDING_MODEL` | `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` | Modelo de embeddings |
| `ENABLE_VERIFIER` | `true` | Activa el verificador de citas |
| `CORS_ORIGINS` | `*` | Orígenes permitidos, separados por coma |
| `AUTH_MODE` | `header` | `header` (identidad con `X-User-Id`) o `jwt` (token de dispositivo, T19) |
| `JWT_SECRET` | vacío | Secreto para firmar los tokens; obligatorio y de al menos 32 caracteres con `AUTH_MODE=jwt` |
| `JWT_TTL_DAYS` | `30` | Días de vida de cada token |

`Settings.from_env` valida los valores (booleanos, números, `TRANSCRIBER`) y falla con `ValueError` claro.

## Privacidad con proveedores externos

El audio y la transcripción salen a Groq (y a Gemini si se configura). Groq ofrece una opción de retención cero de datos en la configuración de la organización; es una afirmación del proveedor que el equipo no ha verificado. El README y la pantalla de inicio de la app deben decir que el audio se envía a un tercero para transcribirse y que TALKY no lo guarda.
