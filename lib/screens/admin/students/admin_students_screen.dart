import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pfe_smartschool/services/firestore_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class AdminStudentsScreen extends ConsumerWidget {
  const AdminStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = ref.watch(filteredStudentsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Students'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(AppRoutes.adminStudentAdd),
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
              hint: 'Search by name, email or RFID...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              onChanged:
                  (val) =>
                      ref.read(studentSearchQueryProvider.notifier).state = val,
            ),
          ),

          // ─── Student Count ───
          students
                  .whenData(
                    (list) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '${list.length} students',
                            style: AppTypography.bodySmall.copyWith(
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .value ??
              const SizedBox.shrink(),

          const SizedBox(height: 8),

          // ─── Students List ───
          Expanded(
            child: students.when(
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
                            title: 'No Students Found',
                            message: 'Add your first student to get started',
                            icon: Icons.people_outline_rounded,
                            buttonLabel: 'Add Student',
                            onButtonTap:
                                () => context.push(AppRoutes.adminStudentAdd),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final student = list[index];
                              return StudentCard(
                                student: student,
                                onTap:
                                    () => context.push(
                                      '${AppRoutes.adminStudentProfile}/${student.id}',
                                    ),
                                // ─── Wire delete callback ───
                                onDelete:
                                    () => _confirmDelete(
                                      context,
                                      ref,
                                      student.id,
                                      student.name,
                                    ),
                              );
                            },
                          ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.adminStudentAdd),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: AppColors.primary),
      ),
    );
  }

  // ─── Confirm Delete Dialog ───
  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String studentId,
    String name,
  ) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete Student'),
            content: Text(
              'This will permanently remove $name and all their data. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    // ─── Use cascade delete (students + users docs) ───
                    await ref
                        .read(firestoreServiceProvider)
                        .deleteStudentCascade(studentId);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$name deleted'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
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
