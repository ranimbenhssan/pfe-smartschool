import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class TeacherIotScreen extends ConsumerWidget {
  const TeacherIotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = ref.watch(roomsProvider);
    final sensorData = ref.watch(
      latestSensorDataProvider(
        rooms.maybeWhen(
          data: (list) => list.isNotEmpty ? list.first.id : '',
          orElse: () => '',
        ),
      ),
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Classroom IoT Monitor'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push(AppRoutes.teacherIotHistory),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Comfort Score ───
            sensorData.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) {
                if (data == null) {
                  return const EmptyState(
                    title: 'No Sensor Data',
                    message: 'No readings available yet',
                    icon: Icons.sensors_off_rounded,
                  );
                }
                final color =
                    data.comfortScore >= 70
                        ? AppColors.success
                        : data.comfortScore >= 40
                        ? AppColors.warning
                        : AppColors.error;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${data.comfortScore.toInt()}%',
                        style: AppTypography.displayLarge.copyWith(
                          color: color,
                          fontSize: 48,
                        ),
                      ),
                      Text(
                        'Comfort Score',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.comfortRecommendation,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ─── Sensor Gauges ───
            Text(
              'Live Readings',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            sensorData.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) {
                if (data == null) return const SizedBox.shrink();
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    SensorGauge(
                      label: 'Temperature',
                      value: data.temperature,
                      min: 0,
                      max: 50,
                      unit: '°C',
                      icon: Icons.thermostat_rounded,
                      color: AppColors.error,
                    ),
                    SensorGauge(
                      label: 'Humidity',
                      value: data.humidity,
                      min: 0,
                      max: 100,
                      unit: '%',
                      icon: Icons.water_drop_rounded,
                      color: AppColors.info,
                    ),
                    SensorGauge(
                      label: 'Light',
                      value: data.lightLevel,
                      min: 0,
                      max: 1000,
                      unit: 'lx',
                      icon: Icons.light_mode_rounded,
                      color: AppColors.warning,
                    ),
                    SensorGauge(
                      label: 'Noise',
                      value: data.noiseLevel,
                      min: 0,
                      max: 100,
                      unit: 'dB',
                      icon: Icons.volume_up_rounded,
                      color: AppColors.success,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
