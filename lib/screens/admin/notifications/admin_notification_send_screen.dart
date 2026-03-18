import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class AdminNotificationSendScreen extends ConsumerStatefulWidget {
  const AdminNotificationSendScreen({super.key});

  @override
  ConsumerState<AdminNotificationSendScreen> createState() =>
      _AdminNotificationSendScreenState();
}

class _AdminNotificationSendScreenState
    extends ConsumerState<AdminNotificationSendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _recipientType = 'all';
  String? _selectedUserId;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      if (_recipientType == 'all') {
        // Send to all users
        final students = await firestoreService.getStudents().first;
        final teachers = await firestoreService.getTeachers().first;

        for (final student in students) {
          await _sendNotification(firestoreService, student.userId);
        }
        for (final teacher in teachers) {
          await _sendNotification(firestoreService, teacher.userId);
        }
      } else if (_recipientType == 'specific' && _selectedUserId != null) {
        await _sendNotification(firestoreService, _selectedUserId!);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent successfully')),
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

  Future<void> _sendNotification(
    dynamic firestoreService,
    String userId,
  ) async {
    final notification = NotificationModel(
      id: const Uuid().v4(),
      userId: userId,
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
      type: NotificationType.general,
      isRead: false,
      createdAt: DateTime.now(),
    );
    await firestoreService.addNotification(notification);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = ref.watch(studentsProvider);
    final teachers = ref.watch(teachersProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Send Notification'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Title ───
              AppTextField(
                label: 'Title',
                hint: 'Notification title',
                controller: _titleController,
                prefixIcon: const Icon(Icons.title_rounded, size: 18),
                validator:
                    (v) => v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Message ───
              AppTextField(
                label: 'Message',
                hint: 'Write your message here...',
                controller: _messageController,
                maxLines: 4,
                prefixIcon: const Icon(Icons.message_rounded, size: 18),
                validator:
                    (v) =>
                        v == null || v.isEmpty ? 'Message is required' : null,
              ),
              const SizedBox(height: 24),

              // ─── Recipient Type ───
              Text(
                'Send To',
                style: AppTypography.labelMedium.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _RecipientOption(
                isDark: isDark,
                label: 'Everyone',
                subtitle: 'Send to all students and teachers',
                icon: Icons.people_rounded,
                isSelected: _recipientType == 'all',
                onTap:
                    () => setState(() {
                      _recipientType = 'all';
                      _selectedUserId = null;
                    }),
              ),
              const SizedBox(height: 8),
              _RecipientOption(
                isDark: isDark,
                label: 'Specific Student',
                subtitle: 'Choose a student',
                icon: Icons.person_rounded,
                isSelected: _recipientType == 'student',
                onTap: () => setState(() => _recipientType = 'student'),
              ),
              const SizedBox(height: 8),
              _RecipientOption(
                isDark: isDark,
                label: 'Specific Teacher',
                subtitle: 'Choose a teacher',
                icon: Icons.school_rounded,
                isSelected: _recipientType == 'teacher',
                onTap: () => setState(() => _recipientType = 'teacher'),
              ),
              const SizedBox(height: 16),

              // ─── User Selector ───
              if (_recipientType == 'student')
                students.when(
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Text('Error: $e'),
                  data:
                      (list) => _buildUserDropdown(
                        isDark: isDark,
                        hint: 'Select student',
                        items:
                            list
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s.userId,
                                    child: Text(s.name),
                                  ),
                                )
                                .toList(),
                      ),
                ),

              if (_recipientType == 'teacher')
                teachers.when(
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Text('Error: $e'),
                  data:
                      (list) => _buildUserDropdown(
                        isDark: isDark,
                        hint: 'Select teacher',
                        items:
                            list
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t.userId,
                                    child: Text(t.name),
                                  ),
                                )
                                .toList(),
                      ),
                ),

              const SizedBox(height: 32),

              // ─── Send Button ───
              AppButton(
                label: 'Send Notification',
                onPressed: _send,
                isLoading: _isLoading,
                width: double.infinity,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserDropdown({
    required bool isDark,
    required String hint,
    required List<DropdownMenuItem<String>> items,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint),
          value: _selectedUserId,
          dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          items: items,
          onChanged: (val) => setState(() => _selectedUserId = val),
        ),
      ),
    );
  }
}

class _RecipientOption extends StatelessWidget {
  final bool isDark;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecipientOption({
    required this.isDark,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.accent.withValues(alpha: 0.08)
                  : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.accent
                    : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : isDark
                        ? AppColors.darkSurface
                        : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color:
                    isSelected
                        ? AppColors.accent
                        : isDark
                        ? AppColors.darkTextHint
                        : AppColors.lightTextHint,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelLarge.copyWith(
                      color:
                          isSelected
                              ? AppColors.accent
                              : isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                    ),
                  ),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
