import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky/app.dart';
import 'package:talky/core/api_client.dart';
import 'package:talky/core/preferences_controller.dart';
import 'package:talky/data/demo_data.dart';
import 'package:talky/screens/result_screen.dart';
import 'package:talky/state/analysis_controller.dart';
import 'package:talky/state/history_controller.dart';
import 'package:talky/theme/app_theme.dart';

void main() {
  testWidgets('la bienvenida lleva al inicio con navegación inferior',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesController();
    await preferences.init();

    final api = ApiClient(
      baseUrl: 'http://api.test',
      userId: preferences.userId,
      client: MockClient((request) async {
        expect(request.headers['X-User-Id'], preferences.userId);
        return http.Response(
          jsonEncode({
            'items': <Map<String, dynamic>>[],
            'total': 0,
            'limit': 20,
            'offset': 0,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferencesController>.value(
            value: preferences,
          ),
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<AnalysisController>(
            create: (_) => AnalysisController(api),
          ),
          ChangeNotifierProvider<HistoryController>(
            create: (_) => HistoryController(api, preferences),
          ),
        ],
        child: const TalkyApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.textContaining('Habla con confianza', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Comenzar'), findsOneWidget);

    await tester.tap(find.text('Comenzar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Análisis recientes'), findsOneWidget);
  });

  testWidgets('el resultado de ejemplo se marca y muestra sus secciones',
      (tester) async {
    final analysis = DemoData.analysis();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ResultScreen(analysis: analysis),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Así te escuchó'), findsOneWidget);
    expect(find.textContaining('Este resultado es un ejemplo'), findsOneWidget);
    expect(find.text('Organización'), findsOneWidget);
    expect(find.text('Claridad'), findsOneWidget);
    expect(find.text('Repetición'), findsOneWidget);
    expect(find.text('Fortalezas'), findsOneWidget);
    expect(
      find.textContaining('Presentas la idea principal'),
      findsOneWidget,
    );
  });
}
