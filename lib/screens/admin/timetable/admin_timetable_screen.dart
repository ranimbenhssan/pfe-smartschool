import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class AdminTimetableScreen extends ConsumerWidget {
  const AdminTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timetable = ref.watch(fullTimetableProvider);
    final classes = ref.watch(classesProvider);
    final selectedClassId = ref.watch(selectedClassIdProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Timetable'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(AppRoutes.adminTimetableAdd),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Class Filter ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: classes.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data:
                  (list) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ClassChip(
                          label: 'All',
                          isSelected: selectedClassId == null,
                          onTap:
                              () =>
                                  ref
                                      .read(selectedClassIdProvider.notifier)
                                      .state = null,
                        ),
                        const SizedBox(width: 8),
                        ...list.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _ClassChip(
                              label: c.name,
                              isSelected: selectedClassId == c.id,
                              onTap:
                                  () =>
                                      ref
                                          .read(
                                            selectedClassIdProvider.notifier,
                                          )
                                          .state = c.id,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),

          // ─── Timetable Grid ───
          Expanded(
            child: timetable.when(
              loading: () => const LoadingWidget(),
              error:
                  (e, _) => EmptyState(
                    title: 'Error',
                    message: e.toString(),
                    icon: Icons.error_outline_rounded,
                  ),
              data: (list) {
                final filtered =
                    selectedClassId == null
                        ? list
                        : list
                            .where((t) => t.classId == selectedClassId)
                            .toList();
                return filtered.isEmpty
                    ? EmptyState(
                      title: 'No Timetable',
                      message: 'No entries yet',
                      icon: Icons.calendar_today_rounded,
                      buttonLabel: 'Add Entry',
                      onButtonTap:
                          () => context.push(AppRoutes.adminTimetableAdd),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TimetableGrid(
                        entries: filtered,
                        onEntryTap: () {},
                      ),
                    );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.adminTimetableAdd),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: AppColors.primary),
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ClassChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.accent
                    : AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? AppColors.primary : AppColors.accent,
          ),
        ),
      ),
    );
  }
}
