# Definición de hecho

Una tarea se marca `done` solo si todo lo aplicable está marcado. El agente la recorre con `/verify` y `/review`; una persona la confirma al revisar el pull request.

## Código

- [ ] Las pruebas del campo `tests:` de la tarea pasan.
- [ ] La suite completa (`python -m pytest -q`) pasa sin regresiones.
- [ ] `ruff check .` y `ruff format --check .` salen limpios.
- [ ] Las firmas públicas coinciden con `harness/context/10-module-contracts.md`.
- [ ] Anotaciones de tipo en toda firma pública.
- [ ] Sin código muerto, sin `print`, sin `TODO` sin tarea.
- [ ] Sin cambios fuera del alcance de la tarea (revisado con `git diff --stat`).

## Arquitectura

- [ ] `domain` y `application` no importan librerías de I/O (`fastapi`, `openai`, `sklearn`, `librosa`, `av`, `faster_whisper`, `sqlite3`, `sentence_transformers`).
- [ ] Ningún módulo fuera de `src/config/container.py` construye adaptadores.
- [ ] Las librerías pesadas se importan de forma perezosa.
- [ ] Las etapas opcionales no pueden tumbar el análisis y reportan en `advertencias`.

## Privacidad y seguridad

- [ ] No se guarda audio ni transcripción completa; los temporales se borran en `finally`.
- [ ] Ningún log incluye texto de usuarios, citas ni identificadores completos.
- [ ] Toda consulta al repositorio filtra por `user_id` y usa parámetros.
- [ ] No hay claves, `.env`, audios, bases de datos ni modelos entrenados en el commit.

## Pruebas

- [ ] Las pruebas de aceptación no se debilitaron (`git diff -- tests/` solo muestra archivos nuevos o ampliaciones justificadas).
- [ ] Las pruebas nuevas son deterministas y no usan red ni modelos.
- [ ] Todo archivo `test_*.py` nuevo está declarado en alguna tarea.

## Documentación y proceso

- [ ] Si cambió un contrato público, se actualizó `harness/context/10-module-contracts.md` (y `07-api-contract.md` si afecta la API).
- [ ] `python harness/tools/check_harness.py` imprime "Harness consistente.".
- [ ] Commit(s) con mensaje convencional `tipo(Txx): descripción`.
- [ ] Estado de la tarea actualizado con `python harness/tools/tasks.py status Txx done`.

## Hitos del MVP

- [ ] Hito de backend (tras T15): toda la suite de aceptación de `tests/` en verde.
- [ ] Hito de cliente (tras T16): flujo completo desde la app contra la API local.
- [ ] Hito de calidad (tras T17): `docs/evaluacion.md` con números reales.
- [ ] Entrega (tras T18): `checklists/demo-monday.md` completo.
