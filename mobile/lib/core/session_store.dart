import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exception.dart';
import 'config.dart';

/// Token de sesión de dispositivo (T19) y su vencimiento.
class Session {
  const Session(this.token, this.expiresAt);

  final String token;
  final DateTime expiresAt;
}

/// Dónde se guarda la sesión; en pruebas se reemplaza por una en memoria.
abstract class SessionStorage {
  Future<Session?> read();
  Future<void> write(Session session);
}

class PreferencesSessionStorage implements SessionStorage {
  static const _tokenKey = 'talky.session.token';
  static const _expiresKey = 'talky.session.expires_at';

  @override
  Future<Session?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final expires = prefs.getInt(_expiresKey);
    if (token == null || expires == null) return null;
    return Session(token, DateTime.fromMillisecondsSinceEpoch(expires, isUtc: true));
  }

  @override
  Future<void> write(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setInt(_expiresKey, session.expiresAt.millisecondsSinceEpoch);
  }
}

/// Obtiene, guarda y renueva el token de sesión con `POST /auth/token` y `POST /auth/refresh`.
class SessionStore {
  SessionStore({
    required http.Client client,
    required Uri baseUrl,
    required SessionStorage storage,
    DateTime Function()? clock,
  }) : _client = client,
       _baseUrl = baseUrl,
       _storage = storage,
       _clock = clock ?? (() => DateTime.now().toUtc());

  final http.Client _client;
  final Uri _baseUrl;
  final SessionStorage _storage;
  final DateTime Function() _clock;
  Session? _current;

  /// Verdadero si hubo que crear una identidad nueva porque la anterior venció.
  bool startedNewIdentity = false;

  /// Devuelve un token válido: lo crea si no hay y lo renueva si está por vencer.
  Future<String> token() async {
    final session = _current ??= await _storage.read();
    if (session == null) return (await _issue()).token;
    final remaining = session.expiresAt.difference(_clock());
    if (remaining <= Duration.zero) {
      startedNewIdentity = true;
      return (await _issue()).token;
    }
    if (remaining < AppConfig.renewBefore) return (await _refresh(session)).token;
    return session.token;
  }

  /// Vencimiento de la sesión guardada; `null` si todavía no hay sesión.
  Future<DateTime?> expiresAt() async => (_current ??= await _storage.read())?.expiresAt;

  /// Tras un 401: intenta renovar; si el servidor rechaza el token, crea una identidad nueva.
  Future<String> recover() async {
    final session = _current ??= await _storage.read();
    if (session != null) {
      try {
        return (await _refresh(session)).token;
      } on ApiException catch (e) {
        if (e.statusCode != 401) rethrow;
      }
    }
    startedNewIdentity = session != null;
    return (await _issue()).token;
  }

  Future<Session> _issue() => _post('/auth/token', const {});

  Future<Session> _refresh(Session session) => _post('/auth/refresh', {'Authorization': 'Bearer ${session.token}'});

  Future<Session> _post(String path, Map<String, String> headers) async {
    final http.Response response;
    try {
      response = await _client.post(_baseUrl.resolve(path), headers: headers).timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.connection();
    } on http.ClientException {
      throw ApiException.connection();
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException.fromResponse(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final session = Session(
      body['access_token'] as String,
      _clock().add(Duration(seconds: (body['expires_in'] as num).toInt())),
    );
    await _storage.write(session);
    _current = session;
    return session;
  }
}
