import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/preferences_controller.dart';
import 'state/analysis_controller.dart';
import 'state/history_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = PreferencesController();
  await preferences.init();

  final api = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    userId: preferences.userId,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferencesController>.value(value: preferences),
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
}
