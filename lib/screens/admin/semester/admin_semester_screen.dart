import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class AdminSemesterScreen extends ConsumerStatefulWidget {
  const AdminSemesterScreen({super.key});

  @override
  ConsumerState<AdminSemesterScreen> createState() =>
      _AdminSemesterScreenState();
}

class _AdminSemesterScreenState extends ConsumerState<AdminSemesterScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final semesters = ref.watch(semestersProvider);
    final weekType = ref.watch(currentWeekTypeProvider);
    final activeSem = ref.watch(activeSemesterProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Semester Management'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showSemesterDialog(context, null),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current week banner ────────────────────────────────────
            activeSem.when(
              loading: () => const LoadingWidget(),
              error: (_, __) => const SizedBox.shrink(),
              data:
                  (sem) =>
                      sem == null
                          ? _noActiveBanner()
                          : _currentWeekBanner(sem, weekType, isDark),
            ),
            const SizedBox(height: 24),

            Text(
              'All Semesters',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),

            semesters.when(
              loading: () => const LoadingWidget(),
              error:
                  (e, _) => EmptyState(
                    title: 'Error',
                    message: e.toString(),
                    icon: Icons.error_outline_rounded,
                  ),
              data:
                  (list) =>
                      list.isEmpty
                          ? const EmptyState(
                            title: 'No Semesters',
                            message: 'Tap + to create the first semester',
                            icon: Icons.calendar_month_rounded,
                          )
                          : Column(
                            children:
                                list
                                    .map(
                                      (s) => _SemesterCard(
                                        semester: s,
                                        isDark: isDark,
                                        onActivate: () => _activate(s),
                                        onEdit:
                                            () =>
                                                _showSemesterDialog(context, s),
                                        onDelete: () => _delete(s),
                                        onManageHolidays:
                                            () =>
                                                _showHolidaysSheet(context, s),
                                        onManageClosures:
                                            () =>
                                                _showClosuresSheet(context, s),
                                      ),
                                    )
                                    .toList(),
                          ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  BANNERS
  // ─────────────────────────────────────────
  Widget _noActiveBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'No active semester. Create and activate one to enable A/B rotation.',
            style: AppTypography.bodySmall,
          ),
        ),
      ],
    ),
  );

  Widget _currentWeekBanner(SemesterModel sem, String weekType, bool isDark) {
    final isA = weekType == 'A';
    final color = isA ? AppColors.teacherColor : AppColors.studentColor;
    final week = (DateTime.now().difference(sem.startDate).inDays ~/ 7) + 1;

    // Check if today is a closure
    final today = DateTime.now();
    final closure = sem.closureFor(today);
    final fixed = sem.fixedHolidayFor(today);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
            closure != null || fixed != null
                ? LinearGradient(
                  colors: [
                    AppColors.error.withValues(alpha: 0.6),
                    AppColors.error,
                  ],
                )
                : LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              closure != null || fixed != null ? 'OFF' : 'W$weekType',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sem.name,
                  style: AppTypography.labelLarge.copyWith(color: Colors.white),
                ),
                if (closure != null)
                  Text(
                    'NO CLASSES — ${closure.name}',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (fixed != null)
                  Text(
                    'NO CLASSES — ${fixed.name}',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else ...[
                  Text(
                    'Week $week · Type $weekType',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Next week: ${isA ? 'B' : 'A'}',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  ACTIONS
  // ─────────────────────────────────────────
  Future<void> _activate(SemesterModel s) async {
    final batch = FirebaseFirestore.instance.batch();
    final all = await FirebaseFirestore.instance.collection('semesters').get();
    for (final doc in all.docs) {
      batch.update(doc.reference, {'isActive': false});
    }
    batch.update(FirebaseFirestore.instance.collection('semesters').doc(s.id), {
      'isActive': true,
    });
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${s.name} is now active')));
    }
  }

  Future<void> _delete(SemesterModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Semester'),
            content: Text('Delete "${s.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('semesters')
          .doc(s.id)
          .delete();
    }
  }

  void _showSemesterDialog(BuildContext context, SemesterModel? existing) {
    showDialog(
      context: context,
      builder:
          (_) => _SemesterDialog(
            existing: existing,
            onSave: (sem) async {
              final ref = FirebaseFirestore.instance
                  .collection('semesters')
                  .doc(sem.id);
              await ref.set(sem.toFirestore(), SetOptions(merge: true));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      existing == null
                          ? 'Semester created'
                          : 'Semester updated',
                    ),
                  ),
                );
              }
            },
          ),
    );
  }

  // ─────────────────────────────────────────
  //  FIXED HOLIDAYS BOTTOM SHEET
  //  Each entry = month + day + name (recurring every year)
  // ─────────────────────────────────────────
  void _showHolidaysSheet(BuildContext context, SemesterModel sem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FixedHolidaysSheet(semester: sem),
    );
  }

  // ─────────────────────────────────────────
  //  SCHOOL CLOSURES BOTTOM SHEET
  //  Each entry = name + startDate + endDate (date range)
  // ─────────────────────────────────────────
  void _showClosuresSheet(BuildContext context, SemesterModel sem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SchoolClosuresSheet(semester: sem),
    );
  }
}

