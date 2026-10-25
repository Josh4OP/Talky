import 'package:flutter_test/flutter_test.dart';
import 'package:talky/models/analysis.dart';
import 'package:talky/models/analysis_summary.dart';

void main() {
  group('Analysis.fromJson', () {
    test('parsea un resultado completo del contrato', () {
      final analysis = Analysis.fromJson(_fullJson);

      expect(analysis.id, '6f1c2d3e-4a5b-6c7d-8e9f-0a1b2c3d4e5f');
      expect(
        analysis.createdAt,
        DateTime.parse('2026-10-23T15:04:05.123456Z'),
      );
      expect(analysis.duracionS, 312.4);
      expect(analysis.ppm, 128.5);
      expect(analysis.ritmo, [131.0, 120.0, 140.0]);
      expect(analysis.isDemo, isFalse);

      expect(analysis.pausas, isNotNull);
      expect(analysis.pausas!.pausasLargas, 4);
      expect(analysis.pausas!.segundosEnPausas, 9.6);
      expect(analysis.pausas!.pausaMaximaS, 3.1);
      expect(analysis.pausas!.pausasPorMinuto, 0.8);

      expect(analysis.muletillas, {'eh': 7, 'o sea': 4, 'entonces': 2});
      expect(analysis.totalMuletillas, 13);
      expect(analysis.muletillasOrdenadas.first.key, 'eh');
      expect(analysis.muletillasPorMinuto, 2.5);
      expect(analysis.transcripcionRecortada, isFalse);

      expect(analysis.coherencia, isNotNull);
      expect(analysis.coherencia!.windows, 12);
      expect(analysis.coherencia!.meanAdjacentSimilarity, 0.52);
      expect(analysis.coherencia!.topicJumps, [4]);
      expect(analysis.coherencia!.repeatedPairs.single.a, 2);
      expect(analysis.coherencia!.repeatedPairs.single.b, 9);
      expect(analysis.coherencia!.repeatedPairs.single.similarity, 0.88);

      expect(analysis.eventosAcusticos, isNotNull);
      expect(analysis.eventosAcusticos!.muletillas.single.texto, 'eh');
      expect(analysis.eventosAcusticos!.muletillas.single.source, 'both');
      expect(analysis.eventosAcusticos!.tarareos.single.confidence, 0.82);

      expect(analysis.modelosUsados, hasLength(2));
      expect(analysis.modelosFallidos, isEmpty);
      expect(analysis.puntajes['organizacion']!.mediana, 7);
      expect(analysis.puntajes['repeticion']!.desacuerdo, isTrue);

      expect(analysis.sintesis, isNotNull);
      expect(analysis.sintesis!.resumen, isNotEmpty);
      expect(analysis.sintesis!.fortalezas, hasLength(2));
      expect(analysis.sintesis!.aspectosPorMejorar, hasLength(1));
      expect(analysis.sintesis!.recomendaciones, hasLength(1));
      expect(analysis.tieneSintesis, isTrue);

      expect(analysis.evidencias, hasLength(1));
      expect(analysis.evidencias.single.verificada, isTrue);
      expect(analysis.evidencias.single.cita, contains('retroalimentación'));

      expect(analysis.verificacion!.tasa, 0.83);
      expect(analysis.verificacion!.descartadas, 2);
      expect(analysis.porModelo, isNotEmpty);
    });

    test('tolera bloques opcionales nulos y campos faltantes', () {
      final analysis = Analysis.fromJson({
        'id': 'solo-basico',
        'creado_en': '2026-10-23T15:04:05Z',
        'duracion_s': 42,
        'ppm': 120,
        'coherencia': null,
        'eventos_acusticos': null,
        'verificacion': null,
        'pausas': null,
        'sintesis': null,
      });

      expect(analysis.id, 'solo-basico');
      expect(analysis.duracionS, 42);
      expect(analysis.ppm, 120);
      expect(analysis.ritmo, isEmpty);
      expect(analysis.muletillas, isEmpty);
      expect(analysis.totalMuletillas, 0);
      expect(analysis.pausas, isNull);
      expect(analysis.coherencia, isNull);
      expect(analysis.eventosAcusticos, isNull);
      expect(analysis.verificacion, isNull);
      expect(analysis.sintesis, isNull);
      expect(analysis.tieneSintesis, isFalse);
      expect(analysis.puntajes, isEmpty);
      expect(analysis.evidencias, isEmpty);
      expect(analysis.advertencias, isEmpty);
      expect(analysis.transcripcionRecortada, isFalse);
    });

    test('acepta números como texto y descarta listas inválidas', () {
      final analysis = Analysis.fromJson({
        'id': 123,
        'duracion_s': '12,5',
        'ppm': '130.5',
        'ritmo': [120, 'x', null, '135,5'],
        'muletillas': {'eh': '3', 'malo': 'muchas'},
      });

      expect(analysis.id, '123');
      expect(analysis.duracionS, 12.5);
      expect(analysis.ppm, 130.5);
      expect(analysis.ritmo, [120.0, 135.5]);
      expect(analysis.muletillas, {'eh': 3});
    });
  });

  group('utilidades del modelo', () {
    test('averagePpm ignora las ventanas finales en cero', () {
      expect(averagePpm([120, 0, 140, 0]), 130);
      expect(averagePpm([0, 0]), isNull);
      expect(averagePpm([]), isNull);
    });

    test('clampScore limita el rango de 0 a 10', () {
      expect(clampScore(null), isNull);
      expect(clampScore(-2), 0);
      expect(clampScore(7.5), 7.5);
      expect(clampScore(14), 10);
    });
  });

  group('AnalysisSummary', () {
    test('parsea la lista y limpia la extensión del nombre', () {
      final summary = AnalysisSummary.fromJson({
        'id': 'abc',
        'filename': 'ensayo final.m4a',
        'created_at': '2026-10-23T15:04:05Z',
        'duracion_s': 312.4,
        'ppm': 128.5,
        'total_muletillas': 13,
      });

      expect(summary.id, 'abc');
      expect(summary.cleanName, 'ensayo final');
      expect(summary.createdAt, DateTime.parse('2026-10-23T15:04:05Z'));
      expect(summary.duracionS, 312.4);
      expect(summary.ppm, 128.5);
      expect(summary.totalMuletillas, 13);
      expect(summary.isDemo, isFalse);
      expect(summary.toJson()['filename'], 'ensayo final.m4a');
    });

    test('usa valores seguros cuando faltan campos', () {
      final summary = AnalysisSummary.fromJson({});
      expect(summary.id, '');
      expect(summary.filename, 'Audio sin nombre');
      expect(summary.cleanName, 'Audio sin nombre');
      expect(summary.createdAt, isNull);
      expect(summary.duracionS, isNull);
      expect(summary.totalMuletillas, 0);
    });
  });
}

