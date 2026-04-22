import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class AdminAttendanceEditScreen extends ConsumerStatefulWidget {
  final AttendanceModel attendance;

  const AdminAttendanceEditScreen({super.key, required this.attendance});

  @override
  ConsumerState<AdminAttendanceEditScreen> createState() =>
      _AdminAttendanceEditScreenState();
}

class _AdminAttendanceEditScreenState
    extends ConsumerState<AdminAttendanceEditScreen> {
  late AttendanceStatus _selectedStatus;
  final _noteController = TextEditingController();
  final _sessionController = TextEditingController();
  final _subjectController = TextEditingController();
  String? _selectedRoomId;
  String? _selectedRoomName;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.attendance.status;
    _noteController.text = widget.attendance.note ?? '';
    _sessionController.text = widget.attendance.sessionName;
    _subjectController.text = widget.attendance.subject;
    _selectedRoomId =
        widget.attendance.roomId.isNotEmpty ? widget.attendance.roomId : null;
    _selectedRoomName =
        widget.attendance.roomName.isNotEmpty
            ? widget.attendance.roomName
            : null;
    _selectedTeacherId =
        widget.attendance.teacherId.isNotEmpty
            ? widget.attendance.teacherId
            : null;
    _selectedTeacherName =
        widget.attendance.teacherName.isNotEmpty
            ? widget.attendance.teacherName
            : null;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _sessionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateAttendance(widget.attendance.id, {
            'status': _selectedStatus.name,
            'note': _noteController.text.trim(),
            'sessionName': _sessionController.text.trim(),
            'subject': _subjectController.text.trim(),
            'teacherId': _selectedTeacherId ?? '',
            'teacherName': _selectedTeacherName ?? '',
            'roomId': _selectedRoomId ?? '',
            'roomName': _selectedRoomName ?? '',
            'recordedAt': Timestamp.fromDate(DateTime.now()),
          });
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = ref.watch(roomsProvider);
    final teachers = ref.watch(teachersProvider);

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
            _StudentInfoCard(attendance: widget.attendance, isDark: isDark),
            const SizedBox(height: 20),

            // ─── Current record info ───
            if (widget.attendance.summary.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.attendance.summary,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Status ───
            Text(
              'Attendance Status',
              style: AppTypography.labelMedium.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children:
                  AttendanceStatus.values.map((status) {
                    final isSelected = _selectedStatus == status;
                    final color =
                        status == AttendanceStatus.present
                            ? AppColors.present
                            : status == AttendanceStatus.absent
                            ? AppColors.absent
                            : AppColors.late;
                    final label =
                        status.name[0].toUpperCase() + status.name.substring(1);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedStatus = status),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? color.withValues(alpha: 0.12)
                                    : isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected
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
                                color: isSelected ? color : null,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: AppTypography.labelSmall.copyWith(
                                  color: isSelected ? color : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 20),

            // ─── Session ───
            AppTextField(
              label: 'Session Name',
              hint: 'e.g. Network Session, TP Python',
              controller: _sessionController,
              prefixIcon: const Icon(Icons.event_note_rounded, size: 18),
            ),
            const SizedBox(height: 14),

            // ─── Subject ───
            AppTextField(
              label: 'Subject',
              hint: 'e.g. Network, Mathematics',
              controller: _subjectController,
              prefixIcon: const Icon(Icons.menu_book_rounded, size: 18),
            ),
            const SizedBox(height: 14),

            // ─── Teacher ───
            Text(
              'Teacher',
              style: AppTypography.labelMedium.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            teachers.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('Error: $e'),
              data:
                  (list) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurface
                              : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Select teacher'),
                        value: _selectedTeacherId,
                        dropdownColor:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        items:
                            list.map((t) {
                              return DropdownMenuItem(
                                value: t.id,
                                onTap: () => _selectedTeacherName = t.name,
                                child: Text(t.name),
                              );
                            }).toList(),
                        onChanged:
                            (val) => setState(() => _selectedTeacherId = val),
                      ),
                    ),
                  ),
            ),
            const SizedBox(height: 14),

            // ─── Room ───
            Text(
              'Room',
              style: AppTypography.labelMedium.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            rooms.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('Error: $e'),
              data:
                  (list) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurface
                              : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Select room'),
                        value: _selectedRoomId,
                        dropdownColor:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        items:
                            list.map((r) {
                              return DropdownMenuItem(
                                value: r.id,
                                onTap: () => _selectedRoomName = r.name,
                                child: Text(r.name),
                              );
                            }).toList(),
                        onChanged:
                            (val) => setState(() => _selectedRoomId = val),
                      ),
                    ),
                  ),
            ),
            const SizedBox(height: 14),

            // ─── Note ───
            AppTextField(
              label: 'Note (Optional)',
              hint: 'Add a note...',
              controller: _noteController,
              maxLines: 3,
              prefixIcon: const Icon(Icons.note_rounded, size: 18),
            ),
            const SizedBox(height: 24),

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

// ─── Shared student info card ───
class _StudentInfoCard extends StatelessWidget {
  final AttendanceModel attendance;
  final bool isDark;

  const _StudentInfoCard({required this.attendance, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.accent.withValues(alpha: 0.15),
            child: Text(
              attendance.studentName.isNotEmpty
                  ? attendance.studentName[0].toUpperCase()
                  : '?',
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attendance.studentName,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                Text('Date: ${attendance.date}', style: AppTypography.caption),
                if (attendance.className.isNotEmpty)
                  Text(
                    'Class: ${attendance.className}',
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
