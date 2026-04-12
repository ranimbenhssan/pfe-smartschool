import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';

// ─────────────────────────────────────────
//  ADMIN TIMETABLE GRID
//  Day/Week toggle + edit/delete actions
// ─────────────────────────────────────────
class AdminTimetableGrid extends StatefulWidget {
  final List<TimetableModel> entries;
  final Function(TimetableModel) onDelete;
  final Function(TimetableModel) onEdit;

  const AdminTimetableGrid({
    super.key,
    required this.entries,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<AdminTimetableGrid> createState() => _AdminTimetableGridState();
}

class _AdminTimetableGridState extends State<AdminTimetableGrid> {
  bool _isWeekView = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Toggle ───
        Row(
          children: [
            Text(
              'View:',
              style: AppTypography.labelMedium.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _toggleBtn(
                    label: 'Day',
                    isActive: !_isWeekView,
                    onTap: () => setState(() => _isWeekView = false),
                  ),
                  _toggleBtn(
                    label: 'Week',
                    isActive: _isWeekView,
                    onTap: () => setState(() => _isWeekView = true),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ─── Content ───
        _isWeekView
            ? _WeekGrid(
              entries: widget.entries,
              isDark: isDark,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
            )
            : _DayView(
              entries: widget.entries,
              isDark: isDark,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
            ),
      ],
    );
  }

  Widget _toggleBtn({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isActive ? AppColors.primary : null,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  DAY VIEW
// ─────────────────────────────────────────
class _DayView extends StatefulWidget {
  final List<TimetableModel> entries;
  final bool isDark;
  final Function(TimetableModel) onEdit;
  final Function(TimetableModel) onDelete;

  const _DayView({
    required this.entries,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];
  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    final w = DateTime.now().weekday;
    _selectedDay = (w >= 1 && w <= 5) ? _days[w - 1] : 'Monday';
  }

  @override
  Widget build(BuildContext context) {
    final dayEntries =
        widget.entries
            .where(
              (e) => e.dayOfWeek.toLowerCase() == _selectedDay.toLowerCase(),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Day chips ───
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                _days.map((day) {
                  final isSelected = _selectedDay == day;
                  final hasClasses = widget.entries.any(
                    (e) => e.dayOfWeek.toLowerCase() == day.toLowerCase(),
                  );
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.accent
                                : widget.isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.accent
                                  : widget.isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            day.substring(0, 3),
                            style: AppTypography.labelMedium.copyWith(
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : widget.isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                            ),
                          ),
                          if (hasClasses)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.primary
                                        : AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // ─── Entries ───
        dayEntries.isEmpty
            ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No classes on $_selectedDay',
                  style: AppTypography.bodySmall.copyWith(
                    color:
                        widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            )
            : Column(
              children:
                  dayEntries
                      .map(
                        (e) => _AdminEntryCard(
                          entry: e,
                          isDark: widget.isDark,
                          onEdit: () => widget.onEdit(e),
                          onDelete: () => widget.onDelete(e),
                        ),
                      )
                      .toList(),
            ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  WEEK GRID — visual table layout
// ─────────────────────────────────────────
class _WeekGrid extends StatelessWidget {
  final List<TimetableModel> entries;
  final bool isDark;
  final Function(TimetableModel) onEdit;
  final Function(TimetableModel) onDelete;

  const _WeekGrid({
    required this.entries,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  Widget build(BuildContext context) {
    // Collect all unique time slots
    final timeSlots =
        entries.map((e) => '${e.startTime}-${e.endTime}').toSet().toList()
          ..sort();

    if (timeSlots.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(130),
          border: TableBorder.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
          children: [
            // ─── Header row ───
            TableRow(
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
              children: [
                _headerCell('Time', isDark),
                ..._days.map((d) => _headerCell(d.substring(0, 3), isDark)),
              ],
            ),

            // ─── Time slot rows ───
            ...timeSlots.map((slot) {
              final parts = slot.split('-');
              final start = parts[0];
              final end = parts[1];

              return TableRow(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                ),
                children: [
                  // Time column
                  _timeCell(start, end, isDark),

                  // Day columns
                  ..._days.map((day) {
                    final entry =
                        entries
                            .where(
                              (e) =>
                                  e.dayOfWeek.toLowerCase() ==
                                      day.toLowerCase() &&
                                  e.startTime == start &&
                                  e.endTime == end,
                            )
                            .firstOrNull;

                    return entry == null
                        ? _emptyCell(isDark)
                        : _entryCell(
                          entry,
                          isDark,
                          onEdit: () => onEdit(entry),
                          onDelete: () => onDelete(entry),
                        );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _timeCell(String start, String end, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(
            start,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            end,
            style: AppTypography.caption.copyWith(
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _emptyCell(bool isDark) {
    return Container(
      height: 70,
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
    );
  }

  Widget _entryCell(
    TimetableModel entry,
    bool isDark, {
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      height: 70,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            entry.subject,
            style: AppTypography.labelSmall.copyWith(
              color: isDark ? AppColors.darkText : AppColors.lightText,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (entry.teacherName.isNotEmpty)
            Text(
              entry.teacherName,
              style: AppTypography.caption,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onEdit,
                child: const Icon(
                  Icons.edit_rounded,
                  size: 12,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 12,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ADMIN ENTRY CARD (day view)
// ─────────────────────────────────────────
class _AdminEntryCard extends StatelessWidget {
  final TimetableModel entry;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminEntryCard({
    required this.entry,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // ─── Time ───
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  entry.startTime,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '|',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  entry.endTime,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.accent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ─── Info ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.subject,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                if (entry.teacherName.isNotEmpty)
                  Text(entry.teacherName, style: AppTypography.caption),
                if (entry.roomName.isNotEmpty)
                  Text('📍 ${entry.roomName}', style: AppTypography.caption),
              ],
            ),
          ),

          // ─── Actions ───
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: AppColors.info,
                ),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
