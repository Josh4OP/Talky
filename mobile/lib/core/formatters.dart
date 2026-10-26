import 'package:intl/intl.dart';

/// Formatos de cifras y fechas en español para la interfaz.
abstract final class Formatters {
  static String duration(double? seconds) {
    if (seconds == null) return '-';
    final total = seconds.round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  static String number(double? value, {int decimals = 1}) =>
      value == null ? '-' : NumberFormat.decimalPatternDigits(locale: 'es', decimalDigits: decimals).format(value);

  static String date(DateTime? value) => value == null ? '' : DateFormat("d MMM, h:mm a", 'es').format(value.toLocal());

  static String fileSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${number(bytes / (1024 * 1024))} MB';
  }

  static String greeting(DateTime now) {
    if (now.hour < 12) return 'Buenos días';
    if (now.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  static String percent(double? ratio) => ratio == null ? '-' : '${(ratio * 100).round()} %';

  /// Nombre del audio sin extensión ni guiones bajos, para mostrarlo.
  static String cleanName(String filename) {
    final dot = filename.lastIndexOf('.');
    final base = dot > 0 ? filename.substring(0, dot) : filename;
    return base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  }

  /// Etiqueta orientativa del ritmo (ver `08-flutter-app.md`).
  static String pace(double? wordsPerMinute) {
    if (wordsPerMinute == null) return '';
    if (wordsPerMinute < 110) return 'Ritmo lento';
    if (wordsPerMinute <= 160) return 'Ritmo adecuado';
    return 'Ritmo rápido';
  }
}