// ─────────────────────────────────────────
//  SEMESTER CARD
// ─────────────────────────────────────────
class _SemesterCard extends StatelessWidget {
  final SemesterModel semester;
  final bool isDark;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageHolidays;
  final VoidCallback onManageClosures;

  const _SemesterCard({
    required this.semester,
    required this.isDark,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
    required this.onManageHolidays,
    required this.onManageClosures,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              semester.isActive
                  ? AppColors.success.withValues(alpha: 0.5)
                  : isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
          width: semester.isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  semester.name,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              if (semester.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(semester.startDate)} → ${fmt.format(semester.endDate)}',
            style: AppTypography.caption,
          ),
          Text(
            'Starts Week ${semester.firstWeekType} · '
            '${semester.fixedHolidays.length} fixed holidays · '
            '${semester.schoolClosures.length} closures',
            style: AppTypography.caption.copyWith(
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            children: [
              if (!semester.isActive)
                _Btn(
                  'Activate',
                  Icons.check_circle_outline_rounded,
                  AppColors.success,
                  onActivate,
                ),
              _Btn(
                'Fixed Holidays',
                Icons.event_rounded,
                AppColors.info,
                onManageHolidays,
              ),
              _Btn(
                'Closures',
                Icons.lock_clock_rounded,
                AppColors.warning,
                onManageClosures,
              ),
              _Btn('Edit', Icons.edit_rounded, AppColors.accent, onEdit),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Btn(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14, color: color),
    label: Text(label, style: AppTypography.caption.copyWith(color: color)),
  );
}

// ─────────────────────────────────────────
//  SEMESTER DIALOG (create / edit)
// ─────────────────────────────────────────
class _SemesterDialog extends StatefulWidget {
  final SemesterModel? existing;
  final Future<void> Function(SemesterModel) onSave;
  const _SemesterDialog({this.existing, required this.onSave});

  @override
  State<_SemesterDialog> createState() => _SemesterDialogState();
}

class _SemesterDialogState extends State<_SemesterDialog> {
  final _nameCtrl = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 120));
  String _firstWeekType = 'A';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _start = e.startDate;
      _end = e.endDate;
      _firstWeekType = e.firstWeekType;
    } else {
      final now = DateTime.now();
      if (now.month >= 9) {
        _start = DateTime(now.year, 9, 1);
        _end = DateTime(now.year, 12, 30);
        _nameCtrl.text = 'Semester 1 ${now.year}-${now.year + 1}';
      } else {
        _start = DateTime(now.year, 1, 6);
        _end = DateTime(now.year, 5, 30);
        _nameCtrl.text = 'Semester 2 ${now.year - 1}-${now.year}';
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Semester' : 'Edit Semester'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Semester Name'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Start: ${fmt.format(_start)}'),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _start,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (p != null) setState(() => _start = p);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('End: ${fmt.format(_end)}'),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _end,
                  firstDate: _start,
                  lastDate: DateTime(2030),
                );
                if (p != null) setState(() => _end = p);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Week 1 starts as: '),
                const SizedBox(width: 8),
                ToggleButtons(
                  isSelected: [_firstWeekType == 'A', _firstWeekType == 'B'],
                  onPressed:
                      (i) =>
                          setState(() => _firstWeekType = i == 0 ? 'A' : 'B'),
                  borderRadius: BorderRadius.circular(8),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text('Week A'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text('Week B'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _saving
                  ? null
                  : () async {
                    if (_nameCtrl.text.trim().isEmpty) return;
                    setState(() => _saving = true);
                    final existing = widget.existing;
                    final sem = SemesterModel(
                      id:
                          existing?.id ??
                          FirebaseFirestore.instance
                              .collection('semesters')
                              .doc()
                              .id,
                      name: _nameCtrl.text.trim(),
                      startDate: _start,
                      endDate: _end,
                      firstWeekType: _firstWeekType,
                      // Preserve existing holidays / closures when editing
                      fixedHolidays:
                          existing?.fixedHolidays ??
                          SemesterModel.defaultFixedHolidays,
                      schoolClosures: existing?.schoolClosures ?? [],
                      isActive: existing?.isActive ?? false,
                    );
                    await widget.onSave(sem);
                    if (context.mounted) Navigator.pop(context);
                  },
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  FIXED HOLIDAYS SHEET
//  Month + Day + Name — recurring every year
// ─────────────────────────────────────────
class _FixedHolidaysSheet extends StatefulWidget {
  final SemesterModel semester;
  const _FixedHolidaysSheet({required this.semester});
  @override
  State<_FixedHolidaysSheet> createState() => _FixedHolidaysSheetState();
}

class _FixedHolidaysSheetState extends State<_FixedHolidaysSheet> {
  late List<FixedHoliday> _holidays;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _holidays = List.from(widget.semester.fixedHolidays);
  }

  static const _months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder:
          (ctx, ctrl) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fixed Holidays',
                            style: AppTypography.headingMedium,
                          ),
                          Text(
                            'Recurring every year · Month + Day only',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _addHoliday(context),
                    ),
                  ],
                ),
              ),
              const Divider(),

