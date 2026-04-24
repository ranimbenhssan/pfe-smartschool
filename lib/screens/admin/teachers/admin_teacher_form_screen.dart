import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
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
  final _rfidController = TextEditingController();
  final _subjectController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.teacherId != null;
    if (_isEditing) _loadTeacher();
  }

  Future<void> _loadTeacher() async {
    if (widget.teacherId == null) return;

    // ─── Get teacher directly by doc ID ───
    final teacher = await ref
        .read(firestoreServiceProvider)
        .getTeacherById(widget.teacherId!);

    if (teacher != null && mounted) {
      setState(() {
        _nameController.text = teacher.name;
        _emailController.text = teacher.email;
        _rfidController.text = teacher.rfidTag;
        _subjectController.text = teacher.subject;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rfidController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        // ─── Update existing teacher ───
        await ref
            .read(firestoreServiceProvider)
            .updateTeacher(widget.teacherId!, {
              'name': _nameController.text.trim(),
              'rfidTag': _rfidController.text.trim(),
              'rfidEnabled': _rfidController.text.trim().isNotEmpty,
              'subject': _subjectController.text.trim(),
            });

        // ─── Update user doc name ───
        await ref.read(firestoreServiceProvider).updateUser(widget.teacherId!, {
          'name': _nameController.text.trim(),
        });
      } else {
        // ─── Create new teacher ───
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
                content: Text(result.error ?? 'Error creating user'),
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
          subject: _subjectController.text.trim(),
          assignedClassIds: [],
          assignedClassNames: [],
          rfidTag: _rfidController.text.trim(),
          rfidEnabled: _rfidController.text.trim().isNotEmpty,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              // ─── Name ───
              AppTextField(
                label: 'Full Name *',
                hint: 'e.g. Mohamed Ali',
                controller: _nameController,
                prefixIcon: const Icon(Icons.person_rounded, size: 18),
                validator:
                    (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Email ───
              if (!_isEditing)
                AppTextField(
                  label: 'Email *',
                  hint: 'teacher@school.com',
                  controller: _emailController,
                  prefixIcon: const Icon(Icons.email_rounded, size: 18),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Email is required';
                    }
                    if (!v.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
              if (!_isEditing) const SizedBox(height: 16),

              // ─── Password ───
              if (!_isEditing)
                AppTextField(
                  label: 'Password *',
                  hint: 'Minimum 6 characters',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 18,
                    ),
                    onPressed:
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  ),
                  validator: (v) {
                    if (!_isEditing && (v == null || v.length < 6)) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
              if (!_isEditing) const SizedBox(height: 16),

              // ─── Subject ───
              AppTextField(
                label: 'Subject (Optional)',
                hint: 'e.g. Network, Mathematics',
                controller: _subjectController,
                prefixIcon: const Icon(Icons.menu_book_rounded, size: 18),
              ),
              const SizedBox(height: 16),

              // ─── RFID ───
              AppTextField(
                label: 'RFID Tag (Optional)',
                hint: 'e.g. A1B2C3D4',
                controller: _rfidController,
                prefixIcon: const Icon(Icons.nfc_rounded, size: 18),
              ),
              if (_rfidController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.nfc_rounded,
                        color: AppColors.success,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'RFID will be enabled for this teacher',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              AppButton(
                label: _isEditing ? 'Update Teacher' : 'Add Teacher',
                onPressed: _save,
                isLoading: _isLoading,
                width: double.infinity,
                icon: _isEditing ? Icons.save_rounded : Icons.add_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
