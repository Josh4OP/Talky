# TALKY - Asistente Inteligente para Presentaciones Orales

> Proyecto del curso **Ingeniería de Software** (NRC 1206), periodo 2026-20, Universidad Tecnológica de Bolívar (UTB).

## 1. Descripción del proyecto

Muchos universitarios no saben cómo desenvolverse en público: usan muletillas, leen las diapositivas y, en el peor de los casos, dan la presentación revisando el celular. Esto transmite la impresión de no dominar el tema.

Ante esta problemática nace **TALKY**, un asistente que escucha una exposición oral grabada y devuelve retroalimentación útil: muletillas, tatareos, pausas, ritmo, organización, claridad y repetición de ideas, junto con fortalezas, aspectos por mejorar y recomendaciones.

Cómo funciona, en resumen: la app (Flutter) sube un archivo de audio a una API (FastAPI). La API lo valida, lo transcribe con Whisper (Groq, con respaldo local con faster-whisper), mide por código las muletillas, el ritmo y las pausas, y entrega esos datos a varios modelos de lenguaje que opinan en paralelo. Un verificador descarta las afirmaciones cuya cita no aparece en la transcripción y un juez sintetiza el resultado, que se guarda en un historial por usuario.

## 2. Problema que resuelve

- **Falta de desarrollo de habilidades orales:** a muchas personas se les dificulta exponer, hacer ponencias o presentaciones sin depender de leer las diapositivas o revisar el celular.
- **Origen escolar del problema:** desde el colegio no se corrige la lectura de carteleras durante las exposiciones, por lo que el hábito de no apropiarse del tema se arrastra hasta la universidad.
- **Escalamiento al entorno laboral:** si no se atiende a tiempo, el problema se traslada a entrevistas y contextos profesionales, donde las habilidades blandas, la retórica y el dominio del tema son fundamentales.

### 2.1 Usuarios y partes interesadas

- Estudiantes universitarios.
- Personas próximas a dar una presentación (ponencias, sustentaciones, entrevistas).
- Cualquier persona interesada en mejorar su retórica y habilidades de comunicación oral.
- Interesados indirectos: docentes.

## 3. Stack tecnológico

| Componente | Tecnología |
|---|---|
| App | Flutter |
| Backend / API | Python 3.11+, FastAPI, Uvicorn |
| Transcripción | Whisper `whisper-large-v3` en Groq; respaldo local con faster-whisper |
| Análisis con LLM | Modelos gratuitos de Groq (opcional: Gemini, Ollama) mediante la API compatible con OpenAI |
| Audio y ML | PyAV y sentence-transformers (opcional). El clasificador acústico (Random Forest con scikit-learn y librosa) queda como mejora futura, fuera del MVP |
| Base de datos | SQLite (historial por usuario) |
| Calidad | pytest, ruff, GitHub Actions |
| Metodología y arquitectura | Kanban y XP; arquitectura en capas con puertos y adaptadores |

## 4. Requisitos

- Python 3.11 o superior.
- Una clave de Groq (plan gratuito) para transcribir y analizar en la nube. Sin clave se puede transcribir en local instalando `requirements-local.txt`.
- Git. En Windows, los comandos de abajo funcionan en Git Bash; en PowerShell activa el entorno con `.venv\Scripts\Activate.ps1`.

## 5. Instalación

```bash
python -m venv .venv
source .venv/bin/activate          # Windows (Git Bash): source .venv/Scripts/activate
pip install -r requirements-dev.txt
```

Archivos de dependencias:

| Archivo | Contenido |
|---|---|
| `requirements.txt` | Núcleo de la API: FastAPI, Uvicorn, pydantic, openai, python-dotenv, numpy, PyAV |
| `requirements-ml.txt` | Clasificador de eventos acústicos (mejora futura): scikit-learn, librosa, joblib |
| `requirements-local.txt` | Respaldo de transcripción local: faster-whisper (descarga el modelo en el primer uso) |
| `requirements-embeddings.txt` | Coherencia temática: sentence-transformers (pesado, instala torch) |
| `requirements-dev.txt` | Núcleo y ML, más pytest, httpx y ruff |

## 6. Variables de entorno

Copia la plantilla y completa los valores. El archivo `.env` nunca se sube al repositorio.

```bash
cp .env.example .env
```

