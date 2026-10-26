import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/session_store.dart';
import 'state/preferences_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final client = http.Client();
  final baseUrl = Uri.parse(AppConfig.apiBaseUrl);
  final session = SessionStore(client: client, baseUrl: baseUrl, storage: PreferencesSessionStorage());
  runApp(
    TalkyApp(
      api: ApiClient(client: client, baseUrl: baseUrl, session: session),
      preferences: PreferencesController(storage: SharedPreferencesStorage()),
    ),
  );
}
