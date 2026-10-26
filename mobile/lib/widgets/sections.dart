import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Encabezado de sección con antetítulo ("LO ESENCIAL"), título y subtítulo.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.eyebrow, required this.title, this.subtitle, this.trailing});

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: AppText.overline.copyWith(color: AppColors.action)),
                const SizedBox(height: 2),
                Semantics(header: true, child: Text(title, style: AppText.heading)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.caption.copyWith(color: AppColors.inkMuted)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Aviso obligatorio cuando la interfaz muestra datos de ejemplo.
class DemoBanner extends StatelessWidget {
  const DemoBanner({
    super.key,
    this.message = 'Estás viendo datos de ejemplo. No provienen de tu audio ni de tu historial.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: AppText.caption.copyWith(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta pequeña redondeada ("Ejemplo", "PASO 1 DE 2").
class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.label, this.color = AppColors.action, this.background = AppColors.tint20});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label, style: AppText.overline.copyWith(color: color, fontSize: 12)),
    );
  }
}

/// Onda de la grabación: barras que siguen el nivel real del micrófono.
class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({super.key, required this.levels, this.height = 56, this.bars = 32});

  final Stream<double> levels;
  final double height;
  final int bars;

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform> {
  late final List<double> _history = List.filled(widget.bars, 0.05, growable: true);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: StreamBuilder<double>(
        stream: widget.levels,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _history
              ..removeAt(0)
              ..add(math.max(0.05, snapshot.data!));
          }
          return SizedBox(
            height: widget.height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final level in _history)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 4,
                    height: widget.height * level,
                    decoration: BoxDecoration(
                      color: Color.lerp(AppColors.tint60, AppColors.action, level),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tarjeta gris que ocupa el lugar de un elemento mientras carga.
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key, this.height = 76});

  final double height;

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
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
        builder: (context, _) => Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.surface, AppColors.tint20, _controller.value),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
