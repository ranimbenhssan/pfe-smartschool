import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class AdminmessageendScreen extends ConsumerStatefulWidget {
  const AdminmessageendScreen({super.key});

  @override
  ConsumerState<AdminmessageendScreen> createState() =>
      _AdminmessageendScreenState();
}

class _AdminmessageendScreenState extends ConsumerState<AdminmessageendScreen> {
  bool _isLoading = false;
  String _targetType = 'whole_school';
  List<String> _selectedClassIds = [];
  List<String> _selectedStudentIds = [];
  List<String> _selectedTeacherIds = [];

  // ── SEND ─────────────────────────────────────────────────────────────────
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

    Future<void> sendOne(String userId, {String recipientLabel = ''}) =>
        service.sendToUser(
          userId,
          title,
          message,
          type: messageType.name,
          senderId: currentUser.id,
          senderName: currentUser.name,
          senderRole: 'admin',
          attachments: attMaps,
          recipientLabel: recipientLabel,
        );

    try {
      switch (_targetType) {
        case 'whole_school':
          await service.sendToAll(
            title,
            message,
            type: messageType.name,
            senderId: currentUser.id,
            senderName: currentUser.name,
            senderRole: 'admin',
            attachments: attMaps,
          );
          break;

        case 'class':
          for (final classId in _selectedClassIds) {
            final cls = await ref
                .read(firestoreServiceProvider)
                .getClass(classId);
            final className = cls?.displayName ?? classId;
            await service.sendToClass(
              classId,
              title,
              message,
              type: messageType.name,
              senderId: currentUser.id,
              senderName: currentUser.name,
              senderRole: 'admin',
              attachments: attMaps,
              className: className,
            );
          }
          break;

        case 'student':
          for (final studentId in _selectedStudentIds) {
            final student = await ref
                .read(firestoreServiceProvider)
                .getStudent(studentId);
            if (student != null && student.userId.isNotEmpty) {
              await sendOne(student.userId, recipientLabel: student.name);
            }
          }
          break;

        case 'teacher':
          for (final teacherId in _selectedTeacherIds) {
            await sendOne(teacherId);
          }
          break;

        case 'mixed':
          for (final teacherId in _selectedTeacherIds) {
            await sendOne(teacherId);
          }
          for (final classId in _selectedClassIds) {
            final cls = await ref
                .read(firestoreServiceProvider)
                .getClass(classId);
            final className = cls?.displayName ?? classId;
            await service.sendToClass(
              classId,
              title,
              message,
              type: messageType.name,
              senderId: currentUser.id,
              senderName: currentUser.name,
              senderRole: 'admin',
              attachments: attMaps,
              className: className,
            );
          }
          for (final studentId in _selectedStudentIds) {
            final student = await ref
                .read(firestoreServiceProvider)
                .getStudent(studentId);
            if (student != null && student.userId.isNotEmpty) {
              await sendOne(student.userId, recipientLabel: student.name);
            }
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message sent ✅')));
        setState(() {
          _targetType = 'whole_school';
          _selectedClassIds = [];
          _selectedStudentIds = [];
          _selectedTeacherIds = [];
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
            _buildTargetSelector(isDark),
            const SizedBox(height: 16),

            if (_targetType == 'class' || _targetType == 'mixed')
              _buildClassSelector(isDark),
            if (_targetType == 'student' || _targetType == 'mixed')
              _buildStudentSelector(isDark),
            if (_targetType == 'teacher' || _targetType == 'mixed')
              _buildTeacherSelector(isDark),

            const SizedBox(height: 8),
            MessageComposeWidget(
              allowedTypes: ['announcement', 'form', 'note', 'general'],
              isLoading: _isLoading,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  // ── TARGET TYPE CHIPS ─────────────────────────────────────────────────────
  Widget _buildTargetSelector(bool isDark) {
    const opts = [
      _Opt('whole_school', 'Whole School', Icons.school_rounded),
      _Opt('class', 'Class(es)', Icons.class_rounded),
      _Opt('student', 'Student(s)', Icons.person_rounded),
      _Opt('teacher', 'Teacher(s)', Icons.person_pin_rounded),
      _Opt('mixed', 'Mixed', Icons.group_rounded),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          opts.map((opt) {
            final sel = _targetType == opt.value;
            return GestureDetector(
              onTap:
                  () => setState(() {
                    _targetType = opt.value;
                    _selectedClassIds = [];
                    _selectedStudentIds = [];
                    _selectedTeacherIds = [];
                  }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      sel
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : isDark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        sel
                            ? AppColors.accent
                            : isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.icon,
                      size: 16,
                      color: sel ? AppColors.accent : null,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      opt.label,
                      style: AppTypography.labelSmall.copyWith(
                        color: sel ? AppColors.accent : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  // ── CLASS SELECTOR ────────────────────────────────────────────────────────
  Widget _buildClassSelector(bool isDark) {
    final classes = ref.watch(classesProvider);
    return classes.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('Error: $e'),
      data:
          (list) => SearchableSelector<ClassModel>(
            isDark: isDark,
            title: 'Select Class(es)',
            hint: 'Search by name...',
            items: list,
            labelOf: (c) => c.displayName,
            subtitleOf: (c) => c.grade,
            idOf: (c) => c.id,
            selectedIds: _selectedClassIds,
            activeColor: AppColors.accent,
            onToggle:
                (cls, isCurrentlySelected) => setState(() {
                  // isCurrentlySelected = true means it's already in the list → remove
                  // isCurrentlySelected = false means it's not in the list → add
                  if (isCurrentlySelected) {
                    _selectedClassIds.remove(cls.id);
                  } else {
                    _selectedClassIds.add(cls.id);
                  }
                }),
          ),
    );
  }

  // ── STUDENT SELECTOR ──────────────────────────────────────────────────────
  Widget _buildStudentSelector(bool isDark) {
    final students = ref.watch(studentsProvider);
    return students.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('Error: $e'),
      data:
          (list) => SearchableSelector<StudentModel>(
            isDark: isDark,
            title: 'Select Student(s)',
            hint: 'Search by name or class...',
            items: list,
            labelOf: (s) => s.name,
            subtitleOf: (s) => s.classDisplay,
            idOf: (s) => s.id,
            selectedIds: _selectedStudentIds,
            activeColor: AppColors.accent,
            onToggle:
                (s, isCurrentlySelected) => setState(() {
                  if (isCurrentlySelected) {
                    _selectedStudentIds.remove(s.id);
                  } else {
                    _selectedStudentIds.add(s.id);
                  }
                }),
          ),
    );
  }

  // ── TEACHER SELECTOR ──────────────────────────────────────────────────────
  Widget _buildTeacherSelector(bool isDark) {
    final teachers = ref.watch(teachersProvider);
    return teachers.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('Error: $e'),
      data:
          (list) => SearchableSelector<TeacherModel>(
            isDark: isDark,
            title: 'Select Teacher(s)',
            hint: 'Search by name or subject...',
            items: list,
            labelOf: (t) => t.name,
            subtitleOf: (t) => t.subject.isNotEmpty ? t.subject : '',
            idOf: (t) => t.id,
            selectedIds: _selectedTeacherIds,
            activeColor: AppColors.accent,
            onToggle:
                (t, isCurrentlySelected) => setState(() {
                  if (isCurrentlySelected) {
                    _selectedTeacherIds.remove(t.id);
                  } else {
                    _selectedTeacherIds.add(t.id);
                  }
                }),
          ),
    );
  }
}

class _Opt {
  final String value, label;
  final IconData icon;
  const _Opt(this.value, this.label, this.icon);
}
