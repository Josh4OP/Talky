import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:talky/data/demo_data.dart';
import 'package:talky/models/analysis.dart';
import 'package:talky/screens/processing_screen.dart';
import 'package:talky/screens/welcome_screen.dart';
import 'package:talky/state/history_controller.dart';
import 'package:talky/state/preferences_controller.dart';

import 'support/fakes.dart';

/// Funciones rescatadas de la primera versión del front (commit 6e6c53b).
Map<String, Object?> item(String id, String name, {double? ppm, int fillers = 0}) => {
  'id': id,
  'filename': name,
  'created_at': '2026-10-24T10:00:00.000000Z',
  'duracion_s': 60.0,
  'ppm': ppm,
  'total_muletillas': fillers,
};

HistoryController historyWith(List<Map<String, Object?>> items, {bool demo = false}) {
  final prefs = memoryPreferences()..demoMode = demo;
  return HistoryController(
    preferences: prefs,
    api: apiWith((_) async => jsonResponse({'items': items, 'total': items.length}, 200)),
  );
}

void main() {
  group('preferences', () {
    test('start with welcome pending, demo off and motion on', () async {
      final prefs = memoryPreferences();
      await prefs.load();
      expect(prefs.welcomeSeen, isFalse);
      expect(prefs.demoMode, isFalse);
      expect(prefs.reduceMotion, isFalse);
    });

    test('changes persist across controllers', () async {
      final storage = MemoryPreferencesStorage();
      final prefs = PreferencesController(storage: storage);
      await prefs.setWelcomeSeen(true);
      await prefs.setDemoMode(true);
      final reloaded = PreferencesController(storage: storage);
      await reloaded.load();
      expect(reloaded.welcomeSeen, isTrue);
      expect(reloaded.demoMode, isTrue);
    });
  });

  group('demo data', () {
    test('every demo item is marked as example', () {
      expect(DemoData.summaries.every((s) => s.isDemo), isTrue);
      expect(DemoData.analysis().isDemo, isTrue);
    });

    test('demo result has every section the result screen shows', () {
      final a = DemoData.analysis();
      expect(a.synthesis!.recommendations, isNotEmpty);
      expect(a.scores.values.every((s) => s.min != null && s.max != null), isTrue);
      expect(a.coherence, isNotNull);
      expect(a.evidences, isNotEmpty);
    });
  });

  group('history', () {
    test('search filters by file name without case', () async {
      final h = historyWith([item('a', 'Clase_Final.m4a'), item('b', 'entrevista.wav')]);
      await h.refresh();
      h.search('clase');
      expect(h.visibleItems.map((i) => i.id), ['a']);
    });

    test('stats average the words per minute that exist and add fillers', () async {
      final h = historyWith([
        item('a', 'a.m4a', ppm: 100, fillers: 3),
        item('b', 'b.m4a', ppm: 140, fillers: 5),
        item('c', 'c.m4a', fillers: 1),
      ]);
      await h.refresh();
      expect(h.averageWordsPerMinute, 120);
      expect(h.loadedFillers, 9);
    });

    test('demo mode shows example items without calling the API', () async {
      final prefs = memoryPreferences()..demoMode = true;
      final h = HistoryController(
        preferences: prefs,
        api: apiWith((_) async => throw http.ClientException('no debería llamar')),
      );
      await h.refresh();
      expect(h.showingDemo, isTrue);
      expect(h.items.every((i) => i.isDemo), isTrue);
      expect((await h.open(h.items.first)).isDemo, isTrue);
    });

    test('turning demo mode off reloads real data', () async {
      final prefs = memoryPreferences()..demoMode = true;
      final h = HistoryController(
        preferences: prefs,
        api: apiWith(
          (_) async => jsonResponse({
            'items': [item('r', 'real.m4a')],
            'total': 1,
          }, 200),
        ),
      );
      await h.refresh();
      await prefs.setDemoMode(false);
      await Future<void>.delayed(Duration.zero);
      expect(h.items.map((i) => i.id), ['r']);
    });
  });

  testWidgets('welcome shows the original copy and starts on tap', (tester) async {
    var started = false;
    await tester.pumpWidget(MaterialApp(home: WelcomeScreen(onStart: () => started = true)));
    expect(find.text('TU COMPAÑERO DE ORATORIA'), findsOneWidget);
    expect(find.text('Tu audio no se guarda'), findsOneWidget);
    await tester.ensureVisible(find.text('Comenzar'));
    await tester.tap(find.text('Comenzar'));
    expect(started, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('processing closes with true when the analysis fails', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pending = Completer<Analysis?>();
    Object? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => popped = await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => ProcessingScreen(pending: pending.future))),
              child: const Text('ir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Mientras esperas'), findsOneWidget);
    pending.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(popped, isTrue);
  });
}
