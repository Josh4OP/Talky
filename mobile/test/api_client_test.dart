import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:talky/core/api_exception.dart';

import 'support/fakes.dart';

void main() {
  test('sends the bearer token and no X-User-Id', () async {
    late http.BaseRequest seen;
    final api = apiWith((request) async {
      seen = request;
      return jsonResponse({'items': [], 'total': 0}, 200);
    });
    await api.listAnalyses();
    expect(seen.headers['Authorization'], 'Bearer token-1');
    expect(seen.headers.containsKey('X-User-Id'), isFalse);
  });

  test('analyze posts multipart audio and parses 201', () async {
    final api = apiWith((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/analyses');
      expect(request.headers['content-type'], startsWith('multipart/form-data'));
      return jsonResponse(fullAnalysisJson(), 201);
    });
    final result = await api.analyze(sampleAudio());
    expect(result.id, '6f1c');
  });

  test('list uses limit and offset', () async {
    late Uri url;
    final api = apiWith((request) async {
      url = request.url;
      return jsonResponse({'items': [], 'total': 0}, 200);
    });
    await api.listAnalyses(limit: 20, offset: 40);
    expect(url.queryParameters, {'limit': '20', 'offset': '40'});
  });

  for (final status in [400, 413, 422]) {
    test('$status shows the API detail', () async {
      final api = apiWith((_) async => jsonResponse({'detail': 'Formato de audio no compatible.'}, status));
      await expectLater(
        api.analyze(sampleAudio()),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Formato de audio no compatible.')),
      );
    });
  }

  test('503 keeps the detail and says the audio was not stored', () async {
    final api = apiWith((_) async => jsonResponse({'detail': 'Los servicios no respondieron.'}, 503));
    await expectLater(
      api.analyze(sampleAudio()),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('no se guardó'))),
    );
  });

  test('401 refreshes the session once and repeats the request', () async {
    final calls = <String>[];
    final api = apiWith((request) async {
      calls.add('${request.method} ${request.url.path} ${request.headers['Authorization']}');
      if (request.url.path == '/auth/refresh') return jsonResponse(tokenBody('token-2'), 200);
      if (request.headers['Authorization'] == 'Bearer token-1') return jsonResponse({'detail': 'no'}, 401);
      return jsonResponse({'items': [], 'total': 0}, 200);
    });
    await api.listAnalyses();
    expect(calls, [
      'GET /analyses Bearer token-1',
      'POST /auth/refresh Bearer token-1',
      'GET /analyses Bearer token-2',
    ]);
  });

  test('a second 401 is reported as an expired session', () async {
    final api = apiWith((request) async {
      if (request.url.path == '/auth/refresh') return jsonResponse(tokenBody('token-2'), 200);
      return jsonResponse({'detail': 'no'}, 401);
    });
    await expectLater(api.listAnalyses(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
  });

  test('a network failure becomes a connection error', () async {
    final api = apiWith((_) async => throw http.ClientException('sin red'));
    await expectLater(api.health(), throwsA(isA<ApiException>().having((e) => e.isConnection, 'conn', isTrue)));
  });

  test('delete expects 204 and maps 404', () async {
    final api = apiWith((request) async => http.Response('{"detail":"Análisis no encontrado."}', 404));
    await expectLater(api.deleteAnalysis('x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
  });
}
