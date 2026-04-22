import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

// ─── Provider for current timetable slot ───
final currentTimetableSlotProvider =
    FutureProvider.family<TimetableModel?, String>((ref, classId) async {
  final now = DateTime.now();
  const days = [
    '', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  final dayName = days[now.weekday];
  final currentTime =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  final snap = await FirebaseFirestore.instance
      .collection('timetable')
      .where('classId', isEqualTo: classId)
      .where('dayOfWeek', isEqualTo: dayName)
      .get();

  for (final doc in snap.docs) {
    final data = doc.data();
    final start = data['startTime']?.toString() ?? '';
    final end = data['endTime']?.toString() ?? '';
    if (currentTime.compareTo(start) >= 0 &&
        currentTime.compareTo(end) <= 0) {
      return TimetableModel.fromFirestore(doc);
    }
  }
  return null;
});

class TeacherNamecallScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;

  const TeacherNamecallScreen({super.key, required this.classId, required this.className});

  @override
  ConsumerState<TeacherNamecallScreen> createState() =>
      _TeacherNamecallScreenState();
}

class _TeacherNamecallScreenState
    extends ConsumerState<TeacherNamecallScreen> {
  final Map<String, AttendanceStatus> _attendanceMap = {};
  final Map<String, bool> _savingMap = {};
  bool _isSubmitted = false;

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ─── Save individual student attendance in real-time ───
  Future<void> _saveStudentAttendance(
    StudentModel student,
    AttendanceStatus status,
    TimetableModel? slot,
    String teacherName,
    String teacherId,
  ) async {
    setState(() => _savingMap[student.id] = true);

    final now = DateTime.now();
    final dateStr = _formatDate(now);

    try {
      final existing = await FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: student.id)
          .where('date', isEqualTo: dateStr)
          .limit(1)
          .get();

      final data = {
        'studentId': student.id,
        'studentName': student.name,
        'classId': student.classId,
        'className': student.className,
        'date': dateStr,
        'status': status.name,
        'entryTime': status == AttendanceStatus.present ||
                status == AttendanceStatus.late
            ? Timestamp.fromDate(now)
            : null,
        'exitTime': null,
        // ─── Auto from timetable ───
        'teacherId': teacherId,
        'teacherName': teacherName,
        'subject': slot?.subject ?? '',
        'sessionName': slot != null
            ? '${slot.subject} Session'
            : '',
        'roomId': slot?.roomId ?? '',
        'roomName': slot?.roomName ?? '',
        'recordedAt': Timestamp.fromDate(now),
        'note': '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'status': status.name,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'subject': slot?.subject ?? '',
          'sessionName': slot != null
              ? '${slot.subject} Session'
              : '',
          'roomId': slot?.roomId ?? '',
          'roomName': slot?.roomName ?? '',
          'recordedAt': Timestamp.fromDate(now),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('attendance')
            .add(data);
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
    final students =
        ref.watch(studentsByClassIdProvider(widget.classId));
    final currentSlot =
        ref.watch(currentTimetableSlotProvider(widget.classId));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Name Call'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: currentUser.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => EmptyState(
          title: 'Error',
          message: e.toString(),
          icon: Icons.error_outline_rounded,
        ),
        data: (user) {
          if (user == null) return const SizedBox.shrink();

          return students.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => EmptyState(
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

              // Init attendance map
              for (final s in studentList) {
                _attendanceMap.putIfAbsent(
                    s.id, () => AttendanceStatus.present);
              }

              return Column(
                children: [
                  // ─── Current session banner ───
                  currentSlot.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (slot) => slot == null
                        ? Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.warning
                                  .withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No active timetable slot found. Attendance will be recorded without session details.',
                                    style: AppTypography.caption
                                        .copyWith(
                                            color:
                                                AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.teacherColor
                                  .withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.teacherColor
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.teacherColor
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: AppColors.teacherColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.subject,
                                        style: AppTypography
                                            .labelLarge
                                            .copyWith(
                                          color: AppColors
                                              .teacherColor,
                                        ),
                                      ),
                                      Text(
                                        '${slot.startTime} - ${slot.endTime}${slot.roomName.isNotEmpty ? ' • ${slot.roomName}' : ''}',
                                        style:
                                            AppTypography.caption,
                                      ),
                                      Text(
                                        'Recorded by ${user.name} • ${DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now())}',
                                        style:
                                            AppTypography.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  // ─── Stats bar ───
                  _buildStatsBar(studentList, isDark),
                  const SizedBox(height: 8),

                  // ─── Student list ───
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
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
                            setState(() {
                              _attendanceMap[student.id] =
                                  newStatus;
                            });
                            // ─── Real-time save ───
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

                  // ─── Mark all done button ───
                  if (!_isSubmitted)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AppButton(
                        label: 'Mark All as Done',
                        onPressed: () =>
                            setState(() => _isSubmitted = true),
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
                          color: AppColors.success
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success
                                .withValues(alpha: 0.3),
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
                              'Attendance saved — synced in real-time ✅',
                              style: AppTypography.labelMedium
                                  .copyWith(
                                      color: AppColors.success),
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

  Widget _buildStatsBar(
      List<StudentModel> students, bool isDark) {
    final present = _attendanceMap.values
        .where((s) => s == AttendanceStatus.present)
        .length;
    final absent = _attendanceMap.values
        .where((s) => s == AttendanceStatus.absent)
        .length;
    final late = _attendanceMap.values
        .where((s) => s == AttendanceStatus.late)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            _StatBadge('Present', present, AppColors.present),
            const SizedBox(width: 8),
            _StatBadge('Late', late, AppColors.late),
            const SizedBox(width: 8),
            _StatBadge('Absent', absent, AppColors.absent),
            const Spacer(),
            Text(
              '${students.length} students',
              style: AppTypography.caption,
            ),
          ],
        ),
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
    final statusColor = status == AttendanceStatus.present
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
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // ─── Avatar ───
          CircleAvatar(
            radius: 20,
            backgroundColor:
                AppColors.teacherColor.withValues(alpha: 0.15),
            child: Text(
              student.name.isNotEmpty
                  ? student.name[0].toUpperCase()
                  : '?',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.teacherColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ─── Info ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                ),
                Text(
                  student.classDisplay,
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),

          // ─── Saving indicator ───
          if (isSaving)
            const SizedBox(
              width: 20,
              height: 20,
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
                  onTap: () =>
                      onStatusChanged(AttendanceStatus.present),
                ),
                const SizedBox(width: 4),
                _StatusBtn(
                  icon: Icons.watch_later_rounded,
                  color: AppColors.late,
                  isActive: status == AttendanceStatus.late,
                  tooltip: 'Late',
                  onTap: () =>
                      onStatusChanged(AttendanceStatus.late),
                ),
                const SizedBox(width: 4),
                _StatusBtn(
                  icon: Icons.cancel_rounded,
                  color: AppColors.absent,
                  isActive: status == AttendanceStatus.absent,
                  tooltip: 'Absent',
                  onTap: () =>
                      onStatusChanged(AttendanceStatus.absent),
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
            color: isActive
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? color
                  : color.withValues(alpha: 0.3),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            color: isActive
                ? color
                : color.withValues(alpha: 0.5),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
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