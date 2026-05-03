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

class _TeacherNamecallScreenState extends ConsumerState<TeacherNamecallScreen> {
  final Map<String, AttendanceStatus> _attendanceMap = {};
  final Map<String, bool> _savingMap = {};
  bool _isSubmitted = false;

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ─── Save single student — pulls all 5 fields from timetable slot ───
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

    // ─── Map all 5 fields from timetable slot ───
    final subject = slot?.subject ?? '';
    final scheduledStartTime = slot?.startTime ?? '';
    final scheduledEndTime = slot?.endTime ?? '';
    final sessionName =
        slot != null
            ? '${slot.subject} (${slot.startTime} – ${slot.endTime})'
            : '';
    final roomId = slot?.roomId ?? '';
    final roomName = slot?.roomName ?? '';

    try {
      final existing =
          await FirebaseFirestore.instance
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
        'entryTime':
            status == AttendanceStatus.present ||
                    status == AttendanceStatus.late
                ? Timestamp.fromDate(now)
                : null,
        'exitTime': null,
        // ─── Timetable-mapped fields ───
        'teacherId': teacherId,
        'teacherName': teacherName,
        'subject': subject,
        'sessionName': sessionName,
        'roomId': roomId,
        'roomName': roomName,
        'scheduledStartTime': scheduledStartTime,
        'scheduledEndTime': scheduledEndTime,
        'recordedAt': Timestamp.fromDate(now),
        'note': '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
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
        await FirebaseFirestore.instance.collection('attendance').add(data);
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

    // ─── Real-time timetable slot ───
    final currentSlot = ref.watch(currentTimetableSlotProvider(widget.classId));

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
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (user) {
          if (user == null) {
            return const EmptyState(
              title: 'Not logged in',
              message: '',
              icon: Icons.lock_outline_rounded,
            );
          }
          return Column(
            children: [
              // ─── Session banner ───
              currentSlot.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data:
                    (slot) =>
                        slot != null
                            ? _SessionBanner(
                              slot: slot,
                              isDark: isDark,
                              teacherName: user.name,
                            )
                            : _NoSessionBanner(isDark: isDark),
              ),

              // ─── Stats bar ───
              _StatsBar(
                attendanceMap: _attendanceMap,
                total: students.value?.length ?? 0,
                isDark: isDark,
              ),

              // ─── Student list ───
              Expanded(
                child: students.when(
                  loading: () => const LoadingWidget(),
                  error:
                      (e, _) => EmptyState(
                        title: 'Error',
                        message: e.toString(),
                        icon: Icons.error_outline_rounded,
                      ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const EmptyState(
                        title: 'No Students',
                        message: 'No students in this class',
                        icon: Icons.people_outline_rounded,
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final student = list[index];
                        final status =
                            _attendanceMap[student.id] ??
                            AttendanceStatus.absent;
                        final isSaving = _savingMap[student.id] ?? false;

                        return _StudentCard(
                          student: student,
                          status: status,
                          isDark: isDark,
                          isSaving: isSaving,
                          isSubmitted: _isSubmitted,
                          onStatusChanged: (newStatus) async {
                            setState(() {
                              _attendanceMap[student.id] = newStatus;
                            });
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
                    onPressed: () => setState(() => _isSubmitted = true),
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
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
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
                          'Attendance saved — synced in real-time ✅',
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

          // ─── 5 fields grid ───
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
              const SizedBox(width: 10),
              Expanded(
                child: _DetailItem(
                  icon: Icons.schedule_rounded,
                  label: 'Scheduled Time',
                  value: '${slot.startTime} – ${slot.endTime}',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailItem(
            icon: Icons.access_time_filled_rounded,
            label: 'Time of Absence Recording',
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
    return fullWidth ? SizedBox(width: double.infinity, child: tile) : tile;
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
                Text(student.className, style: AppTypography.caption),
              ],
            ),
          ),

          // ─── Saving indicator or status buttons ───
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
                  label: 'P',
                  color: AppColors.present,
                  isActive: status == AttendanceStatus.present,
                  onTap: () => onStatusChanged(AttendanceStatus.present),
                ),
                const SizedBox(width: 6),
                _StatusBtn(
                  label: 'L',
                  color: AppColors.late,
                  isActive: status == AttendanceStatus.late,
                  onTap: () => onStatusChanged(AttendanceStatus.late),
                ),
                const SizedBox(width: 6),
                _StatusBtn(
                  label: 'A',
                  color: AppColors.absent,
                  isActive: status == AttendanceStatus.absent,
                  onTap: () => onStatusChanged(AttendanceStatus.absent),
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

  const _StatusBtn({
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

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
