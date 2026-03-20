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
  List<String> _selectedTeacherIds = [];
  List<String> _selectedTeacherNames = [];
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
        _selectedTeacherIds = List.from(cls.teacherIds);
        _selectedTeacherNames = List.from(cls.teacherNames);
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

  void _toggleTeacher(String teacherId, String teacherName) {
    setState(() {
      if (_selectedTeacherIds.contains(teacherId)) {
        _selectedTeacherIds.remove(teacherId);
        _selectedTeacherNames.remove(teacherName);
      } else {
        _selectedTeacherIds.add(teacherId);
        _selectedTeacherNames.add(teacherName);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await ref.read(firestoreServiceProvider).updateClass(widget.classId!, {
          'name': _nameController.text.trim(),
          'grade': _gradeController.text.trim(),
          'teacherIds': _selectedTeacherIds,
          'teacherNames': _selectedTeacherNames,
          'roomId': _selectedRoomId ?? '',
          'roomName': _selectedRoomName ?? '',
        });
      } else {
        final classModel = ClassModel(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          grade: _gradeController.text.trim(),
          teacherIds: _selectedTeacherIds,
          teacherNames: _selectedTeacherNames,
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

              // ─── Teachers Multi-Select ───
              Text(
                'Assign Teachers',
                style: AppTypography.labelMedium.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You can assign multiple teachers to this class',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 8),
              teachers.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
                data:
                    (list) =>
                        list.isEmpty
                            ? Container(
                              padding: const EdgeInsets.all(14),
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
                                'No teachers yet. Add teachers first.',
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
                                  list.map((teacher) {
                                    final isSelected = _selectedTeacherIds
                                        .contains(teacher.id);
                                    return GestureDetector(
                                      onTap:
                                          () => _toggleTeacher(
                                            teacher.id,
                                            teacher.name,
                                          ),
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
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: AppColors
                                                  .teacherColor
                                                  .withValues(alpha: 0.15),
                                              child: Text(
                                                teacher.name.isNotEmpty
                                                    ? teacher.name[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: AppTypography.labelSmall
                                                    .copyWith(
                                                      color:
                                                          AppColors
                                                              .teacherColor,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    teacher.name,
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
                                                    teacher.email,
                                                    style:
                                                        AppTypography.caption,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                color: AppColors.teacherColor,
                                                size: 18,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
              ),
              const SizedBox(height: 16),

              // ─── Selected teachers summary ───
              if (_selectedTeacherNames.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.teacherColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.teacherColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_rounded,
                        color: AppColors.teacherColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedTeacherNames.length} teacher(s): ${_selectedTeacherNames.join(', ')}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.teacherColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // ─── Room Selector ───
              Text(
                'Assign Room (Optional)',
                style: AppTypography.labelMedium.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              rooms.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
                data:
                    (list) => Container(
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
                            'Select a room',
                            style: AppTypography.bodyMedium.copyWith(
                              color:
                                  isDark
                                      ? AppColors.darkTextHint
                                      : AppColors.lightTextHint,
                            ),
                          ),
                          value: _selectedRoomId,
                          dropdownColor:
                              isDark ? AppColors.darkCard : AppColors.lightCard,
                          items:
                              list.map((r) {
                                return DropdownMenuItem(
                                  value: r.id,
                                  child: Text(r.name),
                                  onTap: () => _selectedRoomName = r.name,
                                );
                              }).toList(),
                          onChanged:
                              (val) => setState(() => _selectedRoomId = val),
                        ),
                      ),
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
}
