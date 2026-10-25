# TALKY · App Flutter

Cliente de la API v1 de TALKY. La app **no procesa audio**: graba o elige un archivo, lo sube a la API y presenta el resultado. Pensada para estudiantes que quieren retroalimentación sobre una exposición oral.

## Ejecutar

```bash
flutter pub get
flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

- `API_BASE_URL` es opcional; por defecto apunta a `http://10.0.2.2:8000` (el host visto desde el emulador de Android).
- En un teléfono físico usa la IP de tu equipo en la red local, por ejemplo `--dart-define=API_BASE_URL=http://192.168.1.20:8000`.
- La API debe estar corriendo (`uvicorn main:app --reload`) y acepta CORS de cualquier origen en desarrollo.
- Sin servidor puedes activar el **modo demostración** en Perfil. Los datos de ejemplo siempre llevan un aviso visible y nunca se mezclan con el historial real.

## Verificar

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Qué incluye

| Pantalla | Archivo | Contenido |
|---|---|---|
| Bienvenida | `lib/screens/welcome_screen.dart` | Presentación de Talky y arranque del onboarding |
| Inicio | `lib/screens/home_screen.dart` | Acción principal, resumen del historial y consejo |
| Nuevo análisis | `lib/screens/new_analysis_screen.dart` | Grabación con micrófono o carga de archivo, validación y envío |
| Procesamiento | `lib/screens/processing_screen.dart` | Etapas, reintento y error traducido |
| Resultado | `lib/screens/result_screen.dart` | Síntesis, métricas, puntajes, muletillas, ritmo, pausas, eventos, coherencia, evidencias y avisos |
| Historial | `lib/screens/history_screen.dart` | Lista paginada, apertura y borrado |
| Perfil | `lib/screens/profile_screen.dart` | Identidad, modo demostración, privacidad y estado del servidor |

La navegación vive en `lib/screens/home_shell.dart`: barra inferior en pantallas angostas y barra lateral desde 900 px. `IndexedStack` conserva el estado de cada pestaña.

## Arquitectura

```
lib/
  app.dart                  MaterialApp, tema y compuerta onboarding/inicio
  main.dart                 Arranque, preferencias y providers
  core/                     API, configuración, errores, formato, navegación
  models/                   Analysis (detalle) y AnalysisSummary (lista)
  state/                    AnalysisController y HistoryController
  screens/                  Una pantalla por paso del flujo
  widgets/                  Componentes reutilizables y mascota vectorial
  theme/                    Paleta y ThemeData únicos
  data/demo_data.dart       Datos de ejemplo marcados como tales
```

- **Identidad:** `talky-<uuid>` generado en el primer arranque y guardado con `shared_preferences`; se envía en `X-User-Id`. No es autenticación.
- **API real:** `POST /analyses`, `GET /analyses`, `GET /analyses/{id}`, `DELETE /analyses/{id}`, `GET /health`.
- **Estados:** cada pantalla cubre carga, vacío y error con componentes compartidos.
- **Mascota:** `lib/widgets/talky_mascot.dart` dibuja a Talky con `CustomPainter` en varias poses (bienvenida, saludo, escucha, análisis, celebración, vacío y disculpa), sin imágenes externas.
- **Tipografía:** Plus Jakarta Sans incluida en `assets/fonts` (licencia SIL OFL en `assets/fonts/OFL.txt`).

## Permisos y plataformas

- **Android:** `INTERNET` y `RECORD_AUDIO`; `minSdk` efectivo 24 (el paquete `record` pide 23). `usesCleartextTraffic` está activo para el backend local por HTTP; quítalo al publicar con HTTPS.
- **iOS:** `NSMicrophoneUsageDescription` y `NSAllowsLocalNetworking` para el backend local.
- **Web:** el micrófono requiere `localhost` o HTTPS. Las grabaciones web se envían en WAV; en móvil, en M4A/AAC.
- **Windows:** compila, pero el complemento de grabación puede requerir configuración adicional del micrófono.

## Pendiente para producción

- HTTPS y restricción de `CORS_ORIGINS`.
- Autenticación real (JWT); hoy la identidad es declarada.
- Revisar límites de tamaño (100 MB) y tiempos de espera (120 s) según el servidor real.
