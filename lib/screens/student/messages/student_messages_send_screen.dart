import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/auth_service.dart';
import '../../../services/services.dart';        // ← notificationServiceProvider
import '../../../services/notification_service.dart'; // ← if not in services.dart
import '../../../models/models.dart';

class StudentNotificationSendScreen extends ConsumerStatefulWidget {
  const StudentNotificationSendScreen({super.key});

  @override
  ConsumerState<StudentNotificationSendScreen> createState() =>
      _StudentNotificationSendScreenState();
}

class _StudentNotificationSendScreenState
    extends ConsumerState<StudentNotificationSendScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  String _targetType = 'teacher';
  List<String> _selectedTeacherIds = [];
  List<String> _selectedStudentIds = [];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in title and message')),
      );
      return;
    }

    if (_targetType == 'teacher' && _selectedTeacherIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one teacher')),
      );
      return;
    }

    if (_targetType == 'student' && _selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one classmate')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final title = _titleController.text.trim();
      final message = _messageController.text.trim();

      Future<void> sendToUser(String userId) async {
        await ref
            .read(notificationServiceProvider)
            .sendToUser(
              userId,
              title,
              message,
              type: MessageType.general.name,
              senderId: currentUser.id,
              senderName: currentUser.name,
              senderRole: 'student',
              recipientLabel: '',
            );
      }

      if (_targetType == 'teacher' || _targetType == 'mixed') {
        for (final id in _selectedTeacherIds) {
          await sendToUser(id);
        }
      }

      if (_targetType == 'student' || _targetType == 'mixed') {
        for (final studentId in _selectedStudentIds) {
          final student = await ref
              .read(firestoreServiceProvider)
              .getStudent(studentId);
          if (student != null && student.userId.isNotEmpty) {
            await sendToUser(student.userId);
          }
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
          _titleController.clear();
          _messageController.clear();
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
            // ─── Target type chips ───
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
                const SizedBox(width: 8),
                _chip(isDark, 'mixed', 'Mixed', Icons.group_rounded),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Teacher selector ───
            if (_targetType == 'teacher' || _targetType == 'mixed')
              _buildTeacherSelector(isDark),

            // ─── Classmates selector ───
            if (_targetType == 'student' || _targetType == 'mixed')
              _buildClassmatesSelector(isDark),

            // ─── Title ───
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Message title',
                prefixIcon: const Icon(Icons.title_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Message ───
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'Write your message here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Send button ───
            AppButton(
              label: _isLoading ? 'Sending...' : 'Send Message',
              onPressed: _isLoading ? () {} : _send,
              isLoading: _isLoading,
              width: double.infinity,
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Target type chip ───
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

  // ─── Teacher selector with search ───
  Widget _buildTeacherSelector(bool isDark) {
    final teachers = ref.watch(teachersProvider);
    return teachers.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('Error: $e'),
      data:
          (list) => SearchableSelector<TeacherModel>(
            isDark: isDark,
            title: 'Select Teacher(s)',
            hint: 'Search teacher by name or subject...',
            items: list,
            labelOf: (t) => t.name,
            subtitleOf:
                (t) =>
                    t.subject.isNotEmpty
                        ? t.subject
                        : t.assignedClassNames.join(', '),
            idOf: (t) => t.id,
            selectedIds: _selectedTeacherIds,
            activeColor: AppColors.studentColor,
            onToggle:
                (t, isSelected) => setState(
                  () =>
                      isSelected
                          ? _selectedTeacherIds.remove(t.id)
                          : _selectedTeacherIds.add(t.id),
                ),
          ),
    );
  }

  // ─── Classmates selector with search ───
  Widget _buildClassmatesSelector(bool isDark) {
    final currentUser = ref.watch(currentUserProvider);
    return currentUser.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('Error: $e'),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final classmates = ref.watch(studentsByClassProvider(user.id));
        return classmates.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            // ─── Exclude current user ───
            final others = list.where((s) => s.userId != user.id).toList();

            if (others.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
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
                    Icon(
                      Icons.people_outline_rounded,
                      color:
                          isDark
                              ? AppColors.darkTextHint
                              : AppColors.lightTextHint,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'No classmates found in your class',
                      style: AppTypography.bodySmall.copyWith(
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

            return SearchableSelector<StudentModel>(
              isDark: isDark,
              title: 'Select Classmate(s)',
              hint: 'Search classmate by name...',
              items: others,
              labelOf: (s) => s.name,
              subtitleOf: (s) => s.classDisplay,
              idOf: (s) => s.id,
              selectedIds: _selectedStudentIds,
              activeColor: AppColors.studentColor,
              onToggle:
                  (s, isSelected) => setState(
                    () =>
                        isSelected
                            ? _selectedStudentIds.remove(s.id)
                            : _selectedStudentIds.add(s.id),
                  ),
            );
          },
        );
      },
    );
  }
}
