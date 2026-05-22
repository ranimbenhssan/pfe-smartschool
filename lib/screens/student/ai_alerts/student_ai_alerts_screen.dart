import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';

class StudentAiAlertsScreen extends ConsumerWidget {
  const StudentAiAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Absence Flags'),
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

          // Get student's Firestore document ID (not Auth UID).
          final studentAsync = ref.watch(studentByUserIdProvider(user.id));

          return studentAsync.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (student) {
              if (student == null) {
                return const EmptyState(
                  title: 'Not Found',
                  message: 'Student profile not found.',
                  icon: Icons.person_off_rounded,
                );
              }

              final flags = ref.watch(aiFlagsByStudentProvider(student.id));
              return flags.when(
                loading: () => const LoadingWidget(),
                error:
                    (e, _) => EmptyState(
                      title: 'Error',
                      message: e.toString(),
                      icon: Icons.error_outline_rounded,
                    ),
                data: (list) {
                  final unique =
                      {for (final flag in list) flag.id: flag}.values.toList();

                  return unique.isEmpty
                      ? const EmptyState(
                        title: 'No Flags Yet',
                        message: 'You have no absence flags at the moment.',
                        icon: Icons.flag_rounded,
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: unique.length,
                        itemBuilder:
                            (context, index) => AlertCard(flag: unique[index]),
                      );
                },
              );
            },
          );
        },
      ),
    );
  }
}
