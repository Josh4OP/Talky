import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:talky/core/api_client.dart';
import 'package:talky/core/api_exception.dart';
import 'package:talky/core/config.dart';
import 'package:talky/state/analysis_controller.dart';
import 'package:talky/state/history_controller.dart';

import 'support/fakes.dart';

Map<String, Object?> item(String id) => {
  'id': id,
  'filename': '$id.m4a',
  'created_at': '2026-10-24T10:00:00.000000Z',
  'duracion_s': 60.0,
  'ppm': 120.0,
  'total_muletillas': 3,
};

void main() {
  group('AnalysisController', () {
    test('picking an audio enables analyze', () async {
      final c = AnalysisController(
        api: apiWith((_) async => http.Response('', 500)),
        pickAudio: () async => sampleAudio(),
      );
      await c.pick();
      expect(c.status, AnalysisStatus.picked);
      expect(c.canAnalyze, isTrue);
    });

    test('a file over 100 MB cannot be analyzed', () async {
      final big = AudioUpload(
        name: 'largo.wav',
        sizeBytes: AppConfig.maxUploadBytes + 1,
        open: () => const Stream.empty(),
      );
      final c = AnalysisController(api: apiWith((_) async => http.Response('', 500)), pickAudio: () async => big);
      await c.pick();
      expect(c.tooLarge, isTrue);
      expect(c.canAnalyze, isFalse);
    });

    test('a successful analysis stores the result and clears the audio', () async {
      final c = AnalysisController(
        api: apiWith((_) async => jsonResponse(fullAnalysisJson(), 201)),
        pickAudio: () async => sampleAudio(),
      );
      await c.pick();
      final result = await c.analyze();
      expect(result?.id, '6f1c');
      expect(c.status, AnalysisStatus.done);
      expect(c.audio, isNull);
    });

    test('a failed analysis keeps the audio and exposes the error', () async {
      final c = AnalysisController(
        api: apiWith((_) async => jsonResponse({'detail': 'No se detectó voz en el audio'}, 422)),
        pickAudio: () async => sampleAudio(),
      );
      await c.pick();
      expect(await c.analyze(), isNull);
      expect(c.status, AnalysisStatus.failed);
      expect(c.error?.message, 'No se detectó voz en el audio');
      expect(c.audio, isNotNull);
    });
  });

  group('HistoryController', () {
    test('loads pages until reaching the total', () async {
      final h = HistoryController(
        preferences: memoryPreferences(),
        api: apiWith((request) async {
          final offset = int.parse(request.url.queryParameters['offset']!);
          return jsonResponse({
            'items': [item('a$offset')],
            'total': 2,
          }, 200);
        }),
      );
      await h.refresh();
      expect(h.hasMore, isTrue);
      await h.loadMore();
      expect(h.items.length, 2);
      expect(h.hasMore, isFalse);
    });

    test('delete restores the item when the API fails', () async {
      final h = HistoryController(
        preferences: memoryPreferences(),
        api: apiWith((request) async {
          if (request.method == 'DELETE') return jsonResponse({'detail': 'error'}, 500);
          return jsonResponse({
            'items': [item('a'), item('b')],
            'total': 2,
          }, 200);
        }),
      );
      await h.refresh();
      await expectLater(h.delete(h.items.first), throwsA(isA<ApiException>()));
      expect(h.items.map((i) => i.id).toList(), ['a', 'b']);
      expect(h.total, 2);
    });

    test('delete treats 404 as already deleted', () async {
      final h = HistoryController(
        preferences: memoryPreferences(),
        api: apiWith((request) async {
          if (request.method == 'DELETE') return jsonResponse({'detail': 'Análisis no encontrado.'}, 404);
          return jsonResponse({
            'items': [item('a')],
            'total': 1,
          }, 200);
        }),
      );
      await h.refresh();
      await h.delete(h.items.first);
      expect(h.items, isEmpty);
      expect(h.total, 0);
    });

    test('a load error is kept for the screen', () async {
      final h = HistoryController(
        preferences: memoryPreferences(),
        api: apiWith((_) async => throw http.ClientException('sin red')),
      );
      await h.refresh();
      expect(h.error?.isConnection, isTrue);
      expect(h.loading, isFalse);
    });
  });
}
