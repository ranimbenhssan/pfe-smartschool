import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class TeacherNamecallScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;
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
  // ── Current UI status for each student ──────────────────────────────────
  final Map<String, AttendanceStatus> _attendanceMap = {};

  // ── Local presence count cache — updated immediately on tap ─────────────
  // Populated from Firestore on init, then kept in sync locally.
  // Key: studentId, Value: count of 'present' documents for this student.
  final Map<String, int> _presenceCountMap = {};

  // ── Saving spinner per student ───────────────────────────────────────────
  final Map<String, bool> _savingMap = {};

  bool _isSubmitted = false;
  bool _isLoadingInit = true;

  // ── Date ─────────────────────────────────────────────────────────────────
  late String _dateStr;
  late DateTime _dateTime;
  late bool _isPastDate;

  // ── Timetable slot fetched once in initState ─────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  //  Resolve timetable slot.
  //  Today:     prefer currently-active window; fallback to first slot.
  //  Past date: first slot for that day of week.
  // ─────────────────────────────────────────────────────────────────────────
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

      _resolvedSlot = TimetableModel.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('_resolveTimetableSlot: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Pre-fill attendance map AND presence count map from Firestore.
  //
  //  _attendanceMap  → current status for each student on _dateStr
  //  _presenceCountMap → total present docs ever for each student
  //                      (used for the stats display)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadExistingAttendance() async {
    try {
      // Today's attendance records for this class
      final todaySnap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('classId', isEqualTo: widget.classId)
              .where('date', isEqualTo: _dateStr)
              .get();

      for (final doc in todaySnap.docs) {
        final d = doc.data();
        final sid = d['studentId']?.toString() ?? '';
        if (sid.isEmpty) continue;
        _attendanceMap[sid] = AttendanceStatus.values.firstWhere(
          (s) => s.name == (d['status']?.toString() ?? 'absent'),
          orElse: () => AttendanceStatus.absent,
        );
      }

      // Presence counts — query all present docs for each student in this class
      final presentSnap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('classId', isEqualTo: widget.classId)
              .where('status', isEqualTo: 'present')
              .get();

      // Group by studentId
      final countMap = <String, int>{};
      for (final doc in presentSnap.docs) {
        final sid = doc.data()['studentId']?.toString() ?? '';
        if (sid.isEmpty) continue;
        countMap[sid] = (countMap[sid] ?? 0) + 1;
      }

      if (mounted) _presenceCountMap.addAll(countMap);
    } catch (e) {
      debugPrint('_loadExistingAttendance: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CALCULATE PRESENCE COUNT (dynamic query)
  //
  //  Called after each Firestore write to re-sync the local count from the
  //  source of truth.  Returns the total number of 'present' documents for
  //  this student across all dates.
  // ─────────────────────────────────────────────────────────────────────────
  Future<int> _calculatePresenceCount(String studentId) async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('studentId', isEqualTo: studentId)
              .where('status', isEqualTo: 'present')
              .count()
              .get();
      return snap.count ?? 0;
    } catch (_) {
      // count() requires Firestore index; fallback to get() if not available
      try {
        final snap =
            await FirebaseFirestore.instance
                .collection('attendance')
                .where('studentId', isEqualTo: studentId)
                .where('status', isEqualTo: 'present')
                .get();
        return snap.docs.length;
      } catch (e) {
        debugPrint('_calculatePresenceCount fallback error: $e');
        return _presenceCountMap[studentId] ?? 0;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Resolve className → "Level Name Grade" e.g. "3 IOT 1"
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
  //  SAVE ATTENDANCE — document-based presence tracking
  //
  //  Every status is stored as a Firestore document (present included).
  //  This allows:
  //    • Counting present records via query  (_calculatePresenceCount)
  //    • Deleting the specific present doc when toggled to absent/late
  //    • Deleting the specific absence doc when toggled back to present
  //
  //  TRANSITION TABLE
  //  ┌──────────────────────┬──────────────────────────────────────────────┐
  //  │ new status           │ Firestore action                             │
  //  ├──────────────────────┼──────────────────────────────────────────────┤
  //  │ present              │ create present doc (or update existing)      │
  //  │ absent / late        │ delete present doc if exists for this date   │
  //  │                      │ create absence doc with all 5 context fields │
  //  └──────────────────────┴──────────────────────────────────────────────┘
  //
  //  After commit: _calculatePresenceCount() re-syncs the local cache and
  //  setState() updates the UI count immediately.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveStudentAttendance(
    StudentModel student,
    AttendanceStatus newStatus,
    String teacherName,
    String teacherId,
  ) async {
    setState(() => _savingMap[student.id] = true);

    final db = FirebaseFirestore.instance;
    final now = DateTime.now();

    // Resolve "3 IOT 1" from class doc
    final resolvedClassName = await _resolveClassName(
      student.classId,
      student.className,
    );

    // Session context
    final slot = _resolvedSlot;
    final subject = slot?.subject ?? '';
    final roomId = slot?.roomId ?? '';
    final roomName = slot?.roomName ?? '';
    final scheduledStart = slot?.startTime ?? '';
    final scheduledEnd = slot?.endTime ?? '';
    final sessionName =
        slot != null ? '$subject ($scheduledStart – $scheduledEnd)' : '';

    // Find any existing attendance doc for this student + date
    QuerySnapshot<Map<String, dynamic>> existingSnap;
    try {
      existingSnap =
          await db
              .collection('attendance')
              .where('studentId', isEqualTo: student.id)
              .where('date', isEqualTo: _dateStr)
              .limit(1)
              .get();
    } catch (e) {
      debugPrint('Query error: $e');
      if (mounted) setState(() => _savingMap[student.id] = false);
      return;
    }

    final existingDoc =
        existingSnap.docs.isNotEmpty ? existingSnap.docs.first : null;

    try {
      if (newStatus == AttendanceStatus.present) {
        // ══════════════════════════════════════════════════════════════════
        //  PATH A — PRESENT
        //  Store a present record so it can be queried and deleted later.
        //  No counter field is touched — count is derived from docs.
        // ══════════════════════════════════════════════════════════════════
        final presentPayload = <String, dynamic>{
          'studentId': student.id,
          'studentName': student.name,
          'classId': student.classId,
          'className': resolvedClassName,
          'date': _dateStr,
          'status': 'present',
          'entryTime': Timestamp.fromDate(now),
          'exitTime': null,
          // Minimal context — present records don't need full 5-field detail
          'teacherId': teacherId,
          'teacherName': teacherName,
          'subject': subject,
          'roomId': roomId,
          'roomName': roomName,
          'scheduledStartTime': scheduledStart,
          'scheduledEndTime': scheduledEnd,
          'sessionName': sessionName,
          'recordedAt': Timestamp.fromDate(now),
          'note': '',
        };

        if (existingDoc != null) {
          await existingDoc.reference.update({
            'status': 'present',
            'recordedAt': Timestamp.fromDate(now),
            'entryTime': Timestamp.fromDate(now),
          });
        } else {
          await db.collection('attendance').add({
            ...presentPayload,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // ══════════════════════════════════════════════════════════════════
        //  PATH B — ABSENT / LATE
        //  1. Delete the present doc for this date if it exists.
        //     This is what keeps the count accurate — the doc is physically
        //     removed, not just status-updated.
        //  2. Write a new absence doc with all 5 context fields.
        // ══════════════════════════════════════════════════════════════════

        // Step 1: delete present doc
        if (existingDoc != null && existingDoc.data()['status'] == 'present') {
          await existingDoc.reference.delete();
        }

        final entryTimeForPast = DateTime(
          _dateTime.year,
          _dateTime.month,
          _dateTime.day,
          8,
          0,
        );

        final absencePayload = <String, dynamic>{
          'studentId': student.id,
          'studentName': student.name,
          'classId': student.classId,
          'className': resolvedClassName, // "3 IOT 1"
          'date': _dateStr,
          'status': newStatus.name, // 'absent' | 'late'
          // Field 1 — Subject
          'subject': subject,
          // Field 2 — Teacher
          'teacherId': teacherId,
          'teacherName': teacherName,
          // Field 3 — Room
          'roomId': roomId,
          'roomName': roomName,
          // Field 4 — Scheduled Class Time
          'scheduledStartTime': scheduledStart,
          'scheduledEndTime': scheduledEnd,
          'sessionName': sessionName,
          // Field 5 — Time of Absence
          'recordedAt': Timestamp.fromDate(now),
          'entryTime':
              newStatus == AttendanceStatus.late
                  ? Timestamp.fromDate(_isPastDate ? entryTimeForPast : now)
                  : null,
          'exitTime': null,
          'note': _isPastDate ? 'Manually entered for $_dateStr' : '',
        };

        // Step 2: write absence doc
        if (existingDoc != null && existingDoc.data()['status'] != 'present') {
          // Already an absence doc — just update it
          await existingDoc.reference.update(absencePayload);
        } else {
          // Create new absence doc (present doc was deleted above, or no doc existed)
          await db.collection('attendance').add({
            ...absencePayload,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // ── Re-sync presence count from source of truth ───────────────────
      // This is the dynamic count: query all 'present' docs for this student.
      final freshCount = await _calculatePresenceCount(student.id);

      if (mounted) {
        setState(() {
          _presenceCountMap[student.id] = freshCount;
        });
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
    final students = ref.watch(studentsByClassIdProvider(widget.classId));

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
                              'No students found in this class.\nMake sure students are assigned.',
                          icon: Icons.people_outline_rounded,
                        );
                      }

                      // Seed defaults for students not yet recorded
                      for (final s in studentList) {
                        _attendanceMap.putIfAbsent(
                          s.id,
                          () => AttendanceStatus.absent,
                        );
                        _presenceCountMap.putIfAbsent(s.id, () => 0);
                      }

                      return Column(
                        children: [
                          if (_isPastDate)
                            _PastDateBanner(
                              dateLabel: dateLabel,
                              isDark: isDark,
                            ),

                          _SlotBanner(
                            slot: _resolvedSlot,
                            isDark: isDark,
                            teacherName: user.name,
                            isPast: _isPastDate,
                          ),

                          // Stats bar reads from live _attendanceMap
                          _StatsBar(
                            attendanceMap: _attendanceMap,
                            presenceCountMap: _presenceCountMap,
                            total: studentList.length,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 4),

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
                                    AttendanceStatus.absent;
                                final isSaving =
                                    _savingMap[student.id] ?? false;
                                final presenceCount =
                                    _presenceCountMap[student.id] ?? 0;

                                return _StudentCard(
                                  student: student,
                                  status: status,
                                  presenceCount: presenceCount,
                                  isDark: isDark,
                                  isSaving: isSaving,
                                  isSubmitted: _isSubmitted,
                                  onStatusChanged: (newStatus) async {
                                    // Update UI immediately
                                    setState(
                                      () =>
                                          _attendanceMap[student.id] =
                                              newStatus,
                                    );

                                    await _saveStudentAttendance(
                                      student,
                                      newStatus,
                                      user.name,
                                      user.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child:
                                _isSubmitted
                                    ? Container(
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                            style: AppTypography.labelMedium
                                                .copyWith(
                                                  color: AppColors.success,
                                                ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : AppButton(
                                      label:
                                          _isPastDate
                                              ? 'Save Past Attendance'
                                              : 'Mark as Complete',
                                      onPressed:
                                          () => setState(
                                            () => _isSubmitted = true,
                                          ),
                                      width: double.infinity,
                                      icon: Icons.check_circle_rounded,
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
//  SLOT BANNER
// ─────────────────────────────────────────
class _SlotBanner extends StatelessWidget {
  final TimetableModel? slot;
  final bool isDark;
  final String teacherName;
  final bool isPast;

  const _SlotBanner({
    required this.slot,
    required this.isDark,
    required this.teacherName,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    if (slot == null) {
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
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No timetable slot found — records will save without session context.',
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
      );
    }

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
                child: _DetailItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Subject',
                  value: slot!.subject.isNotEmpty ? slot!.subject : '—',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailItem(
                  icon: Icons.person_rounded,
                  label: 'Teacher',
                  value:
                      teacherName.isNotEmpty ? teacherName : slot!.teacherName,
                  color: AppColors.teacherColor,
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
                  value: slot!.roomName.isNotEmpty ? slot!.roomName : '—',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailItem(
                  icon: Icons.access_time_rounded,
                  label: 'Scheduled',
                  value: '${slot!.startTime} – ${slot!.endTime}',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          _DetailItem(
            icon: Icons.access_time_filled_rounded,
            label: 'Time of Absence',
            value: DateFormat('HH:mm  –  dd/MM/yyyy').format(DateTime.now()),
            color: AppColors.warning,
            fullWidth: true,
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
  final bool fullWidth;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.labelSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: tile) : tile;
  }
}

// ─────────────────────────────────────────
//  STATS BAR
// ─────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final Map<String, AttendanceStatus> attendanceMap;
  final Map<String, int> presenceCountMap;
  final int total;
  final bool isDark;

  const _StatsBar({
    required this.attendanceMap,
    required this.presenceCountMap,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Present = students marked present RIGHT NOW in this session
    final presentNow =
        attendanceMap.values.where((s) => s == AttendanceStatus.present).length;
    final absent =
        attendanceMap.values.where((s) => s == AttendanceStatus.absent).length;
    final late =
        attendanceMap.values.where((s) => s == AttendanceStatus.late).length;

    // Total presence across all sessions (dynamic query result)
    final totalPresence = presenceCountMap.values.fold<int>(
      0,
      (sum, c) => sum + c,
    );

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
            _StatPill('Present', presentNow, AppColors.present),
            const SizedBox(width: 8),
            _StatPill('Late', late, AppColors.late),
            const SizedBox(width: 8),
            _StatPill('Absent', absent, AppColors.absent),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$total students', style: AppTypography.caption),
                Text(
                  '$totalPresence total presences',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.present,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
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
  final int presenceCount;
  final bool isDark;
  final bool isSaving;
  final bool isSubmitted;
  final Function(AttendanceStatus) onStatusChanged;

  const _StudentCard({
    required this.student,
    required this.status,
    required this.presenceCount,
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
          // ── Avatar with presence count badge ──
          Stack(
            clipBehavior: Clip.none,
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
              // Presence count badge
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.present,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$presenceCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // ── Name + class ──
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

          // ── Saving / submitted / buttons ──
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
