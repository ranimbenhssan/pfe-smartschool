import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class AdminStudentFormScreen extends ConsumerStatefulWidget {
  final String? studentId;

  const AdminStudentFormScreen({super.key, this.studentId});

  @override
  ConsumerState<AdminStudentFormScreen> createState() =>
      _AdminStudentFormScreenState();
}

class _AdminStudentFormScreenState
    extends ConsumerState<AdminStudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _rfidController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedClassId;
  String? _selectedClassName;
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.studentId != null;
    if (_isEditing) _loadStudent();
  }

  Future<void> _loadStudent() async {
    final student = await ref
        .read(firestoreServiceProvider)
        .getStudent(widget.studentId!);
    if (student != null && mounted) {
      setState(() {
        _nameController.text = student.name;
        _emailController.text = student.email;
        _rfidController.text = student.rfidTag;
        _selectedClassId = student.classId;
        _selectedClassName = student.className;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _rfidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a class')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await ref
            .read(firestoreServiceProvider)
            .updateStudent(widget.studentId!, {
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
              'rfidTag': _rfidController.text.trim(),
              'classId': _selectedClassId,
              'className': _selectedClassName,
            });
      } else {
        final result = await ref
            .read(authServiceProvider)
            .createUser(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              name: _nameController.text.trim(),
              role: UserRole.student,
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

        final student = StudentModel(
          id: result.userId!,
          userId: result.userId!,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          rfidTag: _rfidController.text.trim(),
          classId: _selectedClassId!,
          className: _selectedClassName!,
          createdAt: DateTime.now(),
        );

        await ref.read(firestoreServiceProvider).addStudent(student);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Student updated successfully'
                  : 'Student added successfully',
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
    final classes = ref.watch(classesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Student' : 'Add Student'),
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
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.accent,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ─── Name ───
              AppTextField(
                label: 'Full Name',
                hint: 'Enter student full name',
                controller: _nameController,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                validator:
                    (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Email ───
              AppTextField(
                label: 'Email',
                hint: 'Enter student email',
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

              // ─── Password (new student only) ───
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

              // ─── RFID Tag ───
              AppTextField(
                label: 'RFID Tag UID',
                hint: 'Scan or enter RFID tag UID',
                controller: _rfidController,
                prefixIcon: const Icon(Icons.nfc_rounded, size: 18),
                validator:
                    (v) =>
                        v == null || v.isEmpty ? 'RFID tag is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Class Selector ───
              Text(
                'Class',
                style: AppTypography.labelMedium.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              classes.when(
                loading: () => const LoadingWidget(),
                error:
                    (e, _) => Text(
                      'Error loading classes: $e',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                data:
                    (classList) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.darkSurface
                                : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(
                            'Select a class',
                            style: AppTypography.bodyMedium.copyWith(
                              color:
                                  isDark
                                      ? AppColors.darkTextHint
                                      : AppColors.lightTextHint,
                            ),
                          ),
                          value: _selectedClassId,
                          dropdownColor:
                              isDark ? AppColors.darkCard : AppColors.lightCard,
                          items:
                              classList.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color:
                                          isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText,
                                    ),
                                  ),
                                  onTap: () => _selectedClassName = c.name,
                                );
                              }).toList(),
                          onChanged:
                              (val) => setState(() => _selectedClassId = val),
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: 32),

              // ─── Save Button ───
              AppButton(
                label: _isEditing ? 'Update Student' : 'Add Student',
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
