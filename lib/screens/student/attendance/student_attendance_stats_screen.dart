import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class StudentAttendanceStatsScreen extends ConsumerStatefulWidget {
  const StudentAttendanceStatsScreen({super.key});

  @override
  ConsumerState<StudentAttendanceStatsScreen> createState() =>
      _StudentAttendanceStatsScreenState();
}

class _StudentAttendanceStatsScreenState
    extends ConsumerState<StudentAttendanceStatsScreen> {
  // ─── Filter: all / absent / late  (no 'present' — counter only, no docs) ───
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance Details'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: currentUser.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (user) {
          if (user == null) return const SizedBox.shrink();

          // ─── presenceCount from student doc (not from attendance collection) ───
          final studentAsync = ref.watch(studentProvider(user.id));

          // ─── Only absent/late docs exist in attendance collection ───
          final attendanceAsync = ref.watch(
            attendanceByStudentProvider(user.id),
          );

          return studentAsync.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (student) {
              if (student == null) return const SizedBox.shrink();

              return attendanceAsync.when(
                loading: () => const LoadingWidget(),
                error:
                    (e, _) => EmptyState(
                      title: 'Error',
                      message: e.toString(),
                      icon: Icons.error_outline_rounded,
                    ),
                data: (list) {
                  final absent =
                      list
                          .where((a) => a.status == AttendanceStatus.absent)
                          .length;
                  final late =
                      list
                          .where((a) => a.status == AttendanceStatus.late)
                          .length;

                  final presenceCount = student.presenceCount;
                  final total = presenceCount + list.length;
                  final rate =
                      total > 0 ? ((presenceCount / total) * 100).toInt() : 0;

                  final filtered =
                      _filter == 'all'
                          ? list
                          : list
                              .where((a) => a.status.name == _filter)
                              .toList();

                  return Column(
                    children: [
                      // ─── Summary banner ───
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.studentColor.withValues(alpha: 0.8),
                              AppColors.studentColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // ─── Rate circle ───
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: rate / 100,
                                    strokeWidth: 6,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                  ),
                                  Text(
                                    '$rate%',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // ─── Mini stats ───
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attendance Rate',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _MiniStat(
                                        'Present',
                                        presenceCount,
                                        Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      _MiniStat(
                                        'Absent',
                                        absent,
                                        Colors.white70,
                                      ),
                                      const SizedBox(width: 12),
                                      _MiniStat('Late', late, Colors.white60),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Filter chips ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All absences (${list.length})',
                                isActive: _filter == 'all',
                                color: AppColors.accent,
                                onTap: () => setState(() => _filter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Absent ($absent)',
                                isActive: _filter == 'absent',
                                color: AppColors.absent,
                                onTap: () => setState(() => _filter = 'absent'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Late ($late)',
                                isActive: _filter == 'late',
                                color: AppColors.late,
                                onTap: () => setState(() => _filter = 'late'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ─── Records list ───
                      Expanded(
                        child:
                            filtered.isEmpty
                                ? EmptyState(
                                  title: 'No Records',
                                  message:
                                      _filter == 'all'
                                          ? 'No absence records yet'
                                          : 'No $_filter records',
                                  icon: Icons.event_busy_rounded,
                                )
                                : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final record = filtered[index];
                                    return _AttendanceDetailCard(
                                      record: record,
                                      isDark: isDark,
                                    );
                                  },
                                ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ATTENDANCE DETAIL CARD — all 5 fields
// ─────────────────────────────────────────
class _AttendanceDetailCard extends StatelessWidget {
  final AttendanceModel record;
  final bool isDark;

  const _AttendanceDetailCard({required this.record, required this.isDark});

  String _fmtDate(String s) {
    try {
      final p = s.split('-');
      return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : s;
    } catch (_) {
      return s;
    }
  }

  bool get _hasContext =>
      record.subject.isNotEmpty ||
      record.teacherName.isNotEmpty ||
      record.roomName.isNotEmpty ||
      record.recordedAt != null ||
      record.scheduledTimeRange.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final sc =
        record.status == AttendanceStatus.late
            ? AppColors.late
            : AppColors.absent;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sc.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header row ───
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  record.status == AttendanceStatus.late
                      ? Icons.watch_later_rounded
                      : Icons.cancel_rounded,
                  color: sc,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtDate(record.date),
                      style: AppTypography.labelLarge.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    if (record.className.isNotEmpty)
                      Text(record.className, style: AppTypography.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sc.withValues(alpha: 0.3)),
                ),
                child: Text(
                  record.status.name.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: sc,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // ─── 5-field detail grid ───
          if (_hasContext) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? AppColors.darkBackground
                        : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // ─── Row 1: Subject + Teacher ───
                  Row(
                    children: [
                      Expanded(
                        child: _FieldTile(
                          icon: Icons.menu_book_rounded,
                          label: 'Subject',
                          value:
                              record.subject.isNotEmpty ? record.subject : '—',
                          color: AppColors.info,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TeacherDetailItem(
                          teacherName: record.teacherName,
                          teacherId: record.teacherId,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ─── Row 2: Room + Scheduled Time ───
                  Row(
                    children: [
                      Expanded(
                        child: _FieldTile(
                          icon: Icons.meeting_room_rounded,
                          label: 'Room',
                          value:
                              record.roomName.isNotEmpty
                                  ? record.roomName
                                  : '—',
                          color: AppColors.success,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FieldTile(
                          icon: Icons.schedule_rounded,
                          label: 'Scheduled Time',
                          value:
                              record.scheduledTimeRange.isNotEmpty
                                  ? record.scheduledTimeRange
                                  : '—',
                          color: AppColors.accent,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ─── Row 3: Time of Absence — full width ───
                  _FieldTile(
                    icon: Icons.access_time_filled_rounded,
                    label: 'Time of Absence',
                    value:
                        record.recordedAt != null
                            ? DateFormat(
                              'HH:mm  –  dd/MM/yyyy',
                            ).format(record.recordedAt!)
                            : record.entryTime != null
                            ? DateFormat(
                              'HH:mm  –  dd/MM/yyyy',
                            ).format(record.entryTime!)
                            : '—',
                    color: sc,
                    isDark: isDark,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          ],

          // ─── Manual entry note ───
          if (record.note != null && record.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.note_rounded,
                  size: 12,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(record.note!, style: AppTypography.caption),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  FIELD TILE
// ─────────────────────────────────────────
class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool fullWidth;

  const _FieldTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: tile) : tile;
  }
}

// ─────────────────────────────────────────
//  MINI STAT
// ─────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: AppTypography.labelLarge.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: AppTypography.caption.copyWith(color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  FILTER CHIP
// ─────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isActive ? color : null,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TeacherDetailItem extends ConsumerWidget {
  final String teacherName;
  final String teacherId;

  const _TeacherDetailItem({
    required this.teacherName,
    required this.teacherId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use stored name if available.
    if (teacherName.isNotEmpty) {
      return _FieldTile(
        icon: Icons.person_rounded,
        label: 'Teacher',
        value: teacherName,
        color: AppColors.teacherColor,
        isDark: Theme.of(context).brightness == Brightness.dark,
      );
    }

    // Fallback: look up by teacherId.
    if (teacherId.isEmpty) {
      return _FieldTile(
        icon: Icons.person_rounded,
        label: 'Teacher',
        value: '—',
        color: AppColors.teacherColor,
        isDark: Theme.of(context).brightness == Brightness.dark,
      );
    }

    final teacherAsync = ref.watch(teacherProvider(teacherId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return teacherAsync.when(
      loading:
          () => _FieldTile(
            icon: Icons.person_rounded,
            label: 'Teacher',
            value: '...',
            color: AppColors.teacherColor,
            isDark: isDark,
          ),
      error:
          (_, __) => _FieldTile(
            icon: Icons.person_rounded,
            label: 'Teacher',
            value: '—',
            color: AppColors.teacherColor,
            isDark: isDark,
          ),
      data:
          (t) => _FieldTile(
            icon: Icons.person_rounded,
            label: 'Teacher',
            value: t?.name.isNotEmpty == true ? t!.name : '—',
            color: AppColors.teacherColor,
            isDark: isDark,
          ),
    );
  }
}
