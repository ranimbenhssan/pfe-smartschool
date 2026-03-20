import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class StudentIotScreen extends ConsumerWidget {
  const StudentIotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Classroom Environment'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push(AppRoutes.studentIotHistory),
          ),
        ],
      ),
      body: rooms.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'No Rooms',
              message: 'No rooms configured yet',
              icon: Icons.meeting_room_outlined,
            );
          }
          final roomId = list.first.id;
          final sensorData = ref.watch(latestSensorDataProvider(roomId));
          return sensorData.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (data) {
              if (data == null) {
                return const EmptyState(
                  title: 'No Data',
                  message: 'No sensor readings available',
                  icon: Icons.sensors_off_rounded,
                );
              }
              final color =
                  data.comfortScore >= 70
                      ? AppColors.success
                      : data.comfortScore >= 40
                      ? AppColors.warning
                      : AppColors.error;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ─── Comfort Score ───
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${data.comfortScore.toInt()}%',
                            style: AppTypography.displayLarge.copyWith(
                              color: color,
                              fontSize: 52,
                            ),
                          ),
                          Text(
                            'Comfort Score',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              data.comfortScore >= 70
                                  ? '😊 Good Environment'
                                  : data.comfortScore >= 40
                                  ? '😐 Average Conditions'
                                  : '😟 Poor Conditions',
                              style: AppTypography.labelSmall.copyWith(
                                color: color,
                              ),
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
                    ),
                    const SizedBox(height: 20),

                    // ─── Sensor Gauges ───
                    GridView.count(
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
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
