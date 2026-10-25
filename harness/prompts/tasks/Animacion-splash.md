# Especificación: splash de TALKY y revelado hacia el inicio

Parte de T16 (`harness/prompts/tasks/T16-app-flutter.md`). Implementa en `mobile/` la pantalla de splash de TALKY y su transición a la pantalla de inicio. Solo el SDK de Flutter (sin paquetes de animación ni de SVG), Dart con null safety, `flutter_lints` limpio. Identificadores en inglés, textos visibles en español, sin emojis.

Referencia visual: `mobile/Vocetos/Guía de marca Talky con mascota pirata.png` (teléfono del centro) y el marco "Splash" del archivo de Figma "TALKY - App".

## Qué hace el splash en TALKY

No es decorativo: cubre el arranque real de la app, que necesita la red antes de mostrar el inicio.

`loadApp` (inyectado como `Future<void> Function()`, para poder probarlo) hace, en orden:

1. Cargar preferencias locales.
2. Obtener o renovar la sesión (T19): `POST /auth/token` si no hay token guardado; `POST /auth/refresh` si le quedan menos de 7 días.
3. `GET /health` para confirmar que el servidor (el PC del equipo en la misma red) responde.

Si algo falla, el splash no revela: muestra el error sobre el mismo cielo (ver "Error y reintento").

## Cómo se ve

- **Fondo**: degradado vertical de cielo con los tokens de marca (`theme/app_colors.dart`, que salen de las variables de Figma): `tint80 #74CCFF` arriba, `primary #4FBEFF` en el centro y `tint60 #99D9FF` abajo, detrás de las nubes. Si en Figma se define un azul más profundo para el centro del cielo, se agrega como token propio (`skyDeep`), no como literal en el widget.
- **Mascota**: la silueta blanca del loro pirata (estado Normal), centrada, unos 45 % del ancho de la pantalla. Asset `assets/brand/mascot_silhouette.png` con variantes `2.0x/` y `3.0x/`, exportado desde Figma. Mientras no exista, un `Icon` blanco grande de relleno.
- **Nubes**: en el 30 % inferior, blancas y esponjosas, en tres capas superpuestas. Las de atrás más transparentes y teñidas de `tint40 #BFE6FF`; las de adelante blancas y opacas.
- **Accesibilidad**: `Semantics(label: "Talky está cargando")` sobre el splash; sin texto visible mientras carga.
- **Splash nativo**: `android/app/src/main/res/drawable*/launch_background.xml` y el `LaunchScreen` de iOS usan `tint80` de fondo, para que no haya un destello blanco antes del primer cuadro de Flutter.

## Nubes vivas mientras carga

Movimiento lento y tranquilo, nunca brusco:

1. **Parallax horizontal**: tres capas hacia la izquierda a 8 px/s (atrás), 14 px/s (medio) y 22 px/s (adelante).
2. **Bucle sin cortes**: cada capa se dibuja dos veces seguidas y se desplaza con módulo de su ancho, para que nunca haya salto ni hueco.
3. **Flotación**: cada capa sube y baja de 3 a 6 px con una onda senoidal de 4 a 7 s de periodo, con desfase distinto por capa.
4. **Opacidad por capa**: 0.45, 0.7 y 1.0.
5. **Rendimiento**: un `Ticker` actualiza un `ValueNotifier<double>` con el tiempo en segundos; un `CustomPainter` con `super(repaint: time)` dibuja, sin reconstruir widgets por cuadro. Todo dentro de un `RepaintBoundary`.
6. **Nubes por código**: cada nube son de 4 a 7 círculos superpuestos de distintos tamaños con `MaskFilter.blur` (sigma 2 a 4), generados con `Random(42)` para que siempre se vean iguales. Las nubes se calculan una vez (no en cada `paint`). Comentario breve de cómo cambiarlas por `assets/brand/clouds_back.png`, `clouds_mid.png` y `clouds_front.png` con el mismo desplazamiento.
7. **Mascota flotando**: la silueta sube y baja 4 px con periodo de 3 s.

El mismo pintor de nubes se reutiliza en el fondo del error de conexión, así que va en `lib/widgets/sky/`, no dentro de la pantalla.

## Cuándo termina

