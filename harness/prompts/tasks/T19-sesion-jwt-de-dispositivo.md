---
id: T19
title: Sesión con JWT de dispositivo
status: done
phase: 3-integracion
depends_on: [T15]
requirements: [RNF-01]
estimate: 3h
tests: [tests/unit/test_jwt_tokens.py, tests/unit/test_auth_settings.py, tests/api/test_auth_routes.py]
touches: [src/domain/interfaces/ports.py, src/domain/exceptions/__init__.py, src/infrastructure/security/jwt_tokens.py, src/presentation/routes/auth.py, src/presentation/routes/analysis.py, src/presentation/app.py, src/config/settings.py, src/config/container.py, requirements.txt, harness/templates/env.example]
---
# T19 - Sesión con JWT de dispositivo

## Objetivo

Reemplazar en la app la identidad declarada (`X-User-Id`, D-06) por un token firmado por el servidor: el servidor genera el identificador del usuario y lo entrega dentro de un JWT; el cliente ya no puede elegir ni suplantar un identificador.

## Contexto

Hoy cualquiera que conozca el identificador de otro puede leer su historial (limitación declarada en D-06 y en `07-api-contract.md`). Registro con contraseña sigue fuera del MVP; esto es una sesión anónima por dispositivo. Decisión tomada el 2026-10-25: se registra como D-12 en `harness/context/12-decisions.md`.

Las pruebas de contrato de T15 (`tests/api/`, `tests/e2e/`) y el doble `post_audio` de `tests/fakes.py` usan `X-User-Id` y no se modifican. Por eso el modo de identidad es configurable y el modo por cabecera sigue siendo el valor por defecto.

## Alcance

1. Dominio: puerto `TokenService` en `ports.py` (`issue(subject: str) -> IssuedToken`, `verify(token: str) -> str` que devuelve el sujeto) y excepción `InvalidTokenError(TalkyError)`.
2. Infraestructura: `src/infrastructure/security/jwt_tokens.py` con `JwtTokenService(secret, ttl_s, clock=time.time)` sobre PyJWT. HS256 fijo (`algorithms=["HS256"]` al verificar), claims `sub`, `iat`, `exp`, `iss="talky"`; el `sub` se valida con el mismo patrón de `X-User-Id`.
3. Configuración: `AUTH_MODE` (`header` por defecto o `jwt`), `JWT_SECRET` (obligatorio y de al menos 32 caracteres en modo `jwt`; si no, `ConfigurationError`), `JWT_TTL_DAYS` (30). Solo `Settings.from_env` lee el entorno; solo el contenedor construye `JwtTokenService`.
4. Presentación:
   - `routes/auth.py`: `POST /auth/token` (201, genera el sujeto `talky-` + UUID v4 en hexadecimal) y `POST /auth/refresh` (requiere un Bearer válido y devuelve uno nuevo con el mismo sujeto). Respuesta: `{"access_token", "token_type": "bearer", "expires_in"}`. Solo se registran en modo `jwt`.
   - `routes/analysis.py`: la dependencia de identidad elige según el modo. En `jwt`, sin `Authorization` devuelve 401 con `WWW-Authenticate: Bearer`; token inválido o vencido, 401 "Tu sesión no es válida o venció. Vuelve a abrir la app."; `X-User-Id` se ignora. En `header`, todo sigue igual que en T15.
5. `requirements.txt`: `PyJWT>=2.8` (justificado en el commit: firmar y verificar JWT sin implementar criptografía propia).
6. Documentación: D-12, sección de identidad de `07-api-contract.md`, `02-architecture.md`, `security-privacy.md`, `.env.example` (variables vacías) y trazabilidad de RNF-01 en `01-requirements.md`.

No hacer: contraseñas, usuarios en la base de datos, listas de revocación, migrar historiales antiguos de `X-User-Id`.

## Contrato

- `presentation` no importa PyJWT: recibe el `TokenService` del contenedor.
- El secreto nunca se registra ni se devuelve; los logs solo dicen el tipo de error del token.
- Los tokens no viajan en la URL, solo en la cabecera `Authorization`.
- Limitación declarada: quien tenga el token es el usuario; perder la app o el token es perder el acceso a ese historial.

## Criterios de aceptación

1. Con la configuración por defecto, la suite actual sigue en verde sin tocar `tests/`.
2. En modo `jwt`: pedir token, analizar, listar y borrar con Bearer funciona; sin token o con token vencido, alterado, firmado con otro secreto o con `alg: none` responde 401.
3. Un usuario no ve los análisis de otro aunque envíe su `X-User-Id`.
4. `uvicorn main:app` con `AUTH_MODE=jwt` y sin `JWT_SECRET` falla al arrancar con un mensaje claro.

## Pruebas

Se escriben primero y se declaran en `tests:` de esta tarea (con su copia en `harness/tests/`):

- `tests/unit/test_jwt_tokens.py`: emitir y verificar; vencido con reloj inyectado; firma alterada; otro secreto; `alg: none`; sujeto inválido.
- `tests/unit/test_auth_settings.py`: valores por defecto, modo `jwt` sin secreto o con secreto corto.
- `tests/api/test_auth_routes.py`: `POST /auth/token`, `POST /auth/refresh`, rutas de análisis con y sin Bearer, aislamiento entre usuarios, rutas de sesión ausentes en modo `header`. Los dobles nuevos van en `tests/extra_fakes.py`.

```bash
python -m pytest tests/unit/test_jwt_tokens.py tests/unit/test_auth_settings.py tests/api/test_auth_routes.py -q
```

## Definición de hecho

- [ ] Verificación de la tarea: las pruebas de arriba en verde.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T19 done`.
- [ ] Commit(s) convencional(es) `tipo(T19): descripción`.
