import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminAttendanceByClassScreen extends ConsumerWidget {
  const AdminAttendanceByClassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classesProvider);
    final selectedClassId = ref.watch(selectedClassIdProvider);
    final today = ref.watch(todayStringProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance by Class'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: Column(
        children: [
          // ─── Class selector dropdown ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: classes.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('Error: $e'),
              data:
                  (list) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkCard
                              : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text(
                          'Select a class',
                          style: AppTypography.bodyMedium.copyWith(
                            color:
                                isDark
                                    ? AppColors.darkTextHint
                                    : AppColors.lightTextHint,
                          ),
                        ),
                        value: selectedClassId,
                        dropdownColor:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        items:
                            list.map((c) {
                              return DropdownMenuItem(
                                value: c.id,
                                // ─── FIX: use getFullName() → "3 IOT 1" ───
                                child: Text(
                                  c.getFullName(),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color:
                                        isDark
                                            ? AppColors.darkText
                                            : AppColors.lightText,
                                  ),
                                ),
                              );
                            }).toList(),
                        onChanged:
                            (val) =>
                                ref
                                    .read(selectedClassIdProvider.notifier)
                                    .state = val,
                      ),
                    ),
                  ),
            ),
          ),

          // ─── Attendance list ───
          Expanded(
            child:
                selectedClassId == null
                    ? const EmptyState(
                      title: 'Select a Class',
                      message: 'Choose a class to view attendance',
                      icon: Icons.class_outlined,
                    )
                    : Consumer(
                      builder: (context, ref, _) {
                        final attendance = ref.watch(
                          attendanceByDateAndClassProvider((
                            date: today,
                            classId: selectedClassId,
                          )),
                        );
                        return attendance.when(
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
                                      ? EmptyState(
                                        title: 'No Records',
                                        message:
                                            'No attendance recorded for today in this class.',
                                        icon: Icons.event_busy_rounded,
                                      )
                                      : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        itemCount: list.length,
                                        itemBuilder: (context, index) {
                                          final record = list[index];
                                          return _AttendanceCard(
                                            record: record,
                                            isDark: isDark,
                                            onTap:
                                                () => context.push(
                                                  '${AppRoutes.adminAttendanceEdit}/${record.id}',
                                                ),
                                          );
                                        },
                                      ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ATTENDANCE CARD
// ─────────────────────────────────────────
class _AttendanceCard extends StatelessWidget {
  final AttendanceModel record;
  final bool isDark;
  final VoidCallback onTap;

  const _AttendanceCard({
    required this.record,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc =
        record.status == AttendanceStatus.late
            ? AppColors.late
            : AppColors.absent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sc.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                record.status == AttendanceStatus.late
                    ? Icons.watch_later_rounded
                    : Icons.cancel_rounded,
                color: sc,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.studentName,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  // ─── FIX: className is now "3 IOT 1" ───
                  Text(record.className, style: AppTypography.caption),
                  if (record.subject.isNotEmpty)
                    Text(
                      '${record.subject}'
                      '${record.scheduledTimeRange.isNotEmpty ? ' · ${record.scheduledTimeRange}' : ''}',
                      style: AppTypography.caption.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sc.withValues(alpha: 0.3)),
              ),
              child: Text(
                record.status.name.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: sc,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
