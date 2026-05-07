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
  final _formKey       = GlobalKey<FormState>();
  final _levelCtrl     = TextEditingController();
  final _nameCtrl      = TextEditingController();
  final _gradeCtrl     = TextEditingController();
  final _groupCtrl     = TextEditingController(); // optional TP group
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
        _levelCtrl.text = cls.level;
        _nameCtrl.text  = cls.name;
        _gradeCtrl.text = cls.grade;
        _groupCtrl.text = cls.group;
      });
    }
  }

  @override
  void dispose() {
    _levelCtrl.dispose();
    _nameCtrl.dispose();
    _gradeCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  String _buildDisplayName() {
    final base  = '${_levelCtrl.text.trim()} ${_nameCtrl.text.trim()} ${_gradeCtrl.text.trim()}'.trim();
    final group = _groupCtrl.text.trim();
    return group.isEmpty ? base : '$base $group';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'level':       _levelCtrl.text.trim(),
        'name':        _nameCtrl.text.trim(),
        'grade':       _gradeCtrl.text.trim(),
        'group':       _groupCtrl.text.trim(),
        'displayName': _buildDisplayName(),
      };

      if (_isEditing) {
        await ref.read(firestoreServiceProvider).updateClass(widget.classId!, data);
      } else {
        final classModel = ClassModel(
          id:           const Uuid().v4(),
          name:         _nameCtrl.text.trim(),
          grade:        _gradeCtrl.text.trim(),
          level:        _levelCtrl.text.trim(),
          group:        _groupCtrl.text.trim(),
          teacherIds:   [],
          teacherNames: [],
          roomId:       '',
          roomName:     '',
          studentCount: 0,
          createdAt:    DateTime.now(),
        );
        await ref.read(firestoreServiceProvider).addClass(classModel);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing
              ? 'Class updated successfully'
              : 'Class added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Live preview of display name
    final preview = _buildDisplayName();

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
              // ── Preview ──────────────────────────────────────────────
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_levelCtrl, _nameCtrl, _gradeCtrl, _groupCtrl]),
                builder: (_, __) {
                  final preview = _buildDisplayName();
                  if (preview.trim().isEmpty) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Preview',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.accent)),
                      Text(preview,
                          style: AppTypography.labelLarge
                              .copyWith(color: AppColors.accent)),
                    ]),
                  );
                },
              ),

              // ── Level ─────────────────────────────────────────────────
              AppTextField(
                label: 'Level *',
                hint: 'e.g. 3, BTS2, L3',
                controller: _levelCtrl,
                prefixIcon: const Icon(Icons.layers_rounded, size: 18),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Level is required' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // ── Class Name ────────────────────────────────────────────
              AppTextField(
                label: 'Class Name *',
                hint: 'e.g. IOT, DNI, Réseau',
                controller: _nameCtrl,
                prefixIcon: const Icon(Icons.class_rounded, size: 18),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Class name is required' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // ── Grade ─────────────────────────────────────────────────
              AppTextField(
                label: 'Grade *',
                hint: 'e.g. 1, 2 (group number within the class)',
                controller: _gradeCtrl,
                prefixIcon: const Icon(Icons.grade_rounded, size: 18),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Grade is required' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // ── Group (optional) ──────────────────────────────────────
              AppTextField(
                label: 'TP Group (optional)',
                hint: 'e.g. TP 1, TP 2 — leave empty if no group',
                controller: _groupCtrl,
                prefixIcon: const Icon(Icons.group_work_rounded, size: 18),
                onChanged: (_) => setState(() {}),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'If filled, the class will be displayed as e.g. "3 IOT 1 TP 2"',
                  style: AppTypography.caption,
                ),
              ),
              const SizedBox(height: 28),

              // ── Save ──────────────────────────────────────────────────
              AppButton(
                label: _isEditing ? 'Update Class' : 'Add Class',
                onPressed: _isLoading ? () {} : _save,
                isLoading: _isLoading,
                width: double.infinity,
                icon: _isEditing
                    ? Icons.save_rounded
                    : Icons.add_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}