# 07 - Contrato de la API v1

Servidor: FastAPI. `create_app(container)` en `src/presentation/app.py`. Documentación automática en `/docs`. Las pruebas del contrato están en `tests/api/test_routes.py` y `tests/e2e/test_pipeline_fake.py`.

## Identidad

La variable `AUTH_MODE` elige el modo (D-06, D-12). Las rutas de `/analyses` usan uno u otro, nunca los dos.

### Modo `jwt` (el que usa la app)

1. En el primer arranque, la app pide `POST /auth/token` (sin cuerpo). Respuesta 201: `{"access_token": "...", "token_type": "bearer", "expires_in": 2592000}`. El servidor genera el identificador del usuario (`talky-` + 32 hexadecimales) y lo firma dentro del token (HS256, claims `sub`, `iat`, `exp`, `iss="talky"`).
2. Cada petición a `/analyses` lleva `Authorization: Bearer <token>`. `X-User-Id` se ignora.
3. `POST /auth/refresh` con un Bearer válido devuelve 200 con un token nuevo del mismo usuario. La app renueva cuando faltan menos de 7 días.
4. Sin token, con token alterado, firmado con otro secreto o vencido: 401 con `WWW-Authenticate: Bearer`.

Es una sesión anónima por dispositivo, no una cuenta: quien tenga el token es el usuario, y si el token se pierde o vence sin renovarse, el historial anterior deja de ser accesible. No hay registro con contraseña.

### Modo `header` (por defecto; desarrollo y pruebas de contrato)

Cada petición (menos `/health`) lleva la cabecera `X-User-Id`, que debe cumplir `^[A-Za-z0-9_.@-]{1,64}$`. Es identidad declarada, no autenticación: cualquiera que conozca el identificador de otro puede leer sus análisis. Las rutas `/auth/*` no existen en este modo.

## Endpoints

| Método | Ruta | Descripción | Respuesta |
|---|---|---|---|
| GET | `/health` | Estado del servicio | 200 `{"status": "ok", ...}` |
| POST | `/auth/token` | Crea una sesión de dispositivo (solo modo `jwt`) | 201 `{access_token, token_type, expires_in}` |
| POST | `/auth/refresh` | Renueva el token actual (solo modo `jwt`) | 200 `{access_token, token_type, expires_in}` o 401 |
| POST | `/analyses` | Sube un audio y devuelve el análisis | 201 con el análisis completo |
| GET | `/analyses?limit=20&offset=0` | Lista del usuario, más recientes primero | 200 `{items, total, limit, offset}` |
| GET | `/analyses/{id}` | Análisis guardado | 200 o 404 |
| DELETE | `/analyses/{id}` | Borra un análisis | 204 o 404 |

`POST /analyses`: `multipart/form-data` con el campo `file`. Extensiones admitidas: `.mp3 .wav .m4a .ogg .flac .webm`. `limit` entre 1 y 100.

## Errores

| Código | Cuándo | Cuerpo |
|---|---|---|
| 400 | Extensión no admitida o `X-User-Id` con formato inválido (modo `header`) | `{"detail": "..."}` en español |
| 401 | Falta `X-User-Id` (modo `header`); falta el token o es inválido o está vencido (modo `jwt`) | idem |
| 404 | Análisis inexistente o de otro usuario | idem |
| 413 | Archivo mayor que `MAX_UPLOAD_MB` (se corta durante la lectura) | idem |
| 422 | Audio ilegible, sin voz, demasiado corto o demasiado largo | idem |
| 503 | Ningún proveedor respondió (transcripción o LLM insuficientes) | idem |

Un análisis de otro usuario devuelve 404, no 403, para no revelar su existencia.

## Respuesta de `POST /analyses` y `GET /analyses/{id}`

```json
{
  "id": "6f1c...",
  "creado_en": "2026-10-23T15:04:05.123456Z",
  "duracion_s": 312.4,
  "ppm": 128.5,
  "ritmo": [131.0, 120.0, 140.0],
  "pausas": {"pausas_largas": 4, "segundos_en_pausas": 9.6, "pausa_maxima_s": 3.1, "pausas_por_minuto": 0.8},
  "muletillas": {"eh": 7, "o sea": 4, "entonces": 2},
  "muletillas_por_minuto": 2.5,
  "transcripcion_recortada": false,
  "coherencia": {
    "windows": 12, "mean_adjacent_similarity": 0.52,
    "topic_jumps": [4],
    "repeated_pairs": [{"a": 2, "b": 9, "similarity": 0.88}]
  },
  "eventos_acusticos": {
    "muletillas": [{"start": 12.3, "end": 12.8, "texto": "eh", "source": "both", "confianza": "alta"}],
    "tarareos": [{"start": 40.1, "end": 41.0, "confidence": 0.82}]
  },
  "advertencias": [],
  "modelos_usados": ["groq:openai/gpt-oss-20b", "groq:openai/gpt-oss-120b"],
  "modelos_fallidos": {},
  "puntajes": {
    "organizacion": {"mediana": 7, "min": 6, "max": 8, "desacuerdo": false},
    "claridad": {"mediana": 6, "min": 5, "max": 7, "desacuerdo": false},
    "repeticion": {"mediana": 5, "min": 3, "max": 7, "desacuerdo": true}
  },
  "sintesis": {"resumen": "...", "fortalezas": [], "aspectos_por_mejorar": [], "recomendaciones": []},
  "evidencias": [{"afirmacion": "...", "cita": "...", "verificada": true}],
  "verificacion": {"tasa": 0.83, "descartadas": 2},
  "por_modelo": {"groq:openai/gpt-oss-20b": {"organizacion": {"puntaje": 7, "comentario": "..."}}}
}
```

Reglas:

- `coherencia` y `eventos_acusticos` son `null` cuando la etapa está apagada o falló (con explicación en `advertencias`).
- `coherencia.topic_jumps` es la lista de índices `i` tales que hay un salto de tema entre la ventana `i` y la `i+1`. `repeated_pairs` lista pares de ventanas `a`, `b` con su similitud. La forma exacta la fija `CoherenceReport.to_dict()` (ver `tests/unit/test_coherence.py`).
- `verificacion` es `null` si el verificador está apagado; `tasa` es `null` si no hubo evidencias.
- `ritmo` es una lista de palabras por minuto por ventana de 30 s.
- Las claves en español se mantienen por compatibilidad con la primera versión de la API.

## Lista

```json
{"items": [{"id": "...", "filename": "ensayo1.m4a", "created_at": "...", "duracion_s": 312.4, "ppm": 128.5, "total_muletillas": 13}],
 "total": 7, "limit": 20, "offset": 0}
```

Los nombres de `items` salen del dataclass `AnalysisSummary` convertido con `dataclasses.asdict`.

## CORS

`CORS_ORIGINS` (por defecto `*`) permite al cliente web o móvil en desarrollo. En producción se restringe.
