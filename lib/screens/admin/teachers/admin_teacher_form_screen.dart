import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class AdminTeacherFormScreen extends ConsumerStatefulWidget {
  final String? teacherId;

  const AdminTeacherFormScreen({super.key, this.teacherId});

  @override
  ConsumerState<AdminTeacherFormScreen> createState() =>
      _AdminTeacherFormScreenState();
}

class _AdminTeacherFormScreenState
    extends ConsumerState<AdminTeacherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  List<String> _selectedClassIds = [];
  List<String> _selectedClassNames = [];
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.teacherId != null;
    if (_isEditing) _loadTeacher();
  }

  Future<void> _loadTeacher() async {
    final teacher = await ref
        .read(firestoreServiceProvider)
        .getTeacher(widget.teacherId!);
    if (teacher != null && mounted) {
      setState(() {
        _nameController.text = teacher.name;
        _emailController.text = teacher.email;
        _selectedClassIds = List.from(teacher.assignedClassIds);
        _selectedClassNames = List.from(teacher.assignedClassNames);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await ref
            .read(firestoreServiceProvider)
            .updateTeacher(widget.teacherId!, {
              'name': _nameController.text.trim(),
              'assignedClassIds': _selectedClassIds,
              'assignedClassNames': _selectedClassNames,
            });
      } else {
        final result = await ref
            .read(authServiceProvider)
            .createUser(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              name: _nameController.text.trim(),
              role: UserRole.teacher,
            );

        if (!result.isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.errorMessage ?? 'Error creating user'),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        final teacher = TeacherModel(
          id: result.userId!,
          userId: result.userId!,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          assignedClassIds: _selectedClassIds,
          assignedClassNames: _selectedClassNames,
          createdAt: DateTime.now(),
        );

        await ref.read(firestoreServiceProvider).addTeacher(teacher);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Teacher updated successfully'
                  : 'Teacher added successfully',
            ),
          ),
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

  void _toggleClass(String classId, String className) {
    setState(() {
      if (_selectedClassIds.contains(classId)) {
        _selectedClassIds.remove(classId);
        _selectedClassNames.remove(className);
      } else {
        _selectedClassIds.add(classId);
        _selectedClassNames.add(className);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Teacher' : 'Add Teacher'),
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
              // ─── Avatar ───
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.teacherColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.teacherColor,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ─── Name ───
              AppTextField(
                label: 'Full Name',
                hint: 'Enter teacher full name',
                controller: _nameController,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                validator:
                    (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Email ───
              AppTextField(
                label: 'Email',
                hint: 'Enter teacher email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 18),
                enabled: !_isEditing,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ─── Password (new teacher only) ───
              if (!_isEditing) ...[
                AppTextField(
                  label: 'Password',
                  hint: 'Set initial password',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password is required';
                    }
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ─── Assign Classes ───
              Text(
                'Assign Classes',
                style: AppTypography.labelMedium.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              classes.when(
                loading: () => const LoadingWidget(),
                error:
                    (e, _) => Text(
                      'Error: $e',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                data:
                    (classList) =>
                        classList.isEmpty
                            ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppColors.darkCard
                                        : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder,
                                ),
                              ),
                              child: Text(
                                'No classes available. Add classes first.',
                                style: AppTypography.bodySmall.copyWith(
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                ),
                              ),
                            )
                            : Column(
                              children:
                                  classList.map((c) {
                                    final isSelected = _selectedClassIds
                                        .contains(c.id);
                                    return GestureDetector(
                                      onTap: () => _toggleClass(c.id, c.name),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? AppColors.teacherColor
                                                      .withValues(alpha: 0.08)
                                                  : isDark
                                                  ? AppColors.darkCard
                                                  : AppColors.lightCard,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color:
                                                isSelected
                                                    ? AppColors.teacherColor
                                                        .withValues(alpha: 0.4)
                                                    : isDark
                                                    ? AppColors.darkBorder
                                                    : AppColors.lightBorder,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.check_box_rounded
                                                  : Icons
                                                      .check_box_outline_blank_rounded,
                                              color:
                                                  isSelected
                                                      ? AppColors.teacherColor
                                                      : isDark
                                                      ? AppColors.darkTextHint
                                                      : AppColors.lightTextHint,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c.name,
                                                    style: AppTypography
                                                        .labelLarge
                                                        .copyWith(
                                                          color:
                                                              isDark
                                                                  ? AppColors
                                                                      .darkText
                                                                  : AppColors
                                                                      .lightText,
                                                        ),
                                                  ),
                                                  Text(
                                                    'Grade: ${c.grade}',
                                                    style:
                                                        AppTypography.caption,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
              ),
              const SizedBox(height: 32),

              // ─── Save Button ───
              AppButton(
                label: _isEditing ? 'Update Teacher' : 'Add Teacher',
                onPressed: _save,
                isLoading: _isLoading,
                width: double.infinity,
                icon:
                    _isEditing ? Icons.save_rounded : Icons.person_add_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
