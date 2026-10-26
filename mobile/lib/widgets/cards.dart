import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Tarjeta blanca con título opcional, base de las secciones de resultados.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.subtitle, required this.child});

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Semantics(header: true, child: Text(title!, style: AppText.heading)),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: AppText.caption.copyWith(color: AppColors.inkMuted)),
          ],
          if (title != null || subtitle != null) const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Cifra clave con unidad y etiqueta (componente "Metrica" de Figma).
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.unit,
    this.label = '',
    this.background = AppColors.surface,
  });

  final String value;
  final String unit;
  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppText.metric),
          ),
          Text(unit, style: AppText.caption.copyWith(color: AppColors.inkMuted)),
          if (label.isNotEmpty) Text(label, style: AppText.caption.copyWith(color: AppColors.action)),
        ],
      ),
    );
  }
}

/// Fila de tarjetas del mismo ancho y la misma altura.
class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// Puntaje de 1 a 10 con barra, descripción y rango entre modelos (componente "Puntaje" de Figma).
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.aspect, required this.score, this.description, this.range, this.note});

  final String aspect;
  final double score;
  final String? description;

  /// Puntaje mínimo y máximo entre los modelos.
  final (double, double)? range;
  final String? note;

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final value = score.clamp(0, 10).toDouble();
    final shown = _fmt(value);
    final spread = range;
    return Semantics(
      label: '$aspect: $shown de 10',
      excludeSemantics: true,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(aspect, style: AppText.heading),
                      if (description != null)
                        Text(description!, style: AppText.caption.copyWith(color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                Text('$shown/10', style: AppText.metric.copyWith(color: AppColors.action)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: value / 10,
                minHeight: 10,
                backgroundColor: AppColors.tint20,
                color: AppColors.primary,
              ),
            ),
            if (spread != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Los modelos dieron entre ${_fmt(spread.$1)} y ${_fmt(spread.$2)}.',
                style: AppText.caption.copyWith(color: AppColors.inkMuted),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(note!, style: AppText.caption.copyWith(color: AppColors.warning)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista con viñetas de color de marca.
class BulletList extends StatelessWidget {
  const BulletList({super.key, required this.items, this.color = AppColors.primary});

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: AppSpacing.sm),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: const SizedBox.square(dimension: 8),
                  ),
                ),
                Expanded(child: Text(item, style: AppText.body)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Globo de diálogo de la mascota.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.md),
          topRight: Radius.circular(AppRadius.md),
          bottomRight: Radius.circular(AppRadius.md),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Text(text, style: AppText.body),
    );
  }
}

/// Mascota con un mensaje y una acción opcional: estados vacíos y de error.
class MascotMessage extends StatelessWidget {
  const MascotMessage({super.key, required this.mascot, required this.title, required this.message, this.action});

  final Widget mascot;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mascot,
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppText.body.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
        ],
      ),
    );
  }
}
