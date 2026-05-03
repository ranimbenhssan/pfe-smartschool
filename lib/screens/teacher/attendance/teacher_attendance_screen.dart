import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

String _dayName(int weekday) {
  const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return days[weekday];
}

String _formatDateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  final String? classId;
  final String? className;

  const TeacherAttendanceScreen({super.key, this.classId, this.className});

  @override
  ConsumerState<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState
    extends ConsumerState<TeacherAttendanceScreen> {
  late DateTime _selectedDate;

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(), // no future dates
      helpText: 'Select attendance date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.teacherColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacherAsync = ref.watch(currentTeacherProvider);

    final isWeekend = _selectedDate.weekday == DateTime.saturday ||
        _selectedDate.weekday == DateTime.sunday;
    final dayLabel = _isToday
        ? 'Today'
        : DateFormat('EEE d MMM').format(_selectedDate);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance — Name Call'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          TextButton.icon(
            onPressed: () => _pickDate(context),
            icon: Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: _isToday ? AppColors.teacherColor : AppColors.warning,
            ),
            label: Text(
              dayLabel,
              style: AppTypography.labelMedium.copyWith(
                color: _isToday ? AppColors.teacherColor : AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: teacherAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => EmptyState(
            title: 'Error', message: e.toString(), icon: Icons.error_outline_rounded),
        data: (teacher) {
          if (teacher == null) {
            return const EmptyState(
              title: 'Profile Not Found',
              message: 'Your teacher profile could not be loaded.\nContact the admin.',
              icon: Icons.person_off_rounded,
            );
          }

          if (isWeekend) {
            return _buildBanner(
              isDark: isDark,
              child: const EmptyState(
                title: 'No Classes',
                message: 'No classes are scheduled on weekends.',
                icon: Icons.weekend_rounded,
              ),
            );
          }

          // ─── Key fix: query by teacherId + dayOfWeek from timetable ───
          final selectedDayName = _dayName(_selectedDate.weekday);
          final classesAsync = ref.watch(
            classesByTeacherAndDayProvider((
              teacherId: teacher.id,
              dayName: selectedDayName,
            )),
          );

          return classesAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => EmptyState(
                title: 'Error loading classes',
                message: e.toString(),
                icon: Icons.error_outline_rounded),
            data: (classes) => _ClassListBody(
              classes: classes,
              selectedDate: _selectedDate,
              selectedDayName: selectedDayName,
              isToday: _isToday,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBanner({required bool isDark, required Widget child}) {
    return Column(
      children: [
        _DateBanner(date: _selectedDate, isToday: _isToday, isDark: isDark),
        Expanded(child: child),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  CLASS LIST BODY
// ─────────────────────────────────────────
class _ClassListBody extends StatefulWidget {
  final List<ClassModel> classes;
  final DateTime selectedDate;
  final String selectedDayName;
  final bool isToday;
  final bool isDark;

  const _ClassListBody({
    required this.classes,
    required this.selectedDate,
    required this.selectedDayName,
    required this.isToday,
    required this.isDark,
  });

  @override
  State<_ClassListBody> createState() => _ClassListBodyState();
}

class _ClassListBodyState extends State<_ClassListBody> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDateStr(widget.selectedDate);

    final filtered = _searchQuery.isEmpty
        ? widget.classes
        : widget.classes
            .where((c) =>
                c.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.grade.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.level.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        // ─── Date banner ───
        _DateBanner(
            date: widget.selectedDate,
            isToday: widget.isToday,
            isDark: widget.isDark,
            subtitle:
                '${widget.selectedDayName} · ${widget.classes.length} class(es)'),

        // ─── Search ───
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search class...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
              filled: true,
              fillColor: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // ─── List ───
        Expanded(
          child: widget.classes.isEmpty
              ? EmptyState(
                  title: widget.isToday
                      ? 'No Classes Today'
                      : 'No Classes on ${widget.selectedDayName}',
                  message: widget.isToday
                      ? 'You have no classes scheduled for today.\nTap the date button above to view another day.'
                      : 'No timetable entries found for ${DateFormat('d MMM yyyy').format(widget.selectedDate)}.',
                  icon: Icons.event_busy_rounded,
                )
              : filtered.isEmpty
                  ? EmptyState(
                      title: 'No Match',
                      message: 'No class matches "$_searchQuery"',
                      icon: Icons.search_off_rounded,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final cls = filtered[index];
                        return _ClassCard(
                          cls: cls,
                          isDark: widget.isDark,
                          isToday: widget.isToday,
                          onTap: () => context.push(
                            AppRoutes.teacherNameCall,
                            extra: {
                              'classId': cls.id,
                              'className': cls.displayName,
                              'targetDate': dateStr, // ← date passed to name call
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  DATE BANNER
// ─────────────────────────────────────────
class _DateBanner extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isDark;
  final String? subtitle;

  const _DateBanner({
    required this.date,
    required this.isToday,
    required this.isDark,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isToday
              ? [AppColors.teacherColor.withValues(alpha: 0.85), AppColors.teacherColor]
              : [AppColors.warning.withValues(alpha: 0.8), AppColors.warning],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isToday ? Icons.how_to_reg_rounded : Icons.history_edu_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? "Today's Name Call" : 'Past Attendance',
                  style: AppTypography.labelLarge.copyWith(color: Colors.white),
                ),
                Text(
                  subtitle ??
                      (isToday
                          ? 'Today'
                          : DateFormat('EEEE, d MMM yyyy').format(date)),
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          if (!isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Edit mode',
                  style: AppTypography.caption
                      .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CLASS CARD
// ─────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final ClassModel cls;
  final bool isDark;
  final bool isToday;
  final VoidCallback onTap;

  const _ClassCard({
    required this.cls,
    required this.isDark,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.teacherColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.teacherColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.class_rounded,
                  color: AppColors.teacherColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cls.displayName,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (cls.grade.isNotEmpty) ...[
                        _Chip(cls.grade, AppColors.info),
                        const SizedBox(width: 6),
                      ],
                      _Chip('${cls.studentCount} students', AppColors.success),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Icon(
                  isToday
                      ? Icons.edit_note_rounded
                      : Icons.manage_history_rounded,
                  color: AppColors.teacherColor,
                  size: 20,
                ),
                Text(
                  isToday ? 'Take' : 'Edit',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.teacherColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppTypography.caption.copyWith(color: color)),
    );
  }
}