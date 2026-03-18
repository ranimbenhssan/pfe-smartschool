import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../models/ai_flag_model.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.people_rounded, label: 'Students'),
    _NavItem(icon: Icons.sensors_rounded, label: 'IoT'),
    _NavItem(icon: Icons.warning_amber_rounded, label: 'Alerts'),
    _NavItem(icon: Icons.menu_rounded, label: 'More'),
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
              ? const _StudentsQuickView()
              : _selectedIndex == 2
              ? const _IotQuickView()
              : _selectedIndex == 3
              ? const _AlertsQuickView()
              : const _MoreMenu(),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppColors.primary,
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
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 22),
          onPressed: () => context.push(AppRoutes.adminNotifications),
        ),
        GestureDetector(
          onTap: () => _showProfileMenu(context),
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
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
    final stats = ref.watch(dashboardStatsProvider);
    final activeFlags = ref.watch(activeFlagsCountProvider);
    final presentCount = ref.watch(todayPresentCountProvider);
    final absentCount = ref.watch(todayAbsentCountProvider);
    final lateCount = ref.watch(todayLateCountProvider);

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async => ref.refresh(dashboardStatsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(isDark),
            const SizedBox(height: 24),
            _buildHeroCard(
              context,
              isDark,
              presentCount,
              absentCount,
              lateCount,
            ),
            const SizedBox(height: 24),
            Text(
              'Overview',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            stats.when(
              loading: () => const LoadingWidget(),
              error:
                  (e, _) => EmptyState(
                    title: 'Error loading stats',
                    message: e.toString(),
                    icon: Icons.error_outline_rounded,
                  ),
              data: (data) => _buildStatsGrid(context, data, activeFlags),
            ),
            const SizedBox(height: 24),
            Text(
              'Quick Actions',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickActions(context, isDark),
            const SizedBox(height: 24),
            _buildRecentAlerts(context, isDark, ref),
            const SizedBox(height: 24),
            _buildRoomsOverview(context, isDark, ref),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(bool isDark) {
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12
            ? 'Good Morning'
            : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, Admin 👋',
          style: AppTypography.headingLarge.copyWith(
            color: isDark ? AppColors.darkText : AppColors.lightText,
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
    );
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

  Widget _buildHeroCard(
    BuildContext context,
    bool isDark,
    int present,
    int absent,
    int late,
  ) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.adminAttendance),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.08),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'TODAY\'S ATTENDANCE',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.accent,
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
                        value: present.toString(),
                        color: AppColors.success,
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    Container(width: 1, height: 50, color: Colors.white12),
                    Expanded(
                      child: _AttendanceStat(
                        label: 'Absent',
                        value: absent.toString(),
                        color: AppColors.error,
                        icon: Icons.cancel_rounded,
                      ),
                    ),
                    Container(width: 1, height: 50, color: Colors.white12),
                    Expanded(
                      child: _AttendanceStat(
                        label: 'Late',
                        value: late.toString(),
                        color: AppColors.warning,
                        icon: Icons.watch_later_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'View full attendance report',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white60,
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    Map<String, int> data,
    int activeFlags,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatCard(
          title: 'Total Students',
          value: data['totalStudents'].toString(),
          icon: Icons.people_rounded,
          color: AppColors.info,
          onTap: () => context.push(AppRoutes.adminStudents),
        ),
        StatCard(
          title: 'Total Teachers',
          value: data['totalTeachers'].toString(),
          icon: Icons.person_rounded,
          color: AppColors.accent,
          onTap: () => context.push(AppRoutes.adminTeachers),
        ),
        StatCard(
          title: 'Total Classes',
          value: data['totalClasses'].toString(),
          icon: Icons.class_rounded,
          color: AppColors.success,
          onTap: () => context.push(AppRoutes.adminClasses),
        ),
        StatCard(
          title: 'Active AI Flags',
          value: activeFlags.toString(),
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
          onTap: () => context.push(AppRoutes.adminAiAlerts),
          subtitle: activeFlags > 0 ? 'Needs attention' : 'All clear',
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      _QuickAction(
        label: 'RFID Logs',
        icon: Icons.nfc_rounded,
        color: AppColors.info,
        onTap: () => context.push(AppRoutes.adminRfid),
      ),
      _QuickAction(
        label: 'Timetable',
        icon: Icons.calendar_today_rounded,
        color: AppColors.accent,
        onTap: () => context.push(AppRoutes.adminTimetable),
      ),
      _QuickAction(
        label: 'Notifications',
        icon: Icons.notifications_rounded,
        color: AppColors.success,
        onTap: () => context.push(AppRoutes.adminNotifications),
      ),
      _QuickAction(
        label: 'Settings',
        icon: Icons.settings_rounded,
        color: AppColors.warning,
        onTap: () => context.push(AppRoutes.adminSettings),
      ),
    ];

    return Row(
      children:
          actions
              .map(
                (action) => Expanded(
                  child: GestureDetector(
                    onTap: action.onTap,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: action.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: action.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(action.icon, color: action.color, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            action.label,
                            style: AppTypography.labelSmall.copyWith(
                              color: action.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildRecentAlerts(BuildContext context, bool isDark, WidgetRef ref) {
    final alerts = ref.watch(activeAiFlagsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent AI Alerts',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.adminAiAlerts),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        alerts.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                title: 'No Active Alerts',
                message: 'All students are doing well!',
                icon: Icons.check_circle_outline_rounded,
              );
            }
            final recent = list.take(3).toList();
            return Column(
              children:
                  recent
                      .map(
                        (flag) => AlertCard(
                          flag: flag,
                          onTap:
                              () => context.push(
                                '${AppRoutes.adminAlertDetail}/${flag.id}',
                              ),
                        ),
                      )
                      .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoomsOverview(BuildContext context, bool isDark, WidgetRef ref) {
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
              onPressed: () => context.push(AppRoutes.adminIot),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        rooms.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                title: 'No Rooms',
                message: 'No rooms configured yet',
                icon: Icons.meeting_room_outlined,
              );
            }
            return SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final room = list[index];
                  final color =
                      room.comfortScore >= 70
                          ? AppColors.success
                          : room.comfortScore >= 40
                          ? AppColors.warning
                          : AppColors.error;
                  return GestureDetector(
                    onTap:
                        () => context.push(
                          '${AppRoutes.adminRoomDetail}/${room.id}',
                        ),
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                room.comfortScore >= 70
                                    ? 'Good'
                                    : room.comfortScore >= 40
                                    ? 'Average'
                                    : 'Poor',
                                style: AppTypography.labelSmall.copyWith(
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                            'Floor ${room.floor}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Attendance Stat Widget ───
class _AttendanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _AttendanceStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.statNumber.copyWith(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: Colors.white60),
        ),
      ],
    );
  }
}

// ─── Quick Action Model ───
class _QuickAction {
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
}

// ─── Nav Item Model ───
class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
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
            onChanged:
                (val) =>
                    ref.read(studentSearchQueryProvider.notifier).state = val,
          ),
        ),
        Expanded(
          child: students.when(
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
                        ? EmptyState(
                          title: 'No Students',
                          message: 'No students found',
                          icon: Icons.people_outline_rounded,
                          buttonLabel: 'Add Student',
                          onButtonTap:
                              () => context.push(AppRoutes.adminStudentAdd),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: list.length,
                          itemBuilder:
                              (context, index) => StudentCard(
                                student: list[index],
                                onTap:
                                    () => context.push(
                                      '${AppRoutes.adminStudentProfile}/${list[index].id}',
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
                      final color =
                          room.comfortScore >= 70
                              ? AppColors.success
                              : room.comfortScore >= 40
                              ? AppColors.warning
                              : AppColors.error;
                      return GestureDetector(
                        onTap:
                            () => context.push(
                              '${AppRoutes.adminRoomDetail}/${room.id}',
                            ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                            ),
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
                                      style: AppTypography.labelLarge,
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
                                    style: AppTypography.headingSmall.copyWith(
                                      color: color,
                                    ),
                                  ),
                                  Text('comfort', style: AppTypography.caption),
                                ],
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
//  ALERTS QUICK VIEW
// ─────────────────────────────────────────
class _AlertsQuickView extends ConsumerWidget {
  const _AlertsQuickView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(filteredActiveFlagsProvider);
    final currentFilter = ref.watch(flagFilterTypeProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: currentFilter == null,
                  onTap:
                      () =>
                          ref.read(flagFilterTypeProvider.notifier).state =
                              null,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Absent',
                  isSelected: currentFilter == FlagType.frequentAbsent,
                  onTap:
                      () =>
                          ref.read(flagFilterTypeProvider.notifier).state =
                              FlagType.frequentAbsent,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Late',
                  isSelected: currentFilter == FlagType.latePattern,
                  onTap:
                      () =>
                          ref.read(flagFilterTypeProvider.notifier).state =
                              FlagType.latePattern,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Suspicious',
                  isSelected: currentFilter == FlagType.suspicious,
                  onTap:
                      () =>
                          ref.read(flagFilterTypeProvider.notifier).state =
                              FlagType.suspicious,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: alerts.when(
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
                          title: 'No Active Alerts',
                          message: 'All students are doing well!',
                          icon: Icons.check_circle_outline_rounded,
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: list.length,
                          itemBuilder:
                              (context, index) => AlertCard(
                                flag: list[index],
                                onTap:
                                    () => context.push(
                                      '${AppRoutes.adminAlertDetail}/${list[index].id}',
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
        label: 'Teacher Management',
        icon: Icons.person_rounded,
        color: AppColors.accent,
        route: AppRoutes.adminTeachers,
      ),
      _MoreItem(
        label: 'Class Management',
        icon: Icons.class_rounded,
        color: AppColors.info,
        route: AppRoutes.adminClasses,
      ),
      _MoreItem(
        label: 'RFID Management',
        icon: Icons.nfc_rounded,
        color: AppColors.success,
        route: AppRoutes.adminRfid,
      ),
      _MoreItem(
        label: 'Attendance Reports',
        icon: Icons.bar_chart_rounded,
        color: AppColors.warning,
        route: AppRoutes.adminAttendance,
      ),
      _MoreItem(
        label: 'Send Notification',
        icon: Icons.send_rounded,
        color: AppColors.secondary,
        route: AppRoutes.adminNotificationSend,
      ),
      _MoreItem(
        label: 'Timetable',
        icon: Icons.calendar_today_rounded,
        color: AppColors.accent,
        route: AppRoutes.adminTimetable,
      ),
      _MoreItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
        color: AppColors.error,
        route: AppRoutes.adminSettings,
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
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color:
                      isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
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
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          user.when(
            loading: () => const LoadingWidget(),
            error: (_, __) => const Text('Admin'),
            data:
                (u) => Column(
                  children: [
                    Text(
                      u?.name ?? 'Admin',
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
                        color: AppColors.adminColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ADMIN',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.adminColor,
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

// ─── Filter Chip Widget ───
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.accent
                    : AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? AppColors.primary : AppColors.accent,
          ),
        ),
      ),
    );
  }
}
