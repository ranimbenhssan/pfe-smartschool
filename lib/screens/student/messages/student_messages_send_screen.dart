import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class StudentmessageendScreen extends ConsumerStatefulWidget {
  const StudentmessageendScreen({super.key});

  @override
  ConsumerState<StudentmessageendScreen> createState() =>
      _StudentmessageendScreenState();
}

class _StudentmessageendScreenState
    extends ConsumerState<StudentmessageendScreen> {
  bool _isLoading = false;
  String _targetType = 'teacher';
  List<String> _selectedTeacherIds = [];
  List<String> _selectedStudentIds = [];

  Future<void> _send(
    String title,
    String message,
    MessageType messageType,
    List<AttachmentModel> attachments,
  ) async {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) return;

    if (_selectedTeacherIds.isEmpty && _selectedStudentIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one recipient')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    // ── attachments already uploaded to Cloudinary by MessageComposeWidget ──
    // AttachmentModel.url contains the Cloudinary URL.
    final attMaps = attachments.map((a) => a.toMap()).toList();
    final service = ref.read(notificationServiceProvider);

    Future<bool> sendTo(String userId) => service.sendToUser(
      userId,
      title,
      message,
      type: messageType.name,
      senderId: currentUser.id,
      senderName: currentUser.name,
      senderRole: 'student',
      attachments: attMaps, // ← file URL included here
      recipientLabel: 'Student',
    );

    try {
      for (final id in _selectedTeacherIds) {
        await sendTo(id);
      }
      for (final studentId in _selectedStudentIds) {
        final student = await ref
            .read(firestoreServiceProvider)
            .getStudent(studentId);
        if (student != null && student.userId.isNotEmpty) {
          await sendTo(student.userId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully ✅'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _targetType = 'teacher';
          _selectedTeacherIds = [];
          _selectedStudentIds = [];
        });
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

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Send Message'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Recipient type ─────────────────────────────────────────────
            Text(
              'Send To',
              style: AppTypography.labelMedium.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(
                  isDark,
                  'teacher',
                  'Teacher(s)',
                  Icons.person_pin_rounded,
                ),
                const SizedBox(width: 8),
                _chip(isDark, 'student', 'Classmate(s)', Icons.people_rounded),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Teacher selector ────────────────────────────────────────────
            if (_targetType == 'teacher') _buildTeacherSelector(isDark),

            // ─── Classmates selector ─────────────────────────────────────────
            if (_targetType == 'student') _buildClassmatesSelector(isDark),

            const SizedBox(height: 8),

            // ─── Compose widget — includes title, message, file/image attach ──
            MessageComposeWidget(
              allowedTypes: ['general', 'note', 'course'],
              isLoading: _isLoading,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(bool isDark, String value, String label, IconData icon) {
    final isSelected = _targetType == value;
    return GestureDetector(
      onTap:
          () => setState(() {
            _targetType = value;
            _selectedTeacherIds = [];
            _selectedStudentIds = [];
          }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.studentColor.withValues(alpha: 0.12)
                  : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.studentColor
                    : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.studentColor : null,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? AppColors.studentColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherSelector(bool isDark) {
    final teachers = ref.watch(teachersProvider);
    return teachers.when(
      loading: () => const LoadingWidget(),
      error: (_, __) => const SizedBox.shrink(),
      data:
          (list) => SearchableSelector<TeacherModel>(
            isDark: isDark,
            title: 'Select Teacher(s)',
            hint: 'Search teachers...',
            items: list,
            labelOf: (t) => t.name,
            subtitleOf: (t) => t.subject,
            idOf: (t) => t.id,
            selectedIds: _selectedTeacherIds,
            onToggle:
                (t, selected) => setState(
                  () =>
                      selected
                          ? _selectedTeacherIds.add(t.id)
                          : _selectedTeacherIds.remove(t.id),
                ),
            activeColor: AppColors.studentColor,
          ),
    );
  }

  Widget _buildClassmatesSelector(bool isDark) {
    final currentUser = ref.watch(currentUserProvider);
    return currentUser.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final classmates = ref.watch(studentsByClassProvider(user.id));
        return classmates.when(
          loading: () => const LoadingWidget(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            final others = list.where((s) => s.userId != user.id).toList();
            return SearchableSelector<StudentModel>(
              isDark: isDark,
              title: 'Select Classmate(s)',
              hint: 'Search classmates...',
              items: others,
              labelOf: (s) => s.name,
              subtitleOf: (s) => s.className,
              idOf: (s) => s.id,
              selectedIds: _selectedStudentIds,
              onToggle:
                  (s, selected) => setState(
                    () =>
                        selected
                            ? _selectedStudentIds.add(s.id)
                            : _selectedStudentIds.remove(s.id),
                  ),
              activeColor: AppColors.studentColor,
            );
          },
        );
      },
    );
  }
}
