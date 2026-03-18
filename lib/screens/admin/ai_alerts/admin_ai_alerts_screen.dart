import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminAiAlertsScreen extends ConsumerWidget {
  const AdminAiAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alerts = ref.watch(filteredActiveFlagsProvider);
    final currentFilter = ref.watch(flagFilterTypeProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('AI Alerts'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.adminAlertResolved),
            child: Text(
              'Resolved',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filter Chips ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    context: context,
                    ref: ref,
                    label: 'All',
                    isSelected: currentFilter == null,
                    onTap:
                        () =>
                            ref.read(flagFilterTypeProvider.notifier).state =
                                null,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context: context,
                    ref: ref,
                    label: 'Frequent Absent',
                    isSelected: currentFilter == FlagType.frequentAbsent,
                    onTap:
                        () =>
                            ref.read(flagFilterTypeProvider.notifier).state =
                                FlagType.frequentAbsent,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context: context,
                    ref: ref,
                    label: 'Late Pattern',
                    isSelected: currentFilter == FlagType.latePattern,
                    onTap:
                        () =>
                            ref.read(flagFilterTypeProvider.notifier).state =
                                FlagType.latePattern,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context: context,
                    ref: ref,
                    label: 'Suspicious',
                    isSelected: currentFilter == FlagType.suspicious,
                    onTap:
                        () =>
                            ref.read(flagFilterTypeProvider.notifier).state =
                                FlagType.suspicious,
                    color: AppColors.info,
                  ),
                ],
              ),
            ),
          ),

          // ─── Alerts Count ───
          alerts.whenData((list) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${list.length} active alerts',
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).value ??
              const SizedBox.shrink(),

          const SizedBox(height: 8),

          // ─── Alerts List ───
          Expanded(
            child: alerts.when(
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
                            title: 'No Active Alerts',
                            message: 'All students are doing well!',
                            icon: Icons.check_circle_outline_rounded,
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: list.length,
                            itemBuilder:
                                (context, index) => AlertCard(
                                  flag: list[index],
                                  onTap:
                                      () => context.push(
                                        '${AppRoutes.adminAlertDetail}/${list[index].id}',
                                      ),
                                ),
                          ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final chipColor = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? chipColor.withValues(alpha: 0.15)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.lightBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? chipColor : AppColors.lightTextHint,
          ),
        ),
      ),
    );
  }
}
