/// Error de la API ya traducido a un mensaje que se le puede mostrar a una
/// persona. El detalle original se conserva para depuración.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.detail,
    this.statusCode,
    this.retryable = true,
  });

  final String message;
  final String? detail;
  final int? statusCode;
  final bool retryable;

  factory ApiException.fromStatus(int statusCode, String? detail) {
    final cleanDetail = (detail == null || detail.trim().isEmpty)
        ? null
        : detail.trim();

    final (message, retryable) = switch (statusCode) {
      400 => (
          cleanDetail ??
              'No pudimos leer ese archivo. Revisa el formato e inténtalo de nuevo.',
          false,
        ),
      401 => (
          'No encontramos tu identificador de usuario. Reinicia la aplicación e inténtalo otra vez.',
          false,
        ),
      404 => ('Ese análisis ya no está disponible.', false),
      413 => (
          'El audio supera el límite permitido. Prueba con un archivo más liviano.',
          false,
        ),
      422 => (
          cleanDetail ??
              'No pudimos analizar el audio. Verifica que tenga voz clara y una duración adecuada.',
          false,
        ),
      503 => (
          'El servicio de análisis no está disponible en este momento. Inténtalo de nuevo en unos minutos.',
          true,
        ),
      _ => (
          'Ocurrió un problema al conectar con TALKY. Inténtalo de nuevo.',
          true,
        ),
    };

    return ApiException(
      message: message,
      detail: cleanDetail,
      statusCode: statusCode,
      retryable: retryable,
    );
  }

  factory ApiException.timeout() => const ApiException(
        message:
            'El análisis está tardando más de lo esperado. Revisa tu conexión e inténtalo de nuevo.',
        retryable: true,
      );

  factory ApiException.network() => const ApiException(
        message:
            'No pudimos conectar con el servidor de TALKY. Revisa tu conexión y la dirección de la API.',
        retryable: true,
      );

  @override
  String toString() =>
      'ApiException($statusCode): $message${detail == null ? '' : ' — $detail'}';
}
