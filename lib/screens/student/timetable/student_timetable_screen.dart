import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

// ─── Subject colour palette ────────────────────────────────────────────────────
const List<Color> _subjectColors = [
  Color(0xFF4A90D9),
  Color(0xFF7B68EE),
  Color(0xFF20B2AA),
  Color(0xFFE8A838),
  Color(0xFFE05C5C),
  Color(0xFF52A872),
  Color(0xFFD4799A),
  Color(0xFF6B8FD4),
  Color(0xFFB07BC4),
  Color(0xFF5BAACC),
  Color(0xFF8FAF48),
  Color(0xFFD4914A),
];

Color _colorForSubject(String subject) {
  if (subject.isEmpty) return _subjectColors[0];
  int hash = 0;
  for (final c in subject.runes) hash = (hash * 31 + c) & 0x7FFFFFFF;
  return _subjectColors[hash % _subjectColors.length];
}

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

// ─────────────────────────────────────────────────────────────────────────────
class StudentTimetableScreen extends ConsumerStatefulWidget {
  const StudentTimetableScreen({super.key});

  @override
  ConsumerState<StudentTimetableScreen> createState() =>
      _StudentTimetableScreenState();
}

class _StudentTimetableScreenState
    extends ConsumerState<StudentTimetableScreen> {
  bool _isDayView = true;
  DateTime _selectedDate = DateTime.now();
  String? _cachedClassId;

  void _prevDay() => setState(
    () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
  );
  void _nextDay() => setState(
    () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
  );
  void _prevWeek() => setState(
    () => _selectedDate = _selectedDate.subtract(const Duration(days: 7)),
  );
  void _nextWeek() => setState(
    () => _selectedDate = _selectedDate.add(const Duration(days: 7)),
  );

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _fmtMonthYear(DateTime d) {
    const m = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${m[d.month]} ${d.year}';
  }

  String _dayName(DateTime d) {
    const n = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return n[d.weekday];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final students = ref.watch(studentsProvider);

    // ── Auto week type from active semester ─────────────────────────────────
    // weekTypeForDateProvider computes A/B based on
    // (selectedDate - semesterStartDate).inDays ~/ 7 parity.
    final weekType = ref.watch(weekTypeForDateProvider(_selectedDate));
    // Fallback label when no semester configured
    final weekLabel = weekType.isEmpty ? '–' : 'Week $weekType';

    // Resolve student → classId
    final resolvedClassId = currentUser.when(
      data: (user) {
        if (user == null) return null;
        final studentAsync = ref.watch(studentByUserIdProvider(user.id));
        return studentAsync.value?.classId;
      },
      loading: () => null,
      error: (_, __) => null,
    );

    // Cache it — once we have a real classId, keep it
    if (resolvedClassId != null && resolvedClassId.isNotEmpty) {
      _cachedClassId = resolvedClassId;
    }
    final classId = _cachedClassId ?? '';

    final timetableAsync =
        classId.isEmpty ? null : ref.watch(timetableByClassProvider(classId));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111318) : const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────────
            _Header(
              isDayView: _isDayView,
              selectedDate: _selectedDate,
              weekLabel: weekLabel,
              weekType: weekType,
              isDark: isDark,
              onToggleView: () => setState(() => _isDayView = !_isDayView),
              onPrev: _isDayView ? _prevDay : _prevWeek,
              onNext: _isDayView ? _nextDay : _nextWeek,
              fmtDate: _fmtDate,
              fmtMY: _fmtMonthYear,
            ),

            // ── Content ─────────────────────────────────────────────────────────
            Expanded(
              child:
                  (timetableAsync == null)
                      ? const LoadingWidget()
                      : timetableAsync.when(
                        loading: () => const LoadingWidget(),
                        error:
                            (e, _) => EmptyState(
                              title: 'Error',
                              message: e.toString(),
                              icon: Icons.error_outline_rounded,
                            ),
                        data: (allEntries) {
                          // Filter to the week type for the selected date.
                          // weekType == '' means no semester configured → show all entries.
                          final entries =
                              weekType.isEmpty
                                  ? allEntries
                                  : allEntries
                                      .where(
                                        (e) =>
                                            e.weekType.isEmpty ||
                                            e.weekType == weekType,
                                      )
                                      .toList();

                          if (entries.isEmpty) {
                            return EmptyState(
                              title: 'No Timetable',
                              message:
                                  weekType.isEmpty
                                      ? 'No timetable entries found.'
                                      : 'No schedule for $weekLabel.',
                              icon: Icons.calendar_today_rounded,
                            );
                          }

                          return _isDayView
                              ? _DayListView(
                                entries: entries,
                                selectedDate: _selectedDate,
                                isDark: isDark,
                                dayName: _dayName(_selectedDate),
                              )
                              : _WeekGridView(
                                entries: entries,
                                weekStart: _mondayOf(_selectedDate),
                                selectedDate: _selectedDate,
                                isDark: isDark,
                                onDayTap:
                                    (d) => setState(() {
                                      _selectedDate = d;
                                      _isDayView = true;
                                    }),
                              );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool isDayView;
  final DateTime selectedDate;
  final String weekLabel;
  final String weekType;
  final bool isDark;
  final VoidCallback onToggleView, onPrev, onNext;
  final String Function(DateTime) fmtDate;
  final String Function(DateTime) fmtMY;

  const _Header({
    required this.isDayView,
    required this.selectedDate,
    required this.weekLabel,
    required this.weekType,
    required this.isDark,
    required this.onToggleView,
    required this.onPrev,
    required this.onNext,
    required this.fmtDate,
    required this.fmtMY,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1F2A) : Colors.white;
    final isA = weekType == 'A';
    final wColor =
        weekType.isEmpty
            ? Colors.grey
            : isA
            ? AppColors.teacherColor
            : AppColors.studentColor;

    return Container(
      color: bg,
      child: Column(
        children: [
          // ── Top row ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 10),

                // Auto week badge — read-only, shows computed week
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: wColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: wColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    weekLabel,
                    style: AppTypography.labelMedium.copyWith(
                      color: wColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const Spacer(),

                Text(
                  isDayView ? fmtDate(selectedDate) : fmtMY(selectedDate),
                  style: AppTypography.labelMedium.copyWith(
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
                const Spacer(),

                // View toggles
                _VIcon(
                  icon: Icons.view_list_rounded,
                  isActive: isDayView,
                  isDark: isDark,
                  onTap: () {
                    if (!isDayView) onToggleView();
                  },
                ),
                const SizedBox(width: 6),
                _VIcon(
                  icon: Icons.grid_view_rounded,
                  isActive: !isDayView,
                  isDark: isDark,
                  onTap: () {
                    if (isDayView) onToggleView();
                  },
                ),
              ],
            ),
          ),

          // ── Nav row ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onPrev,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                    size: 28,
                  ),
                ),
                Expanded(
                  child:
                      isDayView
                          ? _DayPicker(
                            selectedDate: selectedDate,
                            isDark: isDark,
                          )
                          : Center(
                            child: Text(
                              'Week of ${_short(_monday(selectedDate))}',
                              style: AppTypography.labelMedium.copyWith(
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                            ),
                          ),
                ),
                GestureDetector(
                  onTap: onNext,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color:
                isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
    );
  }

  static DateTime _monday(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));
  static String _short(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month]}';
  }
}

class _VIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive, isDark;
  final VoidCallback onTap;
  const _VIcon({
    required this.icon,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(
      icon,
      size: 22,
      color:
          isActive
              ? AppColors.studentColor
              : isDark
              ? Colors.white38
              : Colors.black26,
    ),
  );
}

class _DayPicker extends StatelessWidget {
  final DateTime selectedDate;
  final bool isDark;
  const _DayPicker({required this.selectedDate, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final monday = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    final today = DateTime.now();
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (i) {
        final d = monday.add(Duration(days: i));
        final isSel =
            d.day == selectedDate.day && d.month == selectedDate.month;
        final isTod =
            d.day == today.day &&
            d.month == today.month &&
            d.year == today.year;
        return Column(
          children: [
            Text(
              labels[i],
              style: AppTypography.caption.copyWith(
                color:
                    isSel
                        ? AppColors.studentColor
                        : isDark
                        ? Colors.white38
                        : Colors.black38,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isSel
                        ? AppColors.studentColor
                        : isTod
                        ? AppColors.studentColor.withValues(alpha: 0.15)
                        : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: Text(
                '${d.day}',
                style: AppTypography.labelSmall.copyWith(
                  color:
                      isSel
                          ? Colors.white
                          : isDark
                          ? Colors.white70
                          : Colors.black87,
                  fontWeight: isSel ? FontWeight.bold : null,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DAY LIST VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _DayListView extends StatelessWidget {
  final List<TimetableModel> entries;
  final DateTime selectedDate;
  final bool isDark;
  final String dayName;

  const _DayListView({
    required this.entries,
    required this.selectedDate,
    required this.isDark,
    required this.dayName,
  });

  @override
  Widget build(BuildContext context) {
    final dayEntries =
        entries.where((e) => e.dayOfWeek == dayName).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final int total = dayEntries.length < 6 ? 6 : dayEntries.length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: total,
      itemBuilder: (context, i) {
        final hasEntry = i < dayEntries.length;
        final entry = hasEntry ? dayEntries[i] : null;
        final color = entry != null ? _colorForSubject(entry.subject) : null;
        final isRatt = entry?.subject.toLowerCase().contains('rattrap') == true;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  'Séance${i + 1}',
                  style: AppTypography.caption.copyWith(
                    color: isDark ? Colors.white30 : Colors.black38,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color:
                      hasEntry
                          ? color!.withValues(alpha: isDark ? 0.18 : 0.1)
                          : isDark
                          ? const Color(0xFF1E2430)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        hasEntry
                            ? color!.withValues(alpha: 0.35)
                            : isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child:
                    hasEntry
                        ? _SCard(
                          entry: entry!,
                          color: color!,
                          isDark: isDark,
                          isRatt: isRatt,
                        )
                        : const SizedBox(height: 52),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SCard extends StatelessWidget {
  final TimetableModel entry;
  final Color color;
  final bool isDark, isRatt;
  const _SCard({
    required this.entry,
    required this.color,
    required this.isDark,
    required this.isRatt,
  });
  @override
  Widget build(BuildContext context) {
    final room =
        entry.roomName.isNotEmpty
            ? entry.roomName
            : entry.roomId.isNotEmpty
            ? entry.roomId
            : '';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.subject,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (room.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    room,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (isRatt) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
          if (entry.teacherName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Teacher: ${entry.teacherName}',
              style: AppTypography.caption.copyWith(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '${entry.startTime} - ${entry.endTime}',
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WEEKLY GRID VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _WeekGridView extends StatelessWidget {
  final List<TimetableModel> entries;
  final DateTime weekStart, selectedDate;
  final bool isDark;
  final ValueChanged<DateTime> onDayTap;

  const _WeekGridView({
    required this.entries,
    required this.weekStart,
    required this.selectedDate,
    required this.isDark,
    required this.onDayTap,
  });

  static const double _hH = 64.0, _sh = 8.5, _eh = 18.5;
  static const double _tW = 44.0, _cW = 96.0;

  double _ty(String t) {
    final p = t.split(':');
    if (p.length != 2) return 0;
    return ((double.tryParse(p[0]) ?? 0) +
            (double.tryParse(p[1]) ?? 0) / 60.0 -
            _sh) *
        _hH;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final totalH = (_eh - _sh) * _hH;
    final gridW = _cW * 5;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _tW + gridW,
          child: Column(
            children: [
              // Day headers
              Row(
                children: [
                  SizedBox(width: _tW),
                  ..._days.asMap().entries.map((e) {
                    final d = weekStart.add(Duration(days: e.key));
                    final isTd =
                        d.day == today.day &&
                        d.month == today.month &&
                        d.year == today.year;
                    return GestureDetector(
                      onTap: () => onDayTap(d),
                      child: SizedBox(
                        width: _cW,
                        child: Column(
                          children: [
                            Text(
                              _dayLabels[e.key],
                              style: AppTypography.caption.copyWith(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    isTd
                                        ? AppColors.studentColor
                                        : Colors.transparent,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${d.day}',
                                style: AppTypography.labelSmall.copyWith(
                                  color:
                                      isTd
                                          ? Colors.white
                                          : isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                  fontWeight: isTd ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: totalH,
                child: Stack(
                  children: [
                    // Hour lines
                    ...List.generate(11, (i) {
                      final h = 8 + i;
                      final y = (h - _sh) * _hH;
                      return Positioned(
                        top: y,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            SizedBox(
                              width: _tW,
                              child: Text(
                                '${h.toString().padLeft(2, '0')}:00',
                                style: AppTypography.caption.copyWith(
                                  color:
                                      isDark ? Colors.white24 : Colors.black26,
                                  fontSize: 9,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color:
                                    isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.04),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Break shade
                    Positioned(
                      top: _ty('12:20'),
                      left: _tW,
                      width: gridW,
                      height: _ty('14:00') - _ty('12:20'),
                      child: Container(
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.02),
                      ),
                    ),

                    // Cards
                    ..._days.asMap().entries.expand((de) {
                      final col = de.key;
                      final day = de.value;
                      return entries.where((e) => e.dayOfWeek == day).map((e) {
                        final top = _ty(e.startTime);
                        final h = (_ty(e.endTime) - top).clamp(
                          24.0,
                          double.infinity,
                        );
                        final left = _tW + col * _cW + 2;
                        final color = _colorForSubject(e.subject);
                        final room =
                            e.roomName.isNotEmpty ? e.roomName : e.roomId;
                        final isRatt = e.subject.toLowerCase().contains(
                          'rattrap',
                        );
                        return Positioned(
                          top: top,
                          left: left,
                          width: _cW - 4,
                          height: h,
                          child: GestureDetector(
                            onTap:
                                () => onDayTap(
                                  weekStart.add(Duration(days: col)),
                                ),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: color.withValues(
                                  alpha: isDark ? 0.75 : 0.85,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.subject,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (e.teacherName.isNotEmpty && h > 52)
                                    Text(
                                      e.teacherName,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 7.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (room.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            room,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      if (isRatt)
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: AppColors.warning,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.notifications_rounded,
                                            size: 8,
                                            color: Colors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      });
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on num {
  double clamp(double min, double max) {
    if (this < min) return min;
    if (this > max) return max;
    return toDouble();
  }
}
