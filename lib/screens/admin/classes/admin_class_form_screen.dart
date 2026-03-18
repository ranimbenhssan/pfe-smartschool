import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class AdminClassFormScreen extends ConsumerStatefulWidget {
  final String? classId;

  const AdminClassFormScreen({super.key, this.classId});

  @override
  ConsumerState<AdminClassFormScreen> createState() =>
      _AdminClassFormScreenState();
}

class _AdminClassFormScreenState extends ConsumerState<AdminClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  String? _selectedRoomId;
  String? _selectedRoomName;
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.classId != null;
    if (_isEditing) _loadClass();
  }

  Future<void> _loadClass() async {
    final cls = await ref
        .read(firestoreServiceProvider)
        .getClass(widget.classId!);
    if (cls != null && mounted) {
      setState(() {
        _nameController.text = cls.name;
        _gradeController.text = cls.grade;
        _selectedTeacherId = cls.teacherId;
        _selectedTeacherName = cls.teacherName;
        _selectedRoomId = cls.roomId;
        _selectedRoomName = cls.roomName;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await ref.read(firestoreServiceProvider).updateClass(widget.classId!, {
          'name': _nameController.text.trim(),
          'grade': _gradeController.text.trim(),
          'teacherId': _selectedTeacherId ?? '',
          'teacherName': _selectedTeacherName ?? '',
          'roomId': _selectedRoomId ?? '',
          'roomName': _selectedRoomName ?? '',
        });
      } else {
        final classModel = ClassModel(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          grade: _gradeController.text.trim(),
          teacherId: _selectedTeacherId ?? '',
          teacherName: _selectedTeacherName ?? '',
          roomId: _selectedRoomId ?? '',
          roomName: _selectedRoomName ?? '',
          studentCount: 0,
          createdAt: DateTime.now(),
        );
        await ref.read(firestoreServiceProvider).addClass(classModel);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Class updated successfully'
                  : 'Class added successfully',
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
    final teachers = ref.watch(teachersProvider);
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Class' : 'Add Class'),
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
              // ─── Class Name ───
              AppTextField(
                label: 'Class Name',
                hint: 'e.g. Class 3A',
                controller: _nameController,
                prefixIcon: const Icon(Icons.class_rounded, size: 18),
                validator:
                    (v) =>
                        v == null || v.isEmpty
                            ? 'Class name is required'
                            : null,
              ),
              const SizedBox(height: 16),

              // ─── Grade ───
              AppTextField(
                label: 'Grade',
                hint: 'e.g. Grade 3',
                controller: _gradeController,
                prefixIcon: const Icon(Icons.grade_rounded, size: 18),
                validator:
                    (v) => v == null || v.isEmpty ? 'Grade is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Teacher Selector ───
              _buildDropdownLabel(isDark, 'Assign Teacher (Optional)'),
              const SizedBox(height: 6),
              teachers.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
                data:
                    (list) => _buildDropdown(
                      isDark: isDark,
                      hint: 'Select a teacher',
                      value: _selectedTeacherId,
                      items:
                          list
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name),
                                  onTap: () => _selectedTeacherName = t.name,
                                ),
                              )
                              .toList(),
                      onChanged:
                          (val) => setState(() => _selectedTeacherId = val),
                    ),
              ),
              const SizedBox(height: 16),

              // ─── Room Selector ───
              _buildDropdownLabel(isDark, 'Assign Room (Optional)'),
              const SizedBox(height: 6),
              rooms.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
                data:
                    (list) => _buildDropdown(
                      isDark: isDark,
                      hint: 'Select a room',
                      value: _selectedRoomId,
                      items:
                          list
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text(r.name),
                                  onTap: () => _selectedRoomName = r.name,
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => _selectedRoomId = val),
                    ),
              ),
              const SizedBox(height: 32),

              // ─── Save Button ───
              AppButton(
                label: _isEditing ? 'Update Class' : 'Add Class',
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

  Widget _buildDropdownLabel(bool isDark, String label) {
    return Text(
      label,
      style: AppTypography.labelMedium.copyWith(
        color:
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
    );
  }

  Widget _buildDropdown({
    required bool isDark,
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
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
          hint: Text(
            hint,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
            ),
          ),
          value: value,
          dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
