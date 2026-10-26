import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talky/core/api_client.dart';
import 'package:talky/core/session_store.dart';
import 'package:talky/state/preferences_controller.dart';

final baseUrl = Uri.parse('http://talky.test');

/// Sesión en memoria para no tocar `shared_preferences`.
class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([this.session]);

  Session? session;

  @override
  Future<Session?> read() async => session;

  @override
  Future<void> write(Session value) async => session = value;
}

http.Response jsonResponse(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

Map<String, Object?> tokenBody(String token, {int expiresIn = 30 * 86400}) => {
  'access_token': token,
  'token_type': 'bearer',
  'expires_in': expiresIn,
};

/// Cliente de API sobre un [MockClient] con una sesión vigente ya guardada.
ApiClient apiWith(MockClientHandler handler, {Session? session, DateTime? now}) {
  final client = MockClient(handler);
  final clock = now ?? DateTime.utc(2026, 10, 25);
  final store = SessionStore(
    client: client,
    baseUrl: baseUrl,
    storage: MemorySessionStorage(session ?? Session('token-1', clock.add(const Duration(days: 20)))),
    clock: () => clock,
  );
  return ApiClient(client: client, baseUrl: baseUrl, session: store);
}

AudioUpload sampleAudio() => AudioUpload(name: 'clase.m4a', sizeBytes: 4, open: () => Stream.value(const [1, 2, 3, 4]));

/// Ejemplo de `07-api-contract.md`.
Map<String, Object?> fullAnalysisJson() => {
  'id': '6f1c',
  'creado_en': '2026-10-23T15:04:05.123456Z',
  'duracion_s': 312.4,
  'ppm': 128.5,
  'ritmo': [131.0, 120.0, 140.0],
  'pausas': {'pausas_largas': 4, 'segundos_en_pausas': 9.6, 'pausa_maxima_s': 3.1, 'pausas_por_minuto': 0.8},
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
      {'start': 12.3, 'end': 12.8, 'texto': 'eh', 'source': 'both', 'confianza': 'alta'},
    ],
    'tarareos': [
      {'start': 40.1, 'end': 41.0, 'confidence': 0.82},
    ],
  },
  'advertencias': <String>[],
  'modelos_usados': ['groq:openai/gpt-oss-20b', 'groq:openai/gpt-oss-120b'],
  'modelos_fallidos': <String, String>{},
  'puntajes': {
    'organizacion': {'mediana': 7, 'min': 6, 'max': 8, 'desacuerdo': false},
    'claridad': {'mediana': 6, 'min': 5, 'max': 7, 'desacuerdo': false},
    'repeticion': {'mediana': 5, 'min': 3, 'max': 7, 'desacuerdo': true},
  },
  'sintesis': {
    'resumen': 'Buena estructura, cuida las muletillas.',
    'fortalezas': ['Cierre claro'],
    'aspectos_por_mejorar': ['Menos "o sea"'],
    'recomendaciones': ['Haz una pausa en lugar de decir "eh"'],
  },
  'evidencias': [
    {'afirmacion': 'Usa ejemplos', 'cita': 'por ejemplo en mi casa', 'verificada': true},
  ],
  'verificacion': {'tasa': 0.83, 'descartadas': 2},
  'por_modelo': <String, Object?>{},
};

/// El mismo resultado con las etapas opcionales apagadas.
Map<String, Object?> minimalAnalysisJson() => fullAnalysisJson()
  ..['coherencia'] = null
  ..['eventos_acusticos'] = null
  ..['verificacion'] = null;

/// Preferencias en memoria para no tocar `shared_preferences`.
class MemoryPreferencesStorage implements PreferencesStorage {
  final values = <String, bool>{};

  @override
  Future<bool?> readBool(String key) async => values[key];

  @override
  Future<void> writeBool(String key, bool value) async => values[key] = value;
}

PreferencesController memoryPreferences() => PreferencesController(storage: MemoryPreferencesStorage());
