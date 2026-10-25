import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../state/analysis_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/app_pill.dart';
import '../widgets/error_view.dart';
import '../widgets/surface_card.dart';
import '../widgets/talky_mascot.dart';
import 'result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  static const _tips = <String>[
    'Una pausa breve también comunica: no necesitas llenar cada silencio.',
    'Las muletillas suelen aparecer cuando buscas la siguiente idea. Respira y continúa.',
    'Un ritmo de 110 a 160 palabras por minuto se entiende bien en una exposición.',
    'Talky compara tus métricas con tus propias palabras, no con un discurso perfecto.',
    'Piensa en tu próxima exposición: ¿qué idea quieres que recuerden?',
  ];

  AnalysisController? _controller;
  bool _listening = false;
  bool _navigated = false;
  bool _allowPop = false;
  int _tipIndex = 0;
  int _elapsed = 0;
  Timer? _clockTimer;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    _tipTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) {
        setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listening) return;
    _controller = context.read<AnalysisController>();
    _controller!.addListener(_onControllerChanged);
    _listening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _onControllerChanged());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _tipTimer?.cancel();
    if (_listening) {
      context.read<AnalysisController>().removeListener(_onControllerChanged);
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || _navigated) return;
    final controller = context.read<AnalysisController>();
    if (controller.status == AnalysisStatus.success &&
        controller.analysis != null) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultScreen(analysis: controller.analysis),
          ),
        );
      });
      return;
    }
    setState(() {});
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del análisis?'),
        content: const Text(
          'El servidor puede terminar de procesar el audio, pero no verás el '
          'resultado en esta pantalla. Si vuelves al historial, aparecerá '
          'cuando esté guardado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir esperando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AnalysisController>();

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(onClose: _confirmLeave),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: ContentContainer(
                      maxWidth: 920,
                      child: controller.status == AnalysisStatus.error
                          ? _ErrorState(
                              controller: controller,
                              onBack: () {
                                setState(() => _allowPop = true);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) Navigator.of(context).pop();
                                });
                              },
                            )
                          : _ProgressState(
                              controller: controller,
                              elapsed: _elapsed,
                              tip: _tips[_tipIndex],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancelar y volver',
            onPressed: onClose,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
          const Spacer(),
          const AppPill(
            label: 'Análisis en curso',
            icon: Icons.auto_awesome_rounded,
            foreground: AppColors.turquoiseDark,
            background: AppColors.turquoiseSoft,
          ),
        ],
      ),
    );
  }
}

class _ProgressState extends StatelessWidget {
  const _ProgressState({
    required this.controller,
    required this.elapsed,
    required this.tip,
  });

  final AnalysisController controller;
  final int elapsed;
  final String tip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        SurfaceCard(
          padding: const EdgeInsets.all(22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 680;
              final mascot = SizedBox(
                height: wide ? 330 : 250,
                child: const Center(
                  child: TalkyMascot(
                    size: 310,
                    pose: TalkyPose.thinking,
                    backdrop: true,
                    animate: true,
                  ),
                ),
              );

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppPill(
                    label: 'TALKY ESTÁ ANALIZANDO',
                    icon: Icons.graphic_eq_rounded,
                    foreground: AppColors.ocean,
                    background: AppColors.blueSoft,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Escuchando con\natención.',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: wide ? 36 : 31,
                          height: 1.05,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Estamos transcribiendo tu exposición y midiendo ritmo, pausas y muletillas. Después preparamos tus recomendaciones.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                          height: 1.55,
                        ),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(
                      minHeight: 8,
                      backgroundColor: AppColors.blueSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 15, color: AppColors.inkMuted),
                      const SizedBox(width: 6),
                      Text(
                        '${Formatters.recordingClock(elapsed)} transcurridos',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '30–60 s aprox.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _StageList(current: controller.stage),
                  const SizedBox(height: 8),
                  const Text(
                    'Las etapas son orientativas; el servidor procesa el audio en una sola solicitud.',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      height: 1.4,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: mascot),
                    const SizedBox(width: 26),
                    Expanded(flex: 6, child: details),
                  ],
                );
              }
              return Column(
                children: [
                  mascot,
                  const SizedBox(height: 8),
                  details,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          color: AppColors.blueMist,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 20, color: AppColors.turquoiseDark),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Column(
                    key: ValueKey(tip),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mientras esperas',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.turquoiseDark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tip,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.inkMuted),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Mantén la pantalla abierta. Tu audio no se guarda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StageList extends StatelessWidget {
  const _StageList({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < AnalysisController.stageLabels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: i < current
                        ? AppColors.turquoiseSoft
                        : i == current
                            ? AppColors.ocean
                            : AppColors.surfaceSunken,
                    shape: BoxShape.circle,
                  ),
                  child: i < current
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: AppColors.turquoiseDark)
                      : i == current
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Colors.white,
                              ),
                            )
                          : Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight:
                          i == current ? FontWeight.w700 : FontWeight.w500,
                      color: i <= current ? AppColors.ink : AppColors.inkMuted,
                    ),
                    child: Text(AnalysisController.stageLabels[i]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.controller, required this.onBack});

  final AnalysisController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ErrorView(
        mascotSize: 170,
        title: 'No pudimos completar el análisis',
        message: controller.error?.message ??
            'Ocurrió un problema al procesar tu audio. Inténtalo de nuevo.',
        onRetry: controller.canRetry
            ? () {
                controller.retry();
              }
            : null,
        secondaryLabel: 'Volver a elegir el audio',
        onSecondary: onBack,
      ),
    );
  }
}
