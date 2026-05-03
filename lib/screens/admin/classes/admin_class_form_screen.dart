import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
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
  final _levelController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.classId != null;
    if (_isEditing) _loadClass();
    // ─── Trigger preview rebuild on every keystroke ───
    _levelController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
    _gradeController.addListener(() => setState(() {}));
  }

  Future<void> _loadClass() async {
    final cls = await ref
        .read(firestoreServiceProvider)
        .getClass(widget.classId!);
    if (cls != null && mounted) {
      setState(() {
        _nameController.text = cls.name;
        _gradeController.text = cls.grade;
        _levelController.text = cls.level;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  /// Build a temporary ClassModel from the current form values
  /// just to use getFullName() for the preview.
  String get _previewName {
    final tmp = ClassModel(
      id: '',
      name: _nameController.text.trim(),
      grade: _gradeController.text.trim(),
      level: _levelController.text.trim(),
      teacherIds: [],
      teacherNames: [],
      roomId: '',
      roomName: '',
      studentCount: 0,
      createdAt: DateTime.now(),
    );
    return tmp.getFullName();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        // ─── FIX: also update the denormalized displayName field ───
        final updatedName = _nameController.text.trim();
        final updatedGrade = _gradeController.text.trim();
        final updatedLevel = _levelController.text.trim();
        final tmp = ClassModel(
          id: widget.classId!,
          name: updatedName,
          grade: updatedGrade,
          level: updatedLevel,
          teacherIds: [],
          teacherNames: [],
          roomId: '',
          roomName: '',
          studentCount: 0,
          createdAt: DateTime.now(),
        );
        await ref.read(firestoreServiceProvider).updateClass(widget.classId!, {
          'name': updatedName,
          'grade': updatedGrade,
          'level': updatedLevel,
          'displayName': tmp.getFullName(), // ← denormalized combined name
        });
      } else {
        final classModel = ClassModel(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          grade: _gradeController.text.trim(),
          level: _levelController.text.trim(),
          teacherIds: [],
          teacherNames: [],
          roomId: '',
          roomName: '',
          studentCount: 0,
          createdAt: DateTime.now(),
        );
        // toFirestore() already includes displayName: getFullName()
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
    final hasPreview =
        _levelController.text.isNotEmpty ||
        _nameController.text.isNotEmpty ||
        _gradeController.text.isNotEmpty;

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
              // ─── Level ───
              AppTextField(
                label: 'Level *',
                hint: 'e.g. 3, BTS2, L3',
                controller: _levelController,
                prefixIcon: const Icon(Icons.layers_rounded, size: 18),
                validator:
                    (v) => v == null || v.isEmpty ? 'Level is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Class Name ───
              AppTextField(
                label: 'Class Name *',
                hint: 'e.g. IOT, Réseau',
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
                label: 'Grade *',
                hint: 'e.g. 1, 2, A',
                controller: _gradeController,
                prefixIcon: const Icon(Icons.grade_rounded, size: 18),
                validator:
                    (v) => v == null || v.isEmpty ? 'Grade is required' : null,
              ),
              const SizedBox(height: 20),

              // ─── Live preview using getFullName() ───
              if (hasPreview)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // ─── FIX: uses getFullName() logic ───
                        _previewName.isNotEmpty ? _previewName : '—',
                        style: AppTypography.headingMedium.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This is how the class will appear across the app.',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

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
