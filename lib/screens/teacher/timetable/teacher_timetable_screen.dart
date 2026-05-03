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

    // ─── FIX: use currentTeacherProvider (direct doc fetch by UID) ───
    // Old code scanned all teachers then checked assignedClassIds,
    // then loaded timetable by classId — returning ALL subjects for that class.
    // New code: fetch teacher doc directly, then query timetable WHERE teacherId == uid.
    final teacherAsync = ref.watch(currentTeacherProvider);

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
      body: teacherAsync.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (teacher) {
          if (teacher == null) {
            return const EmptyState(
              title: 'Profile Not Found',
              message: 'Teacher profile could not be loaded. Contact admin.',
              icon: Icons.person_off_rounded,
            );
          }

          // ─── FIX: query by teacherId — not by classId ───
          // This correctly scopes results to only THIS teacher's sessions,
          // regardless of whether assignedClassIds is populated.
          final timetableAsync = ref.watch(
            timetableByTeacherProvider(teacher.id),
          );

          return timetableAsync.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error loading timetable',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (entries) {
              if (entries.isEmpty) {
                return EmptyState(
                  title: 'No Timetable Yet',
                  message:
                      'No schedule has been assigned to you.\nContact admin to set up your timetable.',
                  icon: Icons.calendar_today_rounded,
                );
              }

              return _isWeekView
                  ? _TeacherWeekGrid(entries: entries, isDark: isDark)
                  : _TeacherDayView(entries: entries, isDark: isDark);
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
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
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
        // ─── Day selector chips ───
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children:
                _days.map((day) {
                  final isActive = day == _selectedDay;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? AppColors.teacherColor
                                : AppColors.teacherColor.withValues(
                                  alpha: 0.08,
                                ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isActive
                                  ? AppColors.teacherColor
                                  : AppColors.teacherColor.withValues(
                                    alpha: 0.3,
                                  ),
                        ),
                      ),
                      child: Text(
                        day.substring(0, 3),
                        style: AppTypography.labelSmall.copyWith(
                          color:
                              isActive ? Colors.white : AppColors.teacherColor,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),

        // ─── Entries or empty ───
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
            // ─── Time rows ───
            ...timeSlots.map((slot) {
              final parts = slot.split('-');
              final start = parts[0];
              final end = parts.length > 1 ? parts[1] : '';

              return TableRow(
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.darkBackground
                          : AppColors.lightBackground,
                ),
                children: [
                  // Time label cell
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          start,
                          style: AppTypography.labelSmall.copyWith(
                            color:
                                isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                          ),
                        ),
                        if (end.isNotEmpty)
                          Text(end, style: AppTypography.caption),
                      ],
                    ),
                  ),
                  // Day cells
                  ..._days.map((day) {
                    final match = entries.where(
                      (e) =>
                          e.dayOfWeek.toLowerCase() == day.toLowerCase() &&
                          e.startTime == start,
                    );
                    if (match.isEmpty) {
                      return Container(
                        height: 70,
                        color:
                            isDark
                                ? AppColors.darkBackground
                                : AppColors.lightBackground,
                      );
                    }
                    final entry = match.first;
                    return Container(
                      height: 70,
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
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (entry.roomName.isNotEmpty)
                            Text(
                              entry.roomName,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.teacherColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          if (entry.className.isNotEmpty)
                            Text(
                              entry.className,
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
          // ─── Time badge ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.teacherColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  entry.startTime,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.teacherColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  entry.endTime,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.teacherColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ─── Subject + class + room ───
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
                    entry.className,
                    style: AppTypography.bodySmall.copyWith(
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                  ),
                if (entry.roomName.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.meeting_room_rounded,
                        size: 12,
                        color: AppColors.teacherColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.roomName,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.teacherColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
