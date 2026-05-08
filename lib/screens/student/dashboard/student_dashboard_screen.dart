import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
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

  static const _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.how_to_reg_rounded, label: 'Attendance'),
    _NavItem(icon: Icons.calendar_today_rounded, label: 'Timetable'),
    _NavItem(icon: Icons.message_rounded, label: 'Messages'),
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
          _DashboardBody(), // placeholder — nav handled by onTap
          _DashboardBody(),
          _DashboardBody(),
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
        onTap: (index) {
          setState(() => _selectedIndex = index);
          switch (index) {
            case 1:
              context.push(AppRoutes.studentAttendance);
              break;
            case 2:
              context.push(AppRoutes.studentTimetable);
              break;
            case 3:
              context.push(AppRoutes.studentmessage);
              break;
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.studentColor,
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

            // ── Resolve student doc to get classId for full class name ──
            final students = ref.watch(studentsProvider);
            final student = students.when(
              data:
                  (list) => list.where((s) => s.userId == user.id).firstOrNull,
              loading: () => null,
              error: (_, __) => null,
            );

            // Full "Level Name Grade" from ClassModel (e.g. "3 IOT 1")
            final classAsync =
                student != null
                    ? ref.watch(classProvider(student.classId))
                    : null;
            final fullClassName = classAsync?.when(
              data: (c) => c?.getFullName ?? student?.className ?? '',
              loading: () => student?.className ?? '',
              error: (_, __) => student?.className ?? '',
            );

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(),
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    // Full class badge — "3 IOT 1"
                    if (fullClassName != null && fullClassName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.studentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.studentColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              size: 12,
                              color: AppColors.studentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              fullClassName,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.studentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── TIMETABLE SÉANCES ──────────────────────────────────
                // Replaces Attendance Summary + Today's Schedule.
                // Fetches sessions for the student's specific classId
                // (derived from Level + Name + Grade via classId lookup).
                _StudentTimetableSeances(userId: user.id, isDark: isDark),
                const SizedBox(height: 24),

                // ── Quick Access ─────────────────────────────────────────
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
                      label: 'Messages',
                      icon: Icons.message_rounded,
                      color: AppColors.warning,
                      onTap: () => context.push(AppRoutes.studentmessage),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Environment ──────────────────────────────────────────
                _buildEnvironment(context, isDark, ref),

                // ── Recent Messages ──────────────────────────────────────
                _buildRecentmessage(context, isDark, ref, user.id),
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

  Widget _buildEnvironment(BuildContext context, bool isDark, WidgetRef ref) {
    return const SizedBox.shrink(); // keep existing env widget if present
  }

  Widget _buildRecentmessage(
    BuildContext context,
    bool isDark,
    WidgetRef ref,
    String userId,
  ) {
    final messages = ref.watch(notificationsProvider(userId));
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
              onPressed: () => context.push(AppRoutes.studentmessage),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        messages.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Text(
                  'No messages yet',
                  style: AppTypography.caption.copyWith(
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
                  list.take(3).map((m) => MessagesTile(message: m)).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STUDENT TIMETABLE SÉANCES
//
//  1. Resolves the student's classId by matching userId in the students
//     collection (classId encodes Level + Name + Grade).
//  2. Fetches all timetable entries for that classId.
//  3. Filters to today's (or tomorrow's) dayOfWeek.
//  4. Groups entries by subject + time into numbered Séances.
//  5. Horizontal scroll — any tap redirects to studentTimetable screen.
// ─────────────────────────────────────────────────────────────────────────────
class _StudentTimetableSeances extends ConsumerWidget {
  final String userId;
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

  const _StudentTimetableSeances({required this.userId, required this.isDark});

  List<_Seance> _groupIntoSeances(List<TimetableModel> entries) {
    final map = <String, _Seance>{};
    for (final e in entries) {
      final key = '${e.subject}|${e.startTime}|${e.endTime}';
      if (map.containsKey(key)) {
        map[key]!.entries.add(e);
      } else {
        map[key] = _Seance(entries: [e]);
      }
    }
    final sorted =
        map.values.toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
    for (int i = 0; i < sorted.length; i++) {
      sorted[i].number = i + 1;
    }
    return sorted;
  }

  bool _isActive(_Seance s) {
    final now = DateTime.now();
    final curr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return curr.compareTo(s.startTime) >= 0 && curr.compareTo(s.endTime) <= 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider);

    return students.when(
      loading: () => const LoadingWidget(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        // Resolve the student doc for this user
        final student = list.where((s) => s.userId == userId).firstOrNull;
        if (student == null) return const SizedBox.shrink();

        // Fetch timetable for this student's classId
        // classId encodes Level + Name + Grade — no extra query needed.
        final timetableAsync = ref.watch(
          timetableByClassProvider(student.classId),
        );

        final now = DateTime.now();
        final showTomorrow = now.hour >= 15;
        final displayDay =
            showTomorrow
                ? _weekdays[now.add(const Duration(days: 1)).weekday]
                : _weekdays[now.weekday];
        final tomorrow = now.add(const Duration(days: 1));
        final displayLabel =
            showTomorrow
                ? 'Timetable tomorrow ${tomorrow.day}.${tomorrow.month.toString().padLeft(2, '0')}.'
                : "Today's Timetable";

        return timetableAsync.when(
          loading: () => const LoadingWidget(),
          error: (_, __) => const SizedBox.shrink(),
          data: (allEntries) {
            final weekType = ref.watch(currentWeekTypeProvider);
            final dayEntries =
                allEntries
                    .where((e) => e.dayOfWeek == displayDay)
                    .where(
                      (e) =>
                          weekType.isEmpty ||
                          e.weekType.isEmpty ||
                          e.weekType == weekType,
                    )
                    .toList();

            final seances = _groupIntoSeances(dayEntries);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
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
                                  isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                            ),
                          ),
                          if (seances.isNotEmpty)
                            Consumer(
                              builder: (context, ref, _) {
                                final classAsync = ref.watch(
                                  classProvider(student.classId),
                                );
                                final label = classAsync.when(
                                  data:
                                      (c) =>
                                          c?.getFullName ?? student.className,
                                  loading: () => student.className,
                                  error: (_, __) => student.className,
                                );
                                return Text(
                                  '$label · ${seances.length} session${seances.length == 1 ? '' : 's'}',
                                  style: AppTypography.caption.copyWith(
                                    color:
                                        isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.studentTimetable),
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
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
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
                  // ── Horizontal scroll — ANY tap → full timetable ────────
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.studentTimetable),
                    child: SizedBox(
                      height: 168,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: seances.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final seance = seances[index];
                          final active = !showTomorrow && _isActive(seance);
                          return _SeanceCard(
                            seance: seance,
                            isActive: active,
                            isDark: isDark,
                            // Student: tap whole timetable → full view
                            onTap:
                                () => context.push(AppRoutes.studentTimetable),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
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

  String get roomLabel {
    final rn = entries.first.roomName.trim();
    if (rn.isNotEmpty) return rn;
    final ri = entries.first.roomId.trim();
    return ri.isNotEmpty ? ri : '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SÉANCE CARD (student version — no class label, shows room instead)
//  Fields: session number, subject, room, time slot.
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
    final bgColor =
        isActive
            ? AppColors.studentColor.withValues(alpha: 0.22)
            : (isDark ? AppColors.darkCard : const Color(0xFF2A2E35));

    final borderColor =
        isActive
            ? AppColors.studentColor.withValues(alpha: 0.6)
            : (isDark
                ? AppColors.darkBorder
                : Colors.white.withValues(alpha: 0.08));

    final labelColor = isActive ? AppColors.studentColor : Colors.white54;
    final roomColor =
        isActive
            ? AppColors.studentColor.withValues(alpha: 0.8)
            : Colors.white38;

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
                      color: AppColors.studentColor.withValues(alpha: 0.25),
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
            // ── Session number ──────────────────────────────────────
            Text(
              'Séance ${seance.number}.',
              style: AppTypography.caption.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),

            // ── Subject ─────────────────────────────────────────────
            Text(
              seance.subject,
              style: AppTypography.headingMedium.copyWith(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Room ────────────────────────────────────────────────
            if (seance.roomLabel.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.meeting_room_rounded, size: 11, color: roomColor),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      seance.roomLabel,
                      style: AppTypography.caption.copyWith(
                        color: roomColor,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              const SizedBox(height: 14),

            // ── Time slot ────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seance.startTime,
                  style: AppTypography.caption.copyWith(color: Colors.white54),
                ),
                Text(
                  seance.endTime,
                  style: AppTypography.caption.copyWith(color: Colors.white54),
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
//  INTERNAL MODELS
// ─────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
