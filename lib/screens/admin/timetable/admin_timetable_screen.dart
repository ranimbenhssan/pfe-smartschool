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

class _AdminTimetableScreenState
    extends ConsumerState<AdminTimetableScreen> {
  final _searchController = TextEditingController();
  String? _selectedClassId;
  String? _selectedClassName;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          if (_selectedClassId != null)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () =>
                  context.push(AppRoutes.adminTimetableForm),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search bar ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: classes.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('Error: $e'),
              data: (list) => Autocomplete<ClassModel>(
                displayStringForOption: (c) => c.displayName,
                optionsBuilder: (textValue) {
                  if (textValue.text.isEmpty) return list;
                  return list.where((c) =>
                      c.displayName
                          .toLowerCase()
                          .contains(textValue.text.toLowerCase()) ||
                      c.name
                          .toLowerCase()
                          .contains(textValue.text.toLowerCase()));
                },
                onSelected: (cls) {
                  setState(() {
                    _selectedClassId = cls.id;
                    _selectedClassName = cls.displayName;
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmit) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Search class...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                      ),
                      suffixIcon: _selectedClassId != null
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  size: 18),
                              onPressed: () {
                                controller.clear();
                                setState(() {
                                  _selectedClassId = null;
                                  _selectedClassName = null;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                          maxWidth: 400,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final cls = options.elementAt(index);
                            return ListTile(
                              leading: const Icon(
                                Icons.class_rounded,
                                size: 18,
                              ),
                              title: Text(cls.displayName),
                              onTap: () => onSelected(cls),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ─── Content ───
          Expanded(
            child: _selectedClassId == null
                ? _buildEmptySelection(isDark)
                : _buildClassTimetable(isDark),
          ),
        ],
      ),
      floatingActionButton: _selectedClassId != null
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push(AppRoutes.adminTimetableForm),
              backgroundColor: AppColors.accent,
              icon: const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
              ),
              label: const Text(
                'Add Entry',
                style: TextStyle(color: AppColors.primary),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptySelection(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 64,
            color: isDark
                ? AppColors.darkTextHint
                : AppColors.lightTextHint,
          ),
          const SizedBox(height: 16),
          Text(
            'Search for a class',
            style: AppTypography.headingMedium.copyWith(
              color:
                  isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a class to view or edit its timetable',
            style: AppTypography.bodySmall.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassTimetable(bool isDark) {
    final timetable =
        ref.watch(timetableByClassProvider(_selectedClassId!));

    return timetable.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => EmptyState(
        title: 'Error',
        message: e.toString(),
        icon: Icons.error_outline_rounded,
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return EmptyState(
            title: 'No Timetable',
            message:
                'No entries for $_selectedClassName yet.\nTap + to add entries.',
            icon: Icons.calendar_today_rounded,
          );
        }

        return Column(
          children: [
            // ─── Class info header ───
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
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
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedClassName ?? '',
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
            const SizedBox(height: 8),

            // ─── Timetable grid ───
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AdminTimetableGrid(
                  entries: entries,
                  onDelete: (entry) =>
                      _deleteEntry(entry, isDark),
                  onEdit: (entry) => context.push(
                    AppRoutes.adminTimetableForm,
                    extra: entry.id,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteEntry(
    TimetableModel entry,
    bool isDark,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text(
          'Delete "${entry.subject}" on ${entry.dayOfWeek}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref
          .read(firestoreServiceProvider)
          .deleteTimetableEntry(entry.id);
    }
  }
}