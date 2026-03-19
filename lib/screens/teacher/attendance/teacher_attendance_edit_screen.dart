import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class TeacherAttendanceEditScreen extends ConsumerStatefulWidget {
  final AttendanceModel attendance;

  const TeacherAttendanceEditScreen({
    super.key,
    required this.attendance,
  });

  @override
  ConsumerState<TeacherAttendanceEditScreen> createState() =>
      _TeacherAttendanceEditScreenState();
}

class _TeacherAttendanceEditScreenState
    extends ConsumerState<TeacherAttendanceEditScreen> {
  late AttendanceStatus _selectedStatus;
  final _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.attendance.status;
    _noteController.text = widget.attendance.note ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(firestoreServiceProvider).updateAttendance(
        widget.attendance.id,
        {
          'status': _selectedStatus.name,
          'note': _noteController.text.trim(),
        },
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Edit Attendance'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Student Info ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        AppColors.teacherColor.withValues(alpha: 0.15),
                    child: Text(
                      widget.attendance.studentName.isNotEmpty
                          ? widget.attendance.studentName[0].toUpperCase()
                          : '?',
                      style: AppTypography.headingSmall.copyWith(
                        color: AppColors.teacherColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.attendance.studentName,
                        style: AppTypography.labelLarge.copyWith(
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      Text(
                        'Date: ${widget.attendance.date}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Status Selector ───
            Text(
              'Attendance Status',
              style: AppTypography.labelMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: AttendanceStatus.values.map((status) {
                final isSelected = _selectedStatus == status;
                final color = status == AttendanceStatus.present
                    ? AppColors.present
                    : status == AttendanceStatus.absent
                        ? AppColors.absent
                        : AppColors.late;
                final label = status == AttendanceStatus.present
                    ? 'Present'
                    : status == AttendanceStatus.absent
                        ? 'Absent'
                        : 'Late';

                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedStatus = status),
                    child: Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 4),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.12)
                            : isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            status == AttendanceStatus.present
                                ? Icons.check_circle_rounded
                                : status == AttendanceStatus.absent
                                    ? Icons.cancel_rounded
                                    : Icons.watch_later_rounded,
                            color: isSelected
                                ? color
                                : isDark
                                    ? AppColors.darkTextHint
                                    : AppColors.lightTextHint,
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: AppTypography.labelSmall.copyWith(
                              color: isSelected
                                  ? color
                                  : isDark
                                      ? AppColors.darkTextHint
                                      : AppColors.lightTextHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ─── Note ───
            AppTextField(
              label: 'Note (Optional)',
              hint: 'Add a note...',
              controller: _noteController,
              maxLines: 3,
              prefixIcon: const Icon(Icons.note_rounded, size: 18),
            ),
            const SizedBox(height: 32),

            AppButton(
              label: 'Save Changes',
              onPressed: _save,
              isLoading: _isLoading,
              width: double.infinity,
              icon: Icons.save_rounded,
            ),
          ],
        ),
      ),
    );
  }
}