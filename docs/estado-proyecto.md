# Estado del proyecto TALKY

Última actualización: viernes 23 de octubre de 2026, al cierre de la sesión. Entrega del MVP: lunes 26 de octubre de 2026.

## Resumen

- Backend completo: la suite de aceptación está en verde (426 pruebas, sin fallos ni errores de recolección), `ruff` limpio y `check_harness.py` consistente.
- Tareas hechas y fusionadas en `main`: T01 a T09, T12, T13, T14 y T15.
- Aplazadas fuera del MVP (decisión D-11 en `harness/context/12-decisions.md`): T10 y T11, el clasificador acústico. Quedan en estado `blocked`; sus pruebas están excluidas en `tests/ml/conftest.py`.
- Pendientes: T16 (app Flutter, 8 h), T17 (evaluación sin clasificador, 5 h), T18 (documentación y demo, 5 h; el Dockerfile se puede omitir porque la demo corre en un PC).

## Pendiente inmediato (en este orden)

1. **Commit de este archivo** (`docs/estado-proyecto.md`) en una rama `docs/estado-proyecto`, de tipo `docs`.
2. **Restaurar lo que faltó en el commit de T12.** El commit `f7613c8` solo incluyó `event_fusion.py` y `filler_detector.py`. Faltan, en una rama `fix/T12-restaura-pruebas`:
   - `harness/prompts/tasks/T12-fusion-de-muletillas.md`: `status: done`, `tests:` con `tests/unit/test_event_fusion_rules.py` y `touches:` con `src/application/services/filler_detector.py`. Hoy `tasks.py next` la muestra como pendiente por esto.
   - `tests/unit/test_event_fusion_rules.py` y su copia en `harness/tests/unit/` (13 pruebas: emparejamiento por cercanía, texto `[acustico]`, confianza en el mínimo, orden de tatareos, `to_dict`, `vocal_filler_key`). Se perdieron al borrar el worktree; hay que reescribirlas.
3. **Probar en Swagger** con una grabación real: `uvicorn main:app --reload`, abrir `http://127.0.0.1:8000/docs`, `POST /analyses` con cabecera `X-User-Id` (por ejemplo `demo`). Requiere `GROQ_API_KEY` y `GROQ_MODEL` en `.env`.
4. Seguir con **T16** (Flutter) y **T17** (grabar clips con transcripción de referencia y medir).

## Decisiones tomadas en esta sesión

- Los títulos de commit van en inglés; el último commit de cada tarea lo hace una persona después de revisar el diff.
- La demo corre en un PC del equipo (`uvicorn main:app --host 0.0.0.0`) y el celular se conecta por la misma red. Render gratuito no sirve: 512 MB no alcanzan para el respaldo local ni los embeddings y su disco borra el historial SQLite.
- "Transcripción local" significa en el servidor, nunca en el celular. La app Flutter es un cliente delgado; el historial vive en `talky.db` del servidor y el celular solo guarda su identificador.
- El clasificador acústico es mejora futura (D-11). Se conservan el puerto `EventClassifier`, la fusión (T12) y la bandera `ENABLE_EVENT_CLASSIFIER` apagada.
- `ruff` trata `src` como paquete propio (`known-first-party`) para que el orden de imports no cambie con cada módulo nuevo.
- Las pruebas nuevas de cada tarea van en `tests/` y en `harness/tests/` (el validador del arnés busca en la segunda), y se declaran en el campo `tests:` de la tarea.

## Riesgos y recomendaciones abiertos

1. Un audio que siga pasando de 25 MB después de comprimirse (exposiciones de más de unos 25 minutos) recibe 413 de Groq y no cae al respaldo local. Arreglarlo implica cambiar `RoutedTranscriber` (T07).
2. `rhythm_profile` deja una última ventana muy corta con 0 ppm si el audio termina con silencio (por ejemplo `[104.0, 0.0]` para 30,9 s). Conviene tenerlo en cuenta en el gráfico de la app.
3. Starlette recibe la subida completa antes de que la ruta aplique el límite de tamaño; para cortarla antes haría falta un middleware que revise `Content-Length`.
4. No se probó el modo estricto de Groq con una llamada real: si rechaza `default` o `minimum` del esquema, el adaptador degrada a `json_object` pero gasta una petición extra por análisis.
5. En este entorno no están instalados `faster-whisper` ni `sentence-transformers`. Para la demo con respaldo local: `pip install -r requirements-local.txt`; para coherencia: `requirements-embeddings.txt` y `ENABLE_TEXT_EMBEDDINGS=true`.
6. El verificador de citas tarda unos 2 s en el peor caso (30 citas inventadas sobre 2000 palabras); revisar en T17 con exposiciones largas.

## Cómo retomar

Abrir una sesión con el prompt de `harness/prompts/sessions/01-resume.md`, leer este archivo y continuar desde "Pendiente inmediato".
