import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _subjectCtrl = TextEditingController();

  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  String? _selectedRoomId;
  String? _selectedRoomName;
  String _selectedDay = 'Monday';
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  String _weekType = ''; // '' = both, 'A' = Week A, 'B' = Week B
  bool _isLoading = false;
  bool _isEditing = false;

  final _days = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.entryId != null;
    if (_isEditing) _loadEntry();
  }

  Future<void> _loadEntry() async {
    if (widget.entryId == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('timetable')
            .doc(widget.entryId)
            .get();
    if (!doc.exists || !mounted) return;
    final t = TimetableModel.fromFirestore(doc);
    setState(() {
      _subjectCtrl.text = t.subject;
      _selectedClassId = t.classId;
      _selectedClassName = t.className;
      _selectedTeacherId = t.teacherId;
      _selectedTeacherName = t.teacherName;
      _selectedRoomId = t.roomId;
      _selectedRoomName = t.roomName;
      _selectedDay = t.dayOfWeek;
      _weekType = t.weekType; // ← load existing weekType
      final parts = t.startTime.split(':');
      if (parts.length == 2) {
        _startTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
      final eParts = t.endTime.split(':');
      if (eParts.length == 2) {
        _endTime = TimeOfDay(
          hour: int.tryParse(eParts[0]) ?? 9,
          minute: int.tryParse(eParts[1]) ?? 0,
        );
      }
    });
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
        subject: _subjectCtrl.text.trim(),
        dayOfWeek: _selectedDay,
        startTime: _fmt(_startTime),
        endTime: _fmt(_endTime),
        weekType: _weekType, // ← saved here
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
              // ── Subject ────────────────────────────────────────────
              AppTextField(
                label: 'Subject',
                hint: 'e.g. Mathematics',
                controller: _subjectCtrl,
                prefixIcon: const Icon(Icons.book_rounded, size: 18),
                validator:
                    (v) =>
                        v == null || v.isEmpty ? 'Subject is required' : null,
              ),
              const SizedBox(height: 16),

              // ── Class ──────────────────────────────────────────────
              _label(isDark, 'Class'),
              const SizedBox(height: 6),
              classes.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
                data:
                    (list) => _dropdown(
                      isDark: isDark,
                      hint: 'Select class',
                      value: _selectedClassId,
                      items:
                          list
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  onTap:
                                      () => _selectedClassName = c.displayName,
                                  child: Text(c.displayName),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _selectedClassId = v),
                    ),
              ),
              const SizedBox(height: 16),

              // ── Teacher ────────────────────────────────────────────
              _label(isDark, 'Teacher (Optional)'),
              const SizedBox(height: 6),
              teachers.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Text('Error: $e'),
                data:
                    (list) => _dropdown(
                      isDark: isDark,
                      hint: 'Select teacher',
                      value: _selectedTeacherId,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('None')),
                        ...list.map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            onTap: () => _selectedTeacherName = t.name,
                            child: Text(t.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedTeacherId = v),
                    ),
              ),
              const SizedBox(height: 16),

              // ── Room ───────────────────────────────────────────────
              _label(isDark, 'Room (Optional)'),
              const SizedBox(height: 6),
              rooms.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => const SizedBox.shrink(),
                data:
                    (list) => _dropdown(
                      isDark: isDark,
                      hint: 'Select room',
                      value: _selectedRoomId,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('None')),
                        ...list.map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            onTap: () => _selectedRoomName = r.name,
                            child: Text(r.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedRoomId = v),
                    ),
              ),
              const SizedBox(height: 16),

              // ── Day of week ────────────────────────────────────────
              _label(isDark, 'Day'),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      _days.map((day) {
                        final sel = _selectedDay == day;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDay = day),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  sel
                                      ? AppColors.accent
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
                            child: Text(
                              day.substring(0, 3),
                              style: AppTypography.labelMedium.copyWith(
                                color:
                                    sel
                                        ? Colors.white
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

              // ── Time ───────────────────────────────────────────────
              _label(isDark, 'Time'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimeBtn(
                      isDark: isDark,
                      label: 'Start',
                      time: _startTime,
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (t != null) setState(() => _startTime = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeBtn(
                      isDark: isDark,
                      label: 'End',
                      time: _endTime,
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (t != null) setState(() => _endTime = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Week type ──────────────────────────────────────────
              _label(isDark, 'Week Type'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final opt in [
                    ('Both A & B', ''),
                    ('Week A only', 'A'),
                    ('Week B only', 'B'),
                  ])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _weekType = opt.$2),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                _weekType == opt.$2
                                    ? AppColors.accent.withValues(alpha: 0.15)
                                    : isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  _weekType == opt.$2
                                      ? AppColors.accent
                                      : isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                            ),
                          ),
                          child: Text(
                            opt.$1,
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              color:
                                  _weekType == opt.$2 ? AppColors.accent : null,
                              fontWeight:
                                  _weekType == opt.$2 ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Save ───────────────────────────────────────────────
              AppButton(
                label: _isEditing ? 'Update Entry' : 'Add Entry',
                onPressed: _isLoading ? () {} : _save,
                isLoading: _isLoading,
                width: double.infinity,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(bool isDark, String text) => Text(
    text,
    style: AppTypography.labelMedium.copyWith(
      color:
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
    ),
  );

  Widget _dropdown<T>({
    required bool isDark,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        isExpanded: true,
        hint: Text(hint),
        value: value,
        dropdownColor:
            isDark ? AppColors.darkSurface : AppColors.lightBackground,
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

class _TimeBtn extends StatelessWidget {
  final bool isDark;
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeBtn({
    required this.isDark,
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final display =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption),
                Text(display, style: AppTypography.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
