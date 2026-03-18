import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminIotScreen extends ConsumerWidget {
  const AdminIotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Classroom IoT Monitor'),
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
        data:
            (list) =>
                list.isEmpty
                    ? const EmptyState(
                      title: 'No Rooms',
                      message: 'No rooms configured yet',
                      icon: Icons.meeting_room_outlined,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final room = list[index];
                        return _RoomCard(room: room);
                      },
                    ),
      ),
    );
  }
}

class _RoomCard extends ConsumerWidget {
  final RoomModel room;

  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sensorData = ref.watch(latestSensorDataProvider(room.id));

    final color =
        room.comfortScore >= 70
            ? AppColors.success
            : room.comfortScore >= 40
            ? AppColors.warning
            : AppColors.error;

    return GestureDetector(
      onTap: () => context.push('${AppRoutes.adminRoomDetail}/${room.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Room Header ───
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.meeting_room_rounded,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: AppTypography.labelLarge.copyWith(
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      Text(
                        'Floor ${room.floor} • ${room.capacity} seats',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${room.comfortScore.toInt()}%',
                      style: AppTypography.headingMedium.copyWith(color: color),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room.comfortScore >= 70
                            ? 'Good'
                            : room.comfortScore >= 40
                            ? 'Average'
                            : 'Poor',
                        style: AppTypography.labelSmall.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Live Sensor Readings ───
            sensorData.when(
              loading:
                  () => const LinearProgressIndicator(
                    color: AppColors.accent,
                    backgroundColor: Colors.transparent,
                  ),
              error:
                  (_, __) => Text(
                    'Sensor data unavailable',
                    style: AppTypography.caption,
                  ),
              data: (data) {
                if (data == null) {
                  return Text(
                    'No sensor data yet',
                    style: AppTypography.caption,
                  );
                }
                return Row(
                  children: [
                    _SensorChip(
                      icon: Icons.thermostat_rounded,
                      value: '${data.temperature.toStringAsFixed(1)}°C',
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    _SensorChip(
                      icon: Icons.water_drop_rounded,
                      value: '${data.humidity.toStringAsFixed(0)}%',
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _SensorChip(
                      icon: Icons.light_mode_rounded,
                      value: '${data.lightLevel.toStringAsFixed(0)}lx',
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    _SensorChip(
                      icon: Icons.volume_up_rounded,
                      value: '${data.noiseLevel.toStringAsFixed(0)}dB',
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

class _SensorChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _SensorChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.caption.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
