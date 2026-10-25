---
id: T16
title: Aplicación Flutter: marca Talky, mascota animada, resultados e historial
status: todo
phase: 4-cliente-y-calidad
depends_on: [T15, T19]
requirements: [RF-01, RF-02, RF-08, RF-11, RNF-01, RNF-02]
estimate: 12h
tests: [-]
touches: [mobile/, docs/img/]
---
# T16 - Aplicación Flutter: marca Talky, mascota animada, resultados e historial

## Objetivo

Entregar la app Flutter de TALKY con identidad visual propia (el loro pirata), diseñada primero en Figma, con la mascota animada según el estado de la app, sesión por token de dispositivo (T19) y las pantallas del flujo principal: splash, inicio, procesando, resultados e historial.

## Contexto

- Ya existe un primer avance en la rama `front` (commit `6e6c53b`): proyecto en `mobile/`, cliente HTTP, modelos, controladores, pantallas y pruebas. El equipo no está conforme con el diseño, así que esta tarea es un **rediseño**: se conserva lo que funcione de `core/`, `models/`, `state/` y `test/` (tras revisarlo contra el contrato) y se rehacen `theme/`, `widgets/` y `screens/` a partir del diseño de Figma.
- Especificación funcional: `harness/context/08-flutter-app.md`. Contrato de datos: `harness/context/07-api-contract.md`. Sesión: T19 (`Authorization: Bearer`, reemplaza a `X-User-Id` en la app).
- Bocetos de referencia en `mobile/Vocetos/`:
  - `Guía de marca Talky con mascota pirata.png`: logotipo, splash, paleta, tipografía e ícono.
  - `Hoja de concepto de Talky, el loro pirata.png`: los tres estados de la mascota, expresiones y poses extra.
- RNF-02: la persona entiende los resultados sin explicación. La mascota acompaña, no distrae: nunca tapa datos ni retrasa una acción.

## Alcance

### 1. Diseño en Figma (antes de escribir UI)

