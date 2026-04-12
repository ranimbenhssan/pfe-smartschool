import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class TeacherNotificationSendScreen extends ConsumerStatefulWidget {
  const TeacherNotificationSendScreen({super.key});

  @override
  ConsumerState<TeacherNotificationSendScreen> createState() =>
      _TeacherNotificationSendScreenState();
}

class _TeacherNotificationSendScreenState
    extends ConsumerState<TeacherNotificationSendScreen> {
  bool _isLoading = false;
  String _targetType = 'class';
  List<String> _selectedClassIds = [];
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

    if (_targetType == 'class' && _selectedClassIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one class')),
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
        senderRole: 'teacher',
        attachments: attMaps,
      );

      if (_targetType == 'class') {
        for (final classId in _selectedClassIds) {
          // Get all students in selected classes
          final studentsSnap = await ref
              .read(firestoreServiceProvider)
              .getStudentsByClassOnce(classId);
          for (final student in studentsSnap) {
            if (student.userId.isNotEmpty) {
              await sendToUser(student.userId);
            }
          }
        }
      } else if (_targetType == 'teacher') {
        for (final id in _selectedTeacherIds) {
          await sendToUser(id);
        }
      } else if (_targetType == 'student') {
        for (final studentId in _selectedStudentIds) {
          final student = await ref
              .read(firestoreServiceProvider)
              .getStudent(studentId);
          if (student?.userId != null && student!.userId.isNotEmpty) {
            await sendToUser(student.userId);
          }
        }
      } else {
        // mixed
        for (final classId in _selectedClassIds) {
          final studentsSnap = await ref
              .read(firestoreServiceProvider)
              .getStudentsByClassOnce(classId);
          for (final student in studentsSnap) {
            if (student.userId.isNotEmpty) {
              await sendToUser(student.userId);
            }
          }
        }
        for (final id in _selectedTeacherIds) {
          await sendToUser(id);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully ✅')),
        );
        setState(() {
          _targetType = 'class';
          _selectedClassIds = [];
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
            // ─── Target type ───
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(isDark, 'class', 'Class(es)', Icons.class_rounded),
                _chip(isDark, 'student', 'Student(s)', Icons.person_rounded),
                _chip(
                  isDark,
                  'teacher',
                  'Teacher(s)',
                  Icons.person_pin_rounded,
                ),
                _chip(isDark, 'mixed', 'Mixed', Icons.group_rounded),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Class selector ───
            if (_targetType == 'class' || _targetType == 'mixed')
              currentUser.when(
                loading: () => const LoadingWidget(),
                error: (_, __) => const SizedBox.shrink(),
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  // Show only teacher's assigned classes
                  final teachers = ref.watch(teachersProvider);
                  return teachers.when(
                    loading: () => const LoadingWidget(),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) {
                      final teacher =
                          list.where((t) => t.userId == user.id).firstOrNull;
                      final myClasses = teacher?.assignedClassIds ?? [];
                      final classes = ref.watch(classesProvider);
                      return classes.when(
                        loading: () => const LoadingWidget(),
                        error: (e, _) => Text('Error: $e'),
                        data: (allClasses) {
                          final filtered =
                              allClasses
                                  .where((c) => myClasses.contains(c.id))
                                  .toList();
                          return SelectorSection(
                            isDark: isDark,
                            title: 'Select Class(es)',
                            child: Column(
                              children:
                                  filtered.map((cls) {
                                    final isSelected = _selectedClassIds
                                        .contains(cls.id);
                                    return SelectTile(
                                      isDark: isDark,
                                      label: cls.displayName,
                                      isSelected: isSelected,
                                      onTap:
                                          () => setState(
                                            () =>
                                                isSelected
                                                    ? _selectedClassIds.remove(
                                                      cls.id,
                                                    )
                                                    : _selectedClassIds.add(
                                                      cls.id,
                                                    ),
                                          ),
                                    );
                                  }).toList(),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

            // ─── Teacher selector ───
            if (_targetType == 'teacher' || _targetType == 'mixed')
              _buildTeacherSelector(isDark),

            // ─── Student selector ───
            if (_targetType == 'student') _buildStudentSelector(isDark),

            const SizedBox(height: 8),

            // ─── Compose ───
            MessageComposeWidget(
              allowedTypes: ['course', 'note', 'general'],
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
            _selectedClassIds = [];
            _selectedTeacherIds = [];
            _selectedStudentIds = [];
          }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.teacherColor.withValues(alpha: 0.12)
                  : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.teacherColor
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
              color: isSelected ? AppColors.teacherColor : null,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? AppColors.teacherColor : null,
              ),
            ),
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
        data:
            (list) => Column(
              children:
                  list.map((t) {
                    final isSelected = _selectedTeacherIds.contains(t.id);
                    return SelectTile(
                      isDark: isDark,
                      label: t.name,
                      isSelected: isSelected,
                      onTap:
                          () => setState(
                            () =>
                                isSelected
                                    ? _selectedTeacherIds.remove(t.id)
                                    : _selectedTeacherIds.add(t.id),
                          ),
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
        data:
            (list) => Column(
              children:
                  list.map((s) {
                    final isSelected = _selectedStudentIds.contains(s.id);
                    return SelectTile(
                      isDark: isDark,
                      label: s.name,
                      subtitle: s.className,
                      isSelected: isSelected,
                      onTap:
                          () => setState(
                            () =>
                                isSelected
                                    ? _selectedStudentIds.remove(s.id)
                                    : _selectedStudentIds.add(s.id),
                          ),
                    );
                  }).toList(),
            ),
      ),
    );
  }
}
