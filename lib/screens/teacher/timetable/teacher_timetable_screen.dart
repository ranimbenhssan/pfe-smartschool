import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

// ─── Merge TP groups that share the same séance ───────────────────────────────
// Key includes weekType so "TP 1 Week A" and "TP 1 Week B" are NOT merged,
// but "TP 1 Week A" and "TP 2 Week A" ARE merged into one card.
List<_MergedEntry> _mergeEntries(List<TimetableModel> entries) {
  final map = <String, _MergedEntry>{};
  for (final e in entries) {
    final key =
        '${e.teacherId}|${e.subject}|${e.dayOfWeek}|${e.startTime}|${e.endTime}|${e.weekType}';
    if (map.containsKey(key)) {
      map[key]!.addClass(e.className);
    } else {
      map[key] = _MergedEntry.from(e);
    }
  }
  return map.values.toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
}

class _MergedEntry {
  final TimetableModel src;
  final List<String> classNames;

  _MergedEntry.from(this.src) : classNames = [src.className];

  void addClass(String name) {
    if (!classNames.contains(name)) classNames.add(name);
  }

  String get subject => src.subject;
  String get dayOfWeek => src.dayOfWeek;
  String get startTime => src.startTime;
  String get endTime => src.endTime;
  String get roomName => src.roomName;
  String get teacherName => src.teacherName;
  String get weekType => src.weekType;

  String get classLabel => classNames.join(' + ');
  bool get isMerged => classNames.length > 1;
}

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

