import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/preferences_controller.dart';
import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/app_background.dart';
import 'widgets/talky_logo.dart';
import 'widgets/talky_mascot.dart';

/// Raíz de TALKY. El tema y las rutas viven aquí; la identidad y el estado se
/// inyectan desde `main.dart` con `provider`.
class TalkyApp extends StatelessWidget {
  const TalkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TALKY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<PreferencesController>();

    if (!preferences.ready) {
      return const _SplashScreen();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: preferences.onboardingComplete
          ? const HomeShell(key: ValueKey('home-shell'))
          : const WelcomeScreen(key: ValueKey('welcome')),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TalkyLogo(markSize: 56),
              const SizedBox(height: 30),
              const TalkyMascot(
                size: 190,
                pose: TalkyPose.welcome,
                backdrop: true,
                animate: true,
              ),
              const SizedBox(height: 22),
              Text(
                'Preparando a Talky…',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
              const SizedBox(height: 18),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
