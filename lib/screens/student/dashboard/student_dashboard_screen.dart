import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../models/models.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState
    extends ConsumerState<StudentDashboardScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.how_to_reg_rounded, label: 'Attendance'),
    _NavItem(icon: Icons.calendar_today_rounded, label: 'Timetable'),
    _NavItem(icon: Icons.sensors_rounded, label: 'Environment'),
    _NavItem(icon: Icons.notifications_rounded, label: 'Notifications'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: _buildAppBar(isDark),
      body:
          _selectedIndex == 0
              ? const _DashboardBody()
              : _selectedIndex == 1
              ? const _AttendanceQuickView()
              : _selectedIndex == 2
              ? const _TimetableQuickView()
              : _selectedIndex == 3
              ? const _EnvironmentQuickView()
              : const _NotificationsQuickView(),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 0,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SmartSchool',
            style: AppTypography.headingMedium.copyWith(
              color: isDark ? AppColors.darkText : AppColors.lightText,
              fontFamily: AppTypography.displayFont,
            ),
          ),
        ],
      ),
      actions: [
        Consumer(
          builder: (context, ref, _) {
            final themeMode = ref.watch(themeModeProvider);
            return IconButton(
              icon: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                size: 20,
              ),
              onPressed: () {
                final current = ref.read(themeModeProvider);
                ref.read(themeModeProvider.notifier).state =
                    current == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
              },
            );
          },
        ),
        GestureDetector(
          onTap: () => _showProfileMenu(context),
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.studentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.studentColor,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _ProfileBottomSheet(),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.transparent,
        elevation: 0,
        items:
            _navItems
                .map(
                  (item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
                )
                .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  DASHBOARD BODY
// ─────────────────────────────────────────
class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return RefreshIndicator(
      color: AppColors.studentColor,
      onRefresh: () async => ref.refresh(currentUserProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Greeting ───
            currentUser.when(
              loading: () => const SizedBox(height: 50),
              error: (_, __) => const SizedBox.shrink(),
              data:
                  (user) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()}, ${user?.name ?? 'Student'} 👋',
                        style: AppTypography.headingLarge.copyWith(
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(),
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 24),

            // ─── Today Attendance Status ───
            _buildTodayStatus(context, isDark, ref),
            const SizedBox(height: 24),

            // ─── Quick Actions ───
            Text(
              'Quick Access',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _QuickAction(
                  label: 'Attendance',
                  icon: Icons.how_to_reg_rounded,
                  color: AppColors.success,
                  onTap: () => context.push(AppRoutes.studentAttendance),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  label: 'Timetable',
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.info,
                  onTap: () => context.push(AppRoutes.studentTimetable),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  label: 'Environment',
                  icon: Icons.sensors_rounded,
                  color: AppColors.accent,
                  onTap: () => context.push(AppRoutes.studentIot),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  label: 'Alerts',
                  icon: Icons.notifications_rounded,
                  color: AppColors.warning,
                  onTap: () => context.push(AppRoutes.studentNotifications),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Today Timetable ───
            _buildTodayTimetable(context, isDark, ref),
            const SizedBox(height: 24),

            // ─── Classroom Environment ───
            _buildEnvironment(context, isDark, ref),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatDate() {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _buildTodayStatus(BuildContext context, bool isDark, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final today = ref.watch(todayStringProvider);

    return currentUser.when(
      loading: () => const LoadingWidget(),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final attendance = ref.watch(attendanceByStudentProvider(user.id));
        return attendance.when(
          loading: () => const LoadingWidget(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            final todayRecord = list.where((a) => a.date == today).firstOrNull;

            final status = todayRecord?.status;
            final color =
                status == AttendanceStatus.present
                    ? AppColors.success
                    : status == AttendanceStatus.late
                    ? AppColors.warning
                    : status == AttendanceStatus.absent
                    ? AppColors.error
                    : AppColors.info;
            final label =
                status == AttendanceStatus.present
                    ? 'Present Today ✅'
                    : status == AttendanceStatus.late
                    ? 'Late Today ⚠️'
                    : status == AttendanceStatus.absent
                    ? 'Absent Today ❌'
                    : 'Not Recorded Yet';

            return GestureDetector(
              onTap: () => context.push(AppRoutes.studentAttendance),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        status == AttendanceStatus.present
                            ? Icons.check_circle_rounded
                            : status == AttendanceStatus.late
                            ? Icons.watch_later_rounded
                            : status == AttendanceStatus.absent
                            ? Icons.cancel_rounded
                            : Icons.help_outline_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: AppTypography.labelLarge.copyWith(
                              color: color,
                            ),
                          ),
                          if (todayRecord?.entryTime != null)
                            Text(
                              'Entry time: ${todayRecord!.entryTime!.hour}:${todayRecord.entryTime!.minute.toString().padLeft(2, '0')}',
                              style: AppTypography.caption,
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: color,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTodayTimetable(
    BuildContext context,
    bool isDark,
    WidgetRef ref,
  ) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final timetable = ref.watch(todayTimetableProvider(user.id));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Classes",
                  style: AppTypography.headingMedium.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.studentTimetable),
                  child: const Text('Full schedule'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            timetable.when(
              data:
                  (list) =>
                      list.isEmpty
                          ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                              ),
                            ),
                            child: Text(
                              'No classes today',
                              style: AppTypography.bodySmall.copyWith(
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                              ),
                            ),
                          )
                          : Column(
                            children:
                                list.map((entry) {
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? AppColors.darkCard
                                              : AppColors.lightCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.studentColor
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.studentColor
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.book_rounded,
                                            color: AppColors.studentColor,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                entry.subject,
                                                style: AppTypography.labelLarge
                                                    .copyWith(
                                                      color:
                                                          isDark
                                                              ? AppColors
                                                                  .darkText
                                                              : AppColors
                                                                  .lightText,
                                                    ),
                                              ),
                                              Text(
                                                '${entry.startTime} - ${entry.endTime} • ${entry.roomName}',
                                                style: AppTypography.caption,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),
              loading: () => const LoadingWidget(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnvironment(BuildContext context, bool isDark, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Classroom Environment',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.studentIot),
              child: const Text('Details'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        rooms.when(
          loading: () => const LoadingWidget(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            final room = list.first;
            final color =
                room.comfortScore >= 70
                    ? AppColors.success
                    : room.comfortScore >= 40
                    ? AppColors.warning
                    : AppColors.error;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.sensors_rounded, color: color, size: 22),
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
                                isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                          ),
                        ),
                        Text(
                          room.comfortScore >= 70
                              ? 'Comfortable environment'
                              : room.comfortScore >= 40
                              ? 'Average conditions'
                              : 'Poor conditions',
                          style: AppTypography.caption.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${room.comfortScore.toInt()}%',
                    style: AppTypography.headingMedium.copyWith(color: color),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  ATTENDANCE QUICK VIEW
// ─────────────────────────────────────────
class _AttendanceQuickView extends ConsumerWidget {
  const _AttendanceQuickView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      loading: () => const LoadingWidget(),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final attendance = ref.watch(attendanceByStudentProvider(user.id));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Attendance',
                    style: AppTypography.headingMedium.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.studentAttendance),
                    child: const Text('Full view'),
                  ),
                ],
              ),
            ),
            attendance.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                final present =
                    list
                        .where((a) => a.status == AttendanceStatus.present)
                        .length;
                final absent =
                    list
                        .where((a) => a.status == AttendanceStatus.absent)
                        .length;
                final late =
                    list.where((a) => a.status == AttendanceStatus.late).length;
                final total = list.length;
                final rate = total > 0 ? ((present / total) * 100).toInt() : 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _StatChip('Present', present, AppColors.present),
                      const SizedBox(width: 8),
                      _StatChip('Absent', absent, AppColors.absent),
                      const SizedBox(width: 8),
                      _StatChip('Late', late, AppColors.late),
                      const SizedBox(width: 8),
                      _StatChip('Rate', rate, AppColors.info, suffix: '%'),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  TIMETABLE QUICK VIEW
// ─────────────────────────────────────────
class _TimetableQuickView extends ConsumerWidget {
  const _TimetableQuickView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      loading: () => const LoadingWidget(),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final timetable = ref.watch(timetableByClassProvider(user.id));
        return timetable.when(
          loading: () => const LoadingWidget(),
          error: (_, __) => const SizedBox.shrink(),
          data:
              (list) =>
                  list.isEmpty
                      ? const EmptyState(
                        title: 'No Timetable',
                        message: 'No schedule available',
                        icon: Icons.calendar_today_rounded,
                      )
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: TimetableGrid(entries: list),
                      ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  ENVIRONMENT QUICK VIEW
// ─────────────────────────────────────────
class _EnvironmentQuickView extends ConsumerWidget {
  const _EnvironmentQuickView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = ref.watch(roomsProvider);

    return rooms.when(
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              sensorData.when(
                loading: () => const LoadingWidget(),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) {
                  if (data == null) {
                    return const EmptyState(
                      title: 'No Data',
                      message: 'No sensor readings yet',
                      icon: Icons.sensors_off_rounded,
                    );
                  }
                  final color =
                      data.comfortScore >= 70
                          ? AppColors.success
                          : data.comfortScore >= 40
                          ? AppColors.warning
                          : AppColors.error;
                  return Column(
                    children: [
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
                      ),
                      const SizedBox(height: 16),
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
                  );
                },
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'View History',
                onPressed: () => context.push(AppRoutes.studentIotHistory),
                isOutlined: true,
                width: double.infinity,
                icon: Icons.history_rounded,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  NOTIFICATIONS QUICK VIEW
// ─────────────────────────────────────────
class _NotificationsQuickView extends ConsumerWidget {
  const _NotificationsQuickView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      loading: () => const LoadingWidget(),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final notifications = ref.watch(notificationsProvider(user.id));
        return notifications.when(
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
                        title: 'No Notifications',
                        message: 'No notifications yet',
                        icon: Icons.notifications_none_rounded,
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder:
                            (context, index) =>
                                NotificationTile(notification: list[index]),
                      ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  PROFILE BOTTOM SHEET
// ─────────────────────────────────────────
class _ProfileBottomSheet extends ConsumerWidget {
  const _ProfileBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.studentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.studentColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          user.when(
            loading: () => const LoadingWidget(),
            error: (_, __) => const Text('Student'),
            data:
                (u) => Column(
                  children: [
                    Text(
                      u?.name ?? 'Student',
                      style: AppTypography.headingMedium.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Text(
                      u?.email ?? '',
                      style: AppTypography.bodySmall.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.studentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'STUDENT',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.studentColor,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Sign Out',
            onPressed: () async {
              await ref.read(authServiceProvider).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
            isOutlined: true,
            icon: Icons.logout_rounded,
            width: double.infinity,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ───
class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String suffix;

  const _StatChip(this.label, this.value, this.color, {this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$value$suffix',
              style: AppTypography.headingSmall.copyWith(color: color),
            ),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
