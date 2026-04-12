import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isLoading = false;
  String _targetType = 'whole_school';
  List<String> _selectedClassIds = [];
  List<String> _selectedStudentIds = [];
  List<String> _selectedTeacherIds = [];

  Future<void> _send(
    String title,
    String message,
    MessageType messageType,
    List<AttachmentModel> attachments,
  ) async {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    final service = ref.read(notificationServiceProvider);
    final attMaps = attachments.map((a) => a.toMap()).toList();

    try {
      Future<bool> send(String userId) => service.sendToUser(
            userId,
            title,
            message,
            type: messageType.name,
            senderId: currentUser.id,
            senderName: currentUser.name,
            senderRole: 'admin',
            attachments: attMaps,
          );

      switch (_targetType) {
        case 'whole_school':
          await service.sendToAll(title, message,
              type: messageType.name);
          break;

        case 'class':
          for (final classId in _selectedClassIds) {
            await service.sendToClass(classId, title, message,
                type: messageType.name);
          }
          break;

        case 'student':
          for (final studentId in _selectedStudentIds) {
            final student = await ref
                .read(firestoreServiceProvider)
                .getStudent(studentId);
            if (student?.userId != null &&
                student!.userId.isNotEmpty) {
              await send(student.userId);
            }
          }
          break;

        case 'teacher':
          for (final id in _selectedTeacherIds) {
            await send(id);
          }
          break;

        case 'mixed':
          for (final id in _selectedTeacherIds) {
            await send(id);
          }
          for (final classId in _selectedClassIds) {
            await service.sendToClass(classId, title, message,
                type: messageType.name);
          }
          for (final studentId in _selectedStudentIds) {
            final student = await ref
                .read(firestoreServiceProvider)
                .getStudent(studentId);
            if (student?.userId != null &&
                student!.userId.isNotEmpty) {
              await send(student.userId);
            }
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Message sent successfully ✅')),
        );
        setState(() {
          _targetType = 'whole_school';
          _selectedClassIds = [];
          _selectedStudentIds = [];
          _selectedTeacherIds = [];
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
            Text(
              'Send To',
              style: AppTypography.labelMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildTargetSelector(isDark),
            const SizedBox(height: 16),

            if (_targetType == 'class' || _targetType == 'mixed')
              _buildClassSelector(isDark),
            if (_targetType == 'student' || _targetType == 'mixed')
              _buildStudentSelector(isDark),
            if (_targetType == 'teacher' || _targetType == 'mixed')
              _buildTeacherSelector(isDark),

            const SizedBox(height: 8),

            // ─── Compose ───
            MessageComposeWidget(
              allowedTypes: [
                'announcement', 'form', 'note', 'general'
              ],
              isLoading: _isLoading,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSelector(bool isDark) {
    final options = [
      _Opt('whole_school', 'Whole School', Icons.school_rounded),
      _Opt('class', 'Class(es)', Icons.class_rounded),
      _Opt('student', 'Student(s)', Icons.person_rounded),
      _Opt('teacher', 'Teacher(s)', Icons.person_pin_rounded),
      _Opt('mixed', 'Mixed', Icons.group_rounded),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = _targetType == opt.value;
        return GestureDetector(
          onTap: () => setState(() {
            _targetType = opt.value;
            _selectedClassIds = [];
            _selectedStudentIds = [];
            _selectedTeacherIds = [];
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : isDark
                      ? AppColors.darkCard
                      : AppColors.lightCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent
                    : isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(opt.icon,
                    size: 16,
                    color:
                        isSelected ? AppColors.accent : null),
                const SizedBox(width: 6),
                Text(
                  opt.label,
                  style: AppTypography.labelSmall.copyWith(
                    color: isSelected ? AppColors.accent : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClassSelector(bool isDark) {
    final classes = ref.watch(classesProvider);
    return SelectorSection(
      isDark: isDark,
      title: 'Select Class(es)',
      child: classes.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Text('Error: $e'),
        data: (list) => Column(
          children: list.map((cls) {
            final isSelected = _selectedClassIds.contains(cls.id);
            return SelectTile(
              isDark: isDark,
              label: cls.displayName,
              isSelected: isSelected,
              onTap: () => setState(() => isSelected
                  ? _selectedClassIds.remove(cls.id)
                  : _selectedClassIds.add(cls.id)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStudentSelector(bool isDark) {
    final students = ref.watch(studentsProvider);
    return SelectorSection(
      isDark: isDark,
      title: 'Select Student(s)',
      child: students.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Text('Error: $e'),
        data: (list) => Column(
          children: list.map((s) {
            final isSelected = _selectedStudentIds.contains(s.id);
            return SelectTile(
              isDark: isDark,
              label: s.name,
              subtitle: s.className,
              isSelected: isSelected,
              onTap: () => setState(() => isSelected
                  ? _selectedStudentIds.remove(s.id)
                  : _selectedStudentIds.add(s.id)),
            );
          }).toList(),
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

class _Opt {
  final String value, label;
  final IconData icon;
  const _Opt(this.value, this.label, this.icon);
}