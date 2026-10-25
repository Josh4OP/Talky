import 'dart:math' as math;

import 'analysis_summary.dart';

/// Resultado completo devuelto por `POST /analyses` y `GET /analyses/{id}`.
///
/// Todos los bloques opcionales se dejan en `null` cuando la API no los envía
/// o cuando la etapa correspondiente está apagada. La interfaz decide qué
/// secciones mostrar; nunca se inventan valores.
class Analysis {
  const Analysis({
    required this.id,
    required this.createdAt,
    required this.duracionS,
    required this.ppm,
    required this.ritmo,
    required this.pausas,
    required this.muletillas,
    required this.muletillasPorMinuto,
    required this.transcripcionRecortada,
    required this.coherencia,
    required this.eventosAcusticos,
    required this.advertencias,
    required this.modelosUsados,
    required this.modelosFallidos,
    required this.puntajes,
    required this.sintesis,
    required this.evidencias,
    required this.verificacion,
    required this.porModelo,
    this.isDemo = false,
  });

  final String id;
  final DateTime? createdAt;
  final double? duracionS;
  final double? ppm;
  final List<double> ritmo;
  final PauseStats? pausas;
  final Map<String, int> muletillas;
  final double? muletillasPorMinuto;
  final bool transcripcionRecortada;
  final Coherence? coherencia;
  final AcousticEvents? eventosAcusticos;
  final List<String> advertencias;
  final List<String> modelosUsados;
  final Map<String, dynamic> modelosFallidos;
  final Map<String, ScoreStat> puntajes;
  final Synthesis? sintesis;
  final List<Evidence> evidencias;
  final Verification? verificacion;
  final Map<String, dynamic> porModelo;

  /// Solo es `true` para datos de ejemplo generados localmente.
  final bool isDemo;

  int get totalMuletillas =>
      muletillas.values.fold(0, (sum, value) => sum + value);

