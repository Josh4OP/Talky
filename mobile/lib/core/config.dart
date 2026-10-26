import 'package:flutter/foundation.dart';

/// Configuración de la app. La URL de la API llega por `--dart-define=API_BASE_URL=...`.
abstract final class AppConfig {
  static const _definedApiUrl = String.fromEnvironment('API_BASE_URL');

  /// IP con la que el emulador de Android ve el PC.
  static const _androidEmulatorApi = 'http://10.0.2.2:8000';

  /// Dirección de la API. Si `API_BASE_URL` falta o llega mal formada (PowerShell parte los argumentos
  /// con puntos si no van entre comillas), en web se usa el mismo equipo en el puerto 8000 y en el
  /// teléfono la dirección del emulador de Android.
  static Uri get apiBaseUri => resolveApiUri(_definedApiUrl, isWeb: kIsWeb, pageHost: kIsWeb ? Uri.base.host : '');

  static String get apiBaseUrl => apiBaseUri.toString();

  @visibleForTesting
  static Uri resolveApiUri(String defined, {required bool isWeb, String pageHost = ''}) {
    final parsed = Uri.tryParse(defined.trim());
    if (parsed != null && (parsed.isScheme('http') || parsed.isScheme('https')) && parsed.host.isNotEmpty) {
      return parsed;
    }
    if (isWeb && pageHost.isNotEmpty) return Uri(scheme: 'http', host: pageHost, port: 8000);
    return Uri.parse(_androidEmulatorApi);
  }

  static const analyzeTimeout = Duration(seconds: 120);
  static const requestTimeout = Duration(seconds: 15);
  static const maxUploadBytes = 100 * 1024 * 1024;
  static const allowedExtensions = ['mp3', 'wav', 'm4a', 'ogg', 'flac', 'webm'];

  /// La app renueva el token cuando le quedan menos días que esto.
  static const renewBefore = Duration(days: 7);
}
