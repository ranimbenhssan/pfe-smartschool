import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminRfidScreen extends ConsumerWidget {
  const AdminRfidScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logs = ref.watch(filteredRfidLogsProvider);
    final filterDate = ref.watch(rfidFilterDateProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('RFID Logs'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.nfc_rounded),
            onPressed: () => context.push(AppRoutes.adminRfidUnrecognized),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filters ───
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            child: Row(
              children: [
                // Date filter
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: filterDate ?? DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        ref.read(rfidFilterDateProvider.notifier).state = date;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.darkCard
                                : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              filterDate != null
                                  ? AppColors.accent
                                  : isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color:
                                filterDate != null
                                    ? AppColors.accent
                                    : isDark
                                    ? AppColors.darkTextHint
                                    : AppColors.lightTextHint,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            filterDate != null
                                ? DateFormat('dd/MM/yyyy').format(filterDate)
                                : 'Filter by date',
                            style: AppTypography.bodySmall.copyWith(
                              color:
                                  filterDate != null
                                      ? AppColors.accent
                                      : isDark
                                      ? AppColors.darkTextHint
                                      : AppColors.lightTextHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Clear filter
                if (filterDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed:
                        () =>
                            ref.read(rfidFilterDateProvider.notifier).state =
                                null,
                  ),
              ],
            ),
          ),

          // ─── Live indicator ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Live feed',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.success,
                  ),
                ),
                const Spacer(),
                logs.whenData((list) {
                      return Text(
                        '${list.length} logs',
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                        ),
                      );
                    }).value ??
                    const SizedBox.shrink(),
              ],
            ),
          ),

          // ─── Logs List ───
          Expanded(
            child: logs.when(
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
                            title: 'No RFID Logs',
                            message: 'No scans recorded yet',
                            icon: Icons.nfc_rounded,
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final log = list[index];
                              return _RfidLogTile(log: log);
                            },
                          ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RfidLogTile extends StatelessWidget {
  final RfidLogModel log;

  const _RfidLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIn = log.direction == RfidDirection.in_;
    final color = isIn ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              log.isRecognized
                  ? color.withValues(alpha: 0.2)
                  : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIn ? Icons.login_rounded : Icons.logout_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      log.isRecognized ? log.studentName : 'Unknown Tag',
                      style: AppTypography.labelLarge.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    if (!log.isRecognized) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'UNKNOWN',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Tag: ${log.rfidTag} • Door: ${log.doorId}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isIn ? 'IN' : 'OUT',
                style: AppTypography.labelSmall.copyWith(color: color),
              ),
              Text(
                DateFormat('HH:mm').format(log.timestamp),
                style: AppTypography.bodySmall.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                DateFormat('dd/MM').format(log.timestamp),
                style: AppTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
