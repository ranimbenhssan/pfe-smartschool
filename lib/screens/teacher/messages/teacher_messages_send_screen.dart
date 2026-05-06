import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class TeachermessageendScreen extends ConsumerStatefulWidget {
  const TeachermessageendScreen({super.key});

  @override
  ConsumerState<TeachermessageendScreen> createState() =>
      _TeachermessageendScreenState();
}

class _TeachermessageendScreenState
    extends ConsumerState<TeachermessageendScreen> {
  bool _isLoading = false;
  String _targetType = 'class';
  List<String> _selectedClassIds = [];
  List<String> _selectedTeacherIds = [];
  List<String> _selectedStudentIds = [];

  // ── SEND ─────────────────────────────────────────────────────────────────
  Future<void> _send(
    String title,
    String message,
    MessageType messageType,
    List<AttachmentModel> attachments,
  ) async {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) return;

    if (_targetType == 'class' && _selectedClassIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one class')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final service = ref.read(notificationServiceProvider);
    final attMaps = attachments.map((a) => a.toMap()).toList();

    Future<void> sendToUser(String userId) => service.sendToUser(
      userId,
      title,
      message,
      type: messageType.name,
      senderId: currentUser.id,
      senderName: currentUser.name,
      senderRole: 'teacher',
      attachments: attMaps,
    );

    try {
      if (_targetType == 'class') {
        for (final classId in _selectedClassIds) {
          final students = await ref
              .read(firestoreServiceProvider)
              .getStudentsByClassOnce(classId);
          for (final s in students) {
            if (s.userId.isNotEmpty) await sendToUser(s.userId);
          }
        }
      } else if (_targetType == 'teacher') {
        for (final id in _selectedTeacherIds) {
          await sendToUser(id);
        }
      } else if (_targetType == 'student') {
        for (final studentId in _selectedStudentIds) {
          final s = await ref
              .read(firestoreServiceProvider)
              .getStudent(studentId);
          if (s != null && s.userId.isNotEmpty) await sendToUser(s.userId);
        }
      } else {
        // mixed — class + teacher
        for (final classId in _selectedClassIds) {
          final students = await ref
              .read(firestoreServiceProvider)
              .getStudentsByClassOnce(classId);
          for (final s in students) {
            if (s.userId.isNotEmpty) await sendToUser(s.userId);
          }
        }
        for (final id in _selectedTeacherIds) {
          await sendToUser(id);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message sent ✅')));
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

  // ── BUILD ─────────────────────────────────────────────────────────────────
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
            // ── Target chips ───────────────────────────────────────────────
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

            // ── Class selector — teacher's assigned classes only ────────────
            // Shown for 'class' and 'mixed' targets
            if (_targetType == 'class' || _targetType == 'mixed')
              _buildClassSelector(isDark),

            // ── Teacher selector ────────────────────────────────────────────
            // Shown for 'teacher' and 'mixed' targets
            if (_targetType == 'teacher' || _targetType == 'mixed')
              _buildTeacherSelector(isDark),

            // ── Student selector ─────────────────────────────────────────────
            if (_targetType == 'student') _buildStudentSelector(isDark),

            const SizedBox(height: 8),
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

  // ── Chip ──────────────────────────────────────────────────────────────────
  Widget _chip(bool isDark, String value, String label, IconData icon) {
    final sel = _targetType == value;
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
              sel
                  ? AppColors.teacherColor.withValues(alpha: 0.12)
                  : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                sel
                    ? AppColors.teacherColor
                    : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: sel ? AppColors.teacherColor : null),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: sel ? AppColors.teacherColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CLASS SELECTOR ────────────────────────────────────────────────────────
  // Shows ONLY the classes assigned to this teacher (via assignedClassIds)
  // Uses teacherClassIdsProvider then looks up ClassModel for each id.
  Widget _buildClassSelector(bool isDark) {
    final classIdsAsync = ref.watch(teacherClassIdsProvider);

    return classIdsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('Error: $e'),
      data: (classIds) {
        if (classIds.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.class_outlined,
                  color:
                      isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text('No classes assigned yet', style: AppTypography.caption),
              ],
            ),
          );
        }

        // Resolve ClassModel objects for the assigned classIds
        final classesAsync = ref.watch(classesProvider);
        return classesAsync.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => Text('Error: $e'),
          data: (allClasses) {
            // Filter to only the teacher's assigned classes
            final myClasses =
                allClasses.where((c) => classIds.contains(c.id)).toList();

            if (myClasses.isEmpty) {
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
                child: Text(
                  'Assigned classes not found',
                  style: AppTypography.caption,
                ),
              );
            }

            return SearchableSelector<ClassModel>(
              isDark: isDark,
              title: 'Select Class(es)',
              hint: 'Search by class name...',
              items: myClasses,
              labelOf: (c) => c.displayName,
              subtitleOf: (c) => c.grade,
              idOf: (c) => c.id,
              selectedIds: _selectedClassIds,
              activeColor: AppColors.teacherColor,
              onToggle:
                  (cls, isCurrentlySelected) => setState(() {
                    if (isCurrentlySelected) {
                      _selectedClassIds.remove(cls.id);
                    } else {
                      _selectedClassIds.add(cls.id);
                    }
                  }),
            );
          },
        );
      },
    );
  }

  // ── TEACHER SELECTOR ─────────────────────────────────────────────────────
  Widget _buildTeacherSelector(bool isDark) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final teachers = ref.watch(teachersProvider);

    return teachers.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('Error: $e'),
      data: (list) {
        // Exclude self from the list
        final selfId = currentUserAsync.value?.id ?? '';
        final others = list.where((t) => t.userId != selfId).toList();

        return SearchableSelector<TeacherModel>(
          isDark: isDark,
          title: 'Select Teacher(s)',
          hint: 'Search by name...',
          items: others,
          labelOf: (t) => t.name,
          subtitleOf: (t) => t.subject.isNotEmpty ? t.subject : '',
          idOf: (t) => t.id,
          selectedIds: _selectedTeacherIds,
          activeColor: AppColors.teacherColor,
          onToggle:
              (t, isCurrentlySelected) => setState(() {
                if (isCurrentlySelected) {
                  _selectedTeacherIds.remove(t.id);
                } else {
                  _selectedTeacherIds.add(t.id);
                }
              }),
        );
      },
    );
  }

  // ── STUDENT SELECTOR ─────────────────────────────────────────────────────
  // Shows all students in teacher's assigned classes
  Widget _buildStudentSelector(bool isDark) {
    final classIdsAsync = ref.watch(teacherClassIdsProvider);

    return classIdsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('Error: $e'),
      data: (classIds) {
        final students = ref.watch(studentsProvider);
        return students.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => Text('Error: $e'),
          data: (list) {
            // Only students in this teacher's classes
            final myStudents =
                classIds.isEmpty
                    ? list
                    : list.where((s) => classIds.contains(s.classId)).toList();

            return SearchableSelector<StudentModel>(
              isDark: isDark,
              title: 'Select Student(s)',
              hint: 'Search by name...',
              items: myStudents,
              labelOf: (s) => s.name,
              subtitleOf: (s) => s.classDisplay,
              idOf: (s) => s.id,
              selectedIds: _selectedStudentIds,
              activeColor: AppColors.teacherColor,
              onToggle:
                  (s, isCurrentlySelected) => setState(() {
                    if (isCurrentlySelected) {
                      _selectedStudentIds.remove(s.id);
                    } else {
                      _selectedStudentIds.add(s.id);
                    }
                  }),
            );
          },
        );
      },
    );
  }
}
