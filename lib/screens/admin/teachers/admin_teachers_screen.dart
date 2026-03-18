import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../navigation/app_routes.dart';

class AdminTeachersScreen extends ConsumerWidget {
  const AdminTeachersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teachers = ref.watch(filteredTeachersProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Teachers'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(AppRoutes.adminTeacherAdd),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search Bar ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(
              label: '',
              hint: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              onChanged:
                  (val) =>
                      ref.read(teacherSearchQueryProvider.notifier).state = val,
            ),
          ),

          // ─── Count ───
          teachers.whenData((list) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${list.length} teachers',
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

          // ─── Teachers List ───
          Expanded(
            child: teachers.when(
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
                            title: 'No Teachers Found',
                            message: 'Add your first teacher to get started',
                            icon: Icons.person_outline_rounded,
                            buttonLabel: 'Add Teacher',
                            onButtonTap:
                                () => context.push(AppRoutes.adminTeacherAdd),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final teacher = list[index];
                              return GestureDetector(
                                onTap:
                                    () => context.push(
                                      '${AppRoutes.adminTeacherProfile}/${teacher.id}',
                                    ),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? AppColors.darkCard
                                            : AppColors.lightCard,
                                    borderRadius: BorderRadius.circular(14),
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
                                        radius: 22,
                                        backgroundColor: AppColors.teacherColor
                                            .withValues(alpha: 0.15),
                                        backgroundImage:
                                            teacher.photoUrl != null
                                                ? NetworkImage(
                                                  teacher.photoUrl!,
                                                )
                                                : null,
                                        child:
                                            teacher.photoUrl == null
                                                ? Text(
                                                  teacher.name.isNotEmpty
                                                      ? teacher.name[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: AppTypography
                                                      .headingSmall
                                                      .copyWith(
                                                        color:
                                                            AppColors
                                                                .teacherColor,
                                                      ),
                                                )
                                                : null,
                                      ),
                                      const SizedBox(width: 12),
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              teacher.name,
                                              style: AppTypography.labelLarge
                                                  .copyWith(
                                                    color:
                                                        isDark
                                                            ? AppColors.darkText
                                                            : AppColors
                                                                .lightText,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              teacher.email,
                                              style: AppTypography.bodySmall.copyWith(
                                                color:
                                                    isDark
                                                        ? AppColors
                                                            .darkTextSecondary
                                                        : AppColors
                                                            .lightTextSecondary,
                                              ),
                                            ),
                                            if (teacher
                                                .assignedClassNames
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                teacher.assignedClassNames.join(
                                                  ', ',
                                                ),
                                                style: AppTypography.caption
                                                    .copyWith(
                                                      color:
                                                          AppColors
                                                              .teacherColor,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Actions
                                      PopupMenuButton(
                                        icon: Icon(
                                          Icons.more_vert_rounded,
                                          color:
                                              isDark
                                                  ? AppColors.darkTextHint
                                                  : AppColors.lightTextHint,
                                        ),
                                        itemBuilder:
                                            (_) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.edit_rounded,
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text('Edit'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.delete_rounded,
                                                      size: 16,
                                                      color: AppColors.error,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: AppColors.error,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            context.push(
                                              '${AppRoutes.adminTeacherEdit}/${teacher.id}',
                                            );
                                          } else if (value == 'delete') {
                                            _confirmDelete(
                                              context,
                                              ref,
                                              teacher.id,
                                              teacher.name,
                                            );
                                          }
                                        },
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.adminTeacherAdd),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: AppColors.primary),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String teacherId,
    String name,
  ) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Teacher'),
            content: Text('Are you sure you want to delete $name?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref
                      .read(firestoreServiceProvider)
                      .deleteTeacher(teacherId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Teacher deleted')),
                    );
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );
  }
}
