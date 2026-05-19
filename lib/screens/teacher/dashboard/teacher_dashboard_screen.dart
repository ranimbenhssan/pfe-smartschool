import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';
import '../attendance/teacher_namecall_screen.dart';

/// Launch namecall smart: auto-detect current seance for selected date.
/// Shows a seance picker if the teacher has multiple simultaneous seances.

/// Merge entries with same subject+day+startTime+endTime into one namecall entry.

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
    _NavItem(icon: Icons.menu_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: _buildAppBar(isDark),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _DashboardBody(),
          _MoreMenu(),
        ],
      ),
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
          onPressed: () => context.push(AppRoutes.teachermessage),
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
        selectedItemColor: AppColors.teacherColor,
        unselectedItemColor:
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
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

  static const _weekdays = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return RefreshIndicator(
      color: AppColors.teacherColor,
      onRefresh: () async => ref.refresh(currentUserProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: currentUser.when(
          loading: () => const LoadingWidget(),
          error: (_, __) => const SizedBox.shrink(),
          data: (user) {
            if (user == null) return const SizedBox.shrink();

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
                // ── Greeting ────────────────────────────────────────────
                Text(
                  '$greeting, ${user.name} 👋',
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
                const SizedBox(height: 24),

                // ── TIMETABLE SÉANCES ─────────────────────────────────────
                // Replaces the old attendance counter card.
                _TimetableSeancesSection(teacherId: user.id, isDark: isDark),
                const SizedBox(height: 24),

                // ── Quick actions ────────────────────────────────────────
                Text(
                  'Quick Actions',
                  style: AppTypography.headingMedium.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // ── Namecall — shows date picker, defaults today ────────
                    _QuickAction(
                      label: 'Namecall',
                      icon: Icons.how_to_reg_rounded,
                      color: AppColors.teacherColor,
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TeacherNamecallScreen(),
                            ),
                          ),
                    ),
                    const SizedBox(width: 10),
                    _QuickAction(
                      label: 'Timetable',
                      icon: Icons.calendar_today_rounded,
                      color: AppColors.info,
                      onTap: () => context.push(AppRoutes.teacherTimetable),
                    ),
                    const SizedBox(width: 10),
                    _QuickAction(
                      label: 'Students',
                      icon: Icons.people_rounded,
                      color: AppColors.success,
                      onTap: () => context.push(AppRoutes.teacherStudents),
                    ),
                    const SizedBox(width: 10),
                    _QuickAction(
                      label: 'IoT',
                      icon: Icons.sensors_rounded,
                      color: AppColors.accent,
                      onTap: () => context.push(AppRoutes.teacherIot),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Absence Flags ────────────────────────────────────────
                _buildAiFlags(context, isDark, ref),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate() {
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

  Widget _buildAiFlags(BuildContext context, bool isDark, WidgetRef ref) {
    final flags = ref.watch(activeAiFlagsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Absence Flags',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.teacherAiAlerts),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        flags.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                title: 'No Flags',
                message: 'No active absence flags',
                icon: Icons.check_circle_outline_rounded,
              );
            }
            return Column(
              children:
                  list
                      .take(3)
                      .map(
                        (flag) => AlertCard(
                          flag: flag,
                          onTap:
                              () => context.push(
                                '${AppRoutes.teacherAlertDetail}/${flag.id}',
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  TIMETABLE SÉANCES SECTION
//
//  Fetches today's timetable entries for the logged-in teacher.
//  Groups entries that share the same subject + time window
//  (same session taught to multiple classes simultaneously) into one card.
//  Numbered sequentially by start time: "Séance 1.", "Séance 2." …
//  Active session is highlighted.
//  Tapping → Namecall for the first classId in that session.
// ─────────────────────────────────────────────────────────────────────────────
class _TimetableSeancesSection extends ConsumerWidget {
  final String teacherId;
  final bool isDark;

  static const _weekdays = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  const _TimetableSeancesSection({
    required this.teacherId,
    required this.isDark,
  });

  /// Group timetable entries that share the same subject + startTime + endTime
  /// into a single séance (one slot can cover multiple classes).
  List<_Seance> _groupIntoSeances(List<TimetableModel> entries) {
    final map = <String, _Seance>{};
    for (final e in entries) {
      // Key: subject + start + end — distinct session slot
      final key = '${e.subject}|${e.startTime}|${e.endTime}';
      if (map.containsKey(key)) {
        map[key]!.entries.add(e);
      } else {
        map[key] = _Seance(entries: [e]);
      }
    }
    // Sort by start time, then number them
    final sorted =
        map.values.toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
    for (int i = 0; i < sorted.length; i++) {
      sorted[i].number = i + 1;
    }
    return sorted;
  }

  bool _isActive(_Seance seance) {
    final now = DateTime.now();
    final curr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return curr.compareTo(seance.startTime) >= 0 &&
        curr.compareTo(seance.endTime) <= 0;
  }

  bool _matchesWeekType(TimetableModel entry, String weekType) {
    if (entry.isRattrapage) return true;
    if (weekType.isEmpty) return true;
    return entry.weekType.isEmpty || entry.weekType == weekType;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayStringProvider);
    final dayName = _weekdays[DateTime.now().weekday];
    final timetable = ref.watch(timetableByTeacherProvider(teacherId));

    // Determine if tomorrow needs showing (after 15:00, show tomorrow's schedule)
    final now = DateTime.now();
    final showTomorrow = now.hour >= 15;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowName = _weekdays[tomorrow.weekday];

    final displayDay = showTomorrow ? tomorrowName : dayName;
    final targetDate = showTomorrow ? tomorrow : now;
    final displayLabel =
        showTomorrow
            ? 'Timetable tomorrow ${tomorrow.day}.${tomorrow.month.toString().padLeft(2, '0')}.'
            : "Today's Timetable";

    return timetable.when(
      loading: () => const LoadingWidget(),
      error:
          (e, _) => EmptyState(
            title: 'Error',
            message: e.toString(),
            icon: Icons.error_outline_rounded,
          ),
      data: (allEntries) {
        // Filter to the display day
        final weekType = ref.watch(currentWeekTypeProvider);
        final dayEntries =
            allEntries
                .where((e) => e.effectiveDayOfWeek == displayDay)
                .where((e) => e.occursOnDate(targetDate))
                .where((e) => _matchesWeekType(e, weekType))
                .toList();

        final seances = _groupIntoSeances(dayEntries);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayLabel,
                        style: AppTypography.headingMedium.copyWith(
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      if (!showTomorrow && seances.isNotEmpty)
                        Text(
                          '${seances.length} session${seances.length == 1 ? '' : 's'}',
                          style: AppTypography.caption.copyWith(
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.teacherTimetable),
                  child: const Text('Full view'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (seances.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 32,
                      color:
                          isDark
                              ? AppColors.darkTextHint
                              : AppColors.lightTextHint,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      showTomorrow
                          ? 'No classes scheduled tomorrow'
                          : 'No classes scheduled today',
                      style: AppTypography.caption.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              // ── Horizontal scrollable séance cards ────────────────────
              SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: seances.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final seance = seances[index];
                    final active = !showTomorrow && _isActive(seance);
                    return _SeanceCard(
                      seance: seance,
                      isActive: active,
                      isDark: isDark,
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => TeacherNamecallScreen(
                                    preselectedSlot: seance.entries.first,
                                  ),
                            ),
                          ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SÉANCE DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────
class _Seance {
  int number = 1;
  final List<TimetableModel> entries;

  _Seance({required this.entries});

  String get subject => entries.first.subject;
  String get startTime => entries.first.startTime;
  String get endTime => entries.first.endTime;

  /// "2DNI1, 2DNI2" — comma-joined class names using className field
  /// (stored as "Level Name Grade" e.g. "2 DNI 1")
  String get classesLabel => entries
      .map((e) {
        // className is already "Level Name Grade" format — compact it for display
        // by removing spaces: "2 DNI 1" → "2DNI1"
        final raw = e.className.trim();
        return raw.replaceAll(' ', '');
      })
      .toSet()
      .join(', ');

  /// All classIds for this session (for multi-class namecall)
  List<String> get classIds => entries.map((e) => e.classId).toSet().toList();

  /// Room name — same for all entries in the session (same slot = same room).
  /// Falls back to roomId if roomName is empty.
  String get roomLabel {
    final rn = entries.first.roomName.trim();
    if (rn.isNotEmpty) return rn;
    final ri = entries.first.roomId.trim();
    return ri.isNotEmpty ? ri : '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SÉANCE CARD
//  Matches the reference image: session number, subject, classes, time slot.
//  Active session has accent/highlighted background.
// ─────────────────────────────────────────────────────────────────────────────
class _SeanceCard extends StatelessWidget {
  final _Seance seance;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _SeanceCard({
    required this.seance,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Active card: teacher-color tinted. Inactive: card background.
    final bgColor =
        isActive
            ? const Color.fromARGB(255, 46, 153, 195)
            : const Color.fromARGB(255, 46, 153, 195);

    final borderColor =
        isActive ? const Color(0xFFA0E6FF) : const Color(0xFFA0E6FF);

    final labelColor = isActive ? AppColors.teacherColor : Colors.white54;

    final subjectColor = Colors.white;
    final classColor = Colors.white70;
    final timeColor = Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow:
              isActive
                  ? [
                    BoxShadow(
                      color: AppColors.teacherColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Session number ──
            Text(
              'Séance ${seance.number}.',
              style: AppTypography.caption.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),

            // ── Subject ──
            Text(
              seance.subject,
              style: AppTypography.headingMedium.copyWith(
                color: subjectColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Classes ──
            Text(
              seance.classesLabel,
              style: AppTypography.labelSmall.copyWith(color: classColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Room ──
            if (seance.roomLabel.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.meeting_room_rounded,
                    size: 11,
                    color:
                        isActive
                            ? AppColors.teacherColor.withValues(alpha: 0.8)
                            : Colors.white38,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      seance.roomLabel,
                      style: AppTypography.caption.copyWith(
                        color:
                            isActive
                                ? AppColors.teacherColor.withValues(alpha: 0.85)
                                : Colors.white38,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

            // ── Time slot ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seance.startTime,
                  style: AppTypography.caption.copyWith(color: timeColor),
                ),
                Text(
                  seance.endTime,
                  style: AppTypography.caption.copyWith(color: timeColor),
                ),
              ],
            ),
          ],
        ),
      ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sensors_rounded, size: 56, color: AppColors.accent),
          const SizedBox(height: 16),
          Text('IoT Monitor', style: AppTypography.headingMedium),
          const SizedBox(height: 8),
          AppButton(
            label: 'Open IoT Dashboard',
            onPressed: () => context.push(AppRoutes.teacherIot),
            icon: Icons.sensors_rounded,
          ),
        ],
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_rounded, size: 56, color: AppColors.success),
          const SizedBox(height: 16),
          Text('My Students', style: AppTypography.headingMedium),
          const SizedBox(height: 8),
          AppButton(
            label: 'View Students',
            onPressed: () => context.push(AppRoutes.teacherStudents),
            icon: Icons.people_rounded,
          ),
        ],
      ),
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

    const items = [
      _MoreItem(
        label: 'Attendance Stats',
        icon: Icons.bar_chart_rounded,
        color: AppColors.teacherColor,
        route: AppRoutes.teacherAttendanceStats,
      ),
      _MoreItem(
        label: 'Attendance by Date',
        icon: Icons.calendar_today_rounded,
        color: AppColors.info,
        route: AppRoutes.teacherAttendanceByDate,
      ),
      _MoreItem(
        label: 'Timetable',
        icon: Icons.schedule_rounded,
        color: AppColors.accent,
        route: AppRoutes.teacherTimetable,
      ),
      _MoreItem(
        label: 'My Students',
        icon: Icons.people_rounded,
        color: AppColors.success,
        route: AppRoutes.teacherStudents,
      ),
      _MoreItem(
        label: 'Absence Flags',
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
        route: AppRoutes.teacherAiAlerts,
      ),
      _MoreItem(
        label: 'IoT Monitor',
        icon: Icons.sensors_rounded,
        color: AppColors.accent,
        route: AppRoutes.teacherIot,
      ),
      _MoreItem(
        label: 'Messages',
        icon: Icons.message_rounded,
        color: AppColors.secondary,
        route: AppRoutes.teachermessage,
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
            data:
                (u) => Column(
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
                      style: AppTypography.caption.copyWith(
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
//  INTERNAL MODELS
// ─────────────────────────────────────────
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
