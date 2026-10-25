import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/analysis_summary.dart';
import '../theme/app_colors.dart';
import 'app_pill.dart';
import 'surface_card.dart';

class AnalysisListCard extends StatelessWidget {
  const AnalysisListCard({
    super.key,
    required this.item,
    this.onTap,
    this.onDelete,
    this.showMenu = true,
  });

  final AnalysisSummary item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
      onTap: onTap,
      semanticLabel: 'Abrir análisis de ${item.cleanName}',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.isDemo
                    ? [AppColors.turquoiseSoft, const Color(0xFFD6F5F0)]
                    : [AppColors.blueSoft, const Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              color: item.isDemo ? AppColors.turquoiseDark : AppColors.ocean,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.cleanName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 14.5,
                            ),
                      ),
                    ),
                    if (item.isDemo) ...[
                      const SizedBox(width: 8),
                      const AppPill(
                        label: 'Ejemplo',
                        compact: true,
                        foreground: AppColors.warning,
                        background: AppColors.warningSoft,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.createdAt == null
                      ? 'Fecha no disponible'
                      : Formatters.relativeDate(item.createdAt!),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppPill(
                      label: '${Formatters.duration(item.duracionS)} de audio',
                      icon: Icons.timer_outlined,
                      compact: true,
                    ),
                    AppPill(
                      label: '${Formatters.ppm(item.ppm)} ppm',
                      icon: Icons.speed_rounded,
                      compact: true,
                      foreground: AppColors.turquoiseDark,
                      background: AppColors.turquoiseSoft,
                    ),
                    AppPill(
                      label:
                          '${item.totalMuletillas} ${item.totalMuletillas == 1 ? 'muletilla' : 'muletillas'}',
                      icon: Icons.record_voice_over_outlined,
                      compact: true,
                      foreground: AppColors.inkSoft,
                      background: AppColors.surfaceSunken,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (showMenu && onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Opciones del análisis',
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: AppColors.inkMuted,
              ),
              onSelected: (value) {
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 19, color: AppColors.danger),
                      SizedBox(width: 8),
                      Text('Borrar análisis'),
                    ],
                  ),
                ),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkMuted,
              ),
            ),
        ],
      ),
    );
  }
}
