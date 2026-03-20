import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class AdminClassDetailScreen extends ConsumerWidget {
  final String classId;

  const AdminClassDetailScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cls = ref.watch(classProvider(classId));
    final students = ref.watch(studentsByClassProvider(classId));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: cls.when(
          loading: () => const Text('Class Detail'),
          error: (_, __) => const Text('Class Detail'),
          data: (c) => Text(c?.name ?? 'Class Detail'),
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed:
                () => context.push('${AppRoutes.adminClassEdit}/$classId'),
          ),
        ],
      ),
      body: cls.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (c) {
          if (c == null) {
            return const EmptyState(
              title: 'Class Not Found',
              message: 'This class does not exist',
              icon: Icons.class_outlined,
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Class Info Card ───
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                            style: AppTypography.displaySmall.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: AppTypography.headingLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Grade: ${c.grade}',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                            Text(
                              '${c.studentCount} students',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Teachers Info ───
                Container(
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
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.teacherColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.people_rounded,
                              color: AppColors.teacherColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('Teachers', style: AppTypography.caption),
                        ],
                      ),
                      const SizedBox(height: 10),
                      c.teacherNames.isEmpty
                          ? Text(
                            'No teachers assigned',
                            style: AppTypography.bodySmall.copyWith(
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                            ),
                          )
                          : Column(
                            children:
                                c.teacherNames
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: AppColors
                                                  .teacherColor
                                                  .withValues(alpha: 0.15),
                                              child: Text(
                                                entry.value.isNotEmpty
                                                    ? entry.value[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                      color:
                                                          AppColors
                                                              .teacherColor,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              entry.value,
                                              style: AppTypography.labelLarge
                                                  .copyWith(
                                                    color:
                                                        isDark
                                                            ? AppColors.darkText
                                                            : AppColors
                                                                .lightText,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                    ],
                  ),
                ),

                // ─── Students List ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Students',
                      style: AppTypography.headingMedium.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push(AppRoutes.adminStudentAdd),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                students.when(
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
                                title: 'No Students',
                                message: 'No students in this class yet',
                                icon: Icons.people_outline_rounded,
                              )
                              : Column(
                                children:
                                    list
                                        .map(
                                          (student) => StudentCard(
                                            student: student,
                                            onTap:
                                                () => context.push(
                                                  '${AppRoutes.adminStudentProfile}/${student.id}',
                                                ),
                                          ),
                                        )
                                        .toList(),
                              ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
