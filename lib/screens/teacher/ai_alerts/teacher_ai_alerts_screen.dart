// lib/screens/teacher/ai_alerts/teacher_ai_alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class TeacherAiAlertsScreen extends ConsumerWidget {
  const TeacherAiAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Absence Flags'),
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

          // Get the teacher record to access assigned classIds
          final teacher = ref.watch(teacherByUserIdProvider(user.id));

          return teacher.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (teacherModel) {
              if (teacherModel == null) {
                return const EmptyState(
                  title: 'No Classes',
                  message: 'No classes assigned yet.',
                  icon: Icons.class_outlined,
                );
              }

              final classIds = teacherModel.assignedClassIds;
              if (classIds.isEmpty) {
                return const EmptyState(
                  title: 'No Active Flags',
                  message: 'All students are doing well!',
                  icon: Icons.check_circle_outline_rounded,
                );
              }

              // Watch flags for all assigned classes
              final flagsAsync = ref.watch(aiFlagsByClassIdsProvider(classIds));

              return flagsAsync.when(
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
                              title: 'No Active Flags',
                              message: 'All students are doing well!',
                              icon: Icons.check_circle_outline_rounded,
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: list.length,
                              itemBuilder:
                                  (context, index) => AlertCard(
                                    flag: list[index],
                                    onTap:
                                        () => context.push(
                                          '${AppRoutes.teacherAlertDetail}/${list[index].id}',
                                        ),
                                  ),
                            ),
              );
            },
          );
        },
      ),
    );
  }
}
