import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/talky_logo.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Contenedor principal de la aplicación. En pantallas anchas usa una barra
/// lateral; en móvil, una barra inferior. Conserva el estado de cada pestaña.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final pages = IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              onOpenHistory: () => _select(1),
              onOpenProfile: () => _select(2),
            ),
            const HistoryScreen(),
            const ProfileScreen(),
          ],
        );

        if (wide) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: AppBackground(
              child: SafeArea(
                child: Row(
                  children: [
                    _SideRail(index: _index, onSelected: _select),
                    const VerticalDivider(width: 1),
                    Expanded(child: pages),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AppBackground(
            child: SafeArea(
              bottom: false,
              child: pages,
            ),
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: 'Historial',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 8),
            child: Tooltip(
              message: 'TALKY',
              child: TalkyMark(size: 40),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onSelected,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.55,
              minWidth: 100,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Inicio'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: Text('Historial'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Perfil'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
            child: Text(
              'Talky 1.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 0.4,
                    color: AppColors.inkMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
