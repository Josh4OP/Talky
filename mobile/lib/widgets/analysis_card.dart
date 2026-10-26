import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/analysis_summary.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'sections.dart';

/// Tarjeta de un análisis del historial (componente "ItemHistorial" de Figma).
class AnalysisCard extends StatelessWidget {
  const AnalysisCard({super.key, required this.item, required this.onTap, this.onDelete});

  final AnalysisSummary item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      Formatters.date(item.createdAt),
      '${item.totalFillers} muletillas',
      if (item.wordsPerMinute != null) '${Formatters.number(item.wordsPerMinute, decimals: 0)} ppm',
    ].where((d) => d.isNotEmpty).join('  ·  ');
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.tint20, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.graphic_eq_rounded, color: AppColors.action),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            Formatters.cleanName(item.filename),
                            style: AppText.bodyStrong,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isDemo) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const AppPill(label: 'EJEMPLO', color: AppColors.warning, background: Color(0xFFFFF4E0)),
                        ],
                      ],
                    ),
                    Text(details, style: AppText.caption.copyWith(color: AppColors.inkMuted)),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Borrar análisis',
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.inkMuted),
                  onPressed: onDelete,
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
