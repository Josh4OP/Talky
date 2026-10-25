import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/analysis.dart';
import '../theme/app_colors.dart';
import 'surface_card.dart';

class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.title,
    required this.description,
    required this.score,
    required this.color,
    this.background = AppColors.blueSoft,
    this.icon,
  });

  final String title;
  final String description;
  final ScoreStat? score;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final median = clampScore(score?.mediana);
    final min = clampScore(score?.min) ?? 0;
    final max = clampScore(score?.max) ?? 0;
    final hasScore = median != null;

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              if (icon != null) const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (score?.desacuerdo == true)
                const Tooltip(
                  message: 'Los modelos no coinciden del todo',
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: AppColors.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.score(median),
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: hasScore ? color : AppColors.inkMuted,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 4, left: 3),
                child: Text(
                  '/ 10',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const Spacer(),
              if (hasScore)
                Text(
                  'rango ${Formatters.score(min)}–${Formatters.score(max)}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _ScoreBar(
            min: min,
            max: max,
            median: median,
            color: color,
            background: background,
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppColors.inkMuted,
            ),
          ),
          if (score?.desacuerdo == true) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: AppColors.warning,
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Los modelos no coinciden del todo',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.min,
    required this.max,
    required this.median,
    required this.color,
    required this.background,
  });

  final double min;
  final double max;
  final double? median;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final start = (min / 10).clamp(0.0, 1.0).toDouble() * width;
        final end = (max / 10).clamp(0.0, 1.0).toDouble() * width;
        final marker =
            ((median ?? 0) / 10).clamp(0.0, 1.0).toDouble() * width;

        return SizedBox(
          height: 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (max > min)
                Positioned(
                  left: start,
                  width: (end - start).clamp(2.0, width).toDouble(),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              if (median != null)
                Positioned(
                  left: (marker - 5).clamp(0.0, width - 10).toDouble(),
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.28),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
