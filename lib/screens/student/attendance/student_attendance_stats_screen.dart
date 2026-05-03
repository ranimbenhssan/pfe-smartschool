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
          final attendance = ref.watch(attendanceByStudentProvider(user.id));

          return attendance.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (list) {
              final present =
                  list
                      .where((a) => a.status == AttendanceStatus.present)
                      .length;
              final absent =
                  list.where((a) => a.status == AttendanceStatus.absent).length;
              final late =
                  list.where((a) => a.status == AttendanceStatus.late).length;
              final total = list.length;
              final rate = total > 0 ? ((present / total) * 100).toInt() : 0;

              final filtered =
                  _filter == 'all'
                      ? list
                      : list.where((a) => a.status.name == _filter).toList();

              return Column(
                children: [
                  // ─── Summary stats ───
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat('Present', present, AppColors.present),
                        _MiniStat('Absent', absent, AppColors.absent),
                        _MiniStat('Late', late, AppColors.late),
                        _MiniStat('Rate', rate, AppColors.info, suffix: '%'),
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
                            label: 'All ($total)',
                            isActive: _filter == 'all',
                            color: AppColors.accent,
                            onTap: () => setState(() => _filter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Present ($present)',
                            isActive: _filter == 'present',
                            color: AppColors.present,
                            onTap: () => setState(() => _filter = 'present'),
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
                                      ? 'No attendance records yet'
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

  String _formatDisplayDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  bool get _hasDetails =>
      record.subject.isNotEmpty ||
      record.teacherName.isNotEmpty ||
      record.roomName.isNotEmpty ||
      record.recordedAt != null ||
      record.scheduledTimeRange.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        record.status == AttendanceStatus.present
            ? AppColors.present
            : record.status == AttendanceStatus.late
            ? AppColors.late
            : AppColors.absent;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: date + status badge ───
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  record.status == AttendanceStatus.present
                      ? Icons.check_circle_rounded
                      : record.status == AttendanceStatus.late
                      ? Icons.watch_later_rounded
                      : Icons.cancel_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDisplayDate(record.date),
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
              AttendanceBadge(status: record.status),
            ],
          ),

          // ─── 5-field detail grid ───
          if (_hasDetails) ...[
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: _FieldTile(
                          icon: Icons.person_rounded,
                          label: 'Teacher',
                          value:
                              record.teacherName.isNotEmpty
                                  ? record.teacherName
                                  : '—',
                          color: AppColors.teacherColor,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ─── Row 2: Room + Scheduled Class Time ───
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

                  // ─── Row 3: Time of Absence (full width) ───
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
                    color: statusColor,
                    isDark: isDark,
                    fullWidth: true,
                  ),
                ],
              ),
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
  final String suffix;

  const _MiniStat(this.label, this.value, this.color, {this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value$suffix',
          style: AppTypography.headingSmall.copyWith(color: color),
        ),
        Text(label, style: AppTypography.caption),
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
