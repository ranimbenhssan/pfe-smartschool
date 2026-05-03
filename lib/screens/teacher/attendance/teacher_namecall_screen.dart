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

  /// The date this name call is for (format: 'yyyy-MM-dd').
  /// Defaults to today if not provided. Pass a past date to edit
  /// historical attendance records.
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
  bool _isLoadingExisting =
      true; // loading spinner while pre-filling past records

  // ─── Resolved date: use widget.targetDate if set, else today ───
  late final String _dateStr;
  late final DateTime _dateTime;
  late final bool _isPastDate;

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = _formatDate(now);

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

    // ─── Pre-load existing records for the target date ───
    _loadExistingAttendance();
  }

  // ─── Query attendance WHERE classId + date → pre-fill status map ───
  Future<void> _loadExistingAttendance() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('classId', isEqualTo: widget.classId)
              .where('date', isEqualTo: _dateStr)
              .get();

      if (mounted) {
        final preloaded = <String, AttendanceStatus>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          final studentId = data['studentId']?.toString() ?? '';
          final statusStr = data['status']?.toString() ?? 'absent';
          if (studentId.isEmpty) continue;
          preloaded[studentId] = AttendanceStatus.values.firstWhere(
            (s) => s.name == statusStr,
            orElse: () => AttendanceStatus.absent,
          );
        }
        setState(() {
          _attendanceMap.addAll(preloaded);
          _isLoadingExisting = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading existing attendance: $e');
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  // ─── Save / update a single student record for _dateStr ───
  Future<void> _saveStudentAttendance(
    StudentModel student,
    AttendanceStatus status,
    TimetableModel? slot,
    String teacherName,
    String teacherId,
  ) async {
    setState(() => _savingMap[student.id] = true);

    final subject = slot?.subject ?? '';
    final scheduledStartTime = slot?.startTime ?? '';
    final scheduledEndTime = slot?.endTime ?? '';
    final sessionName =
        slot != null
            ? '${slot.subject} (${slot.startTime} – ${slot.endTime})'
            : '';
    final roomId = slot?.roomId ?? '';
    final roomName = slot?.roomName ?? '';

    // For past-date edits, recordedAt = now (time of correction).
    // entryTime = noon on the target date (placeholder for past records).
    final now = DateTime.now();
    final entryTimeForPast = DateTime(
      _dateTime.year,
      _dateTime.month,
      _dateTime.day,
      8,
      0,
    );

    try {
      final existing =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('studentId', isEqualTo: student.id)
              .where('date', isEqualTo: _dateStr)
              .limit(1)
              .get();

      if (existing.docs.isNotEmpty) {
        // ─── Update existing record ───
        await existing.docs.first.reference.update({
          'status': status.name,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'subject': subject,
          'sessionName': sessionName,
          'roomId': roomId,
          'roomName': roomName,
          'scheduledStartTime': scheduledStartTime,
          'scheduledEndTime': scheduledEndTime,
          'recordedAt': Timestamp.fromDate(now),
        });
      } else {
        // ─── Create new record ───
        await FirebaseFirestore.instance.collection('attendance').add({
          'studentId': student.id,
          'studentName': student.name,
          'classId': student.classId,
          'className': student.className,
          'date': _dateStr,
          'status': status.name,
          'entryTime':
              (status == AttendanceStatus.present ||
                      status == AttendanceStatus.late)
                  ? Timestamp.fromDate(_isPastDate ? entryTimeForPast : now)
                  : null,
          'exitTime': null,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'subject': subject,
          'sessionName': sessionName,
          'roomId': roomId,
          'roomName': roomName,
          'scheduledStartTime': scheduledStartTime,
          'scheduledEndTime': scheduledEndTime,
          'recordedAt': Timestamp.fromDate(now),
          'note': _isPastDate ? 'Manually entered for $_dateStr' : '',
          'createdAt': FieldValue.serverTimestamp(),
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

    // ─── For today: use live timetable slot ───
    // ─── For past dates: slot is null (no live session), show static banner ───
    final currentSlot =
        _isPastDate
            ? const AsyncValue.data(null)
            : ref.watch(currentTimetableSlotProvider(widget.classId));

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
        // ─── Past-date chip in app bar ───
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

                      // Init absent for any student not already in map
                      for (final s in studentList) {
                        _attendanceMap.putIfAbsent(
                          s.id,
                          () => AttendanceStatus.absent,
                        );
                      }

                      return Column(
                        children: [
                          // ─── Past-date warning banner ───
                          if (_isPastDate)
                            _PastDateBanner(
                              dateLabel: dateLabel,
                              isDark: isDark,
                            ),

                          // ─── Session context (today only) ───
                          if (!_isPastDate)
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
                                    setState(
                                      () =>
                                          _attendanceMap[student.id] =
                                              newStatus,
                                    );
                                    await _saveStudentAttendance(
                                      student,
                                      newStatus,
                                      currentSlot.value,
                                      user.name,
                                      user.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          // ─── Submit / Done button ───
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
                                                : 'Attendance saved — synced ✅',
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
            Icons.history_edu_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing past attendance',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  'Records for $dateLabel will be created or updated.',
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
//  SESSION BANNER (today only)
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
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
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
          const SizedBox(height: 10),
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
              const SizedBox(width: 8),
              Expanded(
                child: _DetailItem(
                  icon: Icons.person_rounded,
                  label: 'Teacher',
                  value:
                      teacherName.isNotEmpty ? teacherName : slot.teacherName,
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
                  value: slot.roomName.isNotEmpty ? slot.roomName : '—',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailItem(
                  icon: Icons.schedule_rounded,
                  label: 'Scheduled',
                  value: '${slot.startTime} – ${slot.endTime}',
                  color: AppColors.accent,
                ),
              ),
            ],
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
                  'Attendance will be saved without session context.',
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
                _StatusBtn(
                  'P',
                  AppColors.present,
                  status == AttendanceStatus.present,
                  () => onStatusChanged(AttendanceStatus.present),
                ),
                const SizedBox(width: 6),
                _StatusBtn(
                  'L',
                  AppColors.late,
                  status == AttendanceStatus.late,
                  () => onStatusChanged(AttendanceStatus.late),
                ),
                const SizedBox(width: 6),
                _StatusBtn(
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
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.name.toUpperCase(),
                style: AppTypography.caption.copyWith(color: statusColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusBtn(this.label, this.color, this.isActive, this.onTap);

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
