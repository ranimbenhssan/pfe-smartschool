import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  final String? classId;
  final String? className;

  const TeacherAttendanceScreen({super.key ,this.classId, this.className});

  @override
  ConsumerState<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState
    extends ConsumerState<TeacherAttendanceScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance — Name Call'),
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

          final teachers = ref.watch(teachersProvider);
          return teachers.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (teacherList) {
              final teacher =
                  teacherList.where((t) => t.userId == user.id).firstOrNull;

              if (teacher == null || teacher.assignedClassIds.isEmpty) {
                return const EmptyState(
                  title: 'No Classes Assigned',
                  message: 'You have no classes assigned.\nContact the admin.',
                  icon: Icons.class_outlined,
                );
              }

              final classes = ref.watch(classesProvider);
              return classes.when(
                loading: () => const LoadingWidget(),
                error:
                    (e, _) => EmptyState(
                      title: 'Error',
                      message: e.toString(),
                      icon: Icons.error_outline_rounded,
                    ),
                data: (allClasses) {
                  // ─── Filter to teacher's classes only ───
                  final myClasses =
                      allClasses
                          .where((c) => teacher.assignedClassIds.contains(c.id))
                          .toList();

                  // ─── Apply search ───
                  final filtered =
                      _searchQuery.isEmpty
                          ? myClasses
                          : myClasses
                              .where(
                                (c) =>
                                    c.displayName.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ) ||
                                    c.grade.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ) ||
                                    c.level.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ),
                              )
                              .toList();

                  return Column(
                    children: [
                      // ─── Today header ───
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.teacherColor.withValues(alpha: 0.8),
                              AppColors.teacherColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.how_to_reg_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Name Call",
                                    style: AppTypography.headingMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${myClasses.length} class(es) assigned',
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Search bar ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _searchController,
                          onChanged:
                              (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search class...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            suffixIcon:
                                _searchQuery.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                    : null,
                            filled: true,
                            fillColor:
                                isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ─── Results count ───
                      if (_searchQuery.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '${filtered.length} result(s) for "$_searchQuery"',
                            style: AppTypography.caption,
                          ),
                        ),

                      // ─── Class list ───
                      Expanded(
                        child:
                            filtered.isEmpty
                                ? EmptyState(
                                  title: 'No Classes Found',
                                  message:
                                      _searchQuery.isNotEmpty
                                          ? 'No class matches "$_searchQuery"'
                                          : 'No classes assigned',
                                  icon: Icons.search_off_rounded,
                                )
                                : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final cls = filtered[index];
                                    return _ClassCard(
                                      cls: cls,
                                      isDark: isDark,
                                      onTap:
                                          () => context.push(
                                            AppRoutes.teacherNameCall,
                                            extra: cls.id,
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
          );
        },
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final ClassModel cls;
  final bool isDark;
  final VoidCallback onTap;

  const _ClassCard({
    required this.cls,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.teacherColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // ─── Icon ───
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.teacherColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.class_rounded,
                color: AppColors.teacherColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // ─── Info ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cls.displayName,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // ─── Grade badge ───
                      _Badge(label: cls.grade, color: AppColors.info),
                      const SizedBox(width: 6),
                      // ─── Level badge ───
                      if (cls.level.isNotEmpty)
                        _Badge(
                          label: 'Level ${cls.level}',
                          color: AppColors.accent,
                        ),
                      const SizedBox(width: 6),
                      // ─── Students count ───
                      _Badge(
                        label: '${cls.studentCount} students',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Arrow ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.teacherColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Start',
                style: AppTypography.labelSmall.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}
