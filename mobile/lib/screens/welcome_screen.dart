import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/mascot/talky_mascot.dart';
import '../widgets/sections.dart';

/// Bienvenida de la primera apertura (contenido de la primera versión del front, con la estética actual).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 2 * AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _MascotWithFeatures(),
                      const SizedBox(height: AppSpacing.lg),
                      const AppPill(label: 'TU COMPAÑERO DE ORATORIA'),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        header: true,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Habla con confianza.\nMejora con '),
                              TextSpan(
                                text: 'Talky.',
                                style: AppText.display.copyWith(color: AppColors.action),
                              ),
                            ],
                          ),
                          style: AppText.display,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Grabamos tu exposición, analizamos cómo te expresas y te damos recomendaciones concretas '
                        'para que tu próxima presentación suene más clara y segura.',
                        style: AppText.body.copyWith(color: AppColors.inkMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _FeatureChip(icon: Icons.mic_none_rounded, label: 'Grabar o subir audio'),
                          _FeatureChip(icon: Icons.insights_rounded, label: 'Análisis claro'),
                          _FeatureChip(icon: Icons.lock_outline_rounded, label: 'Tu audio no se guarda'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(onPressed: onStart, child: const Text('Comenzar')),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Pensado para estudiantes', style: AppText.caption.copyWith(color: AppColors.inkMuted)),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.inkMuted),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              'TALKY no guarda tu audio. El historial conserva métricas y recomendaciones.',
                              style: AppText.caption.copyWith(color: AppColors.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MascotWithFeatures extends StatelessWidget {
  const _MascotWithFeatures();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(color: AppColors.tint20, shape: BoxShape.circle),
          ),
          const TalkyMascot(state: MascotState.normal, size: 220),
          const Positioned(
            left: 0,
            top: 24,
            child: _FloatingFeature(icon: Icons.speed_rounded, label: 'Ritmo y pausas'),
          ),
          const Positioned(
            right: 0,
            top: 96,
            child: _FloatingFeature(icon: Icons.lightbulb_outline_rounded, label: 'Recomendaciones'),
          ),
          const Positioned(
            left: 8,
            bottom: 8,
            child: _FloatingFeature(icon: Icons.trending_down_rounded, label: 'Menos muletillas'),
          ),
        ],
      ),
    );
  }
}

class _FloatingFeature extends StatelessWidget {
  const _FloatingFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: [
          BoxShadow(color: AppColors.deep.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.action),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.action),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}
