import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/audio_picker.dart';
import 'screens/home_shell.dart';
import 'screens/splash_to_home.dart';
import 'state/analysis_controller.dart';
import 'state/history_controller.dart';
import 'theme/app_theme.dart';

class TalkyApp extends StatelessWidget {
  const TalkyApp({super.key, required this.api, this.pickAudio = pickAudioFile});

  final ApiClient api;
  final Future<AudioUpload?> Function() pickAudio;

  /// Antes de mostrar el inicio: comprobar el servidor y tener una sesión válida.
  Future<void> _loadApp() async {
    await api.health();
    await api.session.token();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider(
          create: (_) => AnalysisController(api: api, pickAudio: pickAudio),
        ),
        ChangeNotifierProvider(create: (_) => HistoryController(api: api)),
      ],
      child: MaterialApp(
        title: 'Talky',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: SplashToHome(loadApp: _loadApp, home: const HomeShell()),
      ),
    );
  }
}
