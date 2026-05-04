import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  STUDENT DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────
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

  final _screens = const [_DashboardBody()];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: _buildAppBar(isDark, currentUser),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const _DashboardBody(),
          // navigate on tap instead of embedding full screens
          const _DashboardBody(),
          const _DashboardBody(),
          const _DashboardBody(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, AsyncValue currentUser) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 0,
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

// ─────────────────────────────────────────────────────────────────────────────
//  DASHBOARD BODY
// ─────────────────────────────────────────────────────────────────────────────
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Greeting ───
                Text(
                  '${_getGreeting()}, ${user.name} 👋',
                  style: AppTypography.headingLarge.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
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

                // ─── Session-aware attendance status card ───
                _SessionStatusCard(userId: user.id),
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
                    _QuickActionBtn(
                      label: 'Attendance',
                      icon: Icons.how_to_reg_rounded,
                      color: AppColors.success,
                      onTap: () => context.push(AppRoutes.studentAttendance),
                    ),
                    const SizedBox(width: 8),
                    _QuickActionBtn(
                      label: 'Timetable',
                      icon: Icons.calendar_today_rounded,
                      color: AppColors.info,
                      onTap: () => context.push(AppRoutes.studentTimetable),
                    ),
                    const SizedBox(width: 8),
                    _QuickActionBtn(
                      label: 'Environment',
                      icon: Icons.sensors_rounded,
                      color: AppColors.accent,
                      onTap: () => context.push(AppRoutes.studentIot),
                    ),
                    const SizedBox(width: 8),
                    _QuickActionBtn(
                      label: 'Messages',
                      icon: Icons.message_rounded,
                      color: AppColors.warning,
                      onTap: () => context.push(AppRoutes.studentmessage),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Attendance stats summary ───
                _buildAttendanceStats(context, isDark, ref, user.id),
                const SizedBox(height: 24),

                // ─── Today Timetable ───
                _buildTodayTimetable(context, isDark, ref, user.id),
                const SizedBox(height: 24),

                // ─── Recent messages ───
                _buildRecentMessages(context, isDark, ref, user.id),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
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

  Widget _buildAttendanceStats(
    BuildContext context,
    bool isDark,
    WidgetRef ref,
    String userId,
  ) {
    final attendance = ref.watch(attendanceByStudentProvider(userId));
    final student = ref.watch(studentProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attendance Summary',
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
        student.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data:
              (s) => attendance.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) {
                  final presenceCount = s?.totalPresence ?? 0;
                  final absent =
                      list
                          .where((a) => a.status == AttendanceStatus.absent)
                          .length;
                  final late =
                      list
                          .where((a) => a.status == AttendanceStatus.late)
                          .length;
                  final total = presenceCount + list.length;
                  final rate =
                      total > 0 ? ((presenceCount / total) * 100).toInt() : 0;

                  return Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        _StatChip('Present', presenceCount, AppColors.present),
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
        ),
      ],
    );
  }

  Widget _buildTodayTimetable(
    BuildContext context,
    bool isDark,
    WidgetRef ref,
    String userId,
  ) {
    final students = ref.watch(studentsProvider);
    return students.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final student = list.where((s) => s.userId == userId).firstOrNull;
        if (student == null) return const SizedBox.shrink();

        final timetable = ref.watch(timetableByClassProvider(student.classId));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Schedule",
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            timetable.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => const SizedBox.shrink(),
              data: (entries) {
                const days = [
                  '',
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday',
                ];
                final today = days[DateTime.now().weekday];
                final todayEntries =
                    entries.where((e) => e.dayOfWeek == today).toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime));

                if (todayEntries.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No classes today',
                      style: AppTypography.caption,
                    ),
                  );
                }

                return Column(
                  children:
                      todayEntries
                          .map(
                            (e) => Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppColors.darkCard
                                        : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.studentColor.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.studentColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          e.startTime,
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: AppColors.studentColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          e.endTime,
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.studentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.subject,
                                          style: AppTypography.labelLarge
                                              .copyWith(
                                                color:
                                                    isDark
                                                        ? AppColors.darkText
                                                        : AppColors.lightText,
                                              ),
                                        ),
                                        if (e.roomName.isNotEmpty)
                                          Text(
                                            e.roomName,
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color: AppColors.studentColor,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentMessages(
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
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                      .map((msg) => MessagesTile(message: msg))
                      .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SESSION STATUS CARD
//
//  Shows the student's attendance status for the CURRENT timetable session.
//  - Watches currentTimetableSlotProvider on the student's classId
//  - For the current slot, queries attendance for today + this session
//  - When the slot changes (new subject begins), the status auto-resets
//  - Timer fires every 60s to re-evaluate which slot is current
// ─────────────────────────────────────────────────────────────────────────────
class _SessionStatusCard extends ConsumerStatefulWidget {
  final String userId;
  const _SessionStatusCard({required this.userId});

  @override
  ConsumerState<_SessionStatusCard> createState() => _SessionStatusCardState();
}

class _SessionStatusCardState extends ConsumerState<_SessionStatusCard> {
  Timer? _slotTimer;
  String? _currentSlotId; // tracks slot changes for auto-refresh
  AttendanceStatus? _sessionStatus;
  AttendanceModel? _sessionRecord;
  String _today = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // Poll every 60 seconds to detect slot changes
    _slotTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshStatus(),
    );
  }

  @override
  void dispose() {
    _slotTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    setState(() {}); // triggers rebuild → re-evaluates current slot
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = ref.watch(studentsProvider);

    return students.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final student =
            list.where((s) => s.userId == widget.userId).firstOrNull;
        if (student == null) return const SizedBox.shrink();

        // Watch the live current slot for this student's class
        final slotAsync = ref.watch(
          currentTimetableSlotProvider(student.classId),
        );

        return slotAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (slot) {
            // No active class right now
            if (slot == null) {
              return _buildCard(
                isDark: isDark,
                color: AppColors.info,
                icon: Icons.school_rounded,
                label: 'No class right now',
                subtitle: 'Class: ${student.classDisplay}',
                onTap: () => context.push(AppRoutes.studentAttendance),
              );
            }

            // Slot changed — auto-refresh attendance for new session
            if (_currentSlotId != slot.id) {
              _currentSlotId = slot.id;
              _sessionStatus = null;
              _sessionRecord = null;
              _loading = true;

              // Fetch attendance for this slot
              _fetchSessionStatus(student.id, slot);
            }

            if (_loading) {
              return _buildCard(
                isDark: isDark,
                color: AppColors.info,
                icon: Icons.hourglass_empty_rounded,
                label: 'Loading status...',
                subtitle: slot.subject,
                onTap: null,
              );
            }

            final status = _sessionStatus;
            final record = _sessionRecord;

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
                    ? 'Present ✅'
                    : status == AttendanceStatus.late
                    ? 'Late ⚠️'
                    : status == AttendanceStatus.absent
                    ? 'Absent ❌'
                    : 'Not yet recorded';

            return _buildCard(
              isDark: isDark,
              color: color,
              icon:
                  status == AttendanceStatus.present
                      ? Icons.check_circle_rounded
                      : status == AttendanceStatus.late
                      ? Icons.watch_later_rounded
                      : status == AttendanceStatus.absent
                      ? Icons.cancel_rounded
                      : Icons.help_outline_rounded,
              label: label,
              subtitle: _buildSubtitle(slot, record),
              onTap: () => context.push(AppRoutes.studentAttendance),
            );
          },
        );
      },
    );
  }

  Future<void> _fetchSessionStatus(
    String studentId,
    TimetableModel slot,
  ) async {
    try {
      // Check absence doc first
      final absSnap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('studentId', isEqualTo: studentId)
              .where('date', isEqualTo: _today)
              .limit(1)
              .get();

      AttendanceStatus? status;
      AttendanceModel? record;

      if (absSnap.docs.isNotEmpty) {
        record = AttendanceModel.fromFirestore(absSnap.docs.first);
        status = record.status;
      } else {
        // Check presence_tracking sub-collection
        final trackingDoc =
            await FirebaseFirestore.instance
                .collection('students')
                .doc(studentId)
                .collection('presence_tracking')
                .doc(_today)
                .get();

        if (trackingDoc.exists) {
          status = AttendanceStatus.present;
        }
      }

      if (mounted) {
        setState(() {
          _sessionStatus = status;
          _sessionRecord = record;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('_fetchSessionStatus: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _buildSubtitle(TimetableModel slot, AttendanceModel? record) {
    final parts = <String>[];
    parts.add('${slot.subject} · ${slot.startTime}–${slot.endTime}');
    if (slot.roomName.isNotEmpty) parts.add(slot.roomName);
    if (record?.teacherName.isNotEmpty == true) {
      parts.add(record!.teacherName);
    }
    return parts.join(' · ');
  }

  Widget _buildCard({
    required bool isDark,
    required Color color,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
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
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(color: color),
                    ),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: color),
          ],
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
    final currentUser = ref.watch(currentUserProvider);
    final authService = ref.read(authServiceProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: currentUser.when(
        loading: () => const LoadingWidget(),
        error: (_, __) => const SizedBox.shrink(),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.studentColor.withValues(alpha: 0.15),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: AppTypography.headingLarge.copyWith(
                    color: AppColors.studentColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(user.name, style: AppTypography.headingMedium),
              Text(user.email, style: AppTypography.caption),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Change Password'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.changePassword);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await authService.logout();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
//  QUICK ACTION BUTTON
// ─────────────────────────────────────────
class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
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
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(color: color),
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
//  STAT CHIP
// ─────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String suffix;

  const _StatChip(this.label, this.value, this.color, {this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$value$suffix',
            style: AppTypography.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: AppTypography.caption.copyWith(color: color)),
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
