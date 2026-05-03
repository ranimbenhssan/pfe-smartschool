import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminClassDetailScreen extends ConsumerWidget {
  final String classId;
  const AdminClassDetailScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classAsync = ref.watch(classProvider(classId));
    final studentsAsync = ref.watch(studentsByClassIdProvider(classId));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: classAsync.when(
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
              message: '',
              icon: Icons.class_outlined,
            );
          }

          return CustomScrollView(
            slivers: [
              // ─── Hero app bar ───
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.accent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accent.withValues(alpha: 0.9),
                          AppColors.accent,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                c.name.isNotEmpty
                                    ? c.name[0].toUpperCase()
                                    : 'C',
                                style: AppTypography.displaySmall.copyWith(
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ─── FIX: use getFullName() not c.name ───
                                Text(
                                  c.getFullName(),
                                  style: AppTypography.headingLarge.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _HeaderChip(
                                      label: 'Level ${c.level}',
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    _HeaderChip(
                                      label: 'Grade ${c.grade}',
                                      color: Colors.white60,
                                    ),
                                    const SizedBox(width: 6),
                                    _HeaderChip(
                                      label: '${c.studentCount} students',
                                      color: Colors.white54,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Colors.white),
                    onPressed:
                        () => context.push(
                          '${AppRoutes.adminClassEdit}/$classId',
                        ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Teachers info ───
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Teachers',
                              style: AppTypography.labelLarge.copyWith(
                                color:
                                    isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (c.teacherNames.isEmpty)
                              Text(
                                'No teachers assigned',
                                style: AppTypography.caption,
                              )
                            else
                              ...c.teacherNames.asMap().entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppColors.teacherColor
                                            .withValues(alpha: 0.15),
                                        child: Text(
                                          entry.value.isNotEmpty
                                              ? entry.value[0].toUpperCase()
                                              : '?',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.teacherColor,
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
                                                      : AppColors.lightText,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── Students list heading ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Students',
                            style: AppTypography.headingMedium.copyWith(
                              color:
                                  isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                () => context.push(AppRoutes.adminStudentAdd),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ─── Students list ───
                      studentsAsync.when(
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
                                      message:
                                          'No students enrolled in this class',
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final Color color;
  const _HeaderChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}