- Duración mínima de 1.2 s aunque `loadApp` termine antes, para que no parpadee.
- El revelado empieza cuando `loadApp` terminó **y** pasó el mínimo.
- Mientras `loadApp` no termine, las nubes siguen animándose sin límite. El cliente HTTP ya tiene sus propios tiempos de espera; el splash no agrega otro.

## Error y reintento

Si `loadApp` falla, no se revela ni se cambia de pantalla. Sobre el mismo cielo:

- La silueta pasa a la mascota de color con expresión triste (transición de unos 300 ms).
- Un mensaje breve según el error, usando el mapeo de errores de `core/api_exception.dart`. Para el caso más común: "No pudimos conectar con Talky. Revisa que el servidor esté encendido y que estés en la misma red."
- Botón "Reintentar" que vuelve a ejecutar `loadApp`; la mascota regresa a la silueta y el tiempo mínimo no se vuelve a exigir.

## Revelado circular hacia el inicio

1. **Punto**: sobre el ojo del loro (origen configurable) nace un círculo blanco que crece de 0 a 9 px de radio en 350 ms con `Curves.easeOutBack`, con halo difuso `tint40 #BFE6FF`. Guiño a la mascota: el punto es el brillo del ojo.
2. **Expansión**: en 900 ms con `Curves.easeInOutCubic` el radio crece hasta la distancia del origen a la esquina más lejana.
3. **Recorte**: dentro del círculo se ve la pantalla de inicio, ya construida debajo y recortada con `ClipPath` y un `CustomClipper<Path>` propio (`Path.addOval`). Fuera sigue el splash con las nubes en movimiento. No es un fundido ni un deslizamiento.
4. **Borde brillante**: halo de 10 px blanco con opacidad 0.5 y `MaskFilter.blur` de sigma 12, más una línea nítida de 2 px blanca con opacidad 0.9. La opacidad del anillo es `1 - progreso`.
5. El inicio pasa de escala 1.06 a 1.0 durante la expansión.
6. El relleno blanco del punto se desvanece en el primer 20 % de la expansión.
7. Al terminar se quita el splash del árbol, se detiene el `Ticker` y queda solo el inicio. La mascota del inicio arranca su animación de estado Normal (saludo) justo después.

## Movimiento reducido

Si `MediaQuery.disableAnimations` es verdadero: nubes y mascota quietas, sin punto ni expansión; al terminar la carga se pasa al inicio con un fundido de 200 ms.

## Requisitos técnicos

- `SplashToHome({required Future<void> Function() loadApp, required Widget home, Offset originAdjust = Offset.zero, Duration minDuration = const Duration(milliseconds: 1200)})`, `StatefulWidget` con `TickerProviderStateMixin`.
- Secuencia `async` `_play()`: espera la carga y el mínimo con `Future.wait`, luego el punto y la expansión. Comprueba `mounted` después de cada `await`.
- Punto y anillo en un `CustomPainter` aparte, dentro de un `IgnorePointer`.
- `LayoutBuilder` para el tamaño; origen del círculo con un `GlobalKey` sobre la mascota más `originAdjust`.
- `AnimatedBuilder` con `Listenable.merge`; sin `setState` por cuadro. Fluido a 60 y 120 Hz.
- `Color.withValues(alpha: ...)`, no `withOpacity`. Todos los controladores, el `Ticker` y el `ValueNotifier` se liberan en `dispose()`.
- Archivos sugeridos: `lib/screens/splash_to_home.dart`, `lib/widgets/sky/cloud_layer_painter.dart`, `lib/widgets/sky/reveal_painter.dart`, `lib/widgets/sky/circle_reveal_clipper.dart`.

## Pruebas (`mobile/test/splash_test.dart`)

Con `loadApp` falso y `tester.pump(duración)` (no `pumpAndSettle`: las nubes animan sin fin mientras carga):

1. Si la carga termina a los 200 ms, el inicio no aparece antes de 1.2 s.
2. Tras la carga, el mínimo y unos 1.3 s de revelado, el inicio está en el árbol y el splash no.
3. Si la carga falla, aparece "Reintentar" y el inicio no se construye; al tocarlo, `loadApp` se llama otra vez.
4. Con `disableAnimations`, no hay tickers activos mientras carga.
5. Al desmontar el widget a mitad del revelado no quedan tickers ni temporizadores pendientes.
