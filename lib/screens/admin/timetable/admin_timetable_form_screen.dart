import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class AdminTimetableFormScreen extends ConsumerStatefulWidget {
  final String? entryId;

  const AdminTimetableFormScreen({super.key, this.entryId});

  @override
  ConsumerState<AdminTimetableFormScreen> createState() =>
      _AdminTimetableFormScreenState();
}

class _AdminTimetableFormScreenState
    extends ConsumerState<AdminTimetableFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  String? _selectedRoomId;
  String? _selectedRoomName;
  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = false;
  bool _isEditing = false;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.entryId != null;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
      final entry = TimetableModel(
        id: widget.entryId ?? const Uuid().v4(),
        classId: _selectedClassId!,
        className: _selectedClassName ?? '',
        teacherId: _selectedTeacherId ?? '',
        teacherName: _selectedTeacherName ?? '',
        roomId: _selectedRoomId ?? '',
        roomName: _selectedRoomName ?? '',
        subject: _subjectController.text.trim(),
        dayOfWeek: _selectedDay,
        startTime: _timeToString(_startTime),
        endTime: _timeToString(_endTime),
        createdAt: DateTime.now(),
      );

      if (_isEditing) {
        await ref
            .read(firestoreServiceProvider)
            .updateTimetableEntry(entry.id, entry.toFirestore());
      } else {
        await ref.read(firestoreServiceProvider).addTimetableEntry(entry);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Entry updated successfully'
                  : 'Entry added successfully',
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
    final teachers = ref.watch(teachersProvider);
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Timetable Entry' : 'Add Timetable Entry',
        ),
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
              // ─── Subject ───
              AppTextField(
                label: 'Subject',
                hint: 'e.g. Mathematics',
                controller: _subjectController,
                prefixIcon: const Icon(Icons.book_rounded, size: 18),
                validator:
                    (v) =>
                        v == null || v.isEmpty ? 'Subject is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Class ───
              _buildLabel(isDark, 'Class'),
              const SizedBox(height: 6),
              classes.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
                data:
                    (list) => _buildDropdown(
                      isDark: isDark,
                      hint: 'Select class',
                      value: _selectedClassId,
                      items:
                          list.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                              onTap: () => _selectedClassName = c.name,
                            );
                          }).toList(),
                      onChanged:
                          (val) => setState(() => _selectedClassId = val),
                    ),
              ),
              const SizedBox(height: 16),

              // ─── Teacher ───
              _buildLabel(isDark, 'Teacher (Optional)'),
              const SizedBox(height: 6),
              teachers.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
                data:
                    (list) => _buildDropdown(
                      isDark: isDark,
                      hint: 'Select teacher',
                      value: _selectedTeacherId,
                      items:
                          list.map((t) {
                            return DropdownMenuItem(
                              value: t.id,
                              child: Text(t.name),
                              onTap: () => _selectedTeacherName = t.name,
                            );
                          }).toList(),
                      onChanged:
                          (val) => setState(() => _selectedTeacherId = val),
                    ),
              ),
              const SizedBox(height: 16),

              // ─── Room ───
              _buildLabel(isDark, 'Room (Optional)'),
              const SizedBox(height: 6),
              rooms.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
                data:
                    (list) => _buildDropdown(
                      isDark: isDark,
                      hint: 'Select room',
                      value: _selectedRoomId,
                      items:
                          list.map((r) {
                            return DropdownMenuItem(
                              value: r.id,
                              child: Text(r.name),
                              onTap: () => _selectedRoomName = r.name,
                            );
                          }).toList(),
                      onChanged: (val) => setState(() => _selectedRoomId = val),
                    ),
              ),
              const SizedBox(height: 16),

              // ─── Day ───
              _buildLabel(isDark, 'Day of Week'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      _days.asMap().entries.map((entry) {
                        final dayIndex = entry.key + 1;
                        final isSelected = _selectedDay == dayIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDay = dayIndex),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppColors.accent
                                      : isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? AppColors.accent
                                        : isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                              ),
                            ),
                            child: Text(
                              entry.value.substring(0, 3),
                              style: AppTypography.labelMedium.copyWith(
                                color:
                                    isSelected
                                        ? AppColors.primary
                                        : isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Time ───
              _buildLabel(isDark, 'Time'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      isDark: isDark,
                      label: 'Start',
                      time: _startTime,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (time != null) {
                          setState(() => _startTime = time);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeButton(
                      isDark: isDark,
                      label: 'End',
                      time: _endTime,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (time != null) {
                          setState(() => _endTime = time);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ─── Save ───
              AppButton(
                label: _isEditing ? 'Update Entry' : 'Add Entry',
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

  Widget _buildLabel(bool isDark, String label) {
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
          hint: Text(hint),
          value: value,
          dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final bool isDark;
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeButton({
    required this.isDark,
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              color: AppColors.accent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption),
                Text(
                  time.format(context),
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
