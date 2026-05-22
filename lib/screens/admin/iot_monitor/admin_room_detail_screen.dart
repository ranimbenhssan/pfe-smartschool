import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';

class AdminRoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;

  const AdminRoomDetailScreen({super.key, required this.roomId});

  @override
  ConsumerState<AdminRoomDetailScreen> createState() =>
      _AdminRoomDetailScreenState();
}

class _AdminRoomDetailScreenState extends ConsumerState<AdminRoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final room = ref.watch(roomProvider(widget.roomId));
    final rtdbData = ref.watch(rtdbTemperatureProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: room.when(
          loading: () => const Text('Room Detail'),
          error: (_, __) => const Text('Room Detail'),
          data: (r) => Text(r?.name ?? 'Room Detail'),
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          tabs: const [Tab(text: 'Live Readings')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          rtdbData.when(
            loading: () => const LoadingWidget(),
            error:
                (_, __) => const EmptyState(
                  title: 'Sensor Offline',
                  message: 'Could not reach the sensor.',
                  icon: Icons.sensors_off_rounded,
                ),
            data:
                (d) =>
                    d == null
                        ? const EmptyState(
                          title: 'No Sensor Data',
                          message: 'Sensor has not reported yet.',
                          icon: Icons.sensors_rounded,
                        )
                        : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // ── Last updated ──
                              Text(
                                'Last updated: ${_fmt(d.updatedAt)}',
                                style: AppTypography.caption,
                              ),
                              const SizedBox(height: 16),

                              // ── Sensor Gauges ──
                              GridView.count(
                                crossAxisCount: 1,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.4,
                                children: [
                                  SensorGauge(
                                    label: 'Temperature',
                                    value: d.temperature,
                                    min: 0,
                                    max: 50,
                                    unit: '°C',
                                    icon: Icons.thermostat_rounded,
                                    color: AppColors.error,
                                  ),
                                  SensorGauge(
                                    label: 'Humidity',
                                    value: d.humidity,
                                    min: 0,
                                    max: 100,
                                    unit: '%',
                                    icon: Icons.water_drop_rounded,
                                    color: AppColors.info,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  final String roomId;

  const _HistoryTab({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          (list) =>
              list.isEmpty
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
                        Text('Temperature', style: AppTypography.labelLarge),
                        const SizedBox(height: 8),
                        SensorChart(
                          readings: list,
                          type: 'temperature',
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text('Humidity', style: AppTypography.labelLarge),
                        const SizedBox(height: 8),
                        SensorChart(
                          readings: list,
                          type: 'humidity',
                          color: AppColors.info,
                        ),
                        const SizedBox(height: 16),
                        Text('Light Level', style: AppTypography.labelLarge),
                        const SizedBox(height: 8),
                        SensorChart(
                          readings: list,
                          type: 'light',
                          color: AppColors.warning,
                        ),
                        const SizedBox(height: 16),
                        Text('Noise Level', style: AppTypography.labelLarge),
                        const SizedBox(height: 8),
                        SensorChart(
                          readings: list,
                          type: 'noise',
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ),
    );
  }
}
