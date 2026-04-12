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
          // ─── Toggle day/week view ───
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isWeekView = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          !_isWeekView ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Day',
                      style: AppTypography.labelSmall.copyWith(
                        color:
                            !_isWeekView
                                ? AppColors.primary
                                : isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isWeekView = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _isWeekView ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Week',
                      style: AppTypography.labelSmall.copyWith(
                        color:
                            _isWeekView
                                ? AppColors.primary
                                : isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                      ),
                    ),
                  ),
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

          // Get student's classId
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
              // Find student by userId
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
                      ? _WeekView(entries: entries, isDark: isDark)
                      : _DayView(entries: entries, isDark: isDark);
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
//  DAY VIEW — shows only today's classes
// ─────────────────────────────────────────
class _DayView extends StatefulWidget {
  final List<TimetableModel> entries;
  final bool isDark;

  const _DayView({required this.entries, required this.isDark});

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
    final weekday = DateTime.now().weekday;
    _selectedDay =
        (weekday >= 1 && weekday <= 5) ? _days[weekday - 1] : 'Monday';
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
                        (context, index) => _EntryCard(
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
//  WEEK VIEW — shows full week with Tabs
// ─────────────────────────────────────────
class _WeekView extends StatefulWidget {
  final List<TimetableModel> entries;
  final bool isDark;

  const _WeekView({required this.entries, required this.isDark});

  @override
  State<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<_WeekView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  void initState() {
    super.initState();
    final weekday = DateTime.now().weekday;
    // Sélectionne le jour actuel si on est en semaine, sinon lundi
    final initialIndex = (weekday >= 1 && weekday <= 5) ? weekday - 1 : 0;
    _tabController = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.studentColor,
          labelColor: AppColors.studentColor,
          unselectedLabelColor:
              widget.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children:
                _days.map((day) {
                  final dayEntries =
                      widget.entries
                          .where(
                            (e) =>
                                e.dayOfWeek.toLowerCase() == day.toLowerCase(),
                          )
                          .toList()
                        ..sort((a, b) => a.startTime.compareTo(b.startTime));

                  if (dayEntries.isEmpty) {
                    return Center(
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
                            'No classes on $day',
                            style: AppTypography.bodySmall.copyWith(
                              color:
                                  widget.isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: dayEntries.length,
                    itemBuilder:
                        (context, index) => _EntryCard(
                          entry: dayEntries[index],
                          isDark: widget.isDark,
                        ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  SHARED ENTRY CARD
// ─────────────────────────────────────────
class _EntryCard extends StatelessWidget {
  final TimetableModel entry;
  final bool isDark;

  const _EntryCard({required this.entry, required this.isDark});

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
          // ─── Time ───
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
        ],
      ),
    );
  }
}
