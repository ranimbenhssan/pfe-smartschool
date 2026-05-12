// lib/screens/admin/iot_monitor/admin_iot_screen.dart
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
    final rtdbTemp = ref.watch(rtdbTemperatureProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Sensor Devices'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_rounded),
            tooltip: 'Teacher Presence',
            onPressed: () => context.push(AppRoutes.adminTeacherPresence),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Live DHT22 banner ──────────────────────────────────────────────
          rtdbTemp.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => _OfflineBanner(isDark: isDark),
            data:
                (data) =>
                    data == null
                        ? _OfflineBanner(isDark: isDark)
                        : _DhtBanner(data: data, isDark: isDark),
          ),

          // ── Rooms scrollable list ──────────────────────────────────────────
          Expanded(
            child: rooms.when(
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
                    message: 'No rooms configured yet.',
                    icon: Icons.meeting_room_outlined,
                  );
                }

                // Group by floor
                final Map<int, List<RoomModel>> byFloor = {};
                for (final r in list) {
                  byFloor.putIfAbsent(r.floor, () => []).add(r);
                }
                final floors = byFloor.keys.toList()..sort();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: floors.length,
                  itemBuilder: (ctx, i) {
                    final floor = floors[i];
                    final floorRooms = byFloor[floor]!;
                    return _FloorSection(
                      floor: floor,
                      rooms: floorRooms,
                      rtdbTemp: rtdbTemp,
                      isDark: isDark,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  FLOOR SECTION
// ─────────────────────────────────────────
class _FloorSection extends StatelessWidget {
  final int floor;
  final List<RoomModel> rooms;
  final AsyncValue<DhtData?> rtdbTemp;
  final bool isDark;

  const _FloorSection({
    required this.floor,
    required this.rooms,
    required this.rtdbTemp,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Floor header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.layers_rounded,
                      color: AppColors.accent,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      floor == 0 ? 'Ground Floor' : 'Floor $floor',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${rooms.length} room${rooms.length == 1 ? '' : 's'}',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),

        // Room cards
        ...rooms.map(
          (room) => _RoomTile(room: room, rtdbTemp: rtdbTemp, isDark: isDark),
        ),

        Divider(
          height: 8,
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  ROOM TILE
// ─────────────────────────────────────────
class _RoomTile extends StatelessWidget {
  final RoomModel room;
  final AsyncValue<DhtData?> rtdbTemp;
  final bool isDark;

  const _RoomTile({
    required this.room,
    required this.rtdbTemp,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.adminRoomDetail}/${room.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.meeting_room_rounded,
                color: AppColors.info,
                size: 20,
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
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  Text(
                    'Floor ${room.floor} · ${room.capacity} seats',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            // Show live temp from RTDB
            rtdbTemp.when(
              loading:
                  () => const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              error: (_, __) => _TempChip(label: '--°C', color: Colors.grey),
              data:
                  (d) =>
                      d == null
                          ? _TempChip(label: '--°C', color: Colors.grey)
                          : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TempChip(
                                label: '${d.temperature.toStringAsFixed(1)}°C',
                                color: _tempColor(d.temperature),
                              ),
                              const SizedBox(width: 6),
                              _TempChip(
                                label: '${d.humidity.toStringAsFixed(0)}%',
                                color: AppColors.info,
                              ),
                            ],
                          ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tempColor(double t) {
    if (t < 18) return Colors.blue;
    if (t < 24) return AppColors.success;
    if (t < 28) return AppColors.warning;
    return AppColors.error;
  }
}

// ─────────────────────────────────────────
//  DHT BANNER  — live reading at top
// ─────────────────────────────────────────
class _DhtBanner extends StatelessWidget {
  final DhtData data;
  final bool isDark;
  const _DhtBanner({required this.data, required this.isDark});

  String _ago() {
    final d = DateTime.now().difference(data.updatedAt);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final tColor =
        data.temperature < 18
            ? Colors.blue
            : data.temperature < 24
            ? AppColors.success
            : data.temperature < 28
            ? AppColors.warning
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.thermostat_rounded, color: tColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DHT22 — dht22_ED26 · Floor 2',
                  style: AppTypography.labelMedium,
                ),
                Text('Updated ${_ago()}', style: AppTypography.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.temperature.toStringAsFixed(1)}°C',
                style: AppTypography.headingMedium.copyWith(color: tColor),
              ),
              Text(
                '${data.humidity.toStringAsFixed(0)}% hum',
                style: AppTypography.caption.copyWith(color: AppColors.info),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final bool isDark;
  const _OfflineBanner({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
    ),
    child: const Row(
      children: [
        Icon(Icons.sensors_off_rounded, color: AppColors.error, size: 18),
        SizedBox(width: 8),
        Text(
          'Sensor offline — waiting for ESP32',
          style: TextStyle(fontSize: 13),
        ),
      ],
    ),
  );
}

class _TempChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TempChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: AppTypography.labelSmall.copyWith(color: color)),
  );
}
