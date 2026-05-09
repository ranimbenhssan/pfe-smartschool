import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../services/notification_service.dart';

class TeacherNamecallScreen extends ConsumerStatefulWidget {
  // Optional pre-selected séance (passed from timetable screen tap)
  final TimetableModel? preselectedSlot;

  const TeacherNamecallScreen({super.key, this.preselectedSlot});

  @override
  ConsumerState<TeacherNamecallScreen> createState() =>
      _TeacherNamecallScreenState();
}

class _TeacherNamecallScreenState extends ConsumerState<TeacherNamecallScreen> {
  DateTime _selectedDate = DateTime.now();
  TimetableModel? _selectedSlot;
  bool _slotPicked = false;

  final Map<String, AttendanceStatus> _attendanceMap = {};
  final Map<String, bool> _savingMap = {};

  // Students loaded for the selected slot (from all matching classes)
  List<StudentModel> _students = [];
  // Class IDs that have this teacher+subject+day séance
  List<String> _seanceClassIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedSlot != null) {
      _selectedSlot = widget.preselectedSlot;
      _slotPicked = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadStudentsForSlot(widget.preselectedSlot!),
      );
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  // ─────────────────────────────────────────────────────────────────────────
  //  LOAD STUDENTS FOR SLOT
  //
  //  For the selected séance (teacherId + subject + dayOfWeek):
  //  1. Find ALL timetable entries that match (may be multiple TP groups)
  //  2. Collect all classIds from those entries
  //  3. Load all students whose classId is in that list
  //  4. Load existing attendance for this teacher+subject+date
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadStudentsForSlot(TimetableModel slot) async {
    final teacherId = ref.read(currentUserProvider).value?.id ?? '';
    final weekType = ref.read(weekTypeForDateProvider(_selectedDate));

    // Step 1: Find all timetable entries matching this teacher+subject+day
    final snap =
        await FirebaseFirestore.instance
            .collection('timetable')
            .where('teacherId', isEqualTo: teacherId)
            .where('subject', isEqualTo: slot.subject)
            .where('dayOfWeek', isEqualTo: slot.dayOfWeek)
            .where('startTime', isEqualTo: slot.startTime)
            .where('endTime', isEqualTo: slot.endTime)
            .get();

    // Filter by week type
    final matchingEntries =
        snap.docs
            .map(TimetableModel.fromFirestore)
            .where(
              (t) =>
                  weekType.isEmpty ||
                  t.weekType.isEmpty ||
                  t.weekType == weekType,
            )
            .toList();

    final classIds = matchingEntries.map((t) => t.classId).toSet().toList();

    // Step 2: Load all students from those classes
    final allStudents = <StudentModel>[];
    for (final cid in classIds) {
      final sSnap =
          await FirebaseFirestore.instance
              .collection('students')
              .where('classId', isEqualTo: cid)
              .get();
      allStudents.addAll(sSnap.docs.map(StudentModel.fromFirestore));
    }

    // Deduplicate + sort
    final seen = <String>{};
    final students =
        allStudents.where((s) => seen.add(s.id)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    // Step 3: Load existing attendance
    final dateStr = _fmt(_selectedDate);
    final attSnap =
        await FirebaseFirestore.instance
            .collection('attendance')
            .where('date', isEqualTo: dateStr)
            .where('teacherId', isEqualTo: teacherId)
            .where('subject', isEqualTo: slot.subject)
            .get();

    final attMap = <String, AttendanceStatus>{};
    for (final doc in attSnap.docs) {
      final d = doc.data();
      final id = d['studentId']?.toString() ?? '';
      final s = d['status']?.toString() ?? 'present';
      if (id.isNotEmpty) {
        attMap[id] = AttendanceStatus.values.firstWhere(
          (v) => v.name == s,
          orElse: () => AttendanceStatus.present,
        );
      }
    }

    if (mounted) {
      setState(() {
        _seanceClassIds = classIds;
        _students = students;
        _attendanceMap
          ..clear()
          ..addAll(attMap);
        // Default unset students to present
        for (final s in students) {
          _attendanceMap.putIfAbsent(s.id, () => AttendanceStatus.present);
        }
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SAVE — scoped to teacherId + subject + date
  //  Sends in-app notification to student when:
  //  • Status is absent or late
  //  • Status changes back to present (cleared)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveAttendance(
    StudentModel student,
    AttendanceStatus status,
  ) async {
    if (_selectedSlot == null) return;
    final slot = _selectedSlot!;
    final teacherId = ref.read(currentUserProvider).value?.id ?? '';
    final teachers = ref.read(teachersProvider).value ?? [];
    final teacher = teachers.where((t) => t.userId == teacherId).firstOrNull;
    final teacherName = teacher?.name ?? '';
    final dateStr = _fmt(_selectedDate);

    setState(() => _savingMap[student.id] = true);
    try {
      final existing =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('studentId', isEqualTo: student.id)
              .where('date', isEqualTo: dateStr)
              .where('teacherId', isEqualTo: teacherId)
              .where('subject', isEqualTo: slot.subject)
              .limit(1)
              .get();

      final now = DateTime.now();
      final data = {
        'studentId': student.id,
        'studentName': student.name,
        'classId': student.classId,
        'className': student.className,
        'date': dateStr,
        'status': status.name,
        'entryTime':
            (status == AttendanceStatus.present ||
                    status == AttendanceStatus.late)
                ? Timestamp.fromDate(now)
                : null,
        'exitTime': null,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'subject': slot.subject,
        'sessionName': '${slot.subject} (${slot.startTime}–${slot.endTime})',
        'roomId': slot.roomId,
        'roomName': slot.roomName,
        'recordedAt': FieldValue.serverTimestamp(),
        'note': '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'status': status.name,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'subject': slot.subject,
          'sessionName': '${slot.subject} (${slot.startTime}–${slot.endTime})',
          'roomId': slot.roomId,
          'roomName': slot.roomName,
          'recordedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('attendance').add(data);
      }

      // ── Check absence threshold and create flag if hit ───────────────────
      // Only check when marking absent or late (not when correcting to present)
      if (status == AttendanceStatus.absent ||
          status == AttendanceStatus.late) {
        await _checkThresholdAndFlag(
          studentId: student.id,
          studentName: student.name,
          classId: student.classId,
        );
      }

      // ── Send notification to student ──────────────────────────────────────
      // Fetch the student's Firebase Auth userId (stored in users collection)
      final userSnap =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: student.email)
              .limit(1)
              .get();

      // Also try by student.userId field if email lookup fails
      final studentUserId =
          userSnap.docs.isNotEmpty ? userSnap.docs.first.id : student.userId;

      if (studentUserId.isNotEmpty) {
        final notifService = ref.read(notificationServiceProvider);
        final sessionInfo =
            '${slot.subject} (${slot.startTime}–${slot.endTime})';

        if (status == AttendanceStatus.absent) {
          await notifService.sendToUser(
            studentUserId,
            '⚠️ Marked Absent',
            'You have been marked absent for $sessionInfo on $dateStr.\n'
                'Teacher: $teacherName',
            type: 'attendance',
            senderId: teacherId,
            senderName: teacherName,
            senderRole: 'teacher',
          );
        } else if (status == AttendanceStatus.late) {
          await notifService.sendToUser(
            studentUserId,
            '⏰ Late arrival recorded',
            'You have been marked late for $sessionInfo on $dateStr.\n'
                'Teacher: $teacherName',
            type: 'attendance',
            senderId: teacherId,
            senderName: teacherName,
            senderRole: 'teacher',
          );
        } else if (status == AttendanceStatus.present) {
          // Only notify if toggling back from absent/late
          final prev = _attendanceMap[student.id];
          if (prev == AttendanceStatus.absent ||
              prev == AttendanceStatus.late) {
            await notifService.sendToUser(
              studentUserId,
              '✅ Attendance corrected',
              'Your attendance for $sessionInfo on $dateStr '
                  'has been updated to Present.\n'
                  'Teacher: $teacherName',
              type: 'attendance',
              senderId: teacherId,
              senderName: teacherName,
              senderRole: 'teacher',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Namecall] save error: $e');
    }
    if (mounted) setState(() => _savingMap[student.id] = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CHECK THRESHOLD — reads settings/thresholds, creates ai_flags doc
  //  and notifies student + admin when threshold is hit.
  //  Called every time a student is marked absent or late.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _checkThresholdAndFlag({
    required String studentId,
    required String studentName,
    required String classId,
  }) async {
    final db = FirebaseFirestore.instance;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    // Count absences and lates in the last 30 days
    final snap =
        await db
            .collection('attendance')
            .where('studentId', isEqualTo: studentId)
            .where(
              'recordedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
            )
            .get();

    final records = snap.docs.map((d) => d.data()).toList();
    final absent = records.where((r) => r['status'] == 'absent').length;
    final late = records.where((r) => r['status'] == 'late').length;

    // Read thresholds from Firestore
    int absenceThreshold = 3;
    int lateThreshold = 4;
    try {
      final settingsDoc =
          await db.collection('settings').doc('thresholds').get();
      if (settingsDoc.exists) {
        absenceThreshold =
            (settingsDoc.data()?['absenceThreshold'] as num?)?.toInt() ?? 3;
        lateThreshold =
            (settingsDoc.data()?['lateThreshold'] as num?)?.toInt() ?? 4;
      }
    } catch (_) {}

    // Determine if threshold is hit
    String? flagType;
    String details = '';
    double riskScore = 0;

    if (absent >= absenceThreshold) {
      flagType = 'frequentAbsent';
      details =
          '$studentName has been absent $absent time${absent == 1 ? '' : 's'} '
          'in the last 30 days (threshold: $absenceThreshold)';
      riskScore = (absent / 30).clamp(0.0, 1.0);
    } else if (late >= lateThreshold) {
      flagType = 'latePattern';
      details =
          '$studentName has arrived late $late time${late == 1 ? '' : 's'} '
          'in the last 30 days (threshold: $lateThreshold)';
      riskScore = (late / 30).clamp(0.0, 1.0);
    }

    if (flagType == null) return; // threshold not hit

    // Avoid duplicate active flags for same student + type
    final existing =
        await db
            .collection('ai_flags')
            .where('studentId', isEqualTo: studentId)
            .where('type', isEqualTo: flagType)
            .where('resolved', isEqualTo: false)
            .limit(1)
            .get();

    if (existing.docs.isNotEmpty) return; // already flagged

    // Create flag
    await db.collection('ai_flags').add({
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'type': flagType,
      'details': details,
      'riskScore': riskScore,
      'resolved': false,
      'detectedAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
    });

    debugPrint('[Namecall] Absence flag created: $flagType for $studentName');

    // Notify student
    final studentDoc = await db.collection('students').doc(studentId).get();
    final studentUserId = studentDoc.data()?['userId']?.toString() ?? '';
    if (studentUserId.isNotEmpty) {
      final title =
          flagType == 'frequentAbsent'
              ? '🚩 You have been flagged for frequent absences'
              : '🚩 You have been flagged for a frequent of late arrivals';
      await db.collection('notifications').add({
        'userId': studentUserId,
        'senderId': 'system',
        'senderName': 'SmartSchool',
        'senderRole': 'admin',
        'title': title,
        'message': details,
        'messageType': 'absence_flag',
        'isRead': false,
        'attachments': [],
        'recipientLabel': '',
        'replyToId': '',
        'replyToTitle': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Notify admin
    final adminSnap =
        await db
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .limit(1)
            .get();
    if (adminSnap.docs.isNotEmpty) {
      await db.collection('notifications').add({
        'userId': adminSnap.docs.first.id,
        'senderId': 'system',
        'senderName': 'SmartSchool',
        'senderRole': 'system',
        'title': '🚩 Absence Flag — $studentName',
        'message': details,
        'messageType': 'absence_flag',
        'isRead': false,
        'attachments': [],
        'recipientLabel': 'Admin',
        'replyToId': '',
        'replyToTitle': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SÉANCE PICKER — teacher's séances for selected date
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickSeance(
    BuildContext context,
    String teacherId,
    bool isDark,
  ) async {
    final dayName = _dayName(_selectedDate);
    final weekType = ref.read(weekTypeForDateProvider(_selectedDate));

    final snap =
        await FirebaseFirestore.instance
            .collection('timetable')
            .where('teacherId', isEqualTo: teacherId)
            .where('dayOfWeek', isEqualTo: dayName)
            .get();

    // Deduplicate by subject+time (same séance may have multiple class entries)
    final seen = <String>{};
    final slots =
        snap.docs
            .map(TimetableModel.fromFirestore)
            .where(
              (t) =>
                  weekType.isEmpty ||
                  t.weekType.isEmpty ||
                  t.weekType == weekType,
            )
            .where((t) => seen.add('${t.subject}|${t.startTime}|${t.endTime}'))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (slots.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No séances on $dayName.')));
      }
      return;
    }

    if (slots.length == 1) {
      await _selectSlot(slots.first);
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => _SeancePicker(
            slots: slots,
            isDark: isDark,
            onPick: (slot) async {
              Navigator.pop(context);
              await _selectSlot(slot);
            },
          ),
    );
  }

  Future<void> _selectSlot(TimetableModel slot) async {
    setState(() {
      _selectedSlot = slot;
      _slotPicked = true;
      _students = [];
      _attendanceMap.clear();
    });
    await _loadStudentsForSlot(slot);
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      loading: () => const Scaffold(body: LoadingWidget()),
      error:
          (e, _) => Scaffold(
            body: EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
          ),
      data: (user) {
        if (user == null) return const Scaffold(body: SizedBox.shrink());
        final teacherId = user.id;

        return Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            title: Text(
              _selectedSlot != null
                  ? 'Name Call — ${_selectedSlot!.subject}'
                  : 'Name Call',
            ),
            backgroundColor:
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
            actions: [
              // ── Date switcher ──────────────────────────────────────────
              IconButton(
                icon: const Icon(Icons.calendar_today_rounded),
                tooltip: 'Change date',
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 60),
                    ),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      _selectedDate = picked;
                      _selectedSlot = null;
                      _slotPicked = false;
                      _students = [];
                      _attendanceMap.clear();
                    });
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Date + séance banner ──────────────────────────────────────
              _DateSeanceBanner(
                date: _selectedDate,
                slot: _selectedSlot,
                classIds: _seanceClassIds,
                isDark: isDark,
                onPickSeance: () => _pickSeance(context, teacherId, isDark),
              ),

              // ── Stats ─────────────────────────────────────────────────────
              if (_slotPicked && _students.isNotEmpty)
                _StatsBar(
                  attendanceMap: _attendanceMap,
                  total: _students.length,
                  isDark: isDark,
                ),

              // ── Student list ──────────────────────────────────────────────
              Expanded(
                child:
                    !_slotPicked
                        ? _Hint(isDark: isDark)
                        : _students.isEmpty
                        ? const LoadingWidget()
                        : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _students.length,
                          itemBuilder: (ctx, i) {
                            final s = _students[i];
                            return _StudentCard(
                              student: s,
                              status:
                                  _attendanceMap[s.id] ??
                                  AttendanceStatus.present,
                              isDark: isDark,
                              isSaving: _savingMap[s.id] ?? false,
                              showClass: _seanceClassIds.length > 1,
                              onStatusChanged: (newStatus) {
                                // Capture previous status BEFORE updating map
                                // so _saveAttendance can compare for "toggle to present"
                                _saveAttendance(s, newStatus);
                                setState(
                                  () => _attendanceMap[s.id] = newStatus,
                                );
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  DATE + SÉANCE BANNER
// ─────────────────────────────────────────
class _DateSeanceBanner extends StatelessWidget {
  final DateTime date;
  final TimetableModel? slot;
  final List<String> classIds;
  final bool isDark;
  final VoidCallback onPickSeance;

  const _DateSeanceBanner({
    required this.date,
    required this.slot,
    required this.classIds,
    required this.isDark,
    required this.onPickSeance,
  });

  String _fmtDate(DateTime d) {
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
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday]} ${d.day} ${m[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teacherColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.teacherColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDate(date),
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.teacherColor,
                  ),
                ),
                if (slot != null) ...[
                  Text(
                    '${slot!.subject} · ${slot!.startTime}–${slot!.endTime}',
                    style: AppTypography.caption,
                  ),
                  if (classIds.length > 1)
                    Text(
                      '${classIds.length} groups combined',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.teacherColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ] else
                  Text(
                    'Tap to select séance',
                    style: AppTypography.caption.copyWith(
                      color:
                          isDark
                              ? AppColors.darkTextHint
                              : AppColors.lightTextHint,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onPickSeance,
            icon: const Icon(Icons.schedule_rounded, size: 16),
            label: Text(slot == null ? 'Select Séance' : 'Change'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.teacherColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SÉANCE PICKER
// ─────────────────────────────────────────
class _SeancePicker extends StatelessWidget {
  final List<TimetableModel> slots;
  final bool isDark;
  final void Function(TimetableModel) onPick;
  const _SeancePicker({
    required this.slots,
    required this.isDark,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Select Séance', style: AppTypography.headingMedium),
          ),
        ),
        const Divider(),
        ...slots.map(
          (slot) => ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.teacherColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.teacherColor,
                size: 20,
              ),
            ),
            title: Text(slot.subject, style: AppTypography.labelMedium),
            subtitle: Text(
              '${slot.startTime} – ${slot.endTime}',
              style: AppTypography.caption,
            ),
            onTap: () => onPick(slot),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  HINT (no séance selected yet)
// ─────────────────────────────────────────
class _Hint extends StatelessWidget {
  final bool isDark;
  const _Hint({required this.isDark});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.touch_app_rounded,
          size: 48,
          color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
        ),
        const SizedBox(height: 12),
        Text(
          'Select a séance to start',
          style: AppTypography.bodyMedium.copyWith(
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
            _Pill('Present', present, AppColors.success),
            const SizedBox(width: 8),
            _Pill('Late', late, AppColors.warning),
            const SizedBox(width: 8),
            _Pill('Absent', absent, AppColors.error),
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
  Widget build(BuildContext context) => Container(
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

// ─────────────────────────────────────────
//  STUDENT CARD
// ─────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final AttendanceStatus status;
  final bool isDark, isSaving, showClass;
  final Function(AttendanceStatus) onStatusChanged;
  const _StudentCard({
    required this.student,
    required this.status,
    required this.isDark,
    required this.isSaving,
    required this.showClass,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        status == AttendanceStatus.present
            ? AppColors.success
            : status == AttendanceStatus.late
            ? AppColors.warning
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                  style: AppTypography.labelMedium.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                if (showClass && student.className.isNotEmpty)
                  Text(
                    student.className,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.teacherColor,
                    ),
                  ),
              ],
            ),
          ),
          if (isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in AttendanceStatus.values)
                  GestureDetector(
                    onTap: () => onStatusChanged(s),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            status == s
                                ? _col(s).withValues(alpha: 0.15)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              status == s
                                  ? _col(s)
                                  : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        _icon(s),
                        size: 18,
                        color:
                            status == s
                                ? _col(s)
                                : Colors.grey.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Color _col(AttendanceStatus s) =>
      s == AttendanceStatus.present
          ? AppColors.success
          : s == AttendanceStatus.late
          ? AppColors.warning
          : AppColors.error;
  IconData _icon(AttendanceStatus s) =>
      s == AttendanceStatus.present
          ? Icons.check_circle_rounded
          : s == AttendanceStatus.late
          ? Icons.watch_later_rounded
          : Icons.cancel_rounded;
}
