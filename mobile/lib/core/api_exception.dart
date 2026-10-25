import 'dart:convert';

/// Error de la API ya traducido a un mensaje para la persona.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  static const connectionMessage =
      'No pudimos conectar con Talky. Revisa que el servidor esté encendido y que estés en la misma red.';
  static const timeoutMessage = 'El análisis tardó demasiado. Intenta de nuevo en unos minutos.';
  static const sessionMessage = 'Tu sesión venció. Vuelve a abrir la app.';

  /// Código HTTP; `null` cuando no hubo respuesta (sin red o tiempo agotado).
  final int? statusCode;
  final String message;

  bool get isConnection => statusCode == null;

  factory ApiException.connection() => const ApiException(connectionMessage);

  factory ApiException.timeout() => const ApiException(timeoutMessage);

  /// Usa el `detail` en español de la API y agrega contexto donde ayuda.
  factory ApiException.fromResponse(int statusCode, String body) {
    final detail = _detail(body);
    final message = switch (statusCode) {
      400 || 413 || 422 => detail ?? 'No pudimos procesar ese audio.',
      401 => sessionMessage,
      404 => 'No encontramos ese análisis. Puede que ya se haya borrado.',
      503 => '${detail ?? 'Los servicios de análisis no respondieron.'} Tu audio no se guardó.',
      _ => 'Algo salió mal en el servidor (código $statusCode). Intenta de nuevo.',
    };
    return ApiException(message, statusCode: statusCode);
  }

  static String? _detail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) return decoded['detail'] as String;
    } on FormatException {
      return null;
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
