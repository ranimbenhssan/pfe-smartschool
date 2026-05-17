// lib/screens/teacher/attendance/teacher_attendance_by_date_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

// ── Provider: attendance by teacherId + date ──────────────────────────────────
final _teacherAttendanceByDateProvider = StreamProvider.family<
  List<AttendanceModel>,
  ({String teacherId, String date})
>((ref, params) {
  if (params.teacherId.isEmpty || params.date.isEmpty) {
    return Stream.value([]);
  }
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('teacherId', isEqualTo: params.teacherId)
      .where('date', isEqualTo: params.date)
      .orderBy('studentName')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList(),
      );
});

class TeacherAttendanceByDateScreen extends ConsumerWidget {
  const TeacherAttendanceByDateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDate = ref.watch(selectedDateProvider);
    final dateString = ref.watch(selectedDateStringProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance by Date'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: currentUser.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (user) {
          if (user == null) return const SizedBox.shrink();

          // Get teacher's Firestore document ID
          final teacherAsync = ref.watch(teacherByUserIdProvider(user.id));

          return teacherAsync.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (teacher) {
              final teacherId = teacher?.id ?? '';
              final attendance = ref.watch(
                _teacherAttendanceByDateProvider((
                  teacherId: teacherId,
                  date: dateString,
                )),
              );

              return Column(
                children: [
                  // ── Date picker ──────────────────────────────────────
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        ref.read(selectedDateProvider.notifier).state = date;
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.teacherColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.teacherColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: AppColors.teacherColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat(
                              'EEEE, dd MMMM yyyy',
                            ).format(selectedDate),
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.teacherColor,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: AppColors.teacherColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Attendance list ──────────────────────────────────
                  Expanded(
                    child: attendance.when(
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
                                    title: 'No Attendance',
                                    message:
                                        'No records found for ${DateFormat('d MMM yyyy').format(selectedDate)}',
                                    icon: Icons.event_busy_rounded,
                                  )
                                  : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    itemCount: list.length,
                                    itemBuilder: (ctx, i) {
                                      final record = list[i];
                                      return GestureDetector(
                                        onTap:
                                            () => context.push(
                                              AppRoutes.teacherAttendanceEdit,
                                              extra: record,
                                            ),
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? AppColors.darkCard
                                                    : AppColors.lightCard,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isDark
                                                      ? AppColors.darkBorder
                                                      : AppColors.lightBorder,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Avatar
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: AppColors
                                                    .accent
                                                    .withValues(alpha: 0.12),
                                                child: Text(
                                                  record.studentName.isNotEmpty
                                                      ? record.studentName[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: AppTypography
                                                      .labelLarge
                                                      .copyWith(
                                                        color: AppColors.accent,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Info
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
                                                            color:
                                                                isDark
                                                                    ? AppColors
                                                                        .darkText
                                                                    : AppColors
                                                                        .lightText,
                                                          ),
                                                    ),
                                                    Text(
                                                      record.className,
                                                      style:
                                                          AppTypography.caption,
                                                    ),
                                                    if (record
                                                        .subject
                                                        .isNotEmpty)
                                                      Text(
                                                        record.subject,
                                                        style: AppTypography
                                                            .caption
                                                            .copyWith(
                                                              color:
                                                                  AppColors
                                                                      .teacherColor,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              // Status badge
                                              AttendanceBadge(
                                                status: record.status,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
