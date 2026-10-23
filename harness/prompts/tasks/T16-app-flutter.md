---
id: T16
title: Aplicación Flutter: subir, resultados e historial
status: todo
phase: 4-cliente-y-calidad
depends_on: [T15]
requirements: [RF-01, RF-02, RF-08, RF-11, RNF-02]
estimate: 8h
tests: [-]
touches: [mobile/]
---
# T16 - Aplicación Flutter: subir, resultados e historial

## Objetivo

Entregar una app Flutter sencilla con las tres pantallas del flujo principal, conectada a la API v1.

## Contexto

Especificación completa en `harness/context/08-flutter-app.md` (estructura, pantallas, dependencias, pruebas). Contrato de datos en `harness/context/07-api-contract.md`. Identidad: UUID guardado en el dispositivo enviado en `X-User-Id`. Requisito de usabilidad RNF-02: la persona debe entender los resultados sin explicación.

## Alcance

1. Crear el proyecto en `mobile/` (`flutter create`) y la estructura de la especificación.
2. Cliente HTTP con la cabecera de identidad, tiempo de espera de 120 s y mapeo de errores a mensajes en español.
3. Modelos `Analysis` y `AnalysisSummary` tolerantes a campos `null`.
4. Pantallas: inicio (elegir y enviar), resultados (puntajes, muletillas, ritmo, pausas, eventos, listas, evidencias, avisos) e historial (lista, abrir, borrar).
5. Pruebas de modelo y de cliente (`http.MockClient`).

No hacer: procesar audio en el teléfono, autenticación, grabación dentro de la app (queda como mejora futura; el MVP elige un archivo), traducciones a otros idiomas.

## Contrato

Dependencias: `provider`, `http`, `file_picker`, `fl_chart`, `shared_preferences`, `uuid`. URL base por `--dart-define=API_BASE_URL`. Detalle de pantallas y comportamientos en el documento de la especificación; todo campo `null` oculta su sección sin romper la pantalla.

## Criterios de aceptación

1. `flutter analyze` sin errores y `flutter test` en verde.
2. Flujo manual completo contra la API local: elegir audio, ver resultados, abrir el historial, borrar un análisis.
3. Con la API apagada, la app muestra un mensaje claro y no se cierra.
4. Con una respuesta sin `coherencia`, `eventos_acusticos` ni `verificacion`, la pantalla de resultados se ve completa.
5. Capturas de las tres pantallas en `docs/img/` para el informe.

## Pruebas

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

## Definición de hecho

- [ ] Verificación de la tarea: `cd mobile && flutter analyze && flutter test`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T16 done`.
- [ ] Commit(s) convencional(es) `tipo(T16): descripción`.
