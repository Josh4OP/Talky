# Regla: arquitectura

Contexto completo en `harness/context/02-architecture.md`. Esto es lo que debes cumplir al escribir código.

## Dependencias entre capas

| Capa | Puede importar | No puede importar |
|---|---|---|
| `domain` | librería estándar, pydantic | cualquier otra capa, librerías de I/O |
| `application` | `domain`, librería estándar, numpy si es imprescindible | `infrastructure`, `presentation`, `config`, `fastapi`, `openai`, `sklearn`, `librosa`, `av`, `sqlite3`, `faster_whisper`, `sentence_transformers` |
| `infrastructure` | `domain`, librerías externas, y el tipo de datos `AudioInfo` de `application/routing/input_router.py` | `presentation`, `config`, cualquier otro módulo de `application` |
| `presentation` | `application`, `domain` | `infrastructure` (recibe todo ya armado desde `config`) |
| `config` | todas | - |

Comprobación rápida:

```bash
grep -rnE "^(from|import) (fastapi|openai|sklearn|librosa|av|faster_whisper|sqlite3|sentence_transformers)" src/domain src/application
grep -rn "src.infrastructure" src/domain src/application src/presentation
```

Ambos comandos deben salir vacíos.

## Puertos y adaptadores

- Un puerto nuevo se declara en `src/domain/interfaces/ports.py` como `ABC` con métodos abstractos.
- Los servicios reciben puertos por constructor; nunca crean adaptadores ni leen variables de entorno.
- Los adaptadores aceptan el cliente o el modelo por inyección (parámetro `client=`, `loader=`) para poder probarlos con dobles.

## Servicios puros

Los módulos de `application/services/` son funciones y clases sin I/O: reciben datos y devuelven datos. Si necesitas leer un archivo o llamar a una red, eso es infraestructura.

## Degradación elegante

Toda etapa opcional del caso de uso se envuelve en `try/except Exception`, registra con `logging` (sin contenido de usuario) y agrega un texto útil a `advertencias`. Los errores del usuario (audio inválido) y de configuración son excepciones del dominio, no advertencias.

## Dónde va cada cosa

| Si necesitas... | Va en... |
|---|---|
| Una regla de negocio sin I/O | `application/services/` |
| Elegir entre alternativas con reglas | `application/routing/` |
| Hablar con un servicio externo | `infrastructure/external/` |
| Modelos de ML y datos | `infrastructure/ml/` |
| Persistencia | `infrastructure/repositories/` |
| Validar HTTP y mapear errores | `presentation/routes/` |
| Leer entorno y ensamblar | `config/` |

## Prohibido

Estado global mutable, singletons por importación, lógica en `__init__.py`, imports circulares, variables de entorno leídas fuera de `Settings.from_env`, `print` en código de la aplicación (usa `logging`).
