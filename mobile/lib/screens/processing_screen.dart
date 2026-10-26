import 'dart:async';

import 'package:flutter/material.dart';

import '../models/analysis.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/mascot/talky_mascot.dart';
import '../widgets/sections.dart';
import 'result_screen.dart';

/// Espera del análisis. La API no informa avance: los mensajes son ambientales, sin porcentaje.
/// Al terminar reemplaza esta pantalla por el resultado; si falla, se cierra devolviendo `true`.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.pending});

  final Future<Analysis?> pending;

  static const messages = [
    'Escuchando tu audio',
    'Contando muletillas',
    'Midiendo tu ritmo',
    'Los modelos están opinando',
    'Revisando las citas',
  ];

  /// Consejos de la primera versión del front.
  static const tips = [
    'Una pausa breve también comunica: no necesitas llenar cada silencio.',
    'Las muletillas suelen aparecer cuando buscas la siguiente idea. Respira y continúa.',
    'Un ritmo de 110 a 160 palabras por minuto se entiende bien en una exposición.',
    'Talky compara tus métricas con tus propias palabras, no con un discurso perfecto.',
    'Piensa en tu próxima exposición: ¿qué idea quieres que recuerden?',
  ];

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  var _index = 0;
  var _tip = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (tick) {
      setState(() {
        _index = (_index + 1) % ProcessingScreen.messages.length;
        if (tick.tick.isEven) _tip = (_tip + 1) % ProcessingScreen.tips.length;
      });
    });
    widget.pending.then(_finish);
  }

  void _finish(Analysis? result) {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (result == null) {
      navigator.pop(true);
    } else {
      navigator.pushReplacement(MaterialPageRoute(builder: (_) => ResultScreen(analysis: result)));
    }
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('¿Salir del análisis?', style: AppText.title),
        content: Text(
          'El servidor puede terminar de procesar el audio, pero no verás el resultado en esta pantalla. '
          'Si vuelves al historial, aparecerá cuando esté guardado.',
          style: AppText.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Seguir esperando')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salir')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop(false);
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
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cancelar y volver',
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmExit,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            children: [
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.tint20, shape: BoxShape.circle),
                  child: const TalkyMascot(state: MascotState.thinking, size: 230),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Center(child: AppPill(label: 'TALKY ESTÁ ANALIZANDO')),
              const SizedBox(height: AppSpacing.sm),
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
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Center(child: _Dots()),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Esto toma entre 30 y 60 segundos. Mantén la pantalla abierta. Tu audio no se guarda.',
                style: AppText.caption.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: AppColors.action),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mientras esperas', style: AppText.bodyStrong),
                          const SizedBox(height: AppSpacing.xs),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              ProcessingScreen.tips[_tip],
                              key: ValueKey(_tip),
                              style: AppText.body.copyWith(color: AppColors.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
