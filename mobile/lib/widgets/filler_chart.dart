import 'package:flutter/material.dart';

import '../models/analysis.dart';
import '../theme/app_colors.dart';

/// Barras horizontales de muletillas. Se ordenan de mayor a menor para que la
/// lectura sea inmediata; el texto también expone el conteo para accesibilidad.
class FillerChart extends StatelessWidget {
  const FillerChart({super.key, required this.analysis, this.maxItems = 6});

  final Analysis analysis;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final items = analysis.muletillasOrdenadas.take(maxItems).toList();
    if (items.isEmpty) {
      return const Text(
        'No se detectaron muletillas en este audio.',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          color: AppColors.inkMuted,
          height: 1.5,
        ),
      );
    }

    final maxCount = items.first.value.toDouble();

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _FillerBar(
            label: items[i].key,
            count: items[i].value,
            ratio: maxCount == 0 ? 0 : items[i].value / maxCount,
            color: i == 0 ? AppColors.ocean : AppColors.turquoise,
          ),
          if (i != items.length - 1) const SizedBox(height: 11),
        ],
        if (analysis.muletillas.length > maxItems) ...[
          const SizedBox(height: 10),
          Text(
            '+${analysis.muletillas.length - maxItems} muletillas más',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _FillerBar extends StatelessWidget {
  const _FillerBar({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int count;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $count veces',
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 12,
                color: AppColors.blueMist,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio.clamp(0.03, 1).toDouble()),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color == AppColors.ocean
                                  ? AppColors.blue
                                  : const Color(0xFF3ED9C8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