Archivo "TALKY - App" (https://www.figma.com/design/83qT9rYtx1cbuqcd0uZoNw). El plan Starter permite 3 páginas, así que el prototipo va dentro de Pantallas:

1. **Marca**: variables de color, espaciado y radios (colección "Talky") y estilos de texto (ver Contrato). Son la fuente de los tokens de `theme/`.
2. **Mascota**: referencia de estados. La fuente de verdad de la mascota son los PNG con fondo transparente de `mobile/Vocetos/` (`estado-normal.png`, `estado-pensando.png`, `estado-hablando.png`, `Silueta.png`), fieles a los bocetos de marca. El loro vectorial que se dibujó en Figma quedó descartado por no parecerse a los bocetos.
3. **Pantallas** (móvil 390 x 844): splash, inicio, procesando, resultados, historial, historial vacío, error de conexión y diálogo de error de la API, más el prototipo navegable splash -> inicio -> procesando -> resultados -> historial.

Estado al 2026-10-25: Marca completa; Pantallas con componentes y las pantallas 01 a 04. Se agotó el cupo de llamadas del MCP de Figma del plan Starter; faltan resultados, historial, prototipo y reemplazar el loro vectorial por los PNG. Las capturas de la app real van en `docs/img/`.

### 2. Marca en código

- `theme/app_colors.dart` y `theme/app_theme.dart` con los tokens de Figma. Modo claro primero; el modo oscuro solo si sobra tiempo.
- Fuentes Nunito (títulos) y Nunito Sans (texto) como assets locales con su licencia OFL; se retira `PlusJakartaSans`. No usar `google_fonts` (descarga en tiempo de ejecución).
- Ícono de la app (Android, iOS, web y Windows) desde el ícono de la guía de marca; nombre visible "Talky".

### 3. Mascota animada

Un widget `TalkyMascot(state:, size:)` que muestra la imagen del estado (`mobile/assets/mascot/`, reducidas a 900 px desde `mobile/Vocetos/`) y la anima entera con `AnimationController` y transformaciones (traslación, rotación sobre las patas, escala). Cada estado tiene una animación en bucle:

| Estado | Dónde aparece | Animación |
|---|---|---|
| Normal | Inicio, historial vacío | Respiración (escala 1.00 a 1.015, 3 s) y balanceo leve |
| Pensando | Procesando (mientras `POST /analyses` está en curso) | Cabeza que se inclina y vuelve, flotación leve y brillo que late detrás del bombillo |
| Hablando | Resultados, junto al resumen | Rebote corto al ritmo de la voz |
| Silueta | Splash | Respiración; el splash la hace flotar |

`sorprendido` (errores de la API) y `triste` (sin conexión) aún no tienen imagen propia: reutilizan pensando (con un sacudón) y normal (inclinada y apagada). Si se generan sus PNG, basta con agregarlos y cambiar el mapa de imágenes. El cambio de estado se hace con una transición corta (unos 300 ms), sin saltos.

Reglas de animación:

- Si `MediaQuery.disableAnimations` es verdadero, la mascota queda en su pose estática y el splash no anima nubes.
- `RepaintBoundary` alrededor de la mascota y de los fondos animados; nada de `setState` por cuadro. Los controladores se detienen fuera de pantalla (`TickerMode`) y se liberan en `dispose`.
- Lo aleatorio (nubes) usa `Random` con semilla fija.
- Las animaciones nunca bloquean la navegación ni retrasan la respuesta a un toque.

### 4. Pantallas

1. **Splash**: especificación detallada en `harness/prompts/tasks/Animacion-splash.md`. Durante el splash se obtiene o renueva la sesión (T19) y se comprueba `GET /health`. Si falla, se queda en el cielo con la mascota triste y un botón "Reintentar".
2. **Inicio**: mascota normal, botón "Elegir audio" (`file_picker` con `mp3, wav, m4a, ogg, flac, webm`), nombre y tamaño del archivo (aviso si pasa de 100 MB), botón "Analizar" y la nota fija "Tu audio se envía para transcribirse y no se guarda."
3. **Procesando**: mascota pensando y mensajes que rotan cada pocos segundos ("Escuchando tu audio", "Contando muletillas", "Los modelos están opinando", "Revisando las citas"). La API no informa avance real: los mensajes son ambientales, sin barra de porcentaje. Texto "Esto toma entre 30 y 60 segundos".
4. **Resultados**: el orden y las reglas de `08-flutter-app.md` (resumen con la mascota hablando, datos clave con la etiqueta de ritmo, tres puntajes y aviso de desacuerdo, gráfico de muletillas, gráfico de ritmo, pausas, eventos acústicos si no son `null`, fortalezas, aspectos por mejorar, recomendaciones, evidencias y avisos plegables). El gráfico de ritmo ignora visualmente una última ventana de 0 ppm por silencio final.
5. **Historial**: lista paginada (`limit=20`), abrir, borrar con confirmación y estado vacío con la mascota y un botón hacia el inicio.

### 5. Sesión y red

- `core/api_client.dart` envía `Authorization: Bearer <token>`; deja de enviar `X-User-Id`.
- `core/session_store.dart` (reemplaza a `user_id_store.dart`): guarda el token en `shared_preferences`, lo pide con `POST /auth/token` si no existe y lo renueva con `POST /auth/refresh` cuando le quedan menos de 7 días.
- Ante un 401: un único intento de renovar y repetir la petición. Si el token ya venció, se pide uno nuevo y se avisa que el historial anterior no está disponible en este dispositivo.
- Tiempo de espera de 120 s en `POST /analyses`. Errores (400, 401, 404, 413, 422, 503 y sin conexión) en mensajes en español.

No hacer: procesar audio en el teléfono, registro con contraseña, traducciones, modo oscuro antes de terminar lo demás. La grabación dentro de la app queda como mejora futura.

## Contrato

- **Paleta** (guía de marca): `primary #4FBEFF`, `tint80 #74CCFF`, `tint60 #99D9FF`, `tint40 #BFE6FF`, `tint20 #E3F4FF`, `white #FFFFFF`. Texto principal azul marino oscuro con contraste AA sobre blanco y sobre `tint20`; el texto blanco sobre `primary` solo en tamaños de 18 sp o más, o en negrita de 14 sp o más.
- **Tipografía**: Nunito (títulos y cifras), Nunito Sans (texto). Mínimo 14 sp.
- **Dependencias**: `provider`, `http`, `file_picker`, `fl_chart`, `shared_preferences` e `intl`. Nada de Rive, Lottie ni paquetes de animación: todo con el SDK. La grabación dentro de la app (`record`) se retiró del MVP.
- **Configuración**: `--dart-define=API_BASE_URL=...` (por defecto `http://10.0.2.2:8000`).
- **API**: `07-api-contract.md` más los endpoints de sesión de T19. Todo campo `null` oculta su sección sin romper la pantalla.

## Criterios de aceptación

1. Archivo de Figma con las cuatro páginas y el prototipo navegable; enlace anotado en el pull request.
2. `flutter analyze` sin errores y `flutter test` en verde.
3. La mascota muestra los tres estados en las pantallas indicadas y respeta `disableAnimations`.
4. Flujo manual completo contra la API local con `AUTH_MODE=jwt`: splash, elegir audio, procesando, resultados, historial y borrar un análisis.
5. Con la API apagada, el splash muestra el mensaje y "Reintentar"; la app no se cierra.
6. Con una respuesta sin `coherencia`, `eventos_acusticos` ni `verificacion`, la pantalla de resultados se ve completa.
7. Animaciones fluidas en un teléfono Android de gama media (sin tirones visibles en el perfilador de Flutter).
8. Capturas de splash, inicio, procesando, resultados e historial en `docs/img/`.

## Pruebas

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

Pruebas de Flutter (en `mobile/test/`):

- `analysis_model_test.dart`: JSON completo y JSON con `coherencia`, `eventos_acusticos` y `verificacion` en `null`.
- `api_client_test.dart`: con `http.MockClient`, envía `Authorization: Bearer`, no envía `X-User-Id`, interpreta 201, 400, 401 (renueva una vez y repite), 422 y 503.
- `session_store_test.dart`: pide token si no hay, renueva cuando faltan menos de 7 días, no renueva si falta más.
- `mascot_test.dart`: cada estado se construye sin errores y con `disableAnimations` no quedan tickers activos.
- `splash_test.dart`: los casos de `Animacion-splash.md`.

En Windows, `flutter test` con plugins exige el Modo de desarrollador activado (enlaces simbólicos).

## Definición de hecho

- [ ] Verificación de la tarea: `cd mobile && flutter analyze && flutter test`.
- [ ] Suite completa sin regresiones: `python -m pytest -q` (con el `.venv` del proyecto).
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T16 done`.
- [ ] Commit(s) convencional(es) `tipo(T16): descripción`.
