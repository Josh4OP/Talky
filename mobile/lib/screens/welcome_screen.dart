import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/preferences_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/app_pill.dart';
import '../widgets/gradient_button.dart';
import '../widgets/talky_logo.dart';
import '../widgets/talky_mascot.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 48 : 22,
                  vertical: wide ? 28 : 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TalkyLogo(markSize: 44),
                        SizedBox(height: wide ? 54 : 26),
                        if (wide)
                          _WideHero(onStart: () => _start(context))
                        else
                          _MobileHero(onStart: () => _start(context)),
                        SizedBox(height: wide ? 34 : 26),
                        _PrivacyLine(wide: wide),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context) {
    context.read<PreferencesController>().completeOnboarding();
  }
}

class _WideHero extends StatelessWidget {
  const _WideHero({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: _HeroCopy(onStart: onStart),
        ),
        const SizedBox(width: 36),
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 520,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.turquoiseSoft.withValues(alpha: 0.9),
                        AppColors.blueSoft.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const TalkyMascot(
                  size: 430,
                  pose: TalkyPose.welcome,
                  backdrop: true,
                ),
                const Positioned(
                  left: 8,
                  top: 94,
                  child: _FloatingFeature(
                    icon: Icons.graphic_eq_rounded,
                    label: 'Ritmo y pausas',
                    color: AppColors.ocean,
                  ),
                ),
                const Positioned(
                  right: 0,
                  top: 178,
                  child: _FloatingFeature(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Recomendaciones',
                    color: AppColors.turquoiseDark,
                  ),
                ),
                const Positioned(
                  left: 42,
                  bottom: 64,
                  child: _FloatingFeature(
                    icon: Icons.record_voice_over_rounded,
                    label: 'Menos muletillas',
                    color: AppColors.coralDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileHero extends StatelessWidget {
  const _MobileHero({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TalkyMascot(
          size: 270,
          pose: TalkyPose.welcome,
          backdrop: true,
        ),
        const SizedBox(height: 12),
        _HeroCopy(onStart: onStart),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppPill(
          label: 'TU COMPAÑERO DE ORATORIA',
          icon: Icons.auto_awesome_rounded,
          foreground: AppColors.turquoiseDark,
          background: AppColors.turquoiseSoft,
        ),
        const SizedBox(height: 18),
        RichText(
          text: TextSpan(
            style: text.displayLarge?.copyWith(
              fontSize: MediaQuery.sizeOf(context).width < 420 ? 40 : null,
            ),
            children: [
              const TextSpan(text: 'Habla con confianza.\nMejora con '),
              TextSpan(
                text: 'Talky.',
                style: TextStyle(
                  foreground: Paint()
                    ..shader = AppColors.turquoiseGradient.createShader(
                      const Rect.fromLTWH(0, 0, 240, 60),
                    ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            'Grabamos tu exposición, analizamos cómo te expresas y te damos '
            'recomendaciones concretas para que tu próxima presentación suene '
            'más clara y segura.',
            style: text.bodyLarge?.copyWith(fontSize: 16.5, height: 1.6),
          ),
        ),
        const SizedBox(height: 26),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _FeatureChip(icon: Icons.mic_none_rounded, label: 'Grabar o subir audio'),
            _FeatureChip(icon: Icons.insights_rounded, label: 'Análisis claro'),
            _FeatureChip(icon: Icons.lock_outline_rounded, label: 'Tu audio no se guarda'),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GradientButton(
              label: 'Comenzar',
              icon: Icons.arrow_forward_rounded,
              onPressed: onStart,
              expand: MediaQuery.sizeOf(context).width < 520,
            ),
            Text(
              'Pensado para estudiantes',
              style: text.bodySmall?.copyWith(
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.ocean),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingFeature extends StatelessWidget {
  const _FloatingFeature({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.oceanDeep.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 15,
          color: AppColors.inkMuted,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'TALKY no guarda tu audio. El historial conserva métricas y recomendaciones.',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
