import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HYBRID TRACKING DESIGN
//
//  students/{id}
//    └─ totalPresence: int          ← summary field, updated with FieldValue.increment
//    └─ presence_tracking/{date}    ← sub-collection, one doc per day present
//         studentId, classId, className, date, sessionName, recordedAt
//
//  attendance/{auto-id}             ← only absent / late records
//         all 5 context fields
//
//  ON MARK PRESENT:
//    1. batch.set(students/{id}/presence_tracking/{date})   ← detailed record
//    2. batch.update(students/{id}, {totalPresence: +1})    ← summary field
//    3. batch.delete any existing absence doc for this date
//
//  ON MARK ABSENT/LATE:
//    1. batch.delete(students/{id}/presence_tracking/{date})  ← remove tracking
//    2. batch.update(students/{id}, {totalPresence: -1})       ← decrement summary
//    3. batch.set attendance doc with all 5 fields
//
//  RECONCILE (_reconcilePresenceCount):
//    - Count sub-collection docs
//    - If count ≠ students/{id}.totalPresence → overwrite with correct value
//    - Called on screen open per student
// ─────────────────────────────────────────────────────────────────────────────

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
  final Map<String, AttendanceStatus> _attendanceMap = {};
  final Map<String, int> _presenceCountMap = {};
  final Map<String, bool> _savingMap = {};

  bool _isSubmitted = false;
  bool _isLoadingInit = true;
  bool _countsLoaded = false;

  late String _dateStr;
  late DateTime _dateTime;
  late bool _isPastDate;

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

  // ─────────────────────────────────────────
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

  // ─────────────────────────────────────────
  //  Timetable slot resolution.
  //  Today:     active window preferred → fallback to first slot.
  //  Past date: first slot for that day of week.
  // ─────────────────────────────────────────
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

  // ─────────────────────────────────────────
  //  Load today's attendance state for this class.
  //  Reads both attendance collection (absent/late)
  //  and presence_tracking sub-collections (present).
  // ─────────────────────────────────────────
  Future<void> _loadExistingAttendance() async {
    try {
      // Absent / late records
      final absSnap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('classId', isEqualTo: widget.classId)
              .where('date', isEqualTo: _dateStr)
              .get();

      for (final doc in absSnap.docs) {
        final d = doc.data();
        final sid = d['studentId']?.toString() ?? '';
        if (sid.isEmpty) continue;
        _attendanceMap[sid] = AttendanceStatus.values.firstWhere(
          (s) => s.name == (d['status']?.toString() ?? 'absent'),
          orElse: () => AttendanceStatus.absent,
        );
      }
    } catch (e) {
      debugPrint('_loadExistingAttendance: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  RECONCILE PRESENCE COUNT
  //
  //  Source of truth: students/{id}/presence_tracking sub-collection count.
  //  Fast read:       students/{id}.totalPresence summary field.
  //
  //  If they disagree → overwrite totalPresence with the correct count.
  //  Called once per student when the screen opens.
  // ─────────────────────────────────────────────────────────────────────────
  Future<int> _reconcilePresenceCount(String studentId, int cachedTotal) async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('students')
              .doc(studentId)
              .collection('presence_tracking')
              .get();

      final realCount = snap.docs.length;

      if (realCount != cachedTotal) {
        // Discrepancy found — overwrite the summary field
        await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .update({'totalPresence': realCount});
        debugPrint(
          'Reconciled $studentId: cached=$cachedTotal real=$realCount',
        );
      }

      return realCount;
    } catch (e) {
      debugPrint('_reconcilePresenceCount: $e');
      return cachedTotal;
    }
  }

  // ─────────────────────────────────────────
  //  Resolve className → "Level Name Grade" e.g. "3 IOT 1"
  // ─────────────────────────────────────────
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
  //  SAVE ATTENDANCE — hybrid tracking
  //
  //  PATH A — PRESENT
  //    1. batch.set  presence_tracking/{date}           ← detailed tracking
  //    2. batch.update students/{id} totalPresence +1   ← summary field
  //    3. batch.delete absence doc if any for this date
  //    → UI: _presenceCountMap[id]++ immediately
  //
  //  PATH B — ABSENT / LATE
  //    1. batch.delete presence_tracking/{date}         ← remove tracking
  //    2. batch.update students/{id} totalPresence -1   ← summary field
  //       (only if a tracking doc actually existed)
  //    3. batch.set/update absence doc in attendance collection
  //    → UI: _presenceCountMap[id]-- immediately
  //
  //  After commit: _reconcilePresenceCount verifies sub-collection count
  //  matches summary field and overwrites if needed.
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

    final resolvedClassName = await _resolveClassName(
      student.classId,
      student.className,
    );

    final slot = _resolvedSlot;
    final subject = slot?.subject ?? '';
    final roomId = slot?.roomId ?? '';
    final roomName = slot?.roomName ?? '';
    final scheduledStart = slot?.startTime ?? '';
    final scheduledEnd = slot?.endTime ?? '';
    final sessionName =
        slot != null ? '$subject ($scheduledStart – $scheduledEnd)' : '';

    // Refs
    final studentRef = db.collection('students').doc(student.id);
    final trackingRef = studentRef
        .collection('presence_tracking')
        .doc(_dateStr); // deterministic: one doc per student per day

    // Does a tracking doc already exist for today?
    DocumentSnapshot<Map<String, dynamic>>? existingTracking;
    try {
      final t = await trackingRef.get();
      if (t.exists) existingTracking = t;
    } catch (_) {}

    // Find existing absence doc
    QuerySnapshot<Map<String, dynamic>> absenceSnap;
    try {
      absenceSnap =
          await db
              .collection('attendance')
              .where('studentId', isEqualTo: student.id)
              .where('date', isEqualTo: _dateStr)
              .limit(1)
              .get();
    } catch (e) {
      debugPrint('Absence query: $e');
      if (mounted) setState(() => _savingMap[student.id] = false);
      return;
    }

    final existingAbsenceDoc =
        absenceSnap.docs.isNotEmpty ? absenceSnap.docs.first : null;

    final batch = db.batch();

    try {
      if (newStatus == AttendanceStatus.present) {
        // ══════════════════════════════════════════════════════════════════
        //  PATH A — PRESENT
        // ══════════════════════════════════════════════════════════════════

        // 1. Write tracking record (upsert — safe to re-tap)
        batch.set(trackingRef, {
          'studentId': student.id,
          'studentName': student.name,
          'classId': student.classId,
          'className': resolvedClassName,
          'date': _dateStr,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'subject': subject,
          'roomId': roomId,
          'roomName': roomName,
          'scheduledStartTime': scheduledStart,
          'scheduledEndTime': scheduledEnd,
          'sessionName': sessionName,
          'recordedAt': Timestamp.fromDate(now),
        });

        // 2. Increment summary field — only if no tracking doc existed before
        //    (prevents double-increment on re-tap of the same button)
        if (existingTracking == null) {
          batch.update(studentRef, {'totalPresence': FieldValue.increment(1)});

          // Optimistic UI update
          if (mounted) {
            setState(() {
              _presenceCountMap[student.id] =
                  (_presenceCountMap[student.id] ?? 0) + 1;
            });
          }
        }

        // 3. Delete any absence doc for this date (was absent/late before)
        if (existingAbsenceDoc != null) {
          batch.delete(existingAbsenceDoc.reference);
        }
      } else {
        // ══════════════════════════════════════════════════════════════════
        //  PATH B — ABSENT / LATE
        // ══════════════════════════════════════════════════════════════════

        // 1. Delete tracking record (removes from sub-collection count)
        batch.delete(trackingRef);

        // 2. Decrement summary — only if a tracking doc existed
        //    (prevents spurious decrements when going absent→late)
        if (existingTracking != null) {
          batch.update(studentRef, {'totalPresence': FieldValue.increment(-1)});

          // Optimistic UI update
          if (mounted) {
            setState(() {
              final curr = _presenceCountMap[student.id] ?? 0;
              _presenceCountMap[student.id] = (curr - 1).clamp(0, 9999);
            });
          }
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
          'status': newStatus.name,
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

        // 3. Write / update absence doc
        if (existingAbsenceDoc != null) {
          batch.update(existingAbsenceDoc.reference, absencePayload);
        } else {
          final newRef = db.collection('attendance').doc();
          batch.set(newRef, {
            ...absencePayload,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      // ── Post-commit reconcile (verifies sub-collection vs summary) ───
      final cached = _presenceCountMap[student.id] ?? 0;
      final verified = await _reconcilePresenceCount(student.id, cached);

      if (mounted) {
        setState(() => _presenceCountMap[student.id] = verified);
      }
    } catch (e) {
      debugPrint('Batch commit: $e');
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

  // Eager-load presence counts from student docs (totalPresence field)
  // then reconcile with sub-collection counts.
  void _loadPresenceCounts(List<StudentModel> students) {
    if (_countsLoaded) return;
    _countsLoaded = true;

    for (final s in students) {
      // Seed UI immediately from the cached summary field
      if (!_presenceCountMap.containsKey(s.id)) {
        _presenceCountMap[s.id] = s.totalPresence;
      }

      // Also mark present in _attendanceMap if they have a tracking doc today
      FirebaseFirestore.instance
          .collection('students')
          .doc(s.id)
          .collection('presence_tracking')
          .doc(_dateStr)
          .get()
          .then((doc) {
            if (doc.exists && mounted) {
              setState(() {
                _attendanceMap.putIfAbsent(
                  s.id,
                  () => AttendanceStatus.present,
                );
              });
            }
          });

      // Reconcile in background
      _reconcilePresenceCount(s.id, s.totalPresence).then((verified) {
        if (mounted) {
          setState(() => _presenceCountMap[s.id] = verified);
        }
      });
    }
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

                      for (final s in studentList) {
                        _attendanceMap.putIfAbsent(
                          s.id,
                          () => AttendanceStatus.absent,
                        );
                      }

                      // Seed counts from model + reconcile in background
                      _loadPresenceCounts(studentList);

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
                                    _presenceCountMap[student.id] ??
                                    student.totalPresence;

                                return _StudentCard(
                                  student: student,
                                  status: status,
                                  presenceCount: presenceCount,
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
                'No timetable slot — records will save without session context.',
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
    final presentNow =
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
            _StatPill('Present', presentNow, AppColors.present),
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
          // Avatar + presence badge
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
