import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/auth_service.dart';
import '../../../models/models.dart';

class StudentTimetableScreen extends ConsumerStatefulWidget {
  const StudentTimetableScreen({super.key});

  @override
  ConsumerState<StudentTimetableScreen> createState() =>
      _StudentTimetableScreenState();
}

class _StudentTimetableScreenState
    extends ConsumerState<StudentTimetableScreen> {
  bool _isWeekView = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Timetable'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
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
                  'Day',
                  !_isWeekView,
                  isDark,
                  () => setState(() => _isWeekView = false),
                ),
                _toggleBtn(
                  'Week',
                  _isWeekView,
                  isDark,
                  () => setState(() => _isWeekView = true),
                ),
              ],
            ),
          ),
        ],
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
          final students = ref.watch(studentsProvider);
          return students.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (list) {
              final student =
                  list.where((s) => s.userId == user.id).firstOrNull;
              if (student == null) {
                return const EmptyState(
                  title: 'Not Found',
                  message: 'Student profile not found',
                  icon: Icons.person_off_rounded,
                );
              }
              final timetable = ref.watch(
                timetableByClassProvider(student.classId),
              );
              return timetable.when(
                loading: () => const LoadingWidget(),
                error:
                    (e, _) => EmptyState(
                      title: 'Error',
                      message: e.toString(),
                      icon: Icons.error_outline_rounded,
                    ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const EmptyState(
                      title: 'No Timetable',
                      message: 'No schedule available yet',
                      icon: Icons.calendar_today_rounded,
                    );
                  }
                  return _isWeekView
                      ? _StudentWeekGrid(entries: entries, isDark: isDark)
                      : _StudentDayView(entries: entries, isDark: isDark);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _toggleBtn(
    String label,
    bool isActive,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.studentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color:
                isActive
                    ? Colors.white
                    : isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
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
class _StudentDayView extends StatefulWidget {
  final List<TimetableModel> entries;
  final bool isDark;

  const _StudentDayView({required this.entries, required this.isDark});

  @override
  State<_StudentDayView> createState() => _StudentDayViewState();
}

class _StudentDayViewState extends State<_StudentDayView> {
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
      children: [
        // ─── Day chips ───
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                ? AppColors.studentColor
                                : widget.isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.studentColor
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
                                      ? Colors.white
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
                                        ? Colors.white
                                        : AppColors.studentColor,
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

        // ─── Entries ───
        Expanded(
          child:
              dayEntries.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.free_breakfast_rounded,
                          size: 48,
                          color:
                              widget.isDark
                                  ? AppColors.darkTextHint
                                  : AppColors.lightTextHint,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No classes on $_selectedDay',
                          style: AppTypography.bodyMedium.copyWith(
                            color:
                                widget.isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: dayEntries.length,
                    itemBuilder:
                        (context, index) => _StudentEntryCard(
                          entry: dayEntries[index],
                          isDark: widget.isDark,
                        ),
                  ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  WEEK GRID — same as admin
// ─────────────────────────────────────────
class _StudentWeekGrid extends StatelessWidget {
  final List<TimetableModel> entries;
  final bool isDark;

  const _StudentWeekGrid({required this.entries, required this.isDark});

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  Widget build(BuildContext context) {
    final timeSlots =
        entries.map((e) => '${e.startTime}-${e.endTime}').toSet().toList()
          ..sort();

    if (timeSlots.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(120),
          border: TableBorder.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
          children: [
            // ─── Header ───
            TableRow(
              decoration: BoxDecoration(
                color: AppColors.studentColor.withValues(alpha: 0.15),
              ),
              children: [
                _headerCell('Time'),
                ..._days.map((d) => _headerCell(d.substring(0, 3))),
              ],
            ),

            // ─── Time rows ───
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
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(
                          start,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.studentColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          end,
                          style: AppTypography.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

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

                    if (entry == null) {
                      return Container(
                        height: 72,
                        color:
                            isDark
                                ? AppColors.darkBackground
                                : AppColors.lightBackground,
                      );
                    }

                    return Container(
                      height: 72,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.studentColor.withValues(alpha: 0.08),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.subject,
                            style: AppTypography.labelSmall.copyWith(
                              color:
                                  isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
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
                          if (entry.roomName.isNotEmpty)
                            Text(
                              '📍 ${entry.roomName}',
                              style: AppTypography.caption,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        ],
                      ),
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

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.studentColor,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ENTRY CARD
// ─────────────────────────────────────────
class _StudentEntryCard extends StatelessWidget {
  final TimetableModel entry;
  final bool isDark;

  const _StudentEntryCard({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.studentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.studentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  entry.startTime,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.studentColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '|',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.studentColor,
                  ),
                ),
                Text(
                  entry.endTime,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.studentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
        ],
      ),
    );
  }
}
