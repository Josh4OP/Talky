import 'dart:math' as math;

abstract final class Formatters {
  static const _months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String duration(double? seconds) {
    if (seconds == null || seconds.isNaN || seconds.isInfinite) return '—';
    final total = math.max(0, seconds.round());
    final minutes = total ~/ 60;
    final rest = total % 60;
    if (minutes == 0) return '${rest}s';
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  static String durationLong(double? seconds) {
    if (seconds == null || seconds.isNaN || seconds.isInfinite) return '—';
    final total = math.max(0, seconds.round());
    final minutes = total ~/ 60;
    final rest = total % 60;
    if (minutes == 0) return '$rest segundos';
    if (rest == 0) return '$minutes min';
    return '$minutes min $rest s';
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  }

  static String date(DateTime date) {
    final local = date.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  static String dateTime(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${Formatters.date(local)} · $hour:$minute';
  }

  static String relativeDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    if (diff == 0) return 'Hoy · $hour:$minute';
    if (diff == 1) return 'Ayer · $hour:$minute';
    if (diff > 1 && diff < 7) return 'Hace $diff días';
    return Formatters.date(local);
  }

  static String clock(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  /// Reloj de grabación transcurrido, sin zona horaria: `mm:ss`.
  static String recordingClock(int seconds) {
    final safe = math.max(0, seconds);
    final minutes = safe ~/ 60;
    final rest = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  static String ppm(double? ppm) {
    if (ppm == null || ppm.isNaN) return '—';
    return ppm.round().toString();
  }

  static String ppmLabel(double? ppm) {
    if (ppm == null || ppm.isNaN) return 'Sin dato';
    if (ppm < 110) return 'Ritmo lento';
    if (ppm <= 160) return 'Ritmo adecuado';
    return 'Ritmo rápido';
  }

  static String ppmShortLabel(double? ppm) {
    if (ppm == null || ppm.isNaN) return 'Sin dato';
    if (ppm < 110) return 'Lento';
    if (ppm <= 160) return 'Adecuado';
    return 'Rápido';
  }

  static String score(num? value) {
    if (value == null) return '—';
    final number = value.toDouble();
    if (number == number.roundToDouble()) return number.round().toString();
    return number.toStringAsFixed(1);
  }

  static String percent(double? value) {
    if (value == null || value.isNaN) return '—';
    return '${(value * 100).round()}%';
  }

  static String greeting(DateTime now) {
    if (now.hour < 12) return 'Buenos días';
    if (now.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }
}
