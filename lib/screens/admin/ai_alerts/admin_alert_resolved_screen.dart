import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class AdminAlertResolvedScreen extends ConsumerWidget {
  const AdminAlertResolvedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolved = ref.watch(resolvedAiFlagsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Resolved Alerts'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: resolved.when(
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
                      title: 'No Resolved Alerts',
                      message: 'No alerts have been resolved yet',
                      icon: Icons.history_rounded,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final flag = list[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      flag.studentName,
                                      style: AppTypography.labelLarge.copyWith(
                                        color:
                                            isDark
                                                ? AppColors.darkText
                                                : AppColors.lightText,
                                      ),
                                    ),
                                    Text(
                                      flag.typeLabel,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.success,
                                      ),
                                    ),
                                    if (flag.resolvedAt != null)
                                      Text(
                                        'Resolved: ${DateFormat('dd/MM/yyyy').format(flag.resolvedAt!)}',
                                        style: AppTypography.caption,
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                ),
                                onPressed:
                                    () => context.push(
                                      '${AppRoutes.adminStudentProfile}/${flag.studentId}',
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}
