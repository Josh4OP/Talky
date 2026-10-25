import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../theme/app_colors.dart';

/// Ritmo por ventanas de 30 s. Las ventanas finales en cero (silencio) se
/// descartan para no dibujar una caída artificial, tal como advierte el
/// contrato de la API.
class RhythmChart extends StatelessWidget {
  const RhythmChart({super.key, required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final data = _clean(values);
    if (data.length < 2) {
      return const Text(
        'No hay suficientes ventanas de ritmo para dibujar la evolución.',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          color: AppColors.inkMuted,
          height: 1.5,
        ),
      );
    }

    final minValue = data.reduce(math.min);
    final maxValue = data.reduce(math.max);
    final minY = math.max(0, ((minValue - 25) / 20).floor() * 20).toDouble();
    final maxY = (((maxValue + 25) / 20).ceil() * 20).toDouble();
    final interval = (maxY - minY) <= 100 ? 20.0 : 40.0;
    final labelStep = math.max(1, (data.length / 4).ceil());

    return Semantics(
      label:
          'Gráfico de ritmo: entre ${minValue.round()} y ${maxValue.round()} palabras por minuto.',
      child: SizedBox(
        height: 190,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (data.length - 1).toDouble(),
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.border.withValues(alpha: 0.8),
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: interval,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value.round().toString(),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }
                    if (index % labelStep != 0 && index != data.length - 1) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        Formatters.duration(index * 30),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBorderRadius: BorderRadius.circular(10),
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                getTooltipColor: (_) => AppColors.oceanDeep,
                getTooltipItems: (spots) => spots
                    .map(
                      (spot) => LineTooltipItem(
                        '${spot.y.round()} ppm',
                        const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    )
                    .toList(),
              ),
              getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
                  .map(
                    (_) => TouchedSpotIndicatorData(
                      const FlLine(
                        color: AppColors.ocean,
                        strokeWidth: 1.2,
                        dashArray: [4, 3],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.turquoise,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < data.length; i++)
                    FlSpot(i.toDouble(), data[i]),
                ],
                isCurved: true,
                curveSmoothness: 0.28,
                preventCurveOverShooting: true,
                color: AppColors.ocean,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.turquoise.withValues(alpha: 0.24),
                      AppColors.turquoise.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  List<double> _clean(List<double> input) {
    final data = [...input];
    while (data.isNotEmpty && data.last <= 0) {
      data.removeLast();
    }
    return data;
  }
}
