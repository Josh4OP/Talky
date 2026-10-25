/// Configuración de compilación de TALKY.
///
/// La URL de la API se puede cambiar sin tocar código:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000`
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const requestTimeout = Duration(seconds: 120);
  static const connectivityTimeout = Duration(seconds: 8);
  static const maxUploadMb = 100;
  static const pageSize = 20;
  static const appVersion = '1.0.0';

  static const supportedExtensions = <String>[
    'mp3',
    'wav',
    'm4a',
    'ogg',
    'flac',
    'webm',
  ];

  static String get uploadLimitLabel => '$maxUploadMb MB';
}
