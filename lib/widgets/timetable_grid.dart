import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';

class TimetableGrid extends StatelessWidget {
  final List<TimetableModel> entries;
  final VoidCallback? onEntryTap;

  const TimetableGrid({super.key, required this.entries, this.onEntryTap});

  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  static const List<Color> _subjectColors = [
    Color(0xFF3498DB),
    Color(0xFF2ECC71),
    Color(0xFFE74C3C),
    Color(0xFFF39C12),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFFE67E22),
  ];

  Color _subjectColor(String subject) {
    return _subjectColors[subject.hashCode % _subjectColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day headers
          Row(
            children: [
              const SizedBox(width: 50),
              ..._days.map(
                (day) => Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      day,
                      style: AppTypography.labelMedium.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Timetable rows
          ..._days.asMap().entries.map((dayEntry) {
            final dayIndex = dayEntry.key + 1;
            final dayEntries =
                entries.where((e) => e.dayOfWeek == dayIndex).toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 50,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, right: 8),
                    child: Text(
                      _days[dayIndex - 1],
                      style: AppTypography.labelSmall.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextHint
                                : AppColors.lightTextHint,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                ...dayEntries.map((entry) {
                  final color = _subjectColor(entry.subject);
                  return GestureDetector(
                    onTap: onEntryTap,
                    child: Container(
                      width: 110,
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.subject,
                            style: AppTypography.labelMedium.copyWith(
                              color: color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry.startTime} - ${entry.endTime}',
                            style: AppTypography.caption,
                          ),
                          Text(entry.roomName, style: AppTypography.caption),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }
}