final Map<String, dynamic> _fullJson = {
  'id': '6f1c2d3e-4a5b-6c7d-8e9f-0a1b2c3d4e5f',
  'creado_en': '2026-10-23T15:04:05.123456Z',
  'duracion_s': 312.4,
  'ppm': 128.5,
  'ritmo': [131.0, 120.0, 140.0],
  'pausas': {
    'pausas_largas': 4,
    'segundos_en_pausas': 9.6,
    'pausa_maxima_s': 3.1,
    'pausas_por_minuto': 0.8,
  },
  'muletillas': {'eh': 7, 'o sea': 4, 'entonces': 2},
  'muletillas_por_minuto': 2.5,
  'transcripcion_recortada': false,
  'coherencia': {
    'windows': 12,
    'mean_adjacent_similarity': 0.52,
    'topic_jumps': [4],
    'repeated_pairs': [
      {'a': 2, 'b': 9, 'similarity': 0.88},
    ],
  },
  'eventos_acusticos': {
    'muletillas': [
      {
        'start': 12.3,
        'end': 12.8,
        'texto': 'eh',
        'source': 'both',
        'confianza': 'alta',
      },
    ],
    'tarareos': [
      {'start': 40.1, 'end': 41.0, 'confidence': 0.82},
    ],
  },
  'advertencias': [],
  'modelos_usados': [
    'groq:openai/gpt-oss-20b',
    'groq:openai/gpt-oss-120b',
  ],
  'modelos_fallidos': <String, dynamic>{},
  'puntajes': {
    'organizacion': {'mediana': 7, 'min': 6, 'max': 8, 'desacuerdo': false},
    'claridad': {'mediana': 6, 'min': 5, 'max': 7, 'desacuerdo': false},
    'repeticion': {'mediana': 5, 'min': 3, 'max': 7, 'desacuerdo': true},
  },
  'sintesis': {
    'resumen': 'La exposición tiene una estructura reconocible.',
    'fortalezas': ['Presenta la idea principal.', 'Mantiene el hilo.'],
    'aspectos_por_mejorar': ['Repite una idea al pasar al ejemplo.'],
    'recomendaciones': ['Practica la transición entre tus ideas.'],
  },
  'evidencias': [
    {
      'afirmacion': 'La introducción presenta el tema con claridad.',
      'cita': 'Hoy quiero explicarles cómo la retroalimentación cambia.',
      'verificada': true,
    },
  ],
  'verificacion': {'tasa': 0.83, 'descartadas': 2},
  'por_modelo': {
    'groq:openai/gpt-oss-20b': {
      'organizacion': {'puntaje': 7, 'comentario': 'Clara.'},
    },
  },
};
