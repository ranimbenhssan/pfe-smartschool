import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../services/attendance_notification_service.dart';

class TeacherNamecallScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;

  /// 'yyyy-MM-dd' — empty = today
  final String targetDate;

  const TeacherNamecallScreen({
    super.key,
    this.classId = '',
    this.className = '',
    this.targetDate = '',
  });

  @override
  ConsumerState<TeacherNamecallScreen> createState() =>
      _TeacherNamecallScreenState();
}

class _TeacherNamecallScreenState extends ConsumerState<TeacherNamecallScreen> {
  final Map<String, AttendanceStatus> _attendanceMap = {};
  final Map<String, bool> _savingMap = {};
  bool _isSubmitted = false;
  bool _isLoadingInit = true;

  late DateTime _selectedDate;
  late String _dateStr;
  late bool _isPastDate;

  // Resolved classId — either from widget.classId or from timetable lookup
  String _resolvedClassId = '';
  String _resolvedClassName = '';
  TimetableModel? _resolvedSlot;

  static const _weekdays = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = _fmt(now);

    if (widget.targetDate.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(widget.targetDate);
      } catch (_) {
        _selectedDate = now;
      }
    } else {
      _selectedDate = now;
    }

    _dateStr = _fmt(_selectedDate);
    _isPastDate = _dateStr != today;

    // Pre-populate from widget args (may be empty if launched from Quick Action)
    _resolvedClassId = widget.classId;
    _resolvedClassName = widget.className;

    _initData();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Init — resolves classId from timetable when widget.classId is empty
  //  (launched from Quick Action with no specific class pre-selected).
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initData() async {
    await Future.wait([_resolveClassFromTimetable(), _resolveTimetableSlot()]);
    await _loadExistingAttendance();
    if (mounted) setState(() => _isLoadingInit = false);
  }

  Future<void> _resolveClassFromTimetable() async {
    // If classId already provided (launched from a séance card), skip.
    if (_resolvedClassId.isNotEmpty) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      final dayName = _weekdays[_selectedDate.weekday];
      final snap =
          await FirebaseFirestore.instance
              .collection('timetable')
              .where('teacherId', isEqualTo: user.id)
              .where('dayOfWeek', isEqualTo: dayName)
              .get();

      if (snap.docs.isEmpty) return;

      // Use the first class found for this day — teacher can switch class
      // via the class selector if multiple classes exist.
      final firstDoc = snap.docs.first;
      final d = firstDoc.data();
      _resolvedClassId = d['classId']?.toString() ?? '';
      _resolvedClassName = d['className']?.toString() ?? '';
    } catch (e) {
      debugPrint('_resolveClassFromTimetable: $e');
    }
  }

  Future<void> _resolveTimetableSlot() async {
    if (_resolvedClassId.isEmpty) return;
    try {
      final dayName = _weekdays[_selectedDate.weekday];
      final snap =
          await FirebaseFirestore.instance
              .collection('timetable')
              .where('classId', isEqualTo: _resolvedClassId)
              .where('dayOfWeek', isEqualTo: dayName)
              .get();

      if (snap.docs.isEmpty) return;

      if (!_isPastDate) {
        final now = DateTime.now();
        final curr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        for (final doc in snap.docs) {
          final d = doc.data();
          final start = d['startTime']?.toString() ?? '';
          final end = d['endTime']?.toString() ?? '';
          if (start.isEmpty || end.isEmpty) continue;
          if (curr.compareTo(start) >= 0 && curr.compareTo(end) <= 0) {
            _resolvedSlot = TimetableModel.fromFirestore(doc);
            return;
          }
        }
      }
      _resolvedSlot = TimetableModel.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('_resolveTimetableSlot: $e');
    }
  }

  Future<void> _loadExistingAttendance() async {
    if (_resolvedClassId.isEmpty) return;
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('classId', isEqualTo: _resolvedClassId)
              .where('date', isEqualTo: _dateStr)
              .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        final sid = d['studentId']?.toString() ?? '';
        if (sid.isEmpty) continue;
        _attendanceMap[sid] = AttendanceStatus.values.firstWhere(
          (s) => s.name == (d['status']?.toString() ?? 'present'),
          orElse: () => AttendanceStatus.present,
        );
      }
    } catch (e) {
      debugPrint('_loadExistingAttendance: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  DATE CHANGE — re-runs all init logic for the new date
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _changeDate(DateTime newDate) async {
    final today = _fmt(DateTime.now());
    setState(() {
      _selectedDate = newDate;
      _dateStr = _fmt(newDate);
      _isPastDate = _dateStr != today;
      _isLoadingInit = true;
      _attendanceMap.clear();
      _savingMap.clear();
      _isSubmitted = false;
      _resolvedSlot = null;
      // Keep resolvedClassId — same class, different date
    });
    await _resolveTimetableSlot();
    await _loadExistingAttendance();
    if (mounted) setState(() => _isLoadingInit = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  RESOLVE className → "Level Name Grade" e.g. "3 IOT 1"
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> _resolveClassName(String classId, String fallback) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('classes')
              .doc(classId)
              .get();
      if (!doc.exists) return fallback;
      final d = doc.data()!;
      final lvl = d['level']?.toString().trim() ?? '';
      final nm = d['name']?.toString().trim() ?? '';
      final gr = d['grade']?.toString().trim() ?? '';
      final parts = <String>[];
      if (lvl.isNotEmpty) parts.add(lvl);
      if (nm.isNotEmpty) parts.add(nm);
      if (gr.isNotEmpty) parts.add(gr);
      return parts.isNotEmpty ? parts.join(' ') : fallback;
    } catch (_) {
      return fallback;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SAVE ATTENDANCE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveStudentAttendance(
    StudentModel student,
    AttendanceStatus status,
    TimetableModel? slot,
    String teacherName,
    String teacherId,
  ) async {
    setState(() => _savingMap[student.id] = true);

    final now = DateTime.now();
    final resolvedClassName = await _resolveClassName(
      student.classId,
      student.className,
    );

    final subject = slot?.subject ?? '';
    final sessionName =
        slot != null
            ? '${slot.subject} Session (${slot.startTime} – ${slot.endTime})'
            : '';
    final roomId = slot?.roomId ?? '';
    final roomName = slot?.roomName ?? '';
    final scheduledStart = slot?.startTime ?? '';
    final scheduledEnd = slot?.endTime ?? '';

    try {
      final existing =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('studentId', isEqualTo: student.id)
              .where('date', isEqualTo: _dateStr)
              .limit(1)
              .get();

      final previousStatus =
          existing.docs.isNotEmpty
              ? existing.docs.first.data()['status']?.toString() ?? ''
              : '';

      final entryTimeForPast = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        8,
        0,
      );

      final data = {
        'studentId': student.id,
        'studentName': student.name,
        'classId': student.classId,
        'className': resolvedClassName,
        'date': _dateStr,
        'status': status.name,
        'entryTime':
            status == AttendanceStatus.present ||
                    status == AttendanceStatus.late
                ? Timestamp.fromDate(_isPastDate ? entryTimeForPast : now)
                : null,
        'exitTime': null,
        'subject': subject,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'roomId': roomId,
        'roomName': roomName,
        'scheduledStartTime': scheduledStart,
        'scheduledEndTime': scheduledEnd,
        'sessionName': sessionName,
        'recordedAt': Timestamp.fromDate(now),
        'note': _isPastDate ? 'Manually entered for $_dateStr' : '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'status': status.name,
          'subject': subject,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'roomId': roomId,
          'roomName': roomName,
          'scheduledStartTime': scheduledStart,
          'scheduledEndTime': scheduledEnd,
          'sessionName': sessionName,
          'recordedAt': Timestamp.fromDate(now),
          'className': resolvedClassName,
        });
      } else {
        await FirebaseFirestore.instance.collection('attendance').add(data);
      }

      // Notification (non-fatal)
      try {
        final studentDoc =
            await FirebaseFirestore.instance
                .collection('students')
                .doc(student.id)
                .get();
        final studentUserId = studentDoc.data()?['userId']?.toString() ?? '';
        await AttendanceNotificationService.notify(
          studentUserId: studentUserId,
          studentName: student.name,
          newStatus: status.name,
          previousStatus: previousStatus,
          subject: subject,
          className: resolvedClassName,
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          teacherName: teacherName,
          teacherId: teacherId,
          date: _dateStr,
        );
      } catch (e) {
        debugPrint('Notification (non-fatal): $e');
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) setState(() => _savingMap[student.id] = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final students =
        _resolvedClassId.isNotEmpty
            ? ref.watch(studentsByClassIdProvider(_resolvedClassId))
            : const AsyncValue<List<StudentModel>>.data([]);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(
          _resolvedClassName.isNotEmpty
              ? 'Namecall — $_resolvedClassName'
              : 'Namecall',
        ),
        // ── Date picker in leading area ─────────────────────────────────
        leading: GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2024),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              builder:
                  (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(
                        ctx,
                      ).colorScheme.copyWith(primary: AppColors.teacherColor),
                    ),
                    child: child!,
                  ),
            );
            if (picked != null) await _changeDate(picked);
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (_isPastDate ? AppColors.warning : AppColors.teacherColor)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (_isPastDate
                        ? AppColors.warning
                        : AppColors.teacherColor)
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color:
                      _isPastDate ? AppColors.warning : AppColors.teacherColor,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM').format(_selectedDate),
                  style: AppTypography.caption.copyWith(
                    color:
                        _isPastDate
                            ? AppColors.warning
                            : AppColors.teacherColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        leadingWidth: 90,
      ),
      body:
          _isLoadingInit
              ? const LoadingWidget()
              : currentUser.when(
                loading: () => const LoadingWidget(),
                error:
                    (e, _) => EmptyState(
                      title: 'Error',
                      message: e.toString(),
                      icon: Icons.error_outline_rounded,
                    ),
                data: (user) {
                  if (user == null) return const SizedBox.shrink();

                  if (_resolvedClassId.isEmpty) {
                    return EmptyState(
                      title: 'No Classes Found',
                      message:
                          'No timetable entries for ${DateFormat('EEE d MMM').format(_selectedDate)}.\n'
                          'Tap the date at the top-left to choose a different day.',
                      icon: Icons.event_busy_rounded,
                    );
                  }

                  return students.when(
                    loading: () => const LoadingWidget(),
                    error:
                        (e, _) => EmptyState(
                          title: 'Error',
                          message: e.toString(),
                          icon: Icons.error_outline_rounded,
                        ),
                    data: (studentList) {
                      if (studentList.isEmpty) {
                        return EmptyState(
                          title: 'No Students',
                          message: 'No students found in $_resolvedClassName.',
                          icon: Icons.people_outline_rounded,
                        );
                      }

                      for (final s in studentList) {
                        _attendanceMap.putIfAbsent(
                          s.id,
                          () => AttendanceStatus.present,
                        );
                      }

                      return Column(
                        children: [
                          // ── Past-date banner ───────────────────────────
                          if (_isPastDate)
                            _PastDateBanner(
                              dateLabel: DateFormat(
                                'EEE d MMM yyyy',
                              ).format(_selectedDate),
                              isDark: isDark,
                            ),

                          // ── Session context banner ─────────────────────
                          _slot == null
                              ? _NoSessionBanner(isDark: isDark)
                              : _SessionBanner(
                                slot: _slot!,
                                isDark: isDark,
                                teacherName: user.name,
                                isPast: _isPastDate,
                              ),

                          // ── Stats bar ──────────────────────────────────
                          _StatsBar(
                            attendanceMap: _attendanceMap,
                            total: studentList.length,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 4),

                          // ── Student list ───────────────────────────────
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              itemCount: studentList.length,
                              itemBuilder: (context, index) {
                                final student = studentList[index];
                                final status =
                                    _attendanceMap[student.id] ??
                                    AttendanceStatus.present;
                                final isSaving =
                                    _savingMap[student.id] ?? false;

                                return _StudentCard(
                                  student: student,
                                  status: status,
                                  isDark: isDark,
                                  isSaving: isSaving,
                                  isSubmitted: _isSubmitted,
                                  onStatusChanged: (newStatus) async {
                                    setState(
                                      () =>
                                          _attendanceMap[student.id] =
                                              newStatus,
                                    );
                                    await _saveStudentAttendance(
                                      student,
                                      newStatus,
                                      _slot,
                                      user.name,
                                      user.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          // ── Submit button ──────────────────────────────
                          if (!_isSubmitted)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: AppButton(
                                label:
                                    _isPastDate
                                        ? 'Save Past Attendance'
                                        : 'Mark as Complete',
                                onPressed:
                                    () => setState(() => _isSubmitted = true),
                                width: double.infinity,
                                icon: Icons.check_circle_rounded,
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.success.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isPastDate
                                          ? 'Past attendance saved ✅'
                                          : 'Attendance saved ✅',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
    );
  }

  TimetableModel? get _slot => _resolvedSlot;
}

// ─────────────────────────────────────────
//  PAST DATE BANNER
// ─────────────────────────────────────────
class _PastDateBanner extends StatelessWidget {
  final String dateLabel;
  final bool isDark;
  const _PastDateBanner({required this.dateLabel, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_edu_rounded,
            color: AppColors.warning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Editing past attendance for $dateLabel',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SESSION BANNER
// ─────────────────────────────────────────
class _SessionBanner extends StatelessWidget {
  final TimetableModel slot;
  final bool isDark;
  final String teacherName;
  final bool isPast;

  const _SessionBanner({
    required this.slot,
    required this.isDark,
    required this.teacherName,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isPast ? AppColors.warning : AppColors.teacherColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPast ? 'Session Context (from timetable)' : 'Current Session',
                style: AppTypography.labelLarge.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              if (!isPast)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Subject',
                  value: slot.subject,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DItem(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: '${slot.startTime} – ${slot.endTime}',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DItem(
                  icon: Icons.meeting_room_rounded,
                  label: 'Room',
                  value: slot.roomName.isNotEmpty ? slot.roomName : '—',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DItem(
                  icon: Icons.person_rounded,
                  label: 'Teacher',
                  value: teacherName,
                  color: AppColors.teacherColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoSessionBanner extends StatelessWidget {
  final bool isDark;
  const _NoSessionBanner({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No active timetable slot — records will save without session context.',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _DItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _DItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(color: color),
                ),
                Text(
                  value,
                  style: AppTypography.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  STATS BAR
// ─────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final Map<String, AttendanceStatus> attendanceMap;
  final int total;
  final bool isDark;
  const _StatsBar({
    required this.attendanceMap,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final present =
        attendanceMap.values.where((s) => s == AttendanceStatus.present).length;
    final absent =
        attendanceMap.values.where((s) => s == AttendanceStatus.absent).length;
    final late =
        attendanceMap.values.where((s) => s == AttendanceStatus.late).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            _Pill('Present', present, AppColors.present),
            const SizedBox(width: 8),
            _Pill('Late', late, AppColors.late),
            const SizedBox(width: 8),
            _Pill('Absent', absent, AppColors.absent),
            const Spacer(),
            Text('$total students', style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Pill(this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  STUDENT CARD
// ─────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final AttendanceStatus status;
  final bool isDark, isSaving, isSubmitted;
  final Function(AttendanceStatus) onStatusChanged;

  const _StudentCard({
    required this.student,
    required this.status,
    required this.isDark,
    required this.isSaving,
    required this.isSubmitted,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sc =
        status == AttendanceStatus.present
            ? AppColors.present
            : status == AttendanceStatus.late
            ? AppColors.late
            : AppColors.absent;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sc.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.teacherColor.withValues(alpha: 0.15),
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.teacherColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                Text(student.classDisplay, style: AppTypography.caption),
              ],
            ),
          ),
          if (isSaving)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.teacherColor,
              ),
            )
          else if (isSubmitted)
            AttendanceBadge(status: status)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusBtn(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.present,
                  isActive: status == AttendanceStatus.present,
                  tooltip: 'Present',
                  onTap: () => onStatusChanged(AttendanceStatus.present),
                ),
                const SizedBox(width: 4),
                _StatusBtn(
                  icon: Icons.watch_later_rounded,
                  color: AppColors.late,
                  isActive: status == AttendanceStatus.late,
                  tooltip: 'Late',
                  onTap: () => onStatusChanged(AttendanceStatus.late),
                ),
                const SizedBox(width: 4),
                _StatusBtn(
                  icon: Icons.cancel_rounded,
                  color: AppColors.absent,
                  isActive: status == AttendanceStatus.absent,
                  tooltip: 'Absent',
                  onTap: () => onStatusChanged(AttendanceStatus.absent),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;
  const _StatusBtn({
    required this.icon,
    required this.color,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? color : color.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(icon, size: 18, color: isActive ? Colors.white : color),
        ),
      ),
    );
  }
}
