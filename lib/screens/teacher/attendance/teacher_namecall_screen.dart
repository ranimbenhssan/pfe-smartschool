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

  const TeacherNamecallScreen({
    super.key,
    required this.classId,
    this.className = '',
  });

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

  // ─── Save single student — pulls slot from timetable ───
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

    // ─── Build session context from timetable slot ───
    final subject = slot?.subject ?? '';
    final sessionName = slot != null
        ? '${slot.subject} Session (${slot.startTime} - ${slot.endTime})'
        : '';
    final roomId = slot?.roomId ?? '';
    final roomName = slot?.roomName ?? '';

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
        // ─── Auto-filled from timetable ───
        'teacherId': teacherId,
        'teacherName': teacherName,
        'subject': subject,
        'sessionName': sessionName,
        'roomId': roomId,
        'roomName': roomName,
        'recordedAt': Timestamp.fromDate(now),
        'note': '',
        'createdAt': FieldValue.serverTimestamp(),
      };

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
          'recordedAt': Timestamp.fromDate(now),
        });
      } else {
        // ─── Create new record ───
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

    // ─── Real-time timetable slot ───
    final currentSlot =
        ref.watch(currentTimetableSlotProvider(widget.classId));

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

              // ─── Init attendance map ───
              for (final s in studentList) {
                _attendanceMap.putIfAbsent(
                    s.id, () => AttendanceStatus.present);
              }

              return Column(
                children: [
                  // ─── Session context banner ───
                  currentSlot.when(
                    loading: () => const SizedBox(height: 8),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (slot) => slot == null
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
                            // ─── Real-time save with timetable context ───
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
                  if (!_isSubmitted)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AppButton(
                        label: 'Mark as Complete',
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
          color: AppColors.teacherColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.teacherColor
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.teacherColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-detected Session',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.teacherColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Context pulled from timetable',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              // ─── Live indicator ───
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success
                        .withValues(alpha: 0.3),
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

          // ─── Session details grid ───
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
                  value:
                      '${slot.startTime} – ${slot.endTime}',
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
                  value: slot.roomName.isNotEmpty
                      ? slot.roomName
                      : 'Not assigned',
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

          // ─── Recorded at ───
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 12, color: AppColors.info),
                const SizedBox(width: 6),
                Text(
                  'Attendance records will include: ${slot.subject} session · ${slot.roomName.isNotEmpty ? slot.roomName : "No room"} · ${DateFormat("HH:mm dd/MM/yyyy").format(DateTime.now())}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.info,
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
//  NO SESSION BANNER — outside timetable
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
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
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
        border: Border.all(
            color: color.withValues(alpha: 0.15)),
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
                  style: AppTypography.caption.copyWith(
                    color: color,
                  ),
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
    final present = attendanceMap.values
        .where((s) => s == AttendanceStatus.present)
        .length;
    final absent = attendanceMap.values
        .where((s) => s == AttendanceStatus.absent)
        .length;
    final late = attendanceMap.values
        .where((s) => s == AttendanceStatus.late)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
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
            Text(
              '$total students',
              style: AppTypography.caption,
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
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: color.withValues(alpha: 0.3)),
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

          // ─── Status buttons / saving / submitted ───
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