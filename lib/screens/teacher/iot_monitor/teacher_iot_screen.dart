// lib/screens/teacher/iot_monitor/teacher_iot_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class TeacherIotScreen extends ConsumerStatefulWidget {
  const TeacherIotScreen({super.key});

  @override
  ConsumerState<TeacherIotScreen> createState() => _TeacherIotScreenState();
}

class _TeacherIotScreenState extends ConsumerState<TeacherIotScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = ref.watch(roomsProvider);
    final rtdbTemp = ref.watch(rtdbTemperatureProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Classroom Environment'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: Column(
        children: [
          // ── Live sensor banner ─────────────────────────────────────────────
          rtdbTemp.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => _OfflineBanner(isDark: isDark),
            data:
                (data) =>
                    data == null
                        ? _OfflineBanner(isDark: isDark)
                        : _LiveBanner(data: data, isDark: isDark),
          ),

          // ── Search ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search rooms...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon:
                    _query.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                        : null,
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // ── Rooms list ─────────────────────────────────────────────────────
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
                final filtered =
                    _query.isEmpty
                        ? list
                        : list
                            .where(
                              (r) =>
                                  r.name.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ) ||
                                  r.floor.toString().contains(_query),
                            )
                            .toList();
                if (list.isEmpty) {
                  return const EmptyState(
                    title: 'No Rooms',
                    message: 'No rooms configured yet.',
                    icon: Icons.meeting_room_outlined,
                  );
                }
                if (filtered.isEmpty) {
                  return const EmptyState(
                    title: 'No Results',
                    message: '',
                    icon: Icons.search_off_rounded,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder:
                      (ctx, i) => _RoomRow(
                        room: filtered[i],
                        rtdbTemp: rtdbTemp,
                        isDark: isDark,
                      ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  final DhtData data;
  final bool isDark;
  const _LiveBanner({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tColor =
        data.temperature < 24
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
          Icon(Icons.thermostat_rounded, color: tColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
        Icon(Icons.sensors_off_rounded, color: AppColors.error, size: 16),
        SizedBox(width: 8),
        Text(
          'Sensor offline — waiting for ESP32',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class _RoomRow extends StatelessWidget {
  final RoomModel room;
  final AsyncValue<DhtData?> rtdbTemp;
  final bool isDark;
  const _RoomRow({
    required this.room,
    required this.rtdbTemp,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.teacherColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.meeting_room_rounded,
              color: AppColors.teacherColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  style: AppTypography.labelMedium.copyWith(
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
          rtdbTemp.when(
            loading:
                () => const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            error:
                (_, __) => const Text(
                  '--',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            data:
                (d) =>
                    d == null
                        ? const Text(
                          '--',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${d.temperature.toStringAsFixed(1)}°C',
                              style: AppTypography.labelLarge.copyWith(
                                color:
                                    d.temperature < 24
                                        ? AppColors.success
                                        : d.temperature < 28
                                        ? AppColors.warning
                                        : AppColors.error,
                              ),
                            ),
                            Text(
                              '${d.humidity.toStringAsFixed(0)}% RH',
                              style: AppTypography.labelSmall.copyWith(
                                color:
                                    d.humidity < 40
                                        ? AppColors.warning
                                        : d.humidity < 80
                                        ? AppColors.success
                                        : AppColors.error,
                              ),
                            ),
                          ],
                        ),
          ),
        ],
      ),
    );
  }
}
