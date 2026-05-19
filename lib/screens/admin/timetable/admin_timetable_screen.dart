import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';

class AdminTimetableScreen extends ConsumerStatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  ConsumerState<AdminTimetableScreen> createState() =>
      _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends ConsumerState<AdminTimetableScreen> {
  String? _selectedClassId;
  String? _selectedClassName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Timetable Management'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          // Add entry button — only visible when a class is selected
          if (_selectedClassId != null)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add entry',
              onPressed:
                  () => context.push(
                    AppRoutes.adminTimetableForm,
                    extra: {'classId': _selectedClassId},
                  ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Class selector ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: classes.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('Error: $e'),
              data:
                  (list) => DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Class',
                      prefixIcon: const Icon(Icons.class_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor:
                          isDark ? AppColors.darkCard : AppColors.lightCard,
                    ),
                    value: _selectedClassId,
                    hint: const Text('Choose a class to view or edit'),
                    items:
                        list
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                onTap: () => _selectedClassName = c.displayName,
                                child: Text(c.displayName),
                              ),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => _selectedClassId = val),
                  ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Timetable grid / empty state ───────────────────────────────
          Expanded(
            child:
                _selectedClassId == null
                    ? const Center(
                      child: EmptyState(
                        title: 'Select a Class',
                        message:
                            'Choose a class above to view and edit its timetable.\n'
                            'To import timetables from Excel, use Bulk Import.',
                        icon: Icons.calendar_today_rounded,
                      ),
                    )
                    : _TimetableEditor(
                      classId: _selectedClassId!,
                      className: _selectedClassName ?? '',
                      isDark: isDark,
                    ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TIMETABLE EDITOR
//  Lists all entries for the selected class.
//  Tap an entry → edit form.
//  Long-press or swipe → delete.
// ─────────────────────────────────────────
class _TimetableEditor extends ConsumerWidget {
  final String classId;
  final String className;
  final bool isDark;

  const _TimetableEditor({
    required this.classId,
    required this.className,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetable = ref.watch(fullTimetableProvider);

    return timetable.when(
      loading: () => const LoadingWidget(),
      error:
          (e, _) => EmptyState(
            title: 'Error',
            message: e.toString(),
            icon: Icons.error_outline_rounded,
          ),
      data: (allEntries) {
        final entries =
            allEntries
                .where(
                  (e) =>
                      e.classId == classId ||
                      e.classId == className ||
                      e.className == className,
                )
                .toList()
              ..sort((a, b) {
                // Sort by day then start time
                const days = [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                ];
                final dCmp = days
                    .indexOf(a.dayOfWeek)
                    .compareTo(days.indexOf(b.dayOfWeek));
                if (dCmp != 0) return dCmp;
                return a.startTime.compareTo(b.startTime);
              });

        if (entries.isEmpty) {
          return EmptyState(
            title: 'No Entries',
            message:
                'No timetable entries for $className.\n'
                'Import from Bulk Import or tap + to add manually.',
            icon: Icons.event_note_rounded,
          );
        }

        // Group by Week type for display
        final weekA = entries.where((e) => e.weekType == 'A').toList();
        final weekB = entries.where((e) => e.weekType == 'B').toList();
        final both = entries.where((e) => e.weekType == '').toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.class_rounded,
                      color: AppColors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        className,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    Text(
                      '${entries.length} entries',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Week A
              if (weekA.isNotEmpty) ...[
                _WeekHeader('Week A', AppColors.teacherColor),
                const SizedBox(height: 6),
                ...weekA.map(
                  (e) => _EntryTile(
                    entry: e,
                    isDark: isDark,
                    onEdit:
                        () => context.push(
                          AppRoutes.adminTimetableForm,
                          extra: e.id,
                        ),
                    onDelete: () => _delete(context, ref, e),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Week B
              if (weekB.isNotEmpty) ...[
                _WeekHeader('Week B', AppColors.studentColor),
                const SizedBox(height: 6),
                ...weekB.map(
                  (e) => _EntryTile(
                    entry: e,
                    isDark: isDark,
                    onEdit:
                        () => context.push(
                          AppRoutes.adminTimetableForm,
                          extra: e.id,
                        ),
                    onDelete: () => _delete(context, ref, e),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Both weeks
              if (both.isNotEmpty) ...[
                _WeekHeader('Both Weeks (A & B)', AppColors.info),
                const SizedBox(height: 6),
                ...both.map(
                  (e) => _EntryTile(
                    entry: e,
                    isDark: isDark,
                    onEdit:
                        () => context.push(
                          AppRoutes.adminTimetableForm,
                          extra: e.id,
                        ),
                    onDelete: () => _delete(context, ref, e),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TimetableModel entry,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Entry'),
            content: Text(
              'Delete "${entry.subject}" on ${entry.dayOfWeek} '
              '(${entry.startTime}–${entry.endTime})?',
            ),
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
    if (confirm == true) {
      await ref.read(firestoreServiceProvider).deleteTimetableEntry(entry.id);
    }
  }
}

// ─────────────────────────────────────────
//  WEEK HEADER
// ─────────────────────────────────────────
class _WeekHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _WeekHeader(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  ENTRY TILE  (edit / delete)
// ─────────────────────────────────────────
class _EntryTile extends StatelessWidget {
  final TimetableModel entry;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 42,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.dayOfWeek.substring(0, 3),
                style: AppTypography.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                entry.startTime,
                style: AppTypography.caption.copyWith(fontSize: 9),
              ),
            ],
          ),
        ),
        title: Text(
          entry.subject,
          style: AppTypography.labelMedium.copyWith(
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        subtitle: Text(
          [
            '${entry.startTime}–${entry.endTime}',
            if (entry.teacherName.isNotEmpty) entry.teacherName,
            if (entry.roomName.isNotEmpty) entry.roomName,
          ].join(' · '),
          style: AppTypography.caption,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 16),
              color: AppColors.accent,
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              color: AppColors.error,
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
