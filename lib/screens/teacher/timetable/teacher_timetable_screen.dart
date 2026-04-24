import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class TeacherTimetableScreen extends ConsumerStatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  ConsumerState<TeacherTimetableScreen> createState() =>
      _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState
    extends ConsumerState<TeacherTimetableScreen> {
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
          // ─── Day / Week toggle ───
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

          final teachers = ref.watch(teachersProvider);
          return teachers.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (list) {
              final teacher =
                  list.where((t) => t.userId == user.id).firstOrNull;

              if (teacher == null || teacher.assignedClassIds.isEmpty) {
                return const EmptyState(
                  title: 'No Classes',
                  message: 'No classes assigned yet',
                  icon: Icons.class_outlined,
                );
              }

              // ─── Load timetable for all assigned classes ───
              final allEntries = <TimetableModel>[];
              for (final classId in teacher.assignedClassIds) {
                final timetable = ref.watch(timetableByClassProvider(classId));
                timetable.whenData((entries) => allEntries.addAll(entries));
              }

              if (allEntries.isEmpty) {
                return const EmptyState(
                  title: 'No Timetable',
                  message: 'No schedule available yet',
                  icon: Icons.calendar_today_rounded,
                );
              }

              return _isWeekView
                  ? _TeacherWeekGrid(entries: allEntries, isDark: isDark)
                  : _TeacherDayView(entries: allEntries, isDark: isDark);
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
          color: isActive ? AppColors.teacherColor : Colors.transparent,
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
class _TeacherDayView extends StatefulWidget {
  final List<TimetableModel> entries;
  final bool isDark;

  const _TeacherDayView({required this.entries, required this.isDark});

  @override
  State<_TeacherDayView> createState() => _TeacherDayViewState();
}

class _TeacherDayViewState extends State<_TeacherDayView> {
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
        // ─── Day selector ───
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
                                ? AppColors.teacherColor
                                : widget.isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.teacherColor
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
                                        : AppColors.teacherColor,
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
                        (context, index) => _TeacherEntryCard(
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
//  WEEK GRID
// ─────────────────────────────────────────
class _TeacherWeekGrid extends StatelessWidget {
  final List<TimetableModel> entries;
  final bool isDark;

  const _TeacherWeekGrid({required this.entries, required this.isDark});

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
                color: AppColors.teacherColor.withValues(alpha: 0.15),
              ),
              children: [
                _headerCell('Time'),
                ..._days.map((d) => _headerCell(d.substring(0, 3))),
              ],
            ),

            // ─── Rows ───
            ...timeSlots.map((slot) {
              final parts = slot.split('-');
              final start = parts[0];
              final end = parts[1];

              return TableRow(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          start,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.teacherColor,
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
                        color: AppColors.teacherColor.withValues(alpha: 0.08),
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
                          if (entry.roomName.isNotEmpty)
                            Text(
                              entry.roomName,
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
          color: AppColors.teacherColor,
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
class _TeacherEntryCard extends StatelessWidget {
  final TimetableModel entry;
  final bool isDark;

  const _TeacherEntryCard({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.teacherColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.teacherColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  entry.startTime,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.teacherColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '|',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.teacherColor,
                  ),
                ),
                Text(
                  entry.endTime,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.teacherColor,
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
                if (entry.className.isNotEmpty)
                  Text(
                    'Class: ${entry.className}',
                    style: AppTypography.caption,
                  ),
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
