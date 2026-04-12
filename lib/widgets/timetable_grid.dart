import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';

// ─────────────────────────────────────────
//  SHARED TIMETABLE WEEK GRID
//  Used by Teacher, Student dashboards
// ─────────────────────────────────────────
class TimetableGrid extends StatefulWidget {
  final List<TimetableModel> entries;
  final Color accentColor;

  const TimetableGrid({
    super.key,
    required this.entries,
    this.accentColor = const Color(0xFFD4A843),
  });

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid>
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
    final initial = (weekday >= 1 && weekday <= 5) ? weekday - 1 : 0;
    _tabController = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: initial,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: widget.accentColor,
          labelColor: widget.accentColor,
          unselectedLabelColor:
              isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 400,
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
                                isDark
                                    ? AppColors.darkTextHint
                                    : AppColors.lightTextHint,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No classes on $day',
                            style: AppTypography.bodySmall.copyWith(
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: dayEntries.length,
                    itemBuilder:
                        (context, index) => _TimetableCard(
                          entry: dayEntries[index],
                          isDark: isDark,
                          accentColor: widget.accentColor,
                        ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TimetableCard extends StatelessWidget {
  final TimetableModel entry;
  final bool isDark;
  final Color accentColor;

  const _TimetableCard({
    required this.entry,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  entry.startTime,
                  style: AppTypography.labelSmall.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '|',
                  style: AppTypography.caption.copyWith(color: accentColor),
                ),
                Text(
                  entry.endTime,
                  style: AppTypography.labelSmall.copyWith(color: accentColor),
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
