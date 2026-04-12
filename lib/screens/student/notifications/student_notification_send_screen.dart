import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class StudentNotificationSendScreen extends ConsumerStatefulWidget {
  const StudentNotificationSendScreen({super.key});

  @override
  ConsumerState<StudentNotificationSendScreen> createState() =>
      _StudentNotificationSendScreenState();
}

class _StudentNotificationSendScreenState
    extends ConsumerState<StudentNotificationSendScreen> {
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
     if (!mounted) return;

    if (_targetType == 'teacher' && _selectedTeacherIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one teacher')),
      );
      return;
    }
    if (_targetType == 'student' && _selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one student')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final service = ref.read(notificationServiceProvider);
    final attMaps = attachments.map((a) => a.toMap()).toList();

    try {
      Future<bool> sendToUser(String userId) => service.sendToUser(
            userId,
            title,
            message,
            type: messageType.name,
            senderId: currentUser.id,
            senderName: currentUser.name,
            senderRole: 'student',
            attachments: attMaps,
          );

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
          if (student?.userId != null &&
              student!.userId.isNotEmpty) {
            await sendToUser(student.userId);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Message sent successfully ✅')),
        );
        setState(() {
          _targetType = 'teacher';
          _selectedTeacherIds = [];
          _selectedStudentIds = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

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
            // ─── Target ───
            Text('Send To',
                style: AppTypography.labelMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(isDark, 'teacher', 'Teacher(s)',
                    Icons.person_pin_rounded),
                const SizedBox(width: 8),
                _chip(isDark, 'student', 'Classmate(s)',
                    Icons.people_rounded),
                const SizedBox(width: 8),
                _chip(isDark, 'mixed', 'Mixed',
                    Icons.group_rounded),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Teacher selector ───
            if (_targetType == 'teacher' || _targetType == 'mixed')
              _buildTeacherSelector(isDark),

            // ─── Student selector (classmates only) ───
            if (_targetType == 'student' || _targetType == 'mixed')
              currentUser.when(
                loading: () => const LoadingWidget(),
                error: (_, __) => const SizedBox.shrink(),
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  final classmates =
                      ref.watch(studentsByClassProvider(user.id));
                  return SelectorSection(
                    isDark: isDark,
                    title: 'Select Classmate(s)',
                    child: classmates.when(
                      loading: () => const LoadingWidget(),
                      error: (e, _) => Text('Error: $e'),
                      data: (list) => Column(
                        children: list
                            .where((s) => s.userId != user.id)
                            .map((s) {
                          final isSelected =
                              _selectedStudentIds.contains(s.id);
                          return SelectTile(
                            isDark: isDark,
                            label: s.name,
                            isSelected: isSelected,
                            onTap: () => setState(() => isSelected
                                ? _selectedStudentIds.remove(s.id)
                                : _selectedStudentIds.add(s.id)),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 8),

            // ─── Compose ───
            MessageComposeWidget(
              allowedTypes: ['report', 'general'],
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
      onTap: () => setState(() {
        _targetType = value;
        _selectedTeacherIds = [];
        _selectedStudentIds = [];
      }),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.studentColor.withValues(alpha: 0.12)
              : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.studentColor
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? AppColors.studentColor : null),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.labelSmall.copyWith(
                  color:
                      isSelected ? AppColors.studentColor : null,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherSelector(bool isDark) {
    final teachers = ref.watch(teachersProvider);
    return SelectorSection(
      isDark: isDark,
      title: 'Select Teacher(s)',
      child: teachers.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Text('Error: $e'),
        data: (list) => Column(
          children: list.map((t) {
            final isSelected = _selectedTeacherIds.contains(t.id);
            return SelectTile(
              isDark: isDark,
              label: t.name,
              subtitle: t.assignedClassNames.join(', '),
              isSelected: isSelected,
              onTap: () => setState(() => isSelected
                  ? _selectedTeacherIds.remove(t.id)
                  : _selectedTeacherIds.add(t.id)),
            );
          }).toList(),
        ),
      ),
    );
  }
}