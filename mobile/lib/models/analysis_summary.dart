/// Elemento de `GET /analyses`. La lista no trae el detalle completo.
class AnalysisSummary {
  const AnalysisSummary({
    required this.id,
    required this.filename,
    required this.createdAt,
    required this.duracionS,
    required this.ppm,
    required this.totalMuletillas,
    this.isDemo = false,
  });

  final String id;
  final String filename;
  final DateTime? createdAt;
  final double? duracionS;
  final double? ppm;
  final int totalMuletillas;
  final bool isDemo;

  String get cleanName {
    final dot = filename.lastIndexOf('.');
    if (dot <= 0) return filename;
    return filename.substring(0, dot);
  }

  factory AnalysisSummary.fromJson(Map<String, dynamic> json) {
    return AnalysisSummary(
      id: (json['id'] ?? '').toString(),
      filename: (json['filename'] ?? 'Audio sin nombre').toString(),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['creado_en'] ?? '').toString(),
      ),
      duracionS: _toDouble(json['duracion_s']),
      ppm: _toDouble(json['ppm']),
      totalMuletillas: _toInt(json['total_muletillas']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'duracion_s': duracionS,
        'ppm': ppm,
        'total_muletillas': totalMuletillas,
      };
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}
