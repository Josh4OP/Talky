/// Configuración de la app. La URL de la API llega por `--dart-define=API_BASE_URL=...`.
abstract final class AppConfig {
  /// Por defecto, la IP con la que el emulador de Android ve el PC.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

  static const analyzeTimeout = Duration(seconds: 120);
  static const requestTimeout = Duration(seconds: 15);
  static const maxUploadBytes = 100 * 1024 * 1024;
  static const allowedExtensions = ['mp3', 'wav', 'm4a', 'ogg', 'flac', 'webm'];

  /// La app renueva el token cuando le quedan menos días que esto.
  static const renewBefore = Duration(days: 7);
}
