import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class TeacherStudentsScreen extends ConsumerWidget {
  const TeacherStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Students'),
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

          // Get teacher's assigned classIds
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
              if (teacher == null || teacher.assignedClassIds.isEmpty) {
                return const EmptyState(
                  title: 'No Students',
                  message: 'You have no classes assigned.',
                  icon: Icons.people_outline_rounded,
                );
              }

              // Watch students from all assigned classes
              final query = ref.watch(studentSearchQueryProvider).toLowerCase();
              final allStudentsAsync = ref.watch(
                studentsByClassIdsProvider(teacher.assignedClassIds),
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppTextField(
                      label: '',
                      hint: 'Search students...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      onChanged:
                          (val) =>
                              ref
                                  .read(studentSearchQueryProvider.notifier)
                                  .state = val,
                    ),
                  ),
                  Expanded(
                    child: allStudentsAsync.when(
                      loading: () => const LoadingWidget(),
                      error:
                          (e, _) => EmptyState(
                            title: 'Error',
                            message: e.toString(),
                            icon: Icons.error_outline_rounded,
                          ),
                      data: (list) {
                        final filtered =
                            query.isEmpty
                                ? list
                                : list
                                    .where(
                                      (s) =>
                                          s.name.toLowerCase().contains(
                                            query,
                                          ) ||
                                          s.className.toLowerCase().contains(
                                            query,
                                          ),
                                    )
                                    .toList();

                        return filtered.isEmpty
                            ? const EmptyState(
                              title: 'No Students',
                              message: 'No students found',
                              icon: Icons.people_outline_rounded,
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filtered.length,
                              itemBuilder:
                                  (ctx, i) => StudentCard(
                                    student: filtered[i],
                                    onTap:
                                        () => context.push(
                                          '${AppRoutes.teacherStudentProfile}/${filtered[i].id}',
                                        ),
                                  ),
                            );
                      },
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
