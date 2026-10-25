import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talky/core/api_client.dart';
import 'package:talky/core/api_exception.dart';

void main() {
  group('ApiClient.uploadAnalysis', () {
    test('envía X-User-Id y el archivo como multipart', () async {
      http.Request? captured;
      final api = _client((request) async {
        captured = request;
        return http.Response(
          jsonEncode(_analysisJson),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final analysis = await api.uploadAnalysis(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        filename: 'ensayo.m4a',
      );

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.toString(), 'http://api.test/analyses');
      expect(captured!.headers['X-User-Id'], 'talky-test');
      expect(
        captured!.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );

      final body = utf8.decode(captured!.bodyBytes, allowMalformed: true);
      expect(body, contains('name="file"'));
      expect(body, contains('filename="ensayo.m4a"'));

      expect(analysis.id, 'analisis-1');
      expect(analysis.ppm, 128.5);
      expect(analysis.muletillas['eh'], 7);
    });

    test('traduce un 400 con el detalle de la API', () async {
      final api = _client(
        (_) async => http.Response(
          jsonEncode({'detail': 'Extensión no admitida.'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await expectLater(
        api.uploadAnalysis(
          bytes: Uint8List.fromList([1]),
          filename: 'audio.exe',
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having((error) => error.message, 'message', 'Extensión no admitida.')
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('traduce un 422 conservando el detalle', () async {
      final api = _client(
        (_) async => http.Response(
          jsonEncode({'detail': 'El audio no contiene voz.'}),
          422,
        ),
      );

      await expectLater(
        api.uploadAnalysis(
          bytes: Uint8List.fromList([1]),
          filename: 'silencio.wav',
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having((error) => error.message, 'message', 'El audio no contiene voz.')
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('un 503 produce un mensaje amigable y reintentable', () async {
      final api = _client(
        (_) async => http.Response(
          jsonEncode({'detail': 'Sin proveedores.'}),
          503,
        ),
      );

      await expectLater(
        api.uploadAnalysis(
          bytes: Uint8List.fromList([1]),
          filename: 'audio.wav',
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.retryable, 'retryable', isTrue)
              .having(
                (error) => error.message,
                'message',
                contains('no está disponible'),
              ),
        ),
      );
    });

    test('un fallo de red se convierte en ApiException', () async {
      final api = _client(
        (_) async => throw http.ClientException('sin conexión'),
      );

      await expectLater(
        api.uploadAnalysis(
          bytes: Uint8List.fromList([1]),
          filename: 'audio.wav',
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('No pudimos conectar'),
          ),
        ),
      );
    });
  });

  group('ApiClient.historial', () {
    test('envía paginación e identidad y parsea la lista', () async {
      http.Request? captured;
      final api = _client((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'abc',
                'filename': 'ensayo final.m4a',
                'created_at': '2026-10-23T15:04:05Z',
                'duracion_s': 312.4,
                'ppm': 128.5,
                'total_muletillas': 13,
              },
            ],
            'total': 7,
            'limit': 20,
            'offset': 20,
          }),
          200,
        );
      });

      final page = await api.fetchHistory(limit: 20, offset: 20);

      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/analyses');
      expect(captured!.url.queryParameters['limit'], '20');
      expect(captured!.url.queryParameters['offset'], '20');
      expect(captured!.headers['X-User-Id'], 'talky-test');

      expect(page.total, 7);
      expect(page.limit, 20);
      expect(page.offset, 20);
      expect(page.items.single.cleanName, 'ensayo final');
      expect(page.items.single.totalMuletillas, 13);
    });

    test('limita el parámetro limit al rango de la API', () async {
      Uri? captured;
      final api = _client((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({'items': [], 'total': 0, 'limit': 100, 'offset': 0}),
          200,
        );
      });

      await api.fetchHistory(limit: 500);

      expect(captured!.queryParameters['limit'], '100');
    });

    test('borra con DELETE y acepta 204', () async {
      http.Request? captured;
      final api = _client((request) async {
        captured = request;
        return http.Response('', 204);
      });

      await api.deleteAnalysis('abc123');

      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/analyses/abc123');
      expect(captured!.headers['X-User-Id'], 'talky-test');
    });

    test('un 404 al abrir un análisis se traduce', () async {
      final api = _client(
        (_) async => http.Response(
          jsonEncode({'detail': 'No encontrado.'}),
          404,
        ),
      );

      await expectLater(
        api.fetchAnalysis('no-existe'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.retryable, 'retryable', isFalse)
              .having(
                (error) => error.message,
                'message',
                'Ese análisis ya no está disponible.',
              ),
        ),
      );
    });
  });

  group('ApiClient.checkHealth', () {
    test('detecta un servidor en línea', () async {
      final api = _client(
        (_) async => http.Response(jsonEncode({'status': 'ok'}), 200),
      );

      final health = await api.checkHealth();

      expect(health.online, isTrue);
      expect(health.message, 'Servidor disponible.');
    });

    test('informa un estado HTTP inesperado sin lanzar', () async {
      final api = _client((_) async => http.Response('error', 500));

      final health = await api.checkHealth();

      expect(health.online, isFalse);
      expect(health.message, contains('500'));
    });
  });
}

ApiClient _client(MockClientHandler handler) {
  return ApiClient(
    baseUrl: 'http://api.test/',
    userId: 'talky-test',
    client: MockClient(handler),
    timeout: const Duration(seconds: 5),
  );
}

final Map<String, dynamic> _analysisJson = {
  'id': 'analisis-1',
  'creado_en': '2026-10-23T15:04:05Z',
  'duracion_s': 312.4,
  'ppm': 128.5,
  'ritmo': [131.0, 120.0],
  'muletillas': {'eh': 7, 'o sea': 4},
  'muletillas_por_minuto': 2.5,
};
