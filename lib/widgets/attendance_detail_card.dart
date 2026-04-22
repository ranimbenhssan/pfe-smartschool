import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import 'attendance_badge.dart';

class AttendanceDetailCard extends StatelessWidget {
  final AttendanceModel record;
  final bool isDark;
  final VoidCallback? onTap;

  const AttendanceDetailCard({
    super.key,
    required this.record,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Top row: date + status ───
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDisplayDate(record.date),
                        style: AppTypography.labelLarge.copyWith(
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (record.recordedAt != null)
                        Text(
                          DateFormat('HH:mm').format(record.recordedAt!),
                          style: AppTypography.caption,
                        )
                      else if (record.entryTime != null)
                        Text(
                          'Entry: ${DateFormat('HH:mm').format(record.entryTime!)}',
                          style: AppTypography.caption,
                        ),
                    ],
                  ),
                ),
                AttendanceBadge(status: record.status),
              ],
            ),

            // ─── Session details ───
            if (_hasDetails()) ...[
              const SizedBox(height: 8),
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
                    if (record.sessionName.isNotEmpty)
                      _DetailRow(
                        icon: Icons.event_note_rounded,
                        label: 'Session',
                        value: record.sessionName,
                        color: AppColors.accent,
                        isDark: isDark,
                      ),
                    if (record.subject.isNotEmpty)
                      _DetailRow(
                        icon: Icons.menu_book_rounded,
                        label: 'Subject',
                        value: record.subject,
                        color: AppColors.info,
                        isDark: isDark,
                      ),
                    if (record.teacherName.isNotEmpty)
                      _DetailRow(
                        icon: Icons.person_rounded,
                        label: 'Teacher',
                        value: record.teacherName,
                        color: AppColors.teacherColor,
                        isDark: isDark,
                      ),
                    if (record.roomName.isNotEmpty)
                      _DetailRow(
                        icon: Icons.meeting_room_rounded,
                        label: 'Room',
                        value: record.roomName,
                        color: AppColors.success,
                        isDark: isDark,
                      ),
                    if (record.studentName.isNotEmpty)
                      _DetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Student',
                        value: record.studentName,
                        color: AppColors.studentColor,
                        isDark: isDark,
                      ),
                    if (record.recordedAt != null)
                      _DetailRow(
                        icon: Icons.access_time_rounded,
                        label: 'Recorded',
                        value: DateFormat(
                          'HH:mm dd/MM/yyyy',
                        ).format(record.recordedAt!),
                        color: AppColors.warning,
                        isDark: isDark,
                      ),
                  ],
                ),
              ),

              // ─── Summary ───
              if (record.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  record.summary,
                  style: AppTypography.caption.copyWith(
                    color:
                        isDark
                            ? AppColors.darkTextHint
                            : AppColors.lightTextHint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],

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
      ),
    );
  }

  bool _hasDetails() =>
      record.sessionName.isNotEmpty ||
      record.subject.isNotEmpty ||
      record.teacherName.isNotEmpty ||
      record.roomName.isNotEmpty ||
      record.recordedAt != null;

  String _formatDisplayDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: AppTypography.caption.copyWith(
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
