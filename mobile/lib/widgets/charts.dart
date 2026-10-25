import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Barras horizontales con el conteo por muletilla, de la más frecuente a la menos.
class FillerChart extends StatelessWidget {
  const FillerChart({super.key, required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.take(6).toList();
    final top = entries.map((e) => e.value).fold(0, math.max);
    return Semantics(
      label: 'Muletillas: ${entries.map((e) => '${e.key} ${e.value}').join(', ')}',
      excludeSemantics: true,
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text('"${entry.key}"', style: AppText.caption, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 22,
                          width: math.max(8, constraints.maxWidth * entry.value / math.max(top, 1)),
                          decoration: BoxDecoration(
                            color: entry == entries.first ? AppColors.action : AppColors.tint60,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text('${entry.value}', style: AppText.bodyStrong, textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Palabras por minuto en ventanas de 30 s. Una última ventana en 0 (silencio final) no se dibuja.
class RhythmChart extends StatelessWidget {
  const RhythmChart({super.key, required this.windows});

  final List<double> windows;

  static List<double> visibleWindows(List<double> windows) =>
      windows.length > 1 && windows.last == 0 ? windows.sublist(0, windows.length - 1) : windows;

  @override
  Widget build(BuildContext context) {
    final values = visibleWindows(windows);
    final top = values.fold(0.0, math.max);
    return Semantics(
      label: 'Ritmo por tramo de 30 segundos: ${values.map((v) => v.round()).join(', ')} palabras por minuto',
      excludeSemantics: true,
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: math.max(200, (top / 20).ceil() * 20.0),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 40,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.tint20, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            rangeAnnotations: RangeAnnotations(
              horizontalRangeAnnotations: [
                HorizontalRangeAnnotation(y1: 110, y2: 160, color: AppColors.tint20.withValues(alpha: 0.7)),
              ],
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 40,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) =>
                      Text(value.toInt().toString(), style: AppText.caption.copyWith(color: AppColors.inkMuted)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: math.max(1, (values.length / 5).ceilToDouble()),
                  getTitlesWidget: (value, meta) => Text(
                    '${(value * 30 / 60).toStringAsFixed(value * 30 % 60 == 0 ? 0 : 1)} min',
                    style: AppText.caption.copyWith(color: AppColors.inkMuted),
                  ),
                ),
              ),
            ),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
                isCurved: true,
                preventCurveOverShooting: true,
                color: AppColors.action,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
