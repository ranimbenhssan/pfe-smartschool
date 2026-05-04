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

  /// Target date 'yyyy-MM-dd'. Empty = today.
  final String targetDate;

  const TeacherNamecallScreen({
    super.key,
    required this.classId,
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

  // ─── Date resolution ──────────────────────────────────────────────────────
  late String _dateStr;
  late DateTime _dateTime;
  late bool _isPastDate;

  // ─── Resolved timetable slot (works for any date) ────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = _fmt(now);

    if (widget.targetDate.isNotEmpty) {
      _dateStr = widget.targetDate;
      try {
        _dateTime = DateTime.parse(widget.targetDate);
      } catch (_) {
        _dateTime = now;
      }
    } else {
      _dateStr = today;
      _dateTime = now;
    }

    _isPastDate = _dateStr != today;
    _initData();
  }

  Future<void> _initData() async {
    await Future.wait([_resolveTimetableSlot(), _loadExistingAttendance()]);
    if (mounted) setState(() => _isLoadingInit = false);
  }

  // ─── Resolve timetable slot ───────────────────────────────────────────────
  // Today  → prefer active window, fallback to first slot.
  // Past   → first slot for that day of week (no time filter).
  Future<void> _resolveTimetableSlot() async {
    if (widget.classId.isEmpty) return;
    try {
      final dayName = _weekdays[_dateTime.weekday];
      final snap =
          await FirebaseFirestore.instance
              .collection('timetable')
              .where('classId', isEqualTo: widget.classId)
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

      // Fallback: first slot of the day
      _resolvedSlot = TimetableModel.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('_resolveTimetableSlot: $e');
    }
  }

  // ─── Pre-fill attendance map from existing records ────────────────────────
  Future<void> _loadExistingAttendance() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('classId', isEqualTo: widget.classId)
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

  // ─── Resolve className → "Level Name Grade" e.g. "3 IOT 1" ───────────────
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
  //
  //  Uses `existing` as the query variable (matches live repo).
  //  Captures `previousStatus` from `existing` BEFORE any write.
  //  Writes all 5 context fields on every save.
  //  Fires AttendanceNotificationService after a successful write (non-fatal).
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

    // Resolve "3 IOT 1" from class doc at save time
    final resolvedClassName = await _resolveClassName(
      student.classId,
      student.className,
    );

    // Session context — all 5 fields
    final subject = slot?.subject ?? '';
    final sessionName =
        slot != null
            ? '${slot.subject} Session (${slot.startTime} – ${slot.endTime})'
            : '';
    final roomId = slot?.roomId ?? '';
    final roomName = slot?.roomName ?? '';
    final scheduledStart = slot?.startTime ?? '';
    final scheduledEnd = slot?.endTime ?? '';

    final entryTimeForPast = DateTime(
      _dateTime.year,
      _dateTime.month,
      _dateTime.day,
      8,
      0,
    );

    try {
      // ── Query existing record — variable name `existing` ──────────────
      final existing =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('studentId', isEqualTo: student.id)
              .where('date', isEqualTo: _dateStr)
              .limit(1)
              .get();

      // ── Capture previous status BEFORE writing ────────────────────────
      final previousStatus =
          existing.docs.isNotEmpty
              ? existing.docs.first.data()['status']?.toString() ?? ''
              : '';

      final data = {
        'studentId': student.id,
        'studentName': student.name,
        'classId': student.classId,
        'className': resolvedClassName, // "3 IOT 1"
        'date': _dateStr,
        'status': status.name,
        'entryTime':
            status == AttendanceStatus.present ||
                    status == AttendanceStatus.late
                ? Timestamp.fromDate(_isPastDate ? entryTimeForPast : now)
                : null,
        'exitTime': null,
        // ── Field 1: Subject ──────────────────────────────
        'subject': subject,
        // ── Field 2: Teacher ──────────────────────────────
        'teacherId': teacherId,
        'teacherName': teacherName,
        // ── Field 3: Room ─────────────────────────────────
        'roomId': roomId,
        'roomName': roomName,
        // ── Field 4: Scheduled Time ───────────────────────
        'scheduledStartTime': scheduledStart,
        'scheduledEndTime': scheduledEnd,
        'sessionName': sessionName,
        // ── Field 5: Time of Absence ──────────────────────
        'recordedAt': Timestamp.fromDate(now),
        'note': _isPastDate ? 'Manually entered for $_dateStr' : '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
        // ── Update existing record ──────────────────────────────────────
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
        // ── Create new record ───────────────────────────────────────────
        await FirebaseFirestore.instance.collection('attendance').add(data);
      }

      // ── In-app notification (non-fatal — own try/catch) ───────────────
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
      } catch (notifErr) {
        debugPrint('Notification (non-fatal): $notifErr');
      }
    } catch (e) {
      debugPrint('Error saving attendance: $e');
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
    final students = ref.watch(studentsByClassIdProvider(widget.classId));
    final currentSlot = ref.watch(currentTimetableSlotProvider(widget.classId));

    final dateLabel =
        _isPastDate ? DateFormat('EEE d MMM yyyy').format(_dateTime) : 'Today';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          widget.className.isNotEmpty
              ? 'Name Call — ${widget.className}'
              : 'Name Call',
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          if (_isPastDate)
            Container(
              margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: AppColors.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
                        return const EmptyState(
                          title: 'No Students',
                          message:
                              'No students found in this class.\nMake sure students are assigned to this class.',
                          icon: Icons.people_outline_rounded,
                        );
                      }

                      // Default all students to present on first load
                      for (final s in studentList) {
                        _attendanceMap.putIfAbsent(
                          s.id,
                          () => AttendanceStatus.present,
                        );
                      }

                      return Column(
                        children: [
                          // ─── Past-date banner ───
                          if (_isPastDate)
                            _PastDateBanner(
                              dateLabel: dateLabel,
                              isDark: isDark,
                            ),

                          // ─── Session context banner ───
                          currentSlot.when(
                            loading: () => const SizedBox(height: 8),
                            error: (_, __) => const SizedBox.shrink(),
                            data:
                                (slot) =>
                                    slot == null
                                        ? _NoSessionBanner(isDark: isDark)
                                        : _SessionBanner(
                                          slot: slot,
                                          isDark: isDark,
                                          teacherName: user.name,
                                        ),
                          ),

                          // ─── Stats bar ───
                          _StatsBar(
                            attendanceMap: _attendanceMap,
                            total: studentList.length,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 4),

                          // ─── Student list ───
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
                                    // Use live slot if available, otherwise fall back
                                    // to the pre-resolved slot from initState
                                    await _saveStudentAttendance(
                                      student,
                                      newStatus,
                                      currentSlot.value ?? _resolvedSlot,
                                      user.name,
                                      user.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          // ─── Submit / Done button ───
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
                                          : 'Attendance saved — synced in real-time ✅',
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
//  SESSION BANNER — active session found
// ─────────────────────────────────────────
class _SessionBanner extends StatelessWidget {
  final TimetableModel slot;
  final bool isDark;
  final String teacherName;

  const _SessionBanner({
    required this.slot,
    required this.isDark,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teacherColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.teacherColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Session',
                style: AppTypography.labelLarge.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Subject',
                  value: slot.subject,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailItem(
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
                child: _DetailItem(
                  icon: Icons.meeting_room_rounded,
                  label: 'Room',
                  value:
                      slot.roomName.isNotEmpty ? slot.roomName : 'Not assigned',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailItem(
                  icon: Icons.person_rounded,
                  label: 'Teacher',
                  value: teacherName,
                  color: AppColors.teacherColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 12,
                  color: AppColors.info,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Records will include: ${slot.subject} · '
                    '${slot.roomName.isNotEmpty ? slot.roomName : "No room"} · '
                    '${DateFormat("HH:mm dd/MM/yyyy").format(DateTime.now())}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.info,
                    ),
                  ),
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
//  NO SESSION BANNER
// ─────────────────────────────────────────
class _NoSessionBanner extends StatelessWidget {
  final bool isDark;
  const _NoSessionBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active timetable slot',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  'Attendance will be saved without session context',
                  style: AppTypography.caption,
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
//  DETAIL ITEM
// ─────────────────────────────────────────
class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailItem({
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
          Icon(icon, size: 14, color: color),
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
            _StatPill('Present', present, AppColors.present),
            const SizedBox(width: 8),
            _StatPill('Late', late, AppColors.late),
            const SizedBox(width: 8),
            _StatPill('Absent', absent, AppColors.absent),
            const Spacer(),
            Text('$total students', style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatPill(this.label, this.count, this.color);

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
  final bool isDark;
  final bool isSaving;
  final bool isSubmitted;
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
    final statusColor =
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
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // ─── Avatar ───
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

          // ─── Name + class ───
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

          // ─── Saving / submitted / buttons ───
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

// ─────────────────────────────────────────
//  STATUS BUTTON
// ─────────────────────────────────────────
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
