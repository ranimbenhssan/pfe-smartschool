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

    // ── Serialise attachments ONCE here — every branch must use this list ──
    // AttachmentModel.url already contains the Cloudinary secure_url because
    // MessageComposeWidget uploads to Cloudinary before calling onSend().
    final attMaps = attachments.map((a) => a.toMap()).toList();

    try {
      // ── Helper: send to a single userId ──────────────────────────────────
      Future<void> sendOne(String userId, {String recipientLabel = ''}) =>
          service.sendToUser(
            userId,
            title,
            message,
            type: messageType.name,
            senderId: currentUser.id,
            senderName: currentUser.name,
            senderRole: 'admin',
            attachments: attMaps, // ← Cloudinary URLs included
            recipientLabel: recipientLabel,
          );

      switch (_targetType) {
        // ── Whole school ────────────────────────────────────────────────────
        case 'whole_school':
          await service.sendToAll(
            title,
            message,
            type: messageType.name,
            senderId: currentUser.id,
            senderName: currentUser.name,
            senderRole: 'admin',
            attachments: attMaps, // ← FIX: was missing
          );
          break;

        // ── Class(es) ───────────────────────────────────────────────────────
        case 'class':
          for (final classId in _selectedClassIds) {
            final classDoc = await ref
                .read(firestoreServiceProvider)
                .getClass(classId);
            final className = classDoc?.displayName ?? classId;

            await service.sendToClass(
              classId,
              title,
              message,
              type: messageType.name,
              senderId: currentUser.id,
              senderName: currentUser.name,
              senderRole: 'admin',
              attachments: attMaps, // ← FIX: was missing
              className: className,
            );
          }
          break;

        // ── Student(s) ──────────────────────────────────────────────────────
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

        // ── Teacher(s) ──────────────────────────────────────────────────────
        case 'teacher':
          for (final teacherId in _selectedTeacherIds) {
            await sendOne(teacherId);
          }
          break;

        // ── Mixed ───────────────────────────────────────────────────────────
        case 'mixed':
          for (final teacherId in _selectedTeacherIds) {
            await sendOne(teacherId);
          }
          for (final classId in _selectedClassIds) {
            final classDoc = await ref
                .read(firestoreServiceProvider)
                .getClass(classId);
            final className = classDoc?.displayName ?? classId;
            await service.sendToClass(
              classId,
              title,
              message,
              type: messageType.name,
              senderId: currentUser.id,
              senderName: currentUser.name,
              senderRole: 'admin',
              attachments: attMaps, // ← FIX: was missing
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

  // ─────────────────────────────────────────────────────────────────────────
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

  Widget _buildTargetSelector(bool isDark) {
    const options = [
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
          options.map((opt) {
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
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.icon,
                      size: 14,
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

  Widget _buildClassSelector(bool isDark) {
    final classes = ref.watch(classesProvider);
    return classes.when(
      loading: () => const LoadingWidget(),
      error: (_, __) => const SizedBox.shrink(),
      data:
          (list) => SearchableSelector<ClassModel>(
            isDark: isDark,
            title: 'Select Class(es)',
            hint: 'Search classes...',
            items: list,
            labelOf: (c) => c.displayName,
            idOf: (c) => c.id,
            selectedIds: _selectedClassIds,
            onToggle:
                (c, sel) => setState(
                  () =>
                      sel
                          ? _selectedClassIds.add(c.id)
                          : _selectedClassIds.remove(c.id),
                ),
            activeColor: AppColors.accent,
          ),
    );
  }

  Widget _buildStudentSelector(bool isDark) {
    final students = ref.watch(studentsProvider);
    return students.when(
      loading: () => const LoadingWidget(),
      error: (_, __) => const SizedBox.shrink(),
      data:
          (list) => SearchableSelector<StudentModel>(
            isDark: isDark,
            title: 'Select Student(s)',
            hint: 'Search students...',
            items: list,
            labelOf: (s) => s.name,
            subtitleOf: (s) => s.className,
            idOf: (s) => s.id,
            selectedIds: _selectedStudentIds,
            onToggle:
                (s, sel) => setState(
                  () =>
                      sel
                          ? _selectedStudentIds.add(s.id)
                          : _selectedStudentIds.remove(s.id),
                ),
            activeColor: AppColors.accent,
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
                (t, sel) => setState(
                  () =>
                      sel
                          ? _selectedTeacherIds.add(t.id)
                          : _selectedTeacherIds.remove(t.id),
                ),
            activeColor: AppColors.accent,
          ),
    );
  }
}

class _Opt {
  final String value, label;
  final IconData icon;
  const _Opt(this.value, this.label, this.icon);
}
