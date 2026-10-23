# Regla: estilo de Python

- Python 3.11 o superior. Anotaciones de tipo en toda firma pública, con sintaxis moderna (`list[str]`, `X | None`).
- `ruff check` y `ruff format` sin diferencias. Configuración en `ruff.toml` (línea de 120 caracteres).
- Nombres: `snake_case` para funciones y variables, `PascalCase` para clases, `UPPER_SNAKE` para constantes. Las claves del resultado JSON siguen el español ya definido (`muletillas`, `puntajes`, `sintesis`).
- Funciones cortas y con una responsabilidad. Si necesitas un comentario para explicar un bloque, extráelo a una función con buen nombre.
- Comentarios solo para el porqué, no para el qué. Docstring de una línea en módulos y clases públicas; los contratos largos viven en `harness/context/10-module-contracts.md`.
- Dataclasses para datos simples (`frozen=True` cuando no deban mutar); pydantic para validar entradas externas y el resultado del LLM.
- Excepciones: usa las de `src/domain/exceptions`. No uses `except:` desnudo; `except Exception` solo en los límites de etapas opcionales y con `# noqa: BLE001`.
- Registro con `logging.getLogger("talky.<modulo>")`. Nunca registres transcripciones, audios, claves ni identificadores de usuario completos.
- Rutas con `pathlib` en código nuevo; `os.path` aceptable en código existente que ya lo usa.
- Sin código muerto, sin `TODO` sin tarea asociada, sin imports sin usar.
- Texto visible al usuario (mensajes de error, advertencias): español claro, sin jerga técnica ni trazas.
- Importaciones perezosas para librerías pesadas (`librosa`, `sentence_transformers`, `faster_whisper`, `joblib` si se usa en caliente) dentro de la función o del `__init__` del adaptador.
- Determinismo: todo lo aleatorio recibe `seed`/`random_state` explícito.
