import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.people_rounded, label: 'Students'),
    _NavItem(icon: Icons.more_horiz, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingCount =
        ref
            .watch(
              StreamProvider(
                (ref) => FirebaseFirestore.instance
                    .collection('password_reset_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots()
                    .map((s) => s.docs.length),
              ),
            )
            .value ??
        0;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: _buildAppBar(isDark),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const _DashboardBody(),
          const _StudentsTab(),
          _MoreMenu(pendingCount: pendingCount),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      title: Text(
        'SmartSchool',
        style: AppTypography.headingMedium.copyWith(
          color: isDark ? AppColors.darkText : AppColors.lightText,
          fontFamily: AppTypography.displayFont,
        ),
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
          icon: const Icon(Icons.message_rounded, size: 22),
          onPressed: () => context.push(AppRoutes.adminmessage),
        ),
        GestureDetector(
          onTap:
              () => showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const _ProfileBottomSheet(),
              ),
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
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.accent,
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

    // ── All count providers return int — use directly, no .maybeWhen ───────
    final stats = ref.watch(dashboardStatsProvider);
    final activeFlags = ref.watch(activeFlagsCountProvider);
    final present = ref.watch(todayPresentCountProvider); // int
    final absent = ref.watch(todayAbsentCountProvider); // int
    final late = ref.watch(todayLateCountProvider); // int

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

            // ── Hero attendance card ────────────────────────────────────
            _buildHeroCard(context, isDark, present, absent, late),
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
                    title: 'Error',
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
            _buildQuickActions(context),
            const SizedBox(height: 24),

            _buildRecentMessages(context, isDark, ref),
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
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, Admin 👋',
          style: AppTypography.headingLarge.copyWith(
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        Text(
          '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}',
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

  // ── Hero card — present/absent/late are plain int ──────────────────────
  Widget _buildHeroCard(
    BuildContext context,
    bool isDark,
    int present,
    int absent,
    int late,
  ) {
    final total = present + absent + late;
    final rate = total > 0 ? ((present / total) * 100).toInt() : 0;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "TODAY'S ATTENDANCE",
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.accent,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Stat row — uses plain int directly ──────────────────────
            Row(
              children: [
                Expanded(
                  child: _AttendanceStat(
                    label: 'Present',
                    value: '$present', // int → String directly
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.white12),
                Expanded(
                  child: _AttendanceStat(
                    label: 'Absent',
                    value: '$absent',
                    color: AppColors.error,
                    icon: Icons.cancel_rounded,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.white12),
                Expanded(
                  child: _AttendanceStat(
                    label: 'Late',
                    value: '$late',
                    color: AppColors.warning,
                    icon: Icons.watch_later_rounded,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.white12),
                Expanded(
                  child: _AttendanceStat(
                    label: 'Rate',
                    value: '$rate%',
                    color: AppColors.accent,
                    icon: Icons.percent_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? present / total : 0,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.success,
                ),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 8),

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
          subtitle: activeFlags > 0 ? '$activeFlags need attention' : null,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        _QuickAction(
          label: 'RFID Logs',
          icon: Icons.nfc_rounded,
          color: AppColors.info,
          onTap: () => context.push(AppRoutes.adminRfid),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          label: 'Timetable',
          icon: Icons.calendar_today_rounded,
          color: AppColors.success,
          onTap: () => context.push(AppRoutes.adminTimetable),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          label: 'Messages',
          icon: Icons.notifications_rounded,
          color: AppColors.accent,
          onTap: () => context.push(AppRoutes.adminmessage),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          label: 'Settings',
          icon: Icons.settings_rounded,
          color: AppColors.warning,
          onTap: () => context.push(AppRoutes.adminSettings),
        ),
      ],
    );
  }

  Widget _buildRecentMessages(
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
        final messages = ref.watch(notificationsProvider(user.id));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Messages',
                  style: AppTypography.headingMedium.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.adminmessage),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            messages.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    child: Text(
                      'No messages yet',
                      style: AppTypography.bodySmall.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),
                  );
                }
                return Column(
                  children:
                      list
                          .take(3)
                          .map((m) => MessagesTile(message: m))
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
//  STUDENTS TAB
// ─────────────────────────────────────────
class _StudentsTab extends ConsumerWidget {
  const _StudentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = ref.watch(filteredStudentsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged:
                (v) => ref.read(studentSearchQueryProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
                        ? const EmptyState(
                          title: 'No Students',
                          message: 'No students found',
                          icon: Icons.people_outline_rounded,
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
//  MORE MENU
// ─────────────────────────────────────────
class _MoreMenu extends StatelessWidget {
  final int pendingCount;

  const _MoreMenu({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const items = [
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
        label: 'Password Requests',
        icon: Icons.lock_reset_rounded,
        color: AppColors.warning,
        route: AppRoutes.adminPasswordRequests,
      ),
      _MoreItem(
        label: 'Attendance Reports',
        icon: Icons.bar_chart_rounded,
        color: AppColors.warning,
        route: AppRoutes.adminAttendance,
      ),
      _MoreItem(
        label: 'Send Message',
        icon: Icons.send_rounded,
        color: AppColors.secondary,
        route: AppRoutes.adminmessageend,
      ),
      _MoreItem(
        label: 'Timetable',
        icon: Icons.calendar_today_rounded,
        color: AppColors.accent,
        route: AppRoutes.adminTimetable,
      ),
      _MoreItem(
        label: 'Bulk Import',
        icon: Icons.upload_file_rounded,
        color: AppColors.success,
        route: AppRoutes.adminImport,
      ),
      _MoreItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
        color: AppColors.error,
        route: AppRoutes.adminSettings,
      ),
      _MoreItem(
        label: 'Room Management',
        icon: Icons.meeting_room_rounded,
        color: AppColors.info,
        route: AppRoutes.adminRooms,
      ),
      _MoreItem(
        label: 'Semester Management',
        icon: Icons.calendar_month_rounded,
        color: AppColors.info,
        route: AppRoutes.adminSemesters,
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
                  child:
                      item.label == 'Password Requests' && pendingCount > 0
                          ? Badge(
                            label: Text(pendingCount.toString()),
                            child: Icon(item.icon, color: item.color, size: 20),
                          )
                          : Icon(item.icon, color: item.color, size: 20),
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

// ─────────────────────────────────────────
//  ATTENDANCE STAT WIDGET
// ─────────────────────────────────────────
class _AttendanceStat extends StatelessWidget {
  final String label;
  final String value; // pre-formatted string — no AsyncValue involved
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
        Icon(icon, color: color, size: 18),
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

// ─────────────────────────────────────────
//  QUICK ACTION
// ─────────────────────────────────────────
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

// ─────────────────────────────────────────
//  PROFILE BOTTOM SHEET
// ─────────────────────────────────────────
class _ProfileBottomSheet extends ConsumerWidget {
  const _ProfileBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

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
                  ],
                ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Change Password',
            onPressed: () {
              Navigator.pop(context);
              context.push(AppRoutes.changePassword);
            },
            isOutlined: true,
            icon: Icons.lock_outline_rounded,
            width: double.infinity,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Logout',
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).logout();
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

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
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
