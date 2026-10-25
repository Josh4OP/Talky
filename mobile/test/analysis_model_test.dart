import 'package:flutter_test/flutter_test.dart';
import 'package:talky/core/formatters.dart';
import 'package:talky/models/analysis.dart';
import 'package:talky/models/analysis_summary.dart';
import 'package:talky/widgets/charts.dart';

import 'support/fakes.dart';

void main() {
  group('Analysis.fromJson', () {
    test('parses the full contract example', () {
      final a = Analysis.fromJson(fullAnalysisJson());
      expect(a.durationS, 312.4);
      expect(a.rhythm, [131.0, 120.0, 140.0]);
      expect(a.pauses!.longPauses, 4);
      expect(a.fillers, {'eh': 7, 'o sea': 4, 'entonces': 2});
      expect(a.totalFillers, 13);
      expect(a.scores['repeticion']!.disagreement, isTrue);
      expect(a.synthesis!.recommendations, hasLength(1));
      expect(a.evidences.single.quote, 'por ejemplo en mi casa');
      expect(a.acousticEvents!.hums.single.startS, 40.1);
      expect(a.coherence!.topicJumps, 1);
      expect(a.verification!.rate, 0.83);
      expect(a.createdAt, DateTime.utc(2026, 10, 23, 15, 4, 5, 123, 456));
    });

    test('tolerates optional stages set to null', () {
      final a = Analysis.fromJson(minimalAnalysisJson());
      expect([a.coherence, a.acousticEvents, a.verification], everyElement(isNull));
      expect(a.scores, hasLength(3));
    });

    test('tolerates missing keys and nulls in metrics', () {
      final a = Analysis.fromJson({'id': 'x', 'ppm': null, 'ritmo': null, 'sintesis': null});
      expect(a.wordsPerMinute, isNull);
      expect(a.rhythm, isEmpty);
      expect(a.synthesis, isNull);
      expect(a.totalFillers, 0);
    });

    test('verification rate may be null when there were no evidences', () {
      final json = fullAnalysisJson()..['verificacion'] = {'tasa': null, 'descartadas': 0};
      expect(Analysis.fromJson(json).verification!.rate, isNull);
    });
  });

  test('HistoryPage parses items and total', () {
    final page = HistoryPage.fromJson({
      'items': [
        {
          'id': 'a1',
          'filename': 'ensayo1.m4a',
          'created_at': '2026-10-23T15:04:05.123456Z',
          'duracion_s': null,
          'ppm': 128.5,
          'total_muletillas': 13,
        },
      ],
      'total': 7,
      'limit': 20,
      'offset': 0,
    });
    expect(page.total, 7);
    expect(page.items.single.durationS, isNull);
    expect(page.items.single.totalFillers, 13);
  });

  test('pace label follows the orientative ranges', () {
    expect(
      [Formatters.pace(100), Formatters.pace(130), Formatters.pace(170)],
      ['Ritmo lento', 'Ritmo adecuado', 'Ritmo rápido'],
    );
  });

  test('rhythm chart drops a trailing silent window', () {
    expect(RhythmChart.visibleWindows([104.0, 0.0]), [104.0]);
  });
}
