import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminAlertDetailScreen extends ConsumerWidget {
  final String flagId;

  const AdminAlertDetailScreen({super.key, required this.flagId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flags = ref.watch(activeAiFlagsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Alert Detail'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: flags.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => EmptyState(
          title: 'Error',
          message: e.toString(),
          icon: Icons.error_outline_rounded,
        ),
        data: (list) {
          final flag = list.where((f) => f.id == flagId).firstOrNull;
          if (flag == null) {
            return const EmptyState(
              title: 'Alert Not Found',
              message: 'This alert may have been resolved',
              icon: Icons.check_circle_outline_rounded,
            );
          }
          return _buildDetail(context, isDark, flag, ref);
        },
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    bool isDark,
    AiFlagModel flag,
    WidgetRef ref,
  ) {
    final color = flag.type == FlagType.frequentAbsent
        ? AppColors.error
        : flag.type == FlagType.latePattern
            ? AppColors.warning
            : AppColors.info;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Alert Header ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    flag.type == FlagType.frequentAbsent
                        ? Icons.event_busy_rounded
                        : flag.type == FlagType.latePattern
                            ? Icons.watch_later_rounded
                            : Icons.warning_amber_rounded,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  flag.typeLabel,
                  style: AppTypography.headingMedium.copyWith(
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Risk Score: ${(flag.riskScore * 100).toInt()}%',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Student Info ───
          Text(
            'Student',
            style: AppTypography.headingMedium.copyWith(
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push(
              '${AppRoutes.adminStudentProfile}/${flag.studentId}',
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        AppColors.accent.withValues(alpha: 0.15),
                    child: Text(
                      flag.studentName.isNotEmpty
                          ? flag.studentName[0].toUpperCase()
                          : '?',
                      style: AppTypography.headingSmall.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      flag.studentName,
                      style: AppTypography.labelLarge.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Details ───
          Text(
            'Details',
            style: AppTypography.headingMedium.copyWith(
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flag.details,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Detected: ${DateFormat('dd MMM yyyy HH:mm').format(flag.detectedAt)}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ─── Resolve Button ───
          AppButton(
            label: 'Mark as Resolved',
            onPressed: () async {
              await ref
                  .read(firestoreServiceProvider)
                  .resolveAiFlag(flag.id);
              if (context.mounted) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alert marked as resolved'),
                  ),
                );
              }
            },
            width: double.infinity,
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}