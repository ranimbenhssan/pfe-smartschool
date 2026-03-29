import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../models/student_model.dart';
import '../../../models/attendance_model.dart';
import '../../../providers/providers.dart';

// ─── Local provider: students for teacher's class ───────────────────────────

final teacherClassStudentsProvider =
    StreamProvider.family<List<StudentModel>, String>((ref, classId) {
      return FirebaseFirestore.instance
          .collection('students')
          .where('classId', isEqualTo: classId)
          .snapshots()
          .map((s) {
            final list = s.docs.map(StudentModel.fromFirestore).toList();
            list.sort((a, b) => a.name.compareTo(b.name));
            return list;
          });
    });

// ─── Local provider: today's existing attendance for a class ────────────────

final todayClassAttendanceProvider =
    StreamProvider.family<Map<String, AttendanceStatus>, String>((
      ref,
      classId,
    ) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return FirebaseFirestore.instance
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('date', isEqualTo: today)
          .snapshots()
          .map((s) {
            return {
              for (final doc in s.docs)
                (doc.data()['studentId'] as String):
                    AttendanceModel.fromFirestore(doc).status,
            };
          });
    });

// ─── Main Screen ─────────────────────────────────────────────────────────────

class TeacherNameCallScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;

  const TeacherNameCallScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  ConsumerState<TeacherNameCallScreen> createState() =>
      _TeacherNameCallScreenState();
}

class _TeacherNameCallScreenState extends ConsumerState<TeacherNameCallScreen> {
  final Map<String, AttendanceStatus?> _draft = {};
  bool _saving = false;
  bool _submitted = false;

  void _mark(String studentId, AttendanceStatus status) {
    setState(() => _draft[studentId] = status);
  }

  int get _markedCount => _draft.values.where((v) => v != null).length;

