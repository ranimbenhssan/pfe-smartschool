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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final room = ref.watch(roomProvider(widget.roomId));
    final sensorData = ref.watch(latestSensorDataProvider(widget.roomId));

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
          tabs: const [Tab(text: 'Live Readings'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── Live Tab ───
          sensorData.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data:
                (data) =>
                    data == null
                        ? const EmptyState(
                          title: 'No Data',
                          message: 'No sensor readings available',
                          icon: Icons.sensors_off_rounded,
                        )
                        : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Comfort Score
                              Container(
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
                                      style: AppTypography.displayLarge
                                          .copyWith(
                                            color:
                                                data.comfortScore >= 70
                                                    ? AppColors.success
                                                    : data.comfortScore >= 40
                                                    ? AppColors.warning
                                                    : AppColors.error,
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
                              ),
                              const SizedBox(height: 16),

                              // Sensor Gauges Grid
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
                        ),
          ),

          // ─── History Tab ───
          _HistoryTab(roomId: widget.roomId),
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
