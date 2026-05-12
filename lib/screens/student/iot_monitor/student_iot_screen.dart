// lib/screens/student/iot_monitor/student_iot_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';

class StudentIotScreen extends ConsumerWidget {
  const StudentIotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rtdbTemp = ref.watch(rtdbTemperatureProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Classroom Environment'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: rtdbTemp.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => const EmptyState(
              title: 'Sensor Offline',
              message:
                  'The classroom sensor is not responding.\nPlease try again later.',
              icon: Icons.sensors_off_rounded,
            ),
        data:
            (data) =>
                data == null
                    ? const EmptyState(
                      title: 'No Data',
                      message:
                          'No sensor readings yet.\nThe ESP32 may still be starting up.',
                      icon: Icons.sensors_off_rounded,
                    )
                    : _EnvironmentView(data: data, isDark: isDark),
      ),
    );
  }
}

class _EnvironmentView extends StatelessWidget {
  final DhtData data;
  final bool isDark;
  const _EnvironmentView({required this.data, required this.isDark});

  Color get _tempColor {
    if (data.temperature < 18) return Colors.blue;
    if (data.temperature < 24) return AppColors.success;
    if (data.temperature < 28) return AppColors.warning;
    return AppColors.error;
  }

  String get _tempLabel {
    if (data.temperature < 18) return 'Too Cold';
    if (data.temperature < 24) return 'Comfortable';
    if (data.temperature < 28) return 'Warm';
    return 'Too Hot';
  }

  Color get _humidityColor {
    if (data.humidity < 30 || data.humidity > 70) return AppColors.error;
    if (data.humidity < 40 || data.humidity > 60) return AppColors.warning;
    return AppColors.success;
  }

  String _ago() {
    final d = DateTime.now().difference(data.updatedAt);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Last updated ─────────────────────────────────────────────────
          Center(
            child: Text(
              'Updated ${_ago()}',
              style: AppTypography.caption.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Temperature card ─────────────────────────────────────────────
          _BigCard(
            icon: Icons.thermostat_rounded,
            label: 'Temperature',
            value: '${data.temperature.toStringAsFixed(1)}°C',
            subtext: _tempLabel,
            color: _tempColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // ── Humidity card ────────────────────────────────────────────────
          _BigCard(
            icon: Icons.water_drop_rounded,
            label: 'Humidity',
            value: '${data.humidity.toStringAsFixed(0)}%',
            subtext:
                data.humidity < 40
                    ? 'Dry'
                    : data.humidity > 60
                    ? 'Humid'
                    : 'Comfortable',
            color: _humidityColor,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // ── Comfort summary ──────────────────────────────────────────────
          _ComfortSummary(
            temp: data.temperature,
            humidity: data.humidity,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final IconData icon;
  final String label, value, subtext;
  final Color color;
  final bool isDark;
  const _BigCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                value,
                style: AppTypography.displaySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtext,
                style: AppTypography.caption.copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ComfortSummary extends StatelessWidget {
  final double temp, humidity;
  final bool isDark;
  const _ComfortSummary({
    required this.temp,
    required this.humidity,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isComfortable =
        temp >= 18 && temp <= 26 && humidity >= 30 && humidity <= 70;
    final color = isComfortable ? AppColors.success : AppColors.warning;
    final message =
        isComfortable
            ? 'The classroom environment is comfortable for studying.'
            : temp > 26
            ? 'It\'s warm in the classroom. Stay hydrated.'
            : temp < 18
            ? 'It\'s cold in the classroom.'
            : humidity > 70
            ? 'High humidity — ventilation recommended.'
            : 'Humidity is low.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isComfortable
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
