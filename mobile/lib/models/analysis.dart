/// Resultado completo de `POST /analyses` y `GET /analyses/{id}` (ver `07-api-contract.md`).
/// Toda sección opcional es `null` cuando la API no la envía; la pantalla la oculta.
class Analysis {
  const Analysis({
    required this.id,
    required this.createdAt,
    required this.durationS,
    required this.wordsPerMinute,
    required this.rhythm,
    required this.pauses,
    required this.fillers,
    required this.fillersPerMinute,
    required this.transcriptTrimmed,
    required this.coherence,
    required this.acousticEvents,
    required this.warnings,
    required this.scores,
    required this.synthesis,
    required this.evidences,
    required this.verification,
    this.isDemo = false,
  });

  final String id;
  final DateTime? createdAt;
  final double? durationS;
  final double? wordsPerMinute;
  final List<double> rhythm;
  final Pauses? pauses;

  /// Conteo por muletilla, de mayor a menor como lo entrega la API.
  final Map<String, int> fillers;
  final double? fillersPerMinute;
  final bool transcriptTrimmed;
  final Coherence? coherence;
  final AcousticEvents? acousticEvents;
  final List<String> warnings;
  final Map<String, Score> scores;
  final Synthesis? synthesis;
  final List<Evidence> evidences;
  final Verification? verification;

  /// Resultado de ejemplo creado por la app (modo de ejemplo); nunca viene del servidor.
  final bool isDemo;

  int get totalFillers => fillers.values.fold(0, (a, b) => a + b);

  factory Analysis.fromJson(Map<String, dynamic> json) => Analysis(
    id: json['id'] as String? ?? '',
    createdAt: DateTime.tryParse(json['creado_en'] as String? ?? ''),
    durationS: _double(json['duracion_s']),
    wordsPerMinute: _double(json['ppm']),
    rhythm: [for (final v in json['ritmo'] as List? ?? const []) ?_double(v)],
    pauses: _map(json['pausas'], Pauses.fromJson),
    fillers: {
      for (final e in (json['muletillas'] as Map? ?? const {}).entries) e.key as String: (e.value as num).toInt(),
    },
    fillersPerMinute: _double(json['muletillas_por_minuto']),
    transcriptTrimmed: json['transcripcion_recortada'] as bool? ?? false,
    coherence: _map(json['coherencia'], Coherence.fromJson),
    acousticEvents: _map(json['eventos_acusticos'], AcousticEvents.fromJson),
    warnings: [for (final w in json['advertencias'] as List? ?? const []) w.toString()],
    scores: {
      for (final e in (json['puntajes'] as Map? ?? const {}).entries)
        if (e.value is Map) e.key as String: Score.fromJson(Map<String, dynamic>.from(e.value as Map)),
    },
    synthesis: _map(json['sintesis'], Synthesis.fromJson),
    evidences: [
      for (final e in json['evidencias'] as List? ?? const [])
        if (e is Map) Evidence.fromJson(Map<String, dynamic>.from(e)),
    ],
    verification: _map(json['verificacion'], Verification.fromJson),
  );
}

class Pauses {
  const Pauses({
    required this.longPauses,
    required this.secondsInPauses,
    required this.longestS,
    required this.perMinute,
  });

  final int longPauses;
  final double secondsInPauses;
  final double longestS;
  final double perMinute;

  factory Pauses.fromJson(Map<String, dynamic> json) => Pauses(
    longPauses: (json['pausas_largas'] as num? ?? 0).toInt(),
    secondsInPauses: _double(json['segundos_en_pausas']) ?? 0,
    longestS: _double(json['pausa_maxima_s']) ?? 0,
    perMinute: _double(json['pausas_por_minuto']) ?? 0,
  );
}

class Coherence {
  const Coherence({
    required this.windows,
    required this.meanSimilarity,
    required this.topicJumps,
    required this.repeatedPairs,
  });

  final int windows;

  /// Similitud media entre tramos vecinos (0 a 1); `null` si no se pudo calcular.
  final double? meanSimilarity;
  final int topicJumps;
  final int repeatedPairs;

  factory Coherence.fromJson(Map<String, dynamic> json) => Coherence(
    windows: (json['windows'] as num? ?? 0).toInt(),
    meanSimilarity: _double(json['mean_adjacent_similarity']),
    topicJumps: (json['topic_jumps'] as List? ?? const []).length,
    repeatedPairs: (json['repeated_pairs'] as List? ?? const []).length,
  );
}

class AcousticEvent {
  const AcousticEvent({required this.startS, required this.label});

  final double startS;
  final String label;
}

class AcousticEvents {
  const AcousticEvents({required this.fillers, required this.hums});

  final List<AcousticEvent> fillers;
  final List<AcousticEvent> hums;

  factory AcousticEvents.fromJson(Map<String, dynamic> json) => AcousticEvents(
    fillers: [
      for (final e in json['muletillas'] as List? ?? const [])
        if (e is Map) AcousticEvent(startS: _double(e['start']) ?? 0, label: e['texto']?.toString() ?? 'muletilla'),
    ],
    hums: [
      for (final e in json['tarareos'] as List? ?? const [])
        if (e is Map) AcousticEvent(startS: _double(e['start']) ?? 0, label: 'tarareo'),
    ],
  );
}

class Score {
  const Score({required this.median, this.min, this.max, required this.disagreement});

  final double median;

  /// Puntaje más bajo y más alto entre los modelos; `null` si la API no los envía.
  final double? min;
  final double? max;
  final bool disagreement;

  factory Score.fromJson(Map<String, dynamic> json) => Score(
    median: _double(json['mediana']) ?? 0,
    min: _double(json['min']),
    max: _double(json['max']),
    disagreement: json['desacuerdo'] as bool? ?? false,
  );
}

class Synthesis {
  const Synthesis({
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.recommendations,
  });

  final String summary;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> recommendations;

  factory Synthesis.fromJson(Map<String, dynamic> json) => Synthesis(
    summary: json['resumen']?.toString() ?? '',
    strengths: _strings(json['fortalezas']),
    improvements: _strings(json['aspectos_por_mejorar']),
    recommendations: _strings(json['recomendaciones']),
  );
}

class Evidence {
  const Evidence({required this.claim, required this.quote});

  final String claim;
  final String quote;

  factory Evidence.fromJson(Map<String, dynamic> json) =>
      Evidence(claim: json['afirmacion']?.toString() ?? '', quote: json['cita']?.toString() ?? '');
}

class Verification {
  const Verification({required this.rate, required this.discarded});

  final double? rate;
  final int discarded;

  factory Verification.fromJson(Map<String, dynamic> json) =>
      Verification(rate: _double(json['tasa']), discarded: (json['descartadas'] as num? ?? 0).toInt());
}

double? _double(Object? value) => value is num ? value.toDouble() : null;

List<String> _strings(Object? value) => [for (final v in value as List? ?? const []) v.toString()];

T? _map<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value is Map ? parse(Map<String, dynamic>.from(value)) : null;
