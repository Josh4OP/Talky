import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/history_controller.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// Pestañas principales: Inicio e Historial.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _tab = 0;

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
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onShowHistory: () => _select(1)),
          HistoryScreen(onGoHome: () => _select(0)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Historial'),
        ],
      ),
    );
  }
}
