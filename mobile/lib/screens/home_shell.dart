import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/history_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Pestañas principales: Inicio, Historial y Perfil. En pantallas anchas usa una barra lateral.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Ancho desde el que se muestra la barra lateral (web y escritorio).
  static const wideBreakpoint = 840.0;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _tab = 0;

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.history_rounded, Icons.history_rounded, 'Historial'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = context.read<ApiClient>().session;
      if (session.startedNewIdentity) {
        session.startedNewIdentity = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu sesión anterior venció. Empezamos un historial nuevo en este teléfono.')),
        );
      }
    });
  }

  void _select(int tab) {
    if (tab == 1) context.read<HistoryController>().refresh();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _tab,
      children: [
        HomeScreen(onShowHistory: () => _select(1)),
        HistoryScreen(onGoHome: () => _select(0)),
        const ProfileScreen(),
      ],
    );
    final wide = MediaQuery.sizeOf(context).width >= HomeShell.wideBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: _select,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.tint20,
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: AppColors.action),
              unselectedIconTheme: const IconThemeData(color: AppColors.inkMuted),
              selectedLabelTextStyle: AppText.caption.copyWith(color: AppColors.action),
              unselectedLabelTextStyle: AppText.caption.copyWith(color: AppColors.inkMuted),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Image.asset('assets/mascot/logo_blue.png', width: 64, semanticLabel: 'Talky'),
              ),
              destinations: [
                for (final (icon, selected, label) in _destinations)
                  NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
              ],
            ),
            Expanded(child: pages),
          ],
        ),
      );
    }
    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: [
          for (final (icon, selected, label) in _destinations)
            NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
        ],
      ),
    );
  }
}
