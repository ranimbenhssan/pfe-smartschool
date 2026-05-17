import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  // ── Role-aware nav items ──────────────────────────────────────────────────
  List<_NavItem> _navItemsFor(UserRole role) {
    switch (role) {
      case UserRole.adminRH:
        return const [
          _NavItem(icon: Icons.home_rounded, label: 'Home'),
          _NavItem(icon: Icons.more_horiz, label: 'More'),
        ];
      case UserRole.adminScolarite:
        return const [
          _NavItem(icon: Icons.home_rounded, label: 'Home'),
          _NavItem(icon: Icons.more_horiz, label: 'More'),
        ];
      default: // superAdmin
        return const [
          _NavItem(icon: Icons.home_rounded, label: 'Home'),
          _NavItem(icon: Icons.more_horiz, label: 'More'),
        ];
    }
  }

  // ── Role-aware body ───────────────────────────────────────────────────────
  Widget _bodyFor(UserRole role) {
    switch (role) {
      case UserRole.adminRH:
        switch (_selectedIndex) {
          case 1:
            return const _MoreMenu();
          default:
            return const _RhDashboardBody();
        }
      case UserRole.adminScolarite:
        switch (_selectedIndex) {
          case 1:
            return const _MoreMenu();
          default:
            return const _ScolariteDashboardBody();
        }
      default: // superAdmin
        switch (_selectedIndex) {
          case 1:
            return const _MoreMenu();
          default:
            return const _SuperAdminDashboardBody();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = ref.watch(currentUserProvider).value?.role ?? UserRole.unknown;
    final navItems = _navItemsFor(role);

    if (_selectedIndex >= navItems.length) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setState(() => _selectedIndex = 0),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: _buildAppBar(isDark),
      body: _bodyFor(role),
      bottomNavigationBar: _buildBottomNav(isDark, navItems),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
            'Faccna',
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
                final c = ref.read(themeModeProvider);
                ref.read(themeModeProvider.notifier).state =
                    c == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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

  Widget _buildBottomNav(bool isDark, List<_NavItem> navItems) {
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
        currentIndex: _selectedIndex.clamp(0, navItems.length - 1),
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.accent,
        unselectedItemColor:
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        items:
            navItems
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

// ═══════════════════════════════════════════════════════════════════════════
//  SUPER ADMIN DASHBOARD — everything
// ═══════════════════════════════════════════════════════════════════════════
class _SuperAdminDashboardBody extends ConsumerWidget {
  const _SuperAdminDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider).value;
    final stats = ref.watch(dashboardStatsProvider);
    final activeFlags = ref.watch(activeFlagsCountProvider);
    final present = ref.watch(todayPresentCountProvider);
    final absent = ref.watch(todayAbsentCountProvider);
    final late = ref.watch(todayLateCountProvider);
    final rtdbTemp = ref.watch(rtdbTemperatureProvider);
    final rooms = ref.watch(roomsProvider);

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async => ref.refresh(dashboardStatsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Greeting(
              user: currentUser,
              role: UserRole.superAdmin,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Attendance hero card
            _HeroAttendanceCard(present: present, absent: absent, late: late),
            const SizedBox(height: 24),

            // Stats — all 4
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
              data:
                  (data) => GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      StatCard(
                        title: 'Total Students',
                        value: '${data['totalStudents'] ?? 0}',
                        icon: Icons.people_rounded,
                        color: AppColors.info,
                        onTap: () => context.push(AppRoutes.adminStudents),
                      ),
                      StatCard(
                        title: 'Total Teachers',
                        value: '${data['totalTeachers'] ?? 0}',
                        icon: Icons.person_rounded,
                        color: AppColors.accent,
                        onTap: () => context.push(AppRoutes.adminTeachers),
                      ),
                      StatCard(
                        title: 'Total Classes',
                        value: '${data['totalClasses'] ?? 0}',
                        icon: Icons.class_rounded,
                        color: AppColors.success,
                        onTap: () => context.push(AppRoutes.adminClasses),
                      ),
                      StatCard(
                        title: 'Active Absence Flags',
                        value: '$activeFlags',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.error,
                        onTap: () => context.push(AppRoutes.adminAiAlerts),
                        subtitle:
                            activeFlags > 0
                                ? '$activeFlags need attention'
                                : null,
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                children: [
                  _QA(
                    label: 'Teacher\nPresence',
                    icon: Icons.how_to_reg_rounded,
                    color: AppColors.teacherColor,
                    onTap: () => context.push(AppRoutes.adminTeacherPresence),
                  ),
                  const SizedBox(width: 10),
                  _QA(
                    label: 'RFID Logs',
                    icon: Icons.nfc_rounded,
                    color: AppColors.accent,
                    onTap: () => context.push(AppRoutes.adminRfid),
                  ),
                  const SizedBox(width: 10),
                  _QA(
                    label: 'Flags',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.error,
                    onTap: () => context.push(AppRoutes.adminAiAlerts),
                  ),
                  const SizedBox(width: 10),
                  _QA(
                    label: 'Messages',
                    icon: Icons.message_rounded,
                    color: AppColors.secondary,
                    onTap: () => context.push(AppRoutes.adminmessage),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Temperature
            _TemperatureSection(
              rtdbTemp: rtdbTemp,
              rooms: rooms,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            _RecentMessages(isDark: isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  RH ADMIN DASHBOARD — teachers only
// ═══════════════════════════════════════════════════════════════════════════
class _RhDashboardBody extends ConsumerWidget {
  const _RhDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider).value;
    final stats = ref.watch(dashboardStatsProvider);

    return RefreshIndicator(
      color: AppColors.teacherColor,
      onRefresh: () async => ref.refresh(dashboardStatsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Greeting(
              user: currentUser,
              role: UserRole.adminRH,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Stats — teachers only
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
              data:
                  (data) => GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      StatCard(
                        title: 'Total Teachers',
                        value: '${data['totalTeachers'] ?? 0}',
                        icon: Icons.person_rounded,
                        color: AppColors.teacherColor,
                        onTap: () => context.push(AppRoutes.adminTeachers),
                      ),
                      StatCard(
                        title: 'Total Classes',
                        value: '${data['totalClasses'] ?? 0}',
                        icon: Icons.class_rounded,
                        color: AppColors.success,
                        onTap: () => context.push(AppRoutes.adminClasses),
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 24),

            // Quick Actions — teachers only
            Text(
              'Quick Actions',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _QA(
                    label: 'Teachers',
                    icon: Icons.person_rounded,
                    color: AppColors.teacherColor,
                    onTap: () => context.push(AppRoutes.adminTeachers),
                  ),
                  const SizedBox(width: 10),
                  _QA(
                    label: 'Presence',
                    icon: Icons.how_to_reg_rounded,
                    color: AppColors.success,
                    onTap: () => context.push(AppRoutes.adminTeacherPresence),
                  ),
                  const SizedBox(width: 10),
                  _QA(
                    label: 'Import',
                    icon: Icons.upload_file_rounded,
                    color: AppColors.info,
                    onTap: () => context.push(AppRoutes.adminImport),
                  ),
                  const SizedBox(width: 10),
                  _QA(
                    label: 'Messages',
                    icon: Icons.message_rounded,
                    color: AppColors.secondary,
                    onTap: () => context.push(AppRoutes.adminmessage),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _TemperatureSection(
              rtdbTemp: ref.watch(rtdbTemperatureProvider),
              rooms: ref.watch(roomsProvider),
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            _RecentMessages(isDark: isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCOLARITE DASHBOARD — students, classes, flags, timetables
// ═══════════════════════════════════════════════════════════════════════════
class _ScolariteDashboardBody extends ConsumerWidget {
  const _ScolariteDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider).value;
    final stats = ref.watch(dashboardStatsProvider);
    final activeFlags = ref.watch(activeFlagsCountProvider);
    final present = ref.watch(todayPresentCountProvider);
    final absent = ref.watch(todayAbsentCountProvider);
    final late = ref.watch(todayLateCountProvider);

    return RefreshIndicator(
      color: AppColors.info,
      onRefresh: () async => ref.refresh(dashboardStatsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Greeting(
              user: currentUser,
              role: UserRole.adminScolarite,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Attendance hero (student focused)
            _HeroAttendanceCard(present: present, absent: absent, late: late),
            const SizedBox(height: 24),

            // Stats — students + classes + flags only (no teachers)
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
              data:
                  (data) => GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      StatCard(
                        title: 'Total Students',
                        value: '${data['totalStudents'] ?? 0}',
                        icon: Icons.people_rounded,
                        color: AppColors.info,
                        onTap: () => context.push(AppRoutes.adminStudents),
                      ),
                      StatCard(
                        title: 'Total Classes',
                        value: '${data['totalClasses'] ?? 0}',
                        icon: Icons.class_rounded,
                        color: AppColors.success,
                        onTap: () => context.push(AppRoutes.adminClasses),
                      ),
                      StatCard(
                        title: 'Absence Flags',
                        value: '$activeFlags',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.error,
                        onTap: () => context.push(AppRoutes.adminAiAlerts),
                        subtitle:
                            activeFlags > 0
                                ? '$activeFlags need attention'
                                : null,
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 24),

            // Quick Actions — students only
            Text(
              'Quick Actions',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _QA(
                    label: 'Students',
                    icon: Icons.school_rounded,
                    color: AppColors.studentColor,
                    onTap: () => context.push(AppRoutes.adminStudents),
                  ),
                  const SizedBox(width: 10),
                  _QA(
                    label: 'Timetable',
                    icon: Icons.schedule_rounded,
                    color: AppColors.info,
                    onTap: () => context.push(AppRoutes.adminTimetable),
                  ),
                  const SizedBox(width: 10),
                  _QA(
                    label: 'Import',
                    icon: Icons.upload_file_rounded,
                    color: AppColors.accent,
                    onTap: () => context.push(AppRoutes.adminImport),
                  ),
                  const SizedBox(width: 10),
                  _QA(
                    label: 'Messages',
                    icon: Icons.message_rounded,
                    color: AppColors.secondary,
                    onTap: () => context.push(AppRoutes.adminmessage),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _TemperatureSection(
              rtdbTemp: ref.watch(rtdbTemperatureProvider),
              rooms: ref.watch(roomsProvider),
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            _RecentMessages(isDark: isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STUDENTS TAB
// ═══════════════════════════════════════════════════════════════════════════
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
                              (context, i) => StudentCard(
                                student: list[i],
                                onTap:
                                    () => context.push(
                                      '${AppRoutes.adminStudentProfile}/${list[i].id}',
                                    ),
                              ),
                        ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MORE MENU — role-aware
// ═══════════════════════════════════════════════════════════════════════════
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = ref.watch(currentUserProvider).value?.role ?? UserRole.unknown;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _itemsFor(role).length,
      itemBuilder: (context, i) {
        final item = _itemsFor(role)[i];
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

  List<_MoreItem> _itemsFor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return const [
          _MoreItem(
            label: 'Staff',
            icon: Icons.badge_rounded,
            color: AppColors.info,
            route: AppRoutes.adminStaff,
          ),
          _MoreItem(
            label: 'Teachers',
            icon: Icons.person_rounded,
            color: AppColors.teacherColor,
            route: AppRoutes.adminTeachers,
          ),
          _MoreItem(
            label: 'Students',
            icon: Icons.school_rounded,
            color: AppColors.studentColor,
            route: AppRoutes.adminStudents,
          ),
          _MoreItem(
            label: 'Classes',
            icon: Icons.class_rounded,
            color: AppColors.accent,
            route: AppRoutes.adminClasses,
          ),
          _MoreItem(
            label: 'Timetable',
            icon: Icons.schedule_rounded,
            color: AppColors.info,
            route: AppRoutes.adminTimetable,
          ),
          _MoreItem(
            label: 'RFID Logs',
            icon: Icons.nfc_rounded,
            color: AppColors.accent,
            route: AppRoutes.adminRfid,
          ),
          _MoreItem(
            label: 'Teacher Presence',
            icon: Icons.how_to_reg_rounded,
            color: AppColors.teacherColor,
            route: AppRoutes.adminTeacherPresence,
          ),
          _MoreItem(
            label: 'Teacher Sheet',
            icon: Icons.table_rows_rounded,
            color: AppColors.info,
            route: AppRoutes.adminTeacherSheet,
          ),
          _MoreItem(
            label: 'Absence Flags',
            icon: Icons.warning_amber_rounded,
            color: AppColors.error,
            route: AppRoutes.adminAiAlerts,
          ),
          _MoreItem(
            label: 'Attendance',
            icon: Icons.bar_chart_rounded,
            color: AppColors.success,
            route: AppRoutes.adminAttendance,
          ),
          _MoreItem(
            label: 'IoT Monitor',
            icon: Icons.sensors_rounded,
            color: AppColors.accent,
            route: AppRoutes.adminIot,
          ),
          _MoreItem(
            label: 'Messages',
            icon: Icons.message_rounded,
            color: AppColors.secondary,
            route: AppRoutes.adminmessage,
          ),
          _MoreItem(
            label: 'Staff Password Reqs',
            icon: Icons.lock_reset_rounded,
            color: AppColors.warning,
            route: AppRoutes.adminPasswordRequests,
          ),
          _MoreItem(
            label: 'Import Staff',
            icon: Icons.upload_file_rounded,
            color: AppColors.success,
            route: AppRoutes.adminStaffImport,
          ),
          _MoreItem(
            label: 'Settings',
            icon: Icons.settings_rounded,
            color: AppColors.accent,
            route: AppRoutes.adminSettings,
          ),
        ];

      case UserRole.adminRH:
        return const [
          _MoreItem(
            label: 'Teachers',
            icon: Icons.person_rounded,
            color: AppColors.teacherColor,
            route: AppRoutes.adminTeachers,
          ),
          _MoreItem(
            label: 'Teacher Presence',
            icon: Icons.how_to_reg_rounded,
            color: AppColors.success,
            route: AppRoutes.adminTeacherPresence,
          ),
          _MoreItem(
            label: 'Teacher Sheet',
            icon: Icons.table_rows_rounded,
            color: AppColors.info,
            route: AppRoutes.adminTeacherSheet,
          ),
          _MoreItem(
            label: 'Timetable',
            icon: Icons.schedule_rounded,
            color: AppColors.info,
            route: AppRoutes.adminTimetable,
          ),
          _MoreItem(
            label: 'Import Teachers',
            icon: Icons.upload_file_rounded,
            color: AppColors.success,
            route: AppRoutes.adminImport,
          ),
          _MoreItem(
            label: 'Messages',
            icon: Icons.message_rounded,
            color: AppColors.secondary,
            route: AppRoutes.adminmessage,
          ),
          _MoreItem(
            label: 'Password Requests',
            icon: Icons.lock_reset_rounded,
            color: AppColors.warning,
            route: AppRoutes.adminPasswordRequests,
          ),
        ];

      case UserRole.adminScolarite:
        return const [
          _MoreItem(
            label: 'Students',
            icon: Icons.school_rounded,
            color: AppColors.studentColor,
            route: AppRoutes.adminStudents,
          ),
          _MoreItem(
            label: 'Classes',
            icon: Icons.class_rounded,
            color: AppColors.accent,
            route: AppRoutes.adminClasses,
          ),
          _MoreItem(
            label: 'Timetable',
            icon: Icons.schedule_rounded,
            color: AppColors.info,
            route: AppRoutes.adminTimetable,
          ),
          _MoreItem(
            label: 'Attendance',
            icon: Icons.bar_chart_rounded,
            color: AppColors.success,
            route: AppRoutes.adminAttendance,
          ),
          _MoreItem(
            label: 'Absence Flags',
            icon: Icons.warning_amber_rounded,
            color: AppColors.error,
            route: AppRoutes.adminAiAlerts,
          ),
          _MoreItem(
            label: 'Import',
            icon: Icons.upload_file_rounded,
            color: AppColors.success,
            route: AppRoutes.adminImport,
          ),
          _MoreItem(
            label: 'Messages',
            icon: Icons.message_rounded,
            color: AppColors.secondary,
            route: AppRoutes.adminmessage,
          ),
          _MoreItem(
            label: 'Password Requests',
            icon: Icons.lock_reset_rounded,
            color: AppColors.warning,
            route: AppRoutes.adminPasswordRequests,
          ),
        ];

      default:
        return const [];
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _Greeting extends StatelessWidget {
  final UserModel? user;
  final UserRole role;
  final bool isDark;
  const _Greeting({
    required this.user,
    required this.role,
    required this.isDark,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good Morning'
        : h < 17
        ? 'Good Afternoon'
        : 'Good Evening';
  }

  String _date() {
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
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${_greeting()}, ${user?.name ?? 'Admin'} 👋',
        style: AppTypography.headingLarge.copyWith(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      Text(
        role.label,
        style: AppTypography.caption.copyWith(
          color:
              isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
        ),
      ),
      Text(
        _date(),
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

class _HeroAttendanceCard extends StatelessWidget {
  final int present, absent, late;
  const _HeroAttendanceCard({
    required this.present,
    required this.absent,
    required this.late,
  });

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    'Present',
                    '$present',
                    AppColors.success,
                    Icons.check_circle_rounded,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.white12),
                Expanded(
                  child: _Stat(
                    'Absent',
                    '$absent',
                    AppColors.error,
                    Icons.cancel_rounded,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.white12),
                Expanded(
                  child: _Stat(
                    'Late',
                    '$late',
                    AppColors.warning,
                    Icons.watch_later_rounded,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.white12),
                Expanded(
                  child: _Stat(
                    'Rate',
                    '$rate%',
                    AppColors.accent,
                    Icons.percent_rounded,
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
                valueColor: const AlwaysStoppedAnimation(AppColors.success),
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
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _Stat(this.label, this.value, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Column(
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
      Text(label, style: AppTypography.caption.copyWith(color: Colors.white70)),
    ],
  );
}

class _TemperatureSection extends StatelessWidget {
  final AsyncValue<DhtData?> rtdbTemp;
  final AsyncValue<List<RoomModel>> rooms;
  final bool isDark;
  const _TemperatureSection({
    required this.rtdbTemp,
    required this.rooms,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Classroom Temperature',
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
        rtdbTemp.when(
          loading: () => const LoadingWidget(),
          error:
              (_, __) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.sensors_off_rounded,
                      color: AppColors.error,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('Sensor offline'),
                  ],
                ),
              ),
          data: (d) {
            if (d == null)
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Waiting for sensor data...'),
              );
            final tColor =
                d.temperature < 24
                    ? AppColors.success
                    : d.temperature < 28
                    ? AppColors.warning
                    : AppColors.error;
            return rooms.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data:
                  (list) => SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: list.take(10).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final room = list[i];
                        return Container(
                          width: 110,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(room.name, style: AppTypography.labelSmall),
                              Text(
                                'Floor ${room.floor}',
                                style: AppTypography.caption,
                              ),
                              Text(
                                '${d.temperature.toStringAsFixed(1)}°C',
                                style: AppTypography.labelSmall.copyWith(
                                  color: tColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            );
          },
        ),
      ],
    );
  }
}

class _RecentMessages extends ConsumerWidget {
  final bool isDark;
  const _RecentMessages({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                // superAdmin: hide attendance corrections and absence flag
                // notifications sent to students — only show real messages
                final filtered =
                    list
                        .where((m) {
                          final t =
                              m.rawMessageType.isNotEmpty
                                  ? m.rawMessageType
                                  : m.messageType.name;
                          if (t == 'attendance') return false;
                          if (t == 'absence_flag' &&
                              m.recipientLabel != 'Admin')
                            return false;
                          if (t == 'password_reset') return false;
                          return true;
                        })
                        .take(3)
                        .toList();

                if (filtered.isEmpty) {
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
                      filtered.map((m) => MessagesTile(message: m)).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _QA extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QA({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: color),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

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