| Variable | Para qué sirve |
|---|---|
| `GROQ_API_KEY`, `GROQ_MODEL` | Clave de Groq y uno o varios modelos separados por coma |
| `GROQ_WHISPER_MODEL` | Modelo de transcripción en Groq (por defecto `whisper-large-v3`) |
| `GEMINI_API_KEY`, `GEMINI_MODEL`, `OLLAMA_MODEL` | Proveedores opcionales de LLM |
| `JUDGE_PROVIDER`, `MIN_MODELS_OK` | Quién sintetiza los análisis y cuántos modelos deben responder |
| `TRANSCRIBER`, `WHISPER_MODEL` | `auto`, `groq` o `local`, y tamaño del modelo local |
| `MAX_TRANSCRIPT_CHARS`, `MAX_UPLOAD_MB`, `MAX_DURATION_S`, `MIN_DURATION_S` | Límites de entrada |
| `ENABLE_VERIFIER`, `ENABLE_TEXT_EMBEDDINGS`, `EMBEDDING_MODEL` | Verificador de citas y coherencia con embeddings |
| `ENABLE_EVENT_CLASSIFIER`, `EVENT_MODEL_PATH` | Clasificador acústico y ruta del modelo; se deja en `false` en el MVP (mejora futura) |
| `DB_PATH`, `CORS_ORIGINS` | Base de datos del historial y orígenes permitidos |

El detalle y los valores por defecto están en `.env.example`.

## 7. Pruebas y estilo

```bash
python -m pytest -q                       # suite completa (sin red: usa dobles)
ruff check . && ruff format --check .     # estilo
python harness/tools/check_harness.py     # coherencia del arnés de desarrollo
```

Las pruebas de `tests/` son el contrato del proyecto y no se debilitan. La integración continua (`.github/workflows/ci.yml`) ejecuta lo mismo en cada push y pull request. Los scripts de `scripts/manual/` llaman a servicios reales y no forman parte de la suite.

## 8. Ejecutar el servidor

```bash
uvicorn main:app --reload
```

La API queda en `http://127.0.0.1:8000` y la documentación interactiva en `http://127.0.0.1:8000/docs`. `GET /health` indica qué modelos están activos.

Para producción, restringe `CORS_ORIGINS` a los orígenes de la app (nunca `*`) y sirve la API detrás de HTTPS.

## 8.1 Ejecutar la app Flutter

```bash
cd mobile
flutter pub get
flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

- `API_BASE_URL` cambia la dirección de la API sin tocar código. Por defecto es `http://10.0.2.2:8000`, que es el host visto desde el emulador de Android.
- Para un teléfono físico, usa la IP de tu equipo en la red local (por ejemplo `http://192.168.1.20:8000`).
- La app abre con una pantalla de bienvenida. Si el servidor no está corriendo, puedes activar el **modo demostración** en Perfil: los datos de ejemplo se marcan siempre como tales y nunca se mezclan con tu historial.
- Android ya declara `INTERNET` y `RECORD_AUDIO`; iOS declara `NSMicrophoneUsageDescription`. En la web el micrófono requiere HTTPS o `localhost`.
- Verificación: `flutter analyze` y `flutter test` (20 pruebas) desde `mobile/`.

## 9. Privacidad

- El audio de la exposición se envía a Groq para transcribirse, y la transcripción se envía a los proveedores de LLM configurados (Groq y, si se activa, Gemini). Si se usa el modo `local`, la transcripción se hace en tu equipo.
- TALKY no guarda el audio: se escribe en un archivo temporal, se procesa y se borra, también cuando hay error.
- La transcripción completa no se guarda; el historial conserva métricas, la síntesis y citas cortas.
- El historial se separa por el encabezado `X-User-Id`. Es una identidad declarada, no una autenticación.

## 10. Equipo

| Integrante | Contacto |
|---|---|
| Josh Ortega | joshortega@utb.edu.co |
| Luis Mendoza | luiangulo@utb.edu.co |
| Moises Cortina | mocortina@utb.edu.co |

> Los integrantes están añadidos como colaboradores del repositorio en GitHub.

## 11. Metodología y estado del proyecto

Trabajamos con Kanban y prácticas de XP: tareas pequeñas con contrato, pruebas primero e integración continua. Las tareas del MVP y su orden por dependencias están en `harness/prompts/tasks/` (`python harness/tools/tasks.py list`), y las decisiones de diseño en `harness/context/12-decisions.md`.

**Estado:** construcción del MVP, con entrega el lunes 26 de octubre de 2026. Este README describe el MVP terminado; mientras avanzan las tareas, la versión actual de la API transcribe solo en local y aún no tiene historial ni encabezado `X-User-Id` (llegan con T05 a T15).

---
*Curso de Ingeniería de Software - Universidad Tecnológica de Bolívar (UTB)*
