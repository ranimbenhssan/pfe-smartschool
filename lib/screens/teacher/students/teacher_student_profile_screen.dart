import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class TeacherStudentProfileScreen extends ConsumerStatefulWidget {
  final String studentId;

  const TeacherStudentProfileScreen({super.key, required this.studentId});

  @override
  ConsumerState<TeacherStudentProfileScreen> createState() =>
      _TeacherStudentProfileScreenState();
}

class _TeacherStudentProfileScreenState
    extends ConsumerState<TeacherStudentProfileScreen>
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
    final student = ref.watch(studentProvider(widget.studentId));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: student.when(
        loading: () => const Scaffold(body: LoadingWidget()),
        error:
            (e, _) => Scaffold(
              body: EmptyState(
                title: 'Error',
                message: e.toString(),
                icon: Icons.error_outline_rounded,
              ),
            ),
        data: (student) {
          if (student == null) {
            return const Scaffold(
              body: EmptyState(
                title: 'Student Not Found',
                message: 'This student does not exist',
                icon: Icons.person_off_rounded,
              ),
            );
          }
          return NestedScrollView(
            headerSliverBuilder:
                (context, _) => [
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor:
                        isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.teacherColor.withValues(alpha: 0.8),
                              AppColors.teacherColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              child: Text(
                                student.name.isNotEmpty
                                    ? student.name[0].toUpperCase()
                                    : '?',
                                style: AppTypography.displayMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              student.name,
                              style: AppTypography.headingLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              student.className,
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    bottom: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.accent,
                      labelColor: AppColors.accent,
                      unselectedLabelColor: Colors.white60,
                      tabs: const [
                        Tab(text: 'Attendance'),
                        Tab(text: 'Absence Flags'),
                      ],
                    ),
                  ),
                ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _AttendanceTab(studentId: student.id),
                _AiFlagsTab(studentId: student.id),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AttendanceTab extends ConsumerWidget {
  final String studentId;

  const _AttendanceTab({required this.studentId});

  void _showAttendanceDetail(
    BuildContext context,
    AttendanceModel record,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
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
                // Status header
                AttendanceBadge(status: record.status),
                const SizedBox(height: 16),
                // Details
                _DetailRow(
                  label: 'Date',
                  value: record.date,
                  icon: Icons.calendar_today_rounded,
                ),
                _DetailRow(
                  label: 'Subject',
                  value: record.subject.isNotEmpty ? record.subject : '—',
                  icon: Icons.menu_book_rounded,
                ),
                _DetailRow(
                  label: 'Session',
                  value:
                      record.sessionName.isNotEmpty ? record.sessionName : '—',
                  icon: Icons.event_note_rounded,
                ),
                _TeacherNameRow(
                  teacherId: record.teacherId,
                  teacherName: record.teacherName,
                ),
                _DetailRow(
                  label: 'Room',
                  value: record.roomName.isNotEmpty ? record.roomName : '—',
                  icon: Icons.meeting_room_rounded,
                ),
                if (record.entryTime != null)
                  _DetailRow(
                    label: 'Entry',
                    value: DateFormat('HH:mm').format(record.entryTime!),
                    icon: Icons.login_rounded,
                  ),
                if (record.exitTime != null)
                  _DetailRow(
                    label: 'Exit',
                    value: DateFormat('HH:mm').format(record.exitTime!),
                    icon: Icons.logout_rounded,
                  ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendance = ref.watch(attendanceByStudentProvider(studentId));

    return attendance.when(
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
            title: 'No Records',
            message: 'No attendance data yet',
            icon: Icons.event_busy_rounded,
          );
        }
        final present =
            list.where((a) => a.status == AttendanceStatus.present).length;
        final absent =
            list.where((a) => a.status == AttendanceStatus.absent).length;
        final late =
            list.where((a) => a.status == AttendanceStatus.late).length;
        final total = list.length;
        final rate = total > 0 ? ((present / total) * 100).toInt() : 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _MiniStat('Present', present, AppColors.present),
                  const SizedBox(width: 8),
                  _MiniStat('Absent', absent, AppColors.absent),
                  const SizedBox(width: 8),
                  _MiniStat('Late', late, AppColors.late),
                  const SizedBox(width: 8),
                  _MiniStat('Rate', rate, AppColors.info, suffix: '%'),
                ],
              ),
              const SizedBox(height: 16),
              ...list.map(
                (record) => GestureDetector(
                  onTap: () => _showAttendanceDetail(context, record, isDark),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 8),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.date,
                                style: AppTypography.labelLarge.copyWith(
                                  color:
                                      isDark
                                          ? AppColors.darkText
                                          : AppColors.lightText,
                                ),
                              ),
                              if (record.subject.isNotEmpty)
                                Text(
                                  record.subject,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.teacherColor,
                                  ),
                                ),
                              if (record.entryTime != null)
                                Text(
                                  'Entry: ${DateFormat('HH:mm').format(record.entryTime!)}',
                                  style: AppTypography.caption,
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color:
                              isDark
                                  ? AppColors.darkTextHint
                                  : AppColors.lightTextHint,
                        ),
                        const SizedBox(width: 6),
                        AttendanceBadge(status: record.status),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiFlagsTab extends ConsumerWidget {
  final String studentId;

  const _AiFlagsTab({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(aiFlagsByStudentProvider(studentId));

    return flags.when(
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
                    title: 'No Flags',
                    message: 'No absence flags for this student',
                    icon: Icons.check_circle_outline_rounded,
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder:
                        (context, index) => AlertCard(flag: list[index]),
                  ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String suffix;

  const _MiniStat(this.label, this.value, this.color, {this.suffix = ''});

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

class _DetailRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherNameRow extends ConsumerWidget {
  final String teacherId, teacherName;
  const _TeacherNameRow({required this.teacherId, required this.teacherName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If name already stored — use it directly
    if (teacherName.isNotEmpty) {
      return _DetailRow(
        label: 'Teacher',
        value: teacherName,
        icon: Icons.person_rounded,
      );
    }

    // Fallback: look up by teacherId from teachers collection
    if (teacherId.isEmpty) {
      return _DetailRow(
        label: 'Teacher',
        value: '—',
        icon: Icons.person_rounded,
      );
    }

    final teacherAsync = ref.watch(teacherProvider(teacherId));
    return teacherAsync.when(
      loading:
          () => _DetailRow(
            label: 'Teacher',
            value: '...',
            icon: Icons.person_rounded,
          ),
      error:
          (_, __) => _DetailRow(
            label: 'Teacher',
            value: '—',
            icon: Icons.person_rounded,
          ),
      data:
          (t) => _DetailRow(
            label: 'Teacher',
            value: t?.name.isNotEmpty == true ? t!.name : '—',
            icon: Icons.person_rounded,
          ),
    );
  }
}
