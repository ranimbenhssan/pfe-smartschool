import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../services/auth_service.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends ConsumerState<TeacherDashboardScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.how_to_reg_rounded, label: 'Attendance'),
    _NavItem(icon: Icons.sensors_rounded, label: 'IoT'),
    _NavItem(icon: Icons.people_rounded, label: 'Students'),
    _NavItem(icon: Icons.menu_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: _buildAppBar(isDark),
      body: _selectedIndex == 0
          ? const _DashboardBody()
          : _selectedIndex == 1
              ? const _AttendanceQuickView()
              : _selectedIndex == 2
                  ? const _IotQuickView()
                  : _selectedIndex == 3
                      ? const _StudentsQuickView()
                      : const _MoreMenu(),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.teacherColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppColors.teacherColor,
              size: 18,
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
        Consumer(builder: (context, ref, _) {
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
        }),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 22),
          onPressed: () =>
              context.push(AppRoutes.teacherNotifications),
        ),
        GestureDetector(
          onTap: () => _showProfileMenu(context),
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.teacherColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.teacherColor,
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
        items: _navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                ))
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
    final presentCount = ref.watch(todayPresentCountProvider);
    final absentCount = ref.watch(todayAbsentCountProvider);
    final lateCount = ref.watch(todayLateCountProvider);

    return RefreshIndicator(
      color: AppColors.teacherColor,
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
              data: (user) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_getGreeting()}, ${user?.name ?? 'Teacher'} 👋',
                    style: AppTypography.headingLarge.copyWith(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(),
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Today Attendance Card ───
            GestureDetector(
              onTap: () => context.push(AppRoutes.teacherAttendanceToday),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.teacherColor.withValues(alpha: 0.8),
                      AppColors.teacherColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.teacherColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'TODAY\'S ATTENDANCE',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _AttendanceStat(
                            label: 'Present',
                            value: presentCount.toString(),
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white24,
                        ),
                        Expanded(
                          child: _AttendanceStat(
                            label: 'Absent',
                            value: absentCount.toString(),
                            icon: Icons.cancel_rounded,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white24,
                        ),
                        Expanded(
                          child: _AttendanceStat(
                            label: 'Late',
                            value: lateCount.toString(),
                            icon: Icons.watch_later_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'View full attendance',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Quick Actions ───
            Text(
              'Quick Actions',
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
                  onTap: () =>
                      context.push(AppRoutes.teacherAttendance),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  label: 'IoT Monitor',
                  icon: Icons.sensors_rounded,
                  color: AppColors.info,
                  onTap: () => context.push(AppRoutes.teacherIot),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  label: 'AI Alerts',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  onTap: () =>
                      context.push(AppRoutes.teacherAiAlerts),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  label: 'Timetable',
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.accent,
                  onTap: () =>
                      context.push(AppRoutes.teacherTimetable),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Classroom IoT ───
            _buildClassroomIot(context, isDark, ref),
            const SizedBox(height: 24),

            // ─── Recent AI Alerts ───
            _buildRecentAlerts(context, isDark, ref),
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
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _buildClassroomIot(
    BuildContext context,
    bool isDark,
    WidgetRef ref,
  ) {
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
              onPressed: () => context.push(AppRoutes.teacherIot),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        rooms.when(
          loading: () => const LoadingWidget(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                title: 'No Rooms',
                message: 'No rooms configured yet',
                icon: Icons.meeting_room_outlined,
              );
            }
            final room = list.first;
            final color = room.comfortScore >= 70
                ? AppColors.success
                : room.comfortScore >= 40
                    ? AppColors.warning
                    : AppColors.error;
            return GestureDetector(
              onTap: () => context.push(AppRoutes.teacherIot),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: color.withValues(alpha: 0.3)),
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
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                            ),
                          ),
                          Text(
                            'Floor ${room.floor}',
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
                          style: AppTypography.headingMedium
                              .copyWith(color: color),
                        ),
                        Text(
                          room.comfortScore >= 70
                              ? 'Good'
                              : room.comfortScore >= 40
                                  ? 'Average'
                                  : 'Poor',
                          style: AppTypography.caption
                              .copyWith(color: color),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentAlerts(
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

        final alerts = ref.watch(aiFlagsByClassProvider(user.id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent AI Alerts',
                  style: AppTypography.headingMedium.copyWith(
                    color:
                        isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.push(AppRoutes.teacherAiAlerts),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            alerts.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    title: 'No Active Alerts',
                    message: 'All students are doing well!',
                    icon: Icons.check_circle_outline_rounded,
                  );
                }
                return Column(
                  children: list
                      .take(3)
                      .map((flag) => AlertCard(
                            flag: flag,
                            onTap: () => context.push(
                              '${AppRoutes.teacherAlertDetail}/${flag.id}',
                            ),
                          ))
                      .toList(),
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
//  ATTENDANCE QUICK VIEW
// ─────────────────────────────────────────
class _AttendanceQuickView extends ConsumerWidget {
  const _AttendanceQuickView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayStringProvider);
    final attendance = ref.watch(attendanceByDateProvider(today));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Attendance",
                style: AppTypography.headingMedium.copyWith(
                  color:
                      isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.push(AppRoutes.teacherAttendance),
                child: const Text('Full view'),
              ),
            ],
          ),
        ),
        Expanded(
          child: attendance.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
            data: (list) => list.isEmpty
                ? const EmptyState(
                    title: 'No Attendance',
                    message: 'No records for today yet',
                    icon: Icons.event_busy_rounded,
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final record = list[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.studentName,
                                style: AppTypography.labelLarge.copyWith(
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                                ),
                              ),
                            ),
                            AttendanceBadge(status: record.status),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  IOT QUICK VIEW
// ─────────────────────────────────────────
class _IotQuickView extends ConsumerWidget {
  const _IotQuickView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return rooms.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => EmptyState(
        title: 'Error',
        message: e.toString(),
        icon: Icons.error_outline_rounded,
      ),
      data: (list) => list.isEmpty
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
                final color = room.comfortScore >= 70
                    ? AppColors.success
                    : room.comfortScore >= 40
                        ? AppColors.warning
                        : AppColors.error;
                return GestureDetector(
                  onTap: () => context.push(AppRoutes.teacherIot),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: color.withValues(alpha: 0.3)),
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
                              Text(room.name,
                                  style: AppTypography.labelLarge),
                              Text('Floor ${room.floor}',
                                  style: AppTypography.caption),
                            ],
                          ),
                        ),
                        Text(
                          '${room.comfortScore.toInt()}%',
                          style: AppTypography.headingSmall
                              .copyWith(color: color),
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

// ─────────────────────────────────────────
//  STUDENTS QUICK VIEW
// ─────────────────────────────────────────
class _StudentsQuickView extends ConsumerWidget {
  const _StudentsQuickView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(filteredStudentsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: AppTextField(
            label: '',
            hint: 'Search students...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            onChanged: (val) =>
                ref.read(studentSearchQueryProvider.notifier).state =
                    val,
          ),
        ),
        Expanded(
          child: students.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
            data: (list) => list.isEmpty
                ? const EmptyState(
                    title: 'No Students',
                    message: 'No students found',
                    icon: Icons.people_outline_rounded,
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (context, index) => StudentCard(
                      student: list[index],
                      onTap: () => context.push(
                        '${AppRoutes.teacherStudentProfile}/${list[index].id}',
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  MORE MENU
// ─────────────────────────────────────────
class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _MoreItem(
        label: 'My Timetable',
        icon: Icons.calendar_today_rounded,
        color: AppColors.accent,
        route: AppRoutes.teacherTimetable,
      ),
      _MoreItem(
        label: 'AI Alerts',
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
        route: AppRoutes.teacherAiAlerts,
      ),
      _MoreItem(
        label: 'Notifications',
        icon: Icons.notifications_rounded,
        color: AppColors.info,
        route: AppRoutes.teacherNotifications,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => context.push(item.route),
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.darkTextHint
                      : AppColors.lightTextHint,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MoreItem {
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const _MoreItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });
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
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.teacherColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.teacherColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          user.when(
            loading: () => const LoadingWidget(),
            error: (_, __) => const Text('Teacher'),
            data: (u) => Column(
              children: [
                Text(
                  u?.name ?? 'Teacher',
                  style: AppTypography.headingMedium.copyWith(
                    color:
                        isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                Text(
                  u?.email ?? '',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark
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
                    color:
                        AppColors.teacherColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'TEACHER',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.teacherColor,
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
class _AttendanceStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AttendanceStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.statNumber.copyWith(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
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

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}