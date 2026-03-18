import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

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
          // ─── Class Selector ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: classes.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('Error: $e'),
              data: (list) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
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
                        color: isDark
                            ? AppColors.darkTextHint
                            : AppColors.lightTextHint,
                      ),
                    ),
                    value: selectedClassId,
                    dropdownColor:
                        isDark ? AppColors.darkCard : AppColors.lightCard,
                    items: list
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (val) => ref
                        .read(selectedClassIdProvider.notifier)
                        .state = val,
                  ),
                ),
              ),
            ),
          ),

          // ─── Attendance List ───
          Expanded(
            child: selectedClassId == null
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
                        error: (e, _) => EmptyState(
                          title: 'Error',
                          message: e.toString(),
                          icon: Icons.error_outline_rounded,
                        ),
                        data: (list) => list.isEmpty
                            ? const EmptyState(
                                title: 'No Records',
                                message:
                                    'No attendance for this class today',
                                icon: Icons.event_busy_rounded,
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: list.length,
                                itemBuilder: (context, index) {
                                  final record = list[index];
                                  return GestureDetector(
                                    onTap: () => context.push(
                                      AppRoutes.adminAttendanceEdit,
                                      extra: record,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      margin: const EdgeInsets.only(
                                          bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkCard
                                            : AppColors.lightCard,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  record.studentName,
                                                  style: AppTypography
                                                      .labelLarge
                                                      .copyWith(
                                                    color: isDark
                                                        ? AppColors.darkText
                                                        : AppColors.lightText,
                                                  ),
                                                ),
                                                if (record.entryTime != null)
                                                  Text(
                                                    'Entry: ${DateFormat('HH:mm').format(record.entryTime!)}',
                                                    style:
                                                        AppTypography.caption,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          AttendanceBadge(
                                              status: record.status),
                                        ],
                                      ),
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