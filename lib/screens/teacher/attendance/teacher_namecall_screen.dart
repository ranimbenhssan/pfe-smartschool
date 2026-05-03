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

  /// Target date in 'yyyy-MM-dd' format. Empty = today.
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
  bool _isLoadingExisting = true;

  // ─── Resolved date values ───
  late final String _dateStr;
  late final DateTime _dateTime;
  late final bool _isPastDate;
  late final String _dayName; // "Monday" … "Friday"

  // ─── Cached timetable slot for _dateStr's day ───
  // Fetched once in initState; used for ALL student saves on this screen.
  TimetableModel? _resolvedSlot;

  static const _days = [
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
      _dateStr = widget.targetDate;
      try {
        _dateTime = DateTime.parse(widget.targetDate);
      } catch (_) {
        _dateTime = now; // fallback
      }
    } else {
      _dateStr = today;
      _dateTime = now;
    }

    _isPastDate = _dateStr != today;
    _dayName = _days[_dateTime.weekday]; // weekday is 1-7

    // ─── Load existing attendance + timetable slot in parallel ───
    _initData();
  }

  Future<void> _initData() async {
    await Future.wait([_loadExistingAttendance(), _resolveTimetableSlot()]);
    if (mounted) setState(() => _isLoadingExisting = false);
  }

  Future<void> _updatePresentCount(int delta) async {
    if (delta == 0) return;

    final docRef = FirebaseFirestore.instance
        .collection('attendance_counts')
        .doc('${_dateStr}_${widget.classId}');

    await docRef.set({
      'date': _dateStr,
      'classId': widget.classId,
      'className': widget.className,
      'presentCount': FieldValue.increment(delta),
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────
  //  Resolve timetable slot for the target date's day of week.
  //
  //  For TODAY: if there is an active live slot (within startTime–endTime)
  //  we prefer that. Otherwise fall back to the first slot for the day.
  //  For PAST DATES: always use the first slot for that day — no time filter.
  // ─────────────────────────────────────────
  Future<void> _resolveTimetableSlot() async {
    if (widget.classId.isEmpty) return;
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('timetable')
              .where('classId', isEqualTo: widget.classId)
              .where('dayOfWeek', isEqualTo: _dayName)
              .get();

      if (snap.docs.isEmpty) return;

      if (!_isPastDate) {
        // ─── Today: try to find the currently-active slot ───
        final now = DateTime.now();
        final currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        for (final doc in snap.docs) {
          final d = doc.data();
          final start = d['startTime']?.toString() ?? '';
          final end = d['endTime']?.toString() ?? '';
          if (start.isEmpty || end.isEmpty) continue;
          if (currentTime.compareTo(start) >= 0 &&
              currentTime.compareTo(end) <= 0) {
            _resolvedSlot = TimetableModel.fromFirestore(doc);
            return;
          }
        }
      }

      // ─── Past date OR no active slot today → use the first slot for the day ───
      _resolvedSlot = TimetableModel.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('_resolveTimetableSlot error: $e');
    }
  }

  // ─── Pre-fill status map from existing Firestore records ───
  Future<void> _loadExistingAttendance() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('classId', isEqualTo: widget.classId)
              .where('date', isEqualTo: _dateStr)
              .get();

      final preloaded = <String, AttendanceStatus>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final sid = data['studentId']?.toString() ?? '';
        final statusStr = data['status']?.toString() ?? 'absent';
        if (sid.isEmpty) continue;
        preloaded[sid] = AttendanceStatus.values.firstWhere(
          (s) => s.name == statusStr,
          orElse: () => AttendanceStatus.absent,
        );
      }
      if (mounted) _attendanceMap.addAll(preloaded);
    } catch (e) {
      debugPrint('_loadExistingAttendance error: $e');
    }
  }

  // ─────────────────────────────────────────
  //  Save / update a record — ALL 5 FIELDS guaranteed
  // ─────────────────────────────────────────
  Future<void> _saveStudentAttendance(
    StudentModel student,
    AttendanceStatus status,
    AttendanceStatus previousStatus,
    String teacherName,
    String teacherId,
  ) async {
    setState(() => _savingMap[student.id] = true);

    final presentDelta =
        previousStatus == AttendanceStatus.present &&
                status != AttendanceStatus.present
            ? -1
            : previousStatus != AttendanceStatus.present &&
                status == AttendanceStatus.present
            ? 1
            : 0;

    if (status == AttendanceStatus.present) {
      try {
        await _updatePresentCount(presentDelta);
        final existing =
            await FirebaseFirestore.instance
                .collection('attendance')
                .where('studentId', isEqualTo: student.id)
                .where('date', isEqualTo: _dateStr)
                .limit(1)
                .get();
        if (existing.docs.isNotEmpty) {
          await existing.docs.first.reference.delete();
        }
      } catch (e) {
        debugPrint('Error cleaning present attendance: $e');
      }

      if (mounted) setState(() => _savingMap[student.id] = false);
      return;
    }

    if (presentDelta != 0) {
      try {
        await _updatePresentCount(presentDelta);
      } catch (e) {
        debugPrint('Error updating present count: $e');
      }
    }

    final now = DateTime.now();
    final slot = _resolvedSlot;

    // ─── 1. Subject ───
    final subject = slot?.subject ?? '';

    // ─── 2. Teacher — passed in from currentUser ───
    // (already in parameters)

    // ─── 3. Room ───
    final roomId = slot?.roomId ?? '';
    final roomName = slot?.roomName ?? '';

    // ─── 4. Scheduled Class Time ───
    final scheduledStartTime = slot?.startTime ?? '';
    final scheduledEndTime = slot?.endTime ?? '';

    // ─── 5. Time of Absence = recordedAt (now) ───
    // entryTime for past records = 08:00 on the target date
    final entryTimeForPast = DateTime(
      _dateTime.year,
      _dateTime.month,
      _dateTime.day,
      8,
      0,
    );
    final effectiveEntryTime = _isPastDate ? entryTimeForPast : now;

    final sessionName =
        slot != null
            ? '${slot.subject} ($scheduledStartTime – $scheduledEndTime)'
            : '';

    try {
      final existing =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('studentId', isEqualTo: student.id)
              .where('date', isEqualTo: _dateStr)
              .limit(1)
              .get();

      // ─── Payload with ALL 5 fields ───
      final fullPayload = {
        'status': status.name,
        'teacherId': teacherId,
        'teacherName': teacherName, // Teacher
        'subject': subject, // Subject
        'roomId': roomId,
        'roomName': roomName, // Room
        'sessionName': sessionName,
        'scheduledStartTime': scheduledStartTime, // Scheduled Start
        'scheduledEndTime': scheduledEndTime, // Scheduled End
        'recordedAt': Timestamp.fromDate(now), // Time of Absence
      };

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update(fullPayload);
      } else {
        await FirebaseFirestore.instance.collection('attendance').add({
          'studentId': student.id,
          'studentName': student.name,
          'classId': student.classId,
          'className': student.className,
          'date': _dateStr,
          'entryTime':
              (status == AttendanceStatus.present ||
                      status == AttendanceStatus.late)
                  ? Timestamp.fromDate(effectiveEntryTime)
                  : null,
          'exitTime': null,
          'note': _isPastDate ? 'Manually entered for $_dateStr' : '',
          'createdAt': FieldValue.serverTimestamp(),
          ...fullPayload,
        });
      }
    } catch (e) {
      debugPrint('Error saving attendance: $e');
    }

    if (mounted) setState(() => _savingMap[student.id] = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final students = ref.watch(studentsByClassIdProvider(widget.classId));

    final dateLabel =
        _isPastDate
            ? DateFormat('EEEE, d MMM yyyy').format(_dateTime)
            : 'Today';

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
          _isLoadingExisting
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
                          message: 'No students found in this class.',
                          icon: Icons.people_outline_rounded,
                        );
                      }

                      for (final s in studentList) {
                        _attendanceMap.putIfAbsent(
                          s.id,
                          () => AttendanceStatus.absent,
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
                          _SlotBanner(
                            slot: _resolvedSlot,
                            isDark: isDark,
                            teacherName: user.name,
                            isPast: _isPastDate,
                          ),

                          // ─── Stats ───
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
                                    AttendanceStatus.absent;
                                final isSaving =
                                    _savingMap[student.id] ?? false;

                                return _StudentCard(
                                  student: student,
                                  status: status,
                                  isDark: isDark,
                                  isSaving: isSaving,
                                  isSubmitted: _isSubmitted,
                                  onStatusChanged: (newStatus) async {
                                    final previousStatus =
                                        _attendanceMap[student.id] ??
                                        AttendanceStatus.absent;
                                    setState(
                                      () =>
                                          _attendanceMap[student.id] =
                                              newStatus,
                                    );
                                    await _saveStudentAttendance(
                                      student,
                                      newStatus,
                                      previousStatus,
                                      user.name,
                                      user.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          // ─── Submit / Done ───
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child:
                                _isSubmitted
                                    ? _SubmitDone(isPast: _isPastDate)
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
//  SLOT BANNER — shows all 5 fields from resolved slot
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
                'No timetable slot found. Attendance will save without session context.',
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isPast ? AppColors.warning : AppColors.teacherColor).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isPast ? AppColors.warning : AppColors.teacherColor)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header row ───
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

          // ─── 2×2 grid: Subject / Teacher / Room / Scheduled Time ───
          Row(
            children: [
              Expanded(
                child: _DetailTile(
                  icon: Icons.menu_book_rounded,
                  label: 'Subject',
                  value: slot!.subject.isNotEmpty ? slot!.subject : '—',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailTile(
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
                child: _DetailTile(
                  icon: Icons.meeting_room_rounded,
                  label: 'Room',
                  value: slot!.roomName.isNotEmpty ? slot!.roomName : '—',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailTile(
                  icon: Icons.schedule_rounded,
                  label: 'Scheduled Time',
                  value: '${slot!.startTime} – ${slot!.endTime}',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ─── Time of Absence (5th field) — full width ───
          _DetailTile(
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
//  DETAIL TILE
// ─────────────────────────────────────────
class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  const _DetailTile({
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
//  SUBMIT DONE
// ─────────────────────────────────────────
class _SubmitDone extends StatelessWidget {
  final bool isPast;
  const _SubmitDone({required this.isPast});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: 8),
          Text(
            isPast ? 'Past attendance saved ✅' : 'Attendance saved ✅',
            style: AppTypography.labelMedium.copyWith(color: AppColors.success),
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
                Text(student.className, style: AppTypography.caption),
              ],
            ),
          ),
          if (isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (!isSubmitted)
            Row(
              children: [
                _Btn(
                  'P',
                  AppColors.present,
                  status == AttendanceStatus.present,
                  () => onStatusChanged(AttendanceStatus.present),
                ),
                const SizedBox(width: 6),
                _Btn(
                  'L',
                  AppColors.late,
                  status == AttendanceStatus.late,
                  () => onStatusChanged(AttendanceStatus.late),
                ),
                const SizedBox(width: 6),
                _Btn(
                  'A',
                  AppColors.absent,
                  status == AttendanceStatus.absent,
                  () => onStatusChanged(AttendanceStatus.absent),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.name.toUpperCase(),
                style: AppTypography.caption.copyWith(color: sc),
              ),
            ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;
  const _Btn(this.label, this.color, this.isActive, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: isActive ? Colors.white : color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