// ─────────────────────────────────────────────────────────────────────────────
class TeacherTimetableScreen extends ConsumerStatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  ConsumerState<TeacherTimetableScreen> createState() =>
      _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState
    extends ConsumerState<TeacherTimetableScreen> {
  bool _isDayView = true;
  DateTime _selectedDate = DateTime.now();

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
    final teachers = ref.watch(teachersProvider);

    // Auto week type from semester
    final weekType = ref.watch(weekTypeForDateProvider(_selectedDate));
    final weekLabel = weekType.isEmpty ? '–' : 'Week $weekType';

    // Resolve teacher
    final teacher = currentUser.when(
      data:
          (user) =>
              user == null
                  ? null
                  : teachers.value
                      ?.where((t) => t.userId == user.id)
                      .firstOrNull,
      loading: () => null,
      error: (_, __) => null,
    );

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111318) : const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header (same as student) ─────────────────────────────────────
            _TimetableHeader(
              isDayView: _isDayView,
              selectedDate: _selectedDate,
              weekLabel: weekLabel,
              weekType: weekType,
              isDark: isDark,
              accentColor: AppColors.teacherColor,
              onToggleView: () => setState(() => _isDayView = !_isDayView),
              onPrev: _isDayView ? _prevDay : _prevWeek,
              onNext: _isDayView ? _nextDay : _nextWeek,
              fmtDate: _fmtDate,
              fmtMY: _fmtMonthYear,
            ),

            // ── Content ──────────────────────────────────────────────────────
            Expanded(
              child:
                  teacher == null
                      ? const EmptyState(
                        title: 'No Teacher Profile',
                        message: 'Teacher profile not found.',
                        icon: Icons.person_off_rounded,
                      )
                      : _TimetableContent(
                        teacher: teacher,
                        isDayView: _isDayView,
                        selectedDate: _selectedDate,
                        weekType: weekType,
                        isDark: isDark,
                        dayName: _dayName(_selectedDate),
                        weekStart: _mondayOf(_selectedDate),
                        onDayTap:
                            (d) => setState(() {
                              _selectedDate = d;
                              _isDayView = true;
                            }),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TIMETABLE CONTENT
// ─────────────────────────────────────────────────────────────────────────────
class _TimetableContent extends ConsumerWidget {
  final dynamic teacher;
  final bool isDayView, isDark;
  final DateTime selectedDate, weekStart;
  final String weekType, dayName;
  final ValueChanged<DateTime> onDayTap;

  const _TimetableContent({
    required this.teacher,
    required this.isDayView,
    required this.isDark,
    required this.selectedDate,
    required this.weekStart,
    required this.weekType,
    required this.dayName,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Collect entries from ALL assigned classes
    final allEntries = <TimetableModel>[];
    for (final classId in teacher.assignedClassIds as List<String>) {
      final async = ref.watch(timetableByClassProvider(classId));
      async.whenData((list) => allEntries.addAll(list));
    }

    // Filter to displayed week type
    final entries =
        weekType.isEmpty
            ? allEntries
            : allEntries
                .where((e) => e.weekType.isEmpty || e.weekType == weekType)
                .toList();

    if (entries.isEmpty) {
      return EmptyState(
        title: 'No Timetable',
        message:
            weekType.isEmpty
                ? 'No schedule found.'
                : 'No schedule for $weekType.',
        icon: Icons.calendar_today_rounded,
      );
    }

    return isDayView
        ? _DayListView(entries: entries, dayName: dayName, isDark: isDark)
        : _WeekGridView(
          entries: entries,
          weekStart: weekStart,
          isDark: isDark,
          onDayTap: onDayTap,
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED HEADER  (identical to student, parameterised by accentColor)
// ─────────────────────────────────────────────────────────────────────────────
class _TimetableHeader extends StatelessWidget {
  final bool isDayView;
  final DateTime selectedDate;
  final String weekLabel, weekType;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onToggleView, onPrev, onNext;
  final String Function(DateTime) fmtDate;
  final String Function(DateTime) fmtMY;

  const _TimetableHeader({
    required this.isDayView,
    required this.selectedDate,
    required this.weekLabel,
    required this.weekType,
    required this.isDark,
    required this.accentColor,
    required this.onToggleView,
    required this.onPrev,
    required this.onNext,
    required this.fmtDate,
    required this.fmtMY,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1F2A) : Colors.white;
    final wColor = weekType.isEmpty ? Colors.grey : accentColor;

    return Container(
      color: bg,
      child: Column(
        children: [
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
                _VIcon(
                  icon: Icons.view_list_rounded,
                  isActive: isDayView,
                  color: accentColor,
                  isDark: isDark,
                  onTap: () {
                    if (!isDayView) onToggleView();
                  },
                ),
                const SizedBox(width: 6),
                _VIcon(
                  icon: Icons.grid_view_rounded,
                  isActive: !isDayView,
                  color: accentColor,
                  isDark: isDark,
                  onTap: () {
                    if (isDayView) onToggleView();
                  },
                ),
              ],
            ),
          ),
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
                            accentColor: accentColor,
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
  final Color color;
  final VoidCallback onTap;
  const _VIcon({
    required this.icon,
    required this.isActive,
    required this.isDark,
    required this.color,
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
              ? color
              : isDark
              ? Colors.white38
              : Colors.black26,
    ),
  );
}

class _DayPicker extends StatelessWidget {
  final DateTime selectedDate;
  final bool isDark;
  final Color accentColor;
  const _DayPicker({
    required this.selectedDate,
    required this.isDark,
    required this.accentColor,
  });
  @override
  Widget build(BuildContext context) {
    final monday = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    final today = DateTime.now();
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
              _dayLabels[i],
              style: AppTypography.caption.copyWith(
                color:
                    isSel
                        ? accentColor
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
                        ? accentColor
                        : isTod
                        ? accentColor.withValues(alpha: 0.15)
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
  final String dayName;
  final bool isDark;

  const _DayListView({
    required this.entries,
    required this.dayName,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dayEntries = _mergeEntries(
      entries.where((e) => e.dayOfWeek == dayName).toList(),
    );

    if (dayEntries.isEmpty) {
      return EmptyState(
        title: 'No Classes',
        message: 'No classes on $dayName.',
        icon: Icons.free_breakfast_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: dayEntries.length,
      itemBuilder:
          (context, i) => _MergedCard(merged: dayEntries[i], isDark: isDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WEEK GRID VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _WeekGridView extends StatelessWidget {
  final List<TimetableModel> entries;
  final DateTime weekStart;
  final bool isDark;
  final ValueChanged<DateTime> onDayTap;

  const _WeekGridView({
    required this.entries,
    required this.weekStart,
    required this.isDark,
    required this.onDayTap,
  });

  static const double _hH = 64.0, _sh = 8.5, _eh = 18.5;
  static const double _tW = 44.0, _cW = 100.0;

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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _tW + _cW * 5,
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
                                        ? AppColors.teacherColor
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
                                        ? Colors.white.withValues(alpha: 0.06)
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
                      width: _cW * 5,
                      height: _ty('14:00') - _ty('12:20'),
                      child: Container(
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.02),
                      ),
                    ),
                    // Cards — merge per cell
                    ..._days.asMap().entries.expand((de) {
                      final col = de.key;
                      final dayName = de.value;
                      final daySlots =
                          entries.where((e) => e.dayOfWeek == dayName).toList();
                      final merged = _mergeEntries(daySlots);
                      return merged.map((m) {
                        final top = _ty(m.startTime);
                        final h = (_ty(m.endTime) - top).clamp(
                          24.0,
                          double.infinity,
                        );
                        final left = _tW + col * _cW + 2;
                        final color = _colorFor(m.subject);
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
                                      m.subject,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Class label — highlights merged groups
                                  Text(
                                    m.classLabel,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 7.5,
                                      fontWeight:
                                          m.isMerged
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (m.roomName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        m.roomName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
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

  Color _colorFor(String subject) {
    const palette = [
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
    int hash = 0;
    for (final c in subject.runes) hash = (hash * 31 + c) & 0x7FFFFFFF;
    return palette[hash % palette.length];
  }
}

extension on num {
  double clamp(double min, double max) {
    if (this < min) return min;
    if (this > max) return max;
    return toDouble();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MERGED CARD  (day view)
// ─────────────────────────────────────────────────────────────────────────────
class _MergedCard extends StatelessWidget {
  final _MergedEntry merged;
  final bool isDark;

  const _MergedCard({required this.merged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.teacherColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merged.startTime,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.teacherColor,
                ),
              ),
              Text(
                merged.endTime,
                style: AppTypography.caption.copyWith(
                  color: AppColors.teacherColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merged.subject,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),

                // Class badge — bolded + bordered when multiple TP groups
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teacherColor.withValues(
                      alpha: merged.isMerged ? 0.15 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        merged.isMerged
                            ? Border.all(
                              color: AppColors.teacherColor.withValues(
                                alpha: 0.4,
                              ),
                            )
                            : null,
                  ),
                  child: Text(
                    merged.classLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.teacherColor,
                      fontWeight:
                          merged.isMerged ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),

                if (merged.roomName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.meeting_room_rounded,
                        size: 11,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        merged.roomName,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