              Expanded(
                child:
                    _holidays.isEmpty
                        ? const Center(
                          child: Text('No fixed holidays yet. Tap + to add.'),
                        )
                        : ListView.builder(
                          controller: ctrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _holidays.length,
                          itemBuilder: (_, i) {
                            final h = _holidays[i];
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${h.day}',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                              title: Text(h.name),
                              subtitle: Text(
                                '${_months[h.month]} ${h.day} (every year)',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                onPressed:
                                    () => setState(() => _holidays.removeAt(i)),
                              ),
                            );
                          },
                        ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  label: _saving ? 'Saving...' : 'Save Fixed Holidays',
                  width: double.infinity,
                  onPressed: _saving ? () {} : _save,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _addHoliday(BuildContext context) async {
    final nameCtrl = TextEditingController();
    int month = 1, day = 1;
    final result = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (ctx, ss) => AlertDialog(
                  title: const Text('Add Fixed Holiday'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Holiday Name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: month,
                              decoration: const InputDecoration(
                                labelText: 'Month',
                              ),
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(
                                    [
                                      'Jan',
                                      'Feb',
                                      'Mar',
                                      'Apr',
                                      'May',
                                      'Jun',
                                      'Jul',
                                      'Aug',
                                      'Sep',
                                      'Oct',
                                      'Nov',
                                      'Dec',
                                    ][i],
                                  ),
                                ),
                              ),
                              onChanged: (v) => ss(() => month = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: day,
                              decoration: const InputDecoration(
                                labelText: 'Day',
                              ),
                              items: List.generate(
                                31,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text('${i + 1}'),
                                ),
                              ),
                              onChanged: (v) => ss(() => day = v!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Add'),
                    ),
                  ],
                ),
          ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      setState(
        () => _holidays.add(
          FixedHoliday(month: month, day: day, name: nameCtrl.text.trim()),
        ),
      );
    }
    nameCtrl.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('semesters')
        .doc(widget.semester.id)
        .update({'fixedHolidays': _holidays.map((h) => h.toMap()).toList()});
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fixed holidays saved')));
    }
  }
}