  Future<void> _submitAll(List<StudentModel> students) async {
    setState(() => _saving = true);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    final batch = FirebaseFirestore.instance.batch();

    for (final student in students) {
      final status = _draft[student.id] ?? AttendanceStatus.absent;

      final existing =
          await FirebaseFirestore.instance
              .collection('attendance')
              .where('studentId', isEqualTo: student.id)
              .where('date', isEqualTo: today)
              .limit(1)
              .get();

      if (existing.docs.isNotEmpty) {
        batch.update(existing.docs.first.reference, {
          'status': status.name,
          'entryTime':
              status == AttendanceStatus.present ||
                      status == AttendanceStatus.late
                  ? Timestamp.fromDate(now)
                  : null,
        });
      } else {
        final ref = FirebaseFirestore.instance.collection('attendance').doc();
        batch.set(
          ref,
          AttendanceModel(
            id: ref.id,
            studentId: student.id,
            studentName: student.name,
            classId: widget.classId,
            date: today,
            status: status,
            entryTime:
                status == AttendanceStatus.present ||
                        status == AttendanceStatus.late
                    ? now
                    : null,
            createdAt: now,
          ).toFirestore(),
        );
      }
    }

    await batch.commit();
    setState(() {
      _saving = false;
      _submitted = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Attendance saved successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studentsAsync = ref.watch(
      teacherClassStudentsProvider(widget.classId),
    );
    final existingAsync = ref.watch(
      todayClassAttendanceProvider(widget.classId),
    );
    final today = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name Call',
              style: AppTypography.labelLarge.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            Text(
              widget.className,
              style: AppTypography.caption.copyWith(color: AppColors.accent),
            ),
          ],
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (students) {
          existingAsync.whenData((existing) {
            for (final entry in existing.entries) {
              if (!_draft.containsKey(entry.key)) {
                _draft[entry.key] = entry.value;
              }
            }
          });

          if (students.isEmpty) {
            return _EmptyState(isDark: isDark);
          }

          return Column(
            children: [
              _HeaderBar(
                isDark: isDark,
                date: today,
                marked: _markedCount,
                total: students.length,
                draft: _draft,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final status = _draft[student.id];
                    return _StudentNameCallCard(
                      isDark: isDark,
                      student: student,
                      index: index + 1,
                      status: status,
                      onMark: (s) => _mark(student.id, s),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: studentsAsync.maybeWhen(
        data:
            (students) =>
                students.isEmpty
                    ? null
                    : _SubmitButton(
                      isDark: isDark,
                      saving: _saving,
                      submitted: _submitted,
                      markedCount: _markedCount,
                      totalCount: students.length,
                      onSubmit: () => _submitAll(students),
                    ),
        orElse: () => null,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─── Header Bar ──────────────────────────────────────────────────────────────

class _HeaderBar extends StatelessWidget {
  final bool isDark;
  final String date;
  final int marked;
  final int total;
  final Map<String, AttendanceStatus?> draft;

  const _HeaderBar({
    required this.isDark,
    required this.date,
    required this.marked,
    required this.total,
    required this.draft,
  });

  @override
  Widget build(BuildContext context) {
    final presentCount =
        draft.values.where((v) => v == AttendanceStatus.present).length;
    final absentCount =
        draft.values.where((v) => v == AttendanceStatus.absent).length;
    final lateCount =
        draft.values.where((v) => v == AttendanceStatus.late).length;
    final progress = total == 0 ? 0.0 : marked / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: AppTypography.bodySmall.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                '$marked / $total marked',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                label: 'Present',
                count: presentCount,
                color: AppColors.present,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                label: 'Absent',
                count: absentCount,
                color: AppColors.absent,
              ),
              const SizedBox(width: 8),
              _MiniStat(label: 'Late', count: lateCount, color: AppColors.late),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AppTypography.labelLarge.copyWith(color: color),
            ),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

// ─── Student Name Call Card ───────────────────────────────────────────────────

class _StudentNameCallCard extends StatelessWidget {
  final bool isDark;
  final StudentModel student;
  final int index;
  final AttendanceStatus? status;
  final void Function(AttendanceStatus) onMark;

  const _StudentNameCallCard({
    required this.isDark,
    required this.student,
    required this.index,
    required this.status,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final isMarked = status != null;

    Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    if (status == AttendanceStatus.present) borderColor = AppColors.present;
    if (status == AttendanceStatus.absent) borderColor = AppColors.absent;
    if (status == AttendanceStatus.late) borderColor = AppColors.late;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isMarked
                ? borderColor.withValues(alpha: 0.06)
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isMarked ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                backgroundImage:
                    student.photoUrl != null
                        ? NetworkImage(student.photoUrl!)
                        : null,
                child:
                    student.photoUrl == null
                        ? Text(
                          student.name[0].toUpperCase(),
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.accent,
                          ),
                        )
                        : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: AppTypography.caption.copyWith(fontSize: 9),
                    ),
                  ),
                ),
              ),
            ],
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
                if (status != null)
                  Text(
                    status!.name[0].toUpperCase() + status!.name.substring(1),
                    style: AppTypography.caption.copyWith(color: borderColor),
                  )
                else
                  Text(
                    'Not marked yet',
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
          Row(
            children: [
              _StatusButton(
                label: 'P',
                color: AppColors.present,
                selected: status == AttendanceStatus.present,
                onTap: () => onMark(AttendanceStatus.present),
              ),
              const SizedBox(width: 6),
              _StatusButton(
                label: 'A',
                color: AppColors.absent,
                selected: status == AttendanceStatus.absent,
                onTap: () => onMark(AttendanceStatus.absent),
              ),
              const SizedBox(width: 6),
              _StatusButton(
                label: 'L',
                color: AppColors.late,
                selected: status == AttendanceStatus.late,
                onTap: () => onMark(AttendanceStatus.late),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: selected ? Colors.white : color,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Submit Button ────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final bool isDark;
  final bool saving;
  final bool submitted;
  final int markedCount;
  final int totalCount;
  final VoidCallback onSubmit;

  const _SubmitButton({
    required this.isDark,
    required this.saving,
    required this.submitted,
    required this.markedCount,
    required this.totalCount,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final allMarked = markedCount == totalCount;

    return GestureDetector(
      onTap: saving ? null : onSubmit,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                submitted
                    ? [AppColors.success, AppColors.success]
                    : allMarked
                    ? [
                      AppColors.accent,
                      AppColors.accent.withValues(alpha: 0.8),
                    ]
                    : [AppColors.primary, AppColors.secondary],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (saving)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                submitted ? Icons.check_circle_rounded : Icons.save_rounded,
                color: Colors.white,
                size: 20,
              ),
            const SizedBox(width: 8),
            Text(
              saving
                  ? 'Saving...'
                  : submitted
                  ? 'Attendance Saved'
                  : allMarked
                  ? 'Submit Attendance ($totalCount/$totalCount)'
                  : 'Save Progress ($markedCount/$totalCount)',
              style: AppTypography.labelLarge.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off_rounded,
            size: 64,
            color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
          ),
          const SizedBox(height: 16),
          Text(
            'No students in this class',
            style: AppTypography.headingMedium.copyWith(
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
}
