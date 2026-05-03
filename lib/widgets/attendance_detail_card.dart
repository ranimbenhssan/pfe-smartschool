import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import 'attendance_badge.dart';

/// Reusable card that displays a full attendance record with all
/// 5 timetable-mapped fields:
///   1. Subject
///   2. Teacher
///   3. Room
///   4. Time of Absence (recordedAt)
///   5. Scheduled Class Time (scheduledStartTime – scheduledEndTime)
class AttendanceDetailCard extends StatelessWidget {
  final AttendanceModel record;
  final bool isDark;

  /// Set true when shown in admin/teacher views (shows student name row)
  final bool showStudent;

  const AttendanceDetailCard({
    super.key,
    required this.record,
    required this.isDark,
    this.showStudent = false,
  });

  String _formatDate(String dateStr) {
    try {
      final p = dateStr.split('-');
      return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : dateStr;
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
          // ─── Header row: date + status badge ───
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
                      _formatDate(record.date),
                      style: AppTypography.labelLarge.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    if (showStudent && record.studentName.isNotEmpty)
                      Text(
                        record.studentName,
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
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

          // ─── Timetable detail grid ───
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
                    color:
                        record.status == AttendanceStatus.absent
                            ? AppColors.absent
                            : record.status == AttendanceStatus.late
                            ? AppColors.late
                            : AppColors.present,
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
    final widget = Container(
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

    return fullWidth ? SizedBox(width: double.infinity, child: widget) : widget;
  }
}
