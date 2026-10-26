import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/audio_picker.dart';
import 'screens/home_shell.dart';
import 'screens/splash_to_home.dart';
import 'screens/welcome_screen.dart';
import 'state/analysis_controller.dart';
import 'state/history_controller.dart';
import 'state/preferences_controller.dart';
import 'theme/app_theme.dart';

class TalkyApp extends StatelessWidget {
  const TalkyApp({super.key, required this.api, required this.preferences, this.pickAudio = pickAudioFile});

  final ApiClient api;
  final PreferencesController preferences;
  final Future<AudioUpload?> Function() pickAudio;

  /// Antes de mostrar el inicio: leer preferencias, comprobar el servidor y tener una sesión válida.
  Future<void> _loadApp() async {
    await preferences.load();
    await api.health();
    await api.session.token();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: preferences),
        ChangeNotifierProvider(
          create: (_) => AnalysisController(api: api, pickAudio: pickAudio),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryController(api: api, preferences: preferences),
        ),
      ],
      child: Consumer<PreferencesController>(
        builder: (context, prefs, _) => MaterialApp(
          title: 'Talky',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          // "Reducir animaciones" de Perfil se suma a la preferencia del sistema.
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(disableAnimations: media.disableAnimations || prefs.reduceMotion),
              child: child!,
            );
          },
          home: SplashToHome(loadApp: _loadApp, home: const _Gate()),
        ),
      ),
    );
  }
}

/// Muestra la bienvenida la primera vez y después las pestañas principales.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesController>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: prefs.welcomeSeen
          ? const HomeShell(key: ValueKey('shell'))
          : WelcomeScreen(key: const ValueKey('welcome'), onStart: () => prefs.setWelcomeSeen(true)),
    );
  }
}
