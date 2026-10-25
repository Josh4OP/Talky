import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/analysis.dart';
import 'api_exception.dart';
import 'config.dart';

/// Cliente delgado de la API v1. No procesa audio: solo lo envía y lee el
/// resultado. Cada petición identificada lleva `X-User-Id`.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.userId,
    http.Client? client,
    Duration? timeout,
  })  : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _timeout = timeout ?? AppConfig.requestTimeout;

  final String baseUrl;
  final String userId;
  final http.Client _client;
  final Duration _timeout;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Map<String, String> get _identityHeaders => {'X-User-Id': userId};

  Future<Analysis> uploadAnalysis({
    required Uint8List bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/analyses'))
      ..headers.addAll(_identityHeaders)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final response = await _send(request);
    _ensure(response, expected: 201);
    return Analysis.fromJson(_decode(response));
  }

  Future<AnalysisPage> fetchHistory({int limit = 20, int offset = 0}) async {
    final response = await _get(
      _uri('/analyses', {
        'limit': limit.clamp(1, 100).toString(),
        'offset': offset.toString(),
      }),
    );
    _ensure(response, expected: 200);
    return AnalysisPage.fromJson(_decode(response));
  }

  Future<Analysis> fetchAnalysis(String id) async {
    final response = await _get(
      _uri('/analyses/${Uri.encodeComponent(id)}'),
    );
    _ensure(response, expected: 200);
    return Analysis.fromJson(_decode(response));
  }

  Future<void> deleteAnalysis(String id) async {
    final request = http.Request(
      'DELETE',
      _uri('/analyses/${Uri.encodeComponent(id)}'),
    )..headers.addAll(_identityHeaders);
    final response = await _send(request);
    _ensure(response, expected: 204);
  }

  /// Comprueba que el servidor esté en línea. No requiere identidad.
  Future<HealthResult> checkHealth() async {
    try {
      final response = await _client
          .get(_uri('/health'))
          .timeout(AppConfig.connectivityTimeout);
      if (response.statusCode != 200) {
        return HealthResult(
          online: false,
          message: 'El servidor respondió con estado ${response.statusCode}.',
        );
      }
      final body = _decode(response);
      final status = body['status']?.toString() ?? 'ok';
      return HealthResult(
        online: status == 'ok',
        message: status == 'ok'
            ? 'Servidor disponible.'
            : 'El servidor reporta un estado inesperado.',
      );
    } on TimeoutException {
      return const HealthResult(
        online: false,
        message: 'El servidor no respondió a tiempo.',
      );
    } catch (_) {
      return const HealthResult(
        online: false,
        message: 'No se pudo conectar con el servidor.',
      );
    }
  }

  Future<http.Response> _get(Uri uri) async {
    final request = http.Request('GET', uri)..headers.addAll(_identityHeaders);
    return _send(request);
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException.timeout();
    } on http.ClientException {
      throw ApiException.network();
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException.network();
    }
  }

  void _ensure(http.Response response, {required int expected}) {
    if (response.statusCode == expected) return;
    throw ApiException.fromStatus(response.statusCode, _detail(response));
  }

  String? _detail(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map) return null;
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) return body;
      if (body is Map) return Map<String, dynamic>.from(body);
      throw const ApiException(
        message: 'El servidor devolvió una respuesta que no pudimos interpretar.',
        retryable: true,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        message: 'El servidor devolvió una respuesta que no pudimos interpretar.',
        retryable: true,
      );
    }
  }

  void close() => _client.close();
}

class HealthResult {
  const HealthResult({required this.online, required this.message});

  final bool online;
  final String message;
}
