import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../theme/theme.dart';

class SensorChart extends StatelessWidget {
  final List<SensorModel> readings;
  final String type; // 'temperature' | 'humidity' | 'light' | 'noise'
  final Color color;

  const SensorChart({
    super.key,
    required this.readings,
    required this.type,
    required this.color,
  });

  double _getValue(SensorModel s) {
    switch (type) {
      case 'temperature':
        return s.temperature;
      case 'humidity':
        return s.humidity;
      case 'light':
        return s.lightLevel;
      case 'noise':
        return s.noiseLevel;
      default:
        return 0;
    }
  }

  String get _unit {
    switch (type) {
      case 'temperature':
        return '°C';
      case 'humidity':
        return '%';
      case 'light':
        return 'lux';
      case 'noise':
        return 'dB';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (readings.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: const Center(child: Text('No data available')),
      );
    }

    final spots =
        readings.reversed.toList().asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), _getValue(e.value));
        }).toList();

    final values = spots.map((s) => s.y).toList();
    final minY =
        (values.reduce((a, b) => a < b ? a : b) - 5)
            .clamp(0, double.infinity)
            .toDouble();
    final maxY = values.reduce((a, b) => a > b ? a : b) + 5;

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine:
                (_) => FlLine(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  strokeWidth: 1,
                ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget:
                    (value, _) => Text(
                      '${value.toInt()}$_unit',
                      style: AppTypography.caption,
                    ),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
