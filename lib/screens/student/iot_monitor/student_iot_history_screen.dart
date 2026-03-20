import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';

class StudentIotHistoryScreen extends ConsumerWidget {
  const StudentIotHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Environment History'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
              message: 'No rooms configured',
              icon: Icons.meeting_room_outlined,
            );
          }
          final roomId = list.first.id;
          final history = ref.watch(sensorHistoryProvider(roomId));
          return history.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data:
                (readings) =>
                    readings.isEmpty
                        ? const EmptyState(
                          title: 'No History',
                          message: 'No historical data available',
                          icon: Icons.history_rounded,
                        )
                        : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Temperature',
                                style: AppTypography.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              SensorChart(
                                readings: readings,
                                type: 'temperature',
                                color: AppColors.error,
                              ),
                              const SizedBox(height: 16),
                              Text('Humidity', style: AppTypography.labelLarge),
                              const SizedBox(height: 8),
                              SensorChart(
                                readings: readings,
                                type: 'humidity',
                                color: AppColors.info,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Light Level',
                                style: AppTypography.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              SensorChart(
                                readings: readings,
                                type: 'light',
                                color: AppColors.warning,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Noise Level',
                                style: AppTypography.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              SensorChart(
                                readings: readings,
                                type: 'noise',
                                color: AppColors.success,
                              ),
                            ],
                          ),
                        ),
          );
        },
      ),
    );
  }
}