// ─────────────────────────────────────────
//  SCHOOL CLOSURES SHEET
//  Date ranges — "NO CLASSES" for the whole school
// ─────────────────────────────────────────
class _SchoolClosuresSheet extends StatefulWidget {
  final SemesterModel semester;
  const _SchoolClosuresSheet({required this.semester});
  @override
  State<_SchoolClosuresSheet> createState() => _SchoolClosuresSheetState();
}

class _SchoolClosuresSheetState extends State<_SchoolClosuresSheet> {
  late List<SchoolClosure> _closures;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _closures = List.from(widget.semester.schoolClosures);
  }

  final _fmt = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder:
          (ctx, ctrl) => Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'School Closures',
                            style: AppTypography.headingMedium,
                          ),
                          Text(
                            'Date ranges — whole school "NO CLASSES"',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _addClosure(context),
                    ),
                  ],
                ),
              ),
              const Divider(),

              Expanded(
                child:
                    _closures.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock_open_rounded,
                                size: 40,
                                color: AppColors.success,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No closures configured.',
                                style: AppTypography.bodySmall,
                              ),
                              Text(
                                'All weekdays are school days.',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          controller: ctrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _closures.length,
                          itemBuilder: (_, i) {
                            final c = _closures[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.06,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_clock_rounded,
                                    color: AppColors.warning,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: AppTypography.labelMedium,
                                        ),
                                        Text(
                                          c.durationDays == 1
                                              ? _fmt.format(c.startDate)
                                              : '${_fmt.format(c.startDate)} → ${_fmt.format(c.endDate)}',
                                          style: AppTypography.caption,
                                        ),
                                        Text(
                                          '${c.durationDays} day${c.durationDays == 1 ? '' : 's'}',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.error,
                                      size: 18,
                                    ),
                                    onPressed:
                                        () => setState(
                                          () => _closures.removeAt(i),
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  label: _saving ? 'Saving...' : 'Save Closures',
                  width: double.infinity,
                  onPressed: _saving ? () {} : _save,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _addClosure(BuildContext context) async {
    final nameCtrl = TextEditingController();
    DateTime? start, end;

    final fmt = DateFormat('d MMM yyyy');
    final result = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (ctx, ss) => AlertDialog(
                  title: const Text('Add School Closure'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'e.g. Spring Break, Exam Week',
                        ),
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          start == null
                              ? 'Tap to set start date'
                              : 'From: ${fmt.format(start!)}',
                        ),
                        trailing: const Icon(Icons.calendar_today_rounded),
                        onTap: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate: widget.semester.startDate,
                            firstDate: widget.semester.startDate,
                            lastDate: widget.semester.endDate,
                          );
                          if (p != null) ss(() => start = p);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          end == null
                              ? 'Tap to set end date'
                              : 'To:   ${fmt.format(end!)}',
                        ),
                        trailing: const Icon(Icons.calendar_today_rounded),
                        onTap: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate: start ?? widget.semester.startDate,
                            firstDate: start ?? widget.semester.startDate,
                            lastDate: widget.semester.endDate,
                          );
                          if (p != null) ss(() => end = p);
                        },
                      ),
                      if (start != null &&
                          end != null &&
                          !end!.isBefore(start!))
                        Text(
                          '${end!.difference(start!).inDays + 1} day(s) of closure',
                          style: const TextStyle(color: AppColors.warning),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          (start == null || end == null)
                              ? null
                              : () => Navigator.pop(ctx, true),
                      child: const Text('Add'),
                    ),
                  ],
                ),
          ),
    );

    if (result == true &&
        nameCtrl.text.trim().isNotEmpty &&
        start != null &&
        end != null) {
      setState(
        () => _closures.add(
          SchoolClosure(
            id: const Uuid().v4(),
            name: nameCtrl.text.trim(),
            startDate: start!,
            endDate: end!,
          ),
        ),
      );
    }
    nameCtrl.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('semesters')
        .doc(widget.semester.id)
        .update({'schoolClosures': _closures.map((c) => c.toMap()).toList()});
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('School closures saved ✅')));
    }
  }
}
