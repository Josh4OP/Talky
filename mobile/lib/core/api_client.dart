import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/analysis.dart';
import '../models/analysis_summary.dart';
import 'api_exception.dart';
import 'config.dart';
import 'session_store.dart';

/// Audio elegido por la persona. `open` crea un flujo nuevo cada vez, para poder reintentar el envío.
class AudioUpload {
  const AudioUpload({required this.name, required this.sizeBytes, required this.open});

  final String name;
  final int sizeBytes;
  final Stream<List<int>> Function() open;
}

/// Cliente de la API v1 con sesión Bearer (T19). Ante un 401 renueva la sesión una vez y repite.
class ApiClient {
  ApiClient({required http.Client client, required Uri baseUrl, required SessionStore session})
    : _client = client,
      _baseUrl = baseUrl,
      _session = session;

  final http.Client _client;
  final Uri _baseUrl;
  final SessionStore _session;

  SessionStore get session => _session;

  Future<void> health() async {
    final response = await _guard(() => _client.get(_baseUrl.resolve('/health')), AppConfig.requestTimeout);
    if (response.statusCode != 200) throw ApiException.fromResponse(response.statusCode, response.body);
  }

  Future<Analysis> analyze(AudioUpload audio) async {
    final response = await _authorized((token) async {
      final request = http.MultipartRequest('POST', _baseUrl.resolve('/analyses'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile('file', audio.open(), audio.sizeBytes, filename: audio.name));
      return http.Response.fromStream(await _client.send(request));
    }, AppConfig.analyzeTimeout);
    return Analysis.fromJson(_json(response, 201));
  }

  Future<HistoryPage> listAnalyses({int limit = 20, int offset = 0}) async {
    final uri = _baseUrl.resolve('/analyses').replace(queryParameters: {'limit': '$limit', 'offset': '$offset'});
    final response = await _authorized((token) => _client.get(uri, headers: _auth(token)), AppConfig.requestTimeout);
    return HistoryPage.fromJson(_json(response, 200));
  }

  Future<Analysis> getAnalysis(String id) async {
    final uri = _baseUrl.resolve('/analyses/${Uri.encodeComponent(id)}');
    final response = await _authorized((token) => _client.get(uri, headers: _auth(token)), AppConfig.requestTimeout);
    return Analysis.fromJson(_json(response, 200));
  }

  Future<void> deleteAnalysis(String id) async {
    final uri = _baseUrl.resolve('/analyses/${Uri.encodeComponent(id)}');
    final response = await _authorized((token) => _client.delete(uri, headers: _auth(token)), AppConfig.requestTimeout);
    if (response.statusCode != 204) throw ApiException.fromResponse(response.statusCode, response.body);
  }

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token'};

  Future<http.Response> _authorized(Future<http.Response> Function(String token) send, Duration timeout) async {
    final response = await _guard(() async => send(await _session.token()), timeout);
    if (response.statusCode != 401) return response;
    return _guard(() async => send(await _session.recover()), timeout);
  }

  Future<http.Response> _guard(Future<http.Response> Function() call, Duration timeout) async {
    try {
      return await call().timeout(timeout);
    } on TimeoutException {
      throw timeout == AppConfig.analyzeTimeout ? ApiException.timeout() : ApiException.connection();
    } on http.ClientException {
      throw ApiException.connection();
    }
  }

  Map<String, dynamic> _json(http.Response response, int expected) {
    if (response.statusCode != expected) throw ApiException.fromResponse(response.statusCode, response.body);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
