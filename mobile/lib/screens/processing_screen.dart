import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/mascot/talky_mascot.dart';

/// Espera del análisis. La API no informa avance: los mensajes son ambientales, sin porcentaje.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  static const messages = [
    'Escuchando tu audio',
    'Contando muletillas',
    'Midiendo tu ritmo',
    'Los modelos están opinando',
    'Revisando las citas',
  ];

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  var _index = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      setState(() => _index = (_index + 1) % ProcessingScreen.messages.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.tint20, shape: BoxShape.circle),
                  child: const TalkyMascot(state: MascotState.thinking, size: 250),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text('Analizando tu exposición', style: AppText.title, textAlign: TextAlign.center),
                ),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '${ProcessingScreen.messages[_index]}...',
                      key: ValueKey(_index),
                      style: AppText.bodyStrong.copyWith(color: AppColors.action),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const _Dots(),
                const SizedBox(height: AppSpacing.md),
                Text('Esto toma entre 30 y 60 segundos.', style: AppText.caption.copyWith(color: AppColors.inkMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ((_controller.value * 3).floor() == i) ? AppColors.primary : AppColors.tint40,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
