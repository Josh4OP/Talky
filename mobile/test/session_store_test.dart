import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talky/core/session_store.dart';

import 'support/fakes.dart';

final now = DateTime.utc(2026, 10, 25);

({SessionStore store, MemorySessionStorage storage, List<String> calls}) build(Session? saved) {
  final calls = <String>[];
  final storage = MemorySessionStorage(saved);
  final client = MockClient((request) async {
    calls.add('${request.url.path} ${request.headers['Authorization'] ?? '-'}');
    if (request.url.path == '/auth/token') return jsonResponse(tokenBody('nuevo'), 201);
    if (request.url.path == '/auth/refresh') {
      return request.headers['Authorization'] == 'Bearer vencido'
          ? http.Response('{"detail":"Tu sesión no es válida o venció."}', 401)
          : jsonResponse(tokenBody('renovado'), 200);
    }
    return http.Response('', 404);
  });
  final store = SessionStore(client: client, baseUrl: baseUrl, storage: storage, clock: () => now);
  return (store: store, storage: storage, calls: calls);
}

void main() {
  test('asks for a token when there is none and stores it', () async {
    final s = build(null);
    expect(await s.store.token(), 'nuevo');
    expect(s.calls, ['/auth/token -']);
    expect(s.storage.session!.expiresAt, now.add(const Duration(days: 30)));
  });

  test('refreshes when less than 7 days remain', () async {
    final s = build(Session('viejo', now.add(const Duration(days: 6))));
    expect(await s.store.token(), 'renovado');
    expect(s.calls, ['/auth/refresh Bearer viejo']);
  });

  test('does not refresh when more than 7 days remain', () async {
    final s = build(Session('vigente', now.add(const Duration(days: 8))));
    expect(await s.store.token(), 'vigente');
    expect(s.calls, isEmpty);
  });

  test('an expired token starts a new identity', () async {
    final s = build(Session('vencido', now.subtract(const Duration(minutes: 1))));
    expect(await s.store.token(), 'nuevo');
    expect(s.store.startedNewIdentity, isTrue);
  });

  test('recover refreshes, and falls back to a new identity when the server rejects the token', () async {
    final s = build(Session('vencido', now.add(const Duration(days: 20))));
    expect(await s.store.recover(), 'nuevo');
    expect(s.calls, ['/auth/refresh Bearer vencido', '/auth/token -']);
    expect(s.store.startedNewIdentity, isTrue);
  });
}