  List<MapEntry<String, int>> get muletillasOrdenadas {
    final entries = muletillas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  bool get tieneSintesis =>
      sintesis != null &&
      (sintesis!.resumen.isNotEmpty ||
          sintesis!.fortalezas.isNotEmpty ||
          sintesis!.aspectosPorMejorar.isNotEmpty ||
          sintesis!.recomendaciones.isNotEmpty);

  factory Analysis.fromJson(Map<String, dynamic> json) {
    final rawPauses = _map(json['pausas']);
    final rawCoherence = _map(json['coherencia']);
    final rawEvents = _map(json['eventos_acusticos']);
    final rawSynthesis = _map(json['sintesis']);
    final rawScores = _map(json['puntajes']);
    final rawVerification = _map(json['verificacion']);

    return Analysis(
      id: _string(json['id']) ?? '',
      createdAt: _date(json['creado_en'] ?? json['created_at']),
      duracionS: _double(json['duracion_s']),
      ppm: _double(json['ppm']),
      ritmo: _doubleList(json['ritmo']),
      pausas: rawPauses == null ? null : PauseStats.fromJson(rawPauses),
      muletillas: _intMap(json['muletillas']),
      muletillasPorMinuto: _double(json['muletillas_por_minuto']),
      transcripcionRecortada: json['transcripcion_recortada'] == true,
      coherencia: rawCoherence == null ? null : Coherence.fromJson(rawCoherence),
      eventosAcusticos:
          rawEvents == null ? null : AcousticEvents.fromJson(rawEvents),
      advertencias: _stringList(json['advertencias']),
      modelosUsados: _stringList(json['modelos_usados']),
      modelosFallidos: _map(json['modelos_fallidos']) ?? const {},
      puntajes: rawScores?.map(
            (key, value) => MapEntry(
              key,
              ScoreStat.fromJson(_map(value) ?? const {}),
            ),
          ) ??
          const {},
      sintesis: rawSynthesis == null ? null : Synthesis.fromJson(rawSynthesis),
      evidencias: _list(json['evidencias'])
          .whereType<Map>()
          .map((item) => Evidence.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      verificacion: rawVerification == null
          ? null
          : Verification.fromJson(rawVerification),
      porModelo: _map(json['por_modelo']) ?? const {},
    );
  }
}

class AnalysisPage {
  const AnalysisPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<AnalysisSummary> items;
  final int total;
  final int limit;
  final int offset;

  factory AnalysisPage.fromJson(Map<String, dynamic> json) {
    return AnalysisPage(
      items: _list(json['items'])
          .whereType<Map>()
          .map((item) => AnalysisSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      total: _int(json['total']) ?? 0,
      limit: _int(json['limit']) ?? 20,
      offset: _int(json['offset']) ?? 0,
    );
  }
}

class PauseStats {
  const PauseStats({
    required this.pausasLargas,
    required this.segundosEnPausas,
    required this.pausaMaximaS,
    required this.pausasPorMinuto,
  });

  final int? pausasLargas;
  final double? segundosEnPausas;
  final double? pausaMaximaS;
  final double? pausasPorMinuto;

  factory PauseStats.fromJson(Map<String, dynamic> json) => PauseStats(
        pausasLargas: _int(json['pausas_largas']),
        segundosEnPausas: _double(json['segundos_en_pausas']),
        pausaMaximaS: _double(json['pausa_maxima_s']),
        pausasPorMinuto: _double(json['pausas_por_minuto']),
      );
}

class ScoreStat {
  const ScoreStat({
    required this.mediana,
    required this.min,
    required this.max,
    required this.desacuerdo,
  });

  final double? mediana;
  final double? min;
  final double? max;
  final bool desacuerdo;

  factory ScoreStat.fromJson(Map<String, dynamic> json) => ScoreStat(
        mediana: _double(json['mediana']),
        min: _double(json['min']),
        max: _double(json['max']),
        desacuerdo: json['desacuerdo'] == true,
      );
}

class Synthesis {
  const Synthesis({
    required this.resumen,
    required this.fortalezas,
    required this.aspectosPorMejorar,
    required this.recomendaciones,
  });

  final String resumen;
  final List<String> fortalezas;
  final List<String> aspectosPorMejorar;
  final List<String> recomendaciones;

  factory Synthesis.fromJson(Map<String, dynamic> json) => Synthesis(
        resumen: _string(json['resumen']) ?? '',
        fortalezas: _stringList(json['fortalezas']),
        aspectosPorMejorar: _stringList(json['aspectos_por_mejorar']),
        recomendaciones: _stringList(json['recomendaciones']),
      );
}

class Evidence {
  const Evidence({
    required this.afirmacion,
    required this.cita,
    required this.verificada,
  });

  final String afirmacion;
  final String cita;
  final bool verificada;

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
        afirmacion: _string(json['afirmacion']) ?? '',
        cita: _string(json['cita']) ?? '',
        verificada: json['verificada'] == true,
      );
}

class Verification {
  const Verification({required this.tasa, required this.descartadas});

  final double? tasa;
  final int? descartadas;

  factory Verification.fromJson(Map<String, dynamic> json) => Verification(
        tasa: _double(json['tasa']),
        descartadas: _int(json['descartadas']),
      );
}

class Coherence {
  const Coherence({
    required this.windows,
    required this.meanAdjacentSimilarity,
    required this.topicJumps,
    required this.repeatedPairs,
  });

  final int? windows;
  final double? meanAdjacentSimilarity;
  final List<int> topicJumps;
  final List<RepeatedPair> repeatedPairs;

  factory Coherence.fromJson(Map<String, dynamic> json) => Coherence(
        windows: _int(json['windows']),
        meanAdjacentSimilarity: _double(json['mean_adjacent_similarity']),
        topicJumps: _intList(json['topic_jumps']),
        repeatedPairs: _list(json['repeated_pairs'])
            .whereType<Map>()
            .map((item) => RepeatedPair.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
}

class RepeatedPair {
  const RepeatedPair({required this.a, required this.b, required this.similarity});

  final int? a;
  final int? b;
  final double? similarity;

  factory RepeatedPair.fromJson(Map<String, dynamic> json) => RepeatedPair(
        a: _int(json['a']),
        b: _int(json['b']),
        similarity: _double(json['similarity']),
      );
}

class AcousticEvents {
  const AcousticEvents({required this.muletillas, required this.tarareos});

  final List<AcousticFiller> muletillas;
  final List<HumEvent> tarareos;

  bool get isEmpty => muletillas.isEmpty && tarareos.isEmpty;

  factory AcousticEvents.fromJson(Map<String, dynamic> json) => AcousticEvents(
        muletillas: _list(json['muletillas'])
            .whereType<Map>()
            .map((item) => AcousticFiller.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        tarareos: _list(json['tarareos'])
            .whereType<Map>()
            .map((item) => HumEvent.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
}

class AcousticFiller {
  const AcousticFiller({
    required this.start,
    required this.end,
    required this.texto,
    required this.source,
    required this.confianza,
  });

  final double? start;
  final double? end;
  final String texto;
  final String source;
  final String confianza;

  factory AcousticFiller.fromJson(Map<String, dynamic> json) => AcousticFiller(
        start: _double(json['start']),
        end: _double(json['end']),
        texto: _string(json['texto']) ?? 'muletilla',
        source: _string(json['source']) ?? '',
        confianza: _string(json['confianza']) ?? '',
      );
}

class HumEvent {
  const HumEvent({required this.start, required this.end, required this.confidence});

  final double? start;
  final double? end;
  final double? confidence;

  factory HumEvent.fromJson(Map<String, dynamic> json) => HumEvent(
        start: _double(json['start']),
        end: _double(json['end']),
        confidence: _double(json['confidence']),
      );
}

/// Utilidades de lectura defensiva del JSON.
String? _string(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _double(Object? value) {
  if (value is num) {
    final number = value.toDouble();
    return number.isFinite ? number : null;
  }
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

List<String> _stringList(Object? value) => _list(value)
    .map(_string)
    .whereType<String>()
    .toList(growable: false);

List<double> _doubleList(Object? value) => _list(value)
    .map(_double)
    .whereType<double>()
    .toList(growable: false);

List<int> _intList(Object? value) =>
    _list(value).map(_int).whereType<int>().toList(growable: false);

Map<String, int> _intMap(Object? value) {
  final map = _map(value);
  if (map == null) return const {};
  final result = <String, int>{};
  for (final entry in map.entries) {
    final number = _int(entry.value);
    if (number != null) result[entry.key] = number;
  }
  return result;
}

/// Promedio simple del ritmo ignorando las ventanas en cero que puede dejar
/// el último tramo de silencio (riesgo documentado en el backend).
double? averagePpm(List<double> values) {
  final valid = values.where((value) => value > 0).toList();
  if (valid.isEmpty) return null;
  return valid.reduce((a, b) => a + b) / valid.length;
}

double? clampScore(num? value) {
  if (value == null) return null;
  return math.min(10, math.max(0, value.toDouble()));
}
