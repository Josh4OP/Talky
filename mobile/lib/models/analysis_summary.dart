/// Elemento de `GET /analyses` (dataclass `AnalysisSummary` del backend).
class AnalysisSummary {
  const AnalysisSummary({
    required this.id,
    required this.filename,
    required this.createdAt,
    required this.durationS,
    required this.wordsPerMinute,
    required this.totalFillers,
    this.isDemo = false,
  });

  final String id;
  final String filename;
  final DateTime? createdAt;
  final double? durationS;
  final double? wordsPerMinute;
  final int totalFillers;
  final bool isDemo;

  factory AnalysisSummary.fromJson(Map<String, dynamic> json) => AnalysisSummary(
    id: json['id'] as String,
    filename: json['filename'] as String? ?? 'audio',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    durationS: (json['duracion_s'] as num?)?.toDouble(),
    wordsPerMinute: (json['ppm'] as num?)?.toDouble(),
    totalFillers: (json['total_muletillas'] as num? ?? 0).toInt(),
  );
}

class HistoryPage {
  const HistoryPage({required this.items, required this.total});

  final List<AnalysisSummary> items;
  final int total;

  factory HistoryPage.fromJson(Map<String, dynamic> json) => HistoryPage(
    items: [
      for (final item in json['items'] as List? ?? const [])
        AnalysisSummary.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
    total: (json['total'] as num? ?? 0).toInt(),
  );
}
