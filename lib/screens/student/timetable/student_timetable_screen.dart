import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/auth_service.dart';

class StudentTimetableScreen extends ConsumerWidget {
  const StudentTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Timetable'),
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
          final timetable = ref.watch(timetableByClassProvider(user.id));
          return timetable.when(
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
                          title: 'No Timetable',
                          message: 'No schedule available yet',
                          icon: Icons.calendar_today_rounded,
                        )
                        : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: TimetableGrid(entries: list),
                        ),
          );
        },
      ),
    );
  }
}
