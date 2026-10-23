# 08 - Aplicación Flutter

Especificación para la tarea T16. La app es un cliente delgado de la API v1 (`07-api-contract.md`). No procesa audio localmente.

## Objetivo

Que un estudiante grabe o elija un audio, lo envíe, vea el análisis en pantallas claras y consulte su historial. Cumple RF-01, RF-02, RF-08, RF-11 y RNF-02.

## Estructura

```
mobile/
  pubspec.yaml
  lib/
    main.dart
    app.dart                          # MaterialApp, rutas, tema
    core/
      api_client.dart                 # http + cabecera X-User-Id
      user_id_store.dart              # genera y guarda el identificador (shared_preferences)
      config.dart                     # baseUrl configurable
    models/
      analysis.dart                   # fromJson del resultado completo
      analysis_summary.dart
    state/
      analysis_controller.dart        # ChangeNotifier (provider)
      history_controller.dart
    screens/
      home_screen.dart                # elegir archivo, enviar, progreso
      result_screen.dart              # resultados
      history_screen.dart             # lista, abrir, borrar
    widgets/
      score_card.dart
      filler_chart.dart               # fl_chart
      rhythm_chart.dart
      evidence_tile.dart
  test/
    analysis_model_test.dart
    api_client_test.dart
```

## Dependencias

`provider`, `http`, `file_picker`, `fl_chart`, `shared_preferences`, `uuid`. Nada más sin justificación. Versiones vigentes al momento de implementar (verificar en pub.dev).

## Pantallas

### Inicio (subir)

- Botón "Elegir audio" con `file_picker` limitado a `mp3, wav, m4a, ogg, flac, webm`.
- Muestra nombre y tamaño del archivo elegido. Si supera 100 MB, avisa antes de enviar.
- Botón "Analizar". Mientras espera, muestra indicador de progreso y el texto "Esto toma entre 30 y 60 segundos".
- Nota fija de privacidad: "Tu audio se envía para transcribirse y no se guarda."
- Errores: muestra el `detail` de la API en un diálogo (400, 413, 422, 503 con un texto amigable adicional).

### Resultados

Orden de arriba hacia abajo:

1. Resumen (`sintesis.resumen`) y datos clave: duración, ritmo (ppm) con una etiqueta ("lento", "adecuado", "rápido"; rangos orientativos: menos de 110, 110 a 160, más de 160), muletillas por minuto.
2. Tres tarjetas de puntaje (organización, claridad, repetición) con la mediana. Si `desacuerdo` es verdadero, un aviso "Los modelos no coinciden del todo".
3. Muletillas: gráfico de barras con el conteo por muletilla.
4. Ritmo: gráfico de línea con `ritmo` por ventana de 30 s.
5. Pausas largas: conteo y pausa máxima.
6. Tatareos y muletillas vocales detectadas (si `eventos_acusticos` no es nulo): lista con el segundo en que ocurren.
7. Fortalezas, aspectos por mejorar y recomendaciones, como listas.
8. Evidencias: cada una con su cita entre comillas.
9. Advertencias (si hay): sección plegable "Avisos".

Todo campo `null` oculta su sección, nunca rompe la pantalla.

### Historial

- Lista paginada (`limit=20`) con nombre del audio, fecha, muletillas totales y ppm.
- Tocar abre el resultado (`GET /analyses/{id}`).
- Deslizar o botón para borrar con confirmación (`DELETE`).
- Estado vacío con texto y botón hacia el inicio.

## Comportamiento transversal

- `baseUrl` configurable en `core/config.dart` y por `--dart-define=API_BASE_URL=...`. Por defecto `http://10.0.2.2:8000` (emulador Android).
- Identidad: en el primer arranque se genera `talky-` + UUID v4 sin guiones (cumple el regex `^[A-Za-z0-9_.@-]{1,64}$`) y se guarda localmente.
- Tiempo de espera de red de 120 s para `POST /analyses`.
- Estado con `provider` y `ChangeNotifier`. Sin otras librerías de estado.
- Accesibilidad básica: textos de al menos 14 sp, contraste suficiente, etiquetas semánticas en botones.
- Textos en español.

## Pruebas

- `analysis_model_test.dart`: el modelo parsea un JSON completo (use el ejemplo de `07-api-contract.md`) y uno con `coherencia`, `eventos_acusticos` y `verificacion` en `null`.
- `api_client_test.dart`: con `http.MockClient`, envía la cabecera `X-User-Id`, interpreta 201, 400, 422 y 503.
- `flutter analyze` sin errores y `flutter test` en verde.

## Ejecución

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Para un teléfono físico, la API debe ser alcanzable en la red local (por ejemplo `uvicorn main:app --host 0.0.0.0`) y `API_BASE_URL` apunta a la IP del equipo.
