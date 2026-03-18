import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';

class AdminTeacherProfileScreen extends ConsumerWidget {
  final String teacherId;

  const AdminTeacherProfileScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacher = ref.watch(teacherProvider(teacherId));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: teacher.when(
        loading: () => const Scaffold(body: LoadingWidget()),
        error:
            (e, _) => Scaffold(
              body: EmptyState(
                title: 'Error',
                message: e.toString(),
                icon: Icons.error_outline_rounded,
              ),
            ),
        data: (teacher) {
          if (teacher == null) {
            return const Scaffold(
              body: EmptyState(
                title: 'Teacher Not Found',
                message: 'This teacher does not exist',
                icon: Icons.person_off_rounded,
              ),
            );
          }
          return _buildProfile(context, isDark, teacher, ref);
        },
      ),
    );
  }

  Widget _buildProfile(
    BuildContext context,
    bool isDark,
    TeacherModel teacher,
    WidgetRef ref,
  ) {
    return CustomScrollView(
      slivers: [
        // ─── Header ───
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed:
                  () =>
                      context.push('${AppRoutes.adminTeacherEdit}/$teacherId'),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.teacherColor.withValues(
                      alpha: 0.2,
                    ),
                    backgroundImage:
                        teacher.photoUrl != null
                            ? NetworkImage(teacher.photoUrl!)
                            : null,
                    child:
                        teacher.photoUrl == null
                            ? Text(
                              teacher.name.isNotEmpty
                                  ? teacher.name[0].toUpperCase()
                                  : '?',
                              style: AppTypography.displayMedium.copyWith(
                                color: AppColors.teacherColor,
                              ),
                            )
                            : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    teacher.name,
                    style: AppTypography.headingLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.teacherColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'TEACHER',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.teacherColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Info ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        isDark: isDark,
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value: teacher.email,
                        showDivider: true,
                      ),
                      _buildInfoRow(
                        isDark: isDark,
                        icon: Icons.calendar_today_rounded,
                        label: 'Joined',
                        value: DateFormat(
                          'dd MMM yyyy',
                        ).format(teacher.createdAt),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Assigned Classes ───
                Text(
                  'Assigned Classes',
                  style: AppTypography.headingMedium.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 12),
                teacher.assignedClassNames.isEmpty
                    ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                        ),
                      ),
                      child: Text(
                        'No classes assigned yet',
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                        ),
                      ),
                    )
                    : Column(
                      children:
                          teacher.assignedClassNames.asMap().entries.map((
                            entry,
                          ) {
                            return Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppColors.darkCard
                                        : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.teacherColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.teacherColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.class_rounded,
                                      color: AppColors.teacherColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    entry.value,
                                    style: AppTypography.labelLarge.copyWith(
                                      color:
                                          isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),

                const SizedBox(height: 24),

                // ─── Timetable ───
                Text(
                  'Timetable',
                  style: AppTypography.headingMedium.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final timetable = ref.watch(
                      timetableByTeacherProvider(teacherId),
                    );
                    return timetable.when(
                      loading: () => const LoadingWidget(),
                      error: (e, _) => const SizedBox.shrink(),
                      data:
                          (list) =>
                              list.isEmpty
                                  ? Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? AppColors.darkCard
                                              : AppColors.lightCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            isDark
                                                ? AppColors.darkBorder
                                                : AppColors.lightBorder,
                                      ),
                                    ),
                                    child: Text(
                                      'No timetable entries yet',
                                      style: AppTypography.bodySmall.copyWith(
                                        color:
                                            isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  )
                                  : TimetableGrid(entries: list),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTypography.caption),
                    Text(
                      value,
                      style: AppTypography.labelLarge.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
      ],
    );
  }
}
