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

  const TeacherAttendanceScreen({super.key, this.classId, this.className});

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

    // ─── FIX: use currentTeacherProvider — direct doc fetch by Auth UID ───
    // Old code: ref.watch(teachersProvider) → scan ALL teachers → O(n)
    // New code: ref.watch(currentTeacherProvider) → single doc read → O(1)
    final teacherAsync = ref.watch(currentTeacherProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance — Name Call'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: teacherAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => EmptyState(
          title: 'Error',
          message: e.toString(),
          icon: Icons.error_outline_rounded,
        ),
        data: (teacher) {
          if (teacher == null) {
            return const EmptyState(
              title: 'Profile Not Found',
              message:
                  'Your teacher profile could not be loaded.\nContact the admin.',
              icon: Icons.person_off_rounded,
            );
          }

          // ─── FIX: derive classes from timetable, not assignedClassIds ───
          //
          // Old logic:
          //   if (teacher.assignedClassIds.isEmpty) → "No Classes Assigned"  ← WRONG GATE
          //   classesProvider → filter by assignedClassIds                    ← STALE SOURCE
          //
          // New logic:
          //   classesByTeacherProvider(teacher.id) → timetable WHERE teacherId == uid
          //   → extract unique classIds → fetch class docs
          //   This is always in sync with the actual timetable.
          final classesAsync =
              ref.watch(classesByTeacherProvider(teacher.id));

          return classesAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => EmptyState(
              title: 'Error loading classes',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
            data: (allClasses) {
              // ─── Apply search ───
              final filtered = _searchQuery.isEmpty
                  ? allClasses
                  : allClasses
                      .where(
                        (c) =>
                            c.displayName
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            c.grade
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            c.level
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()),
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
                                '${allClasses.length} class(es) assigned',
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
                      onChanged: (val) =>
                          setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search class...',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon:
                                    const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Class list ───
                  Expanded(
                    child: allClasses.isEmpty
                        ? const EmptyState(
                            title: 'No Classes Assigned',
                            message:
                                'No timetable entries found for your account.\n'
                                'Ask the admin to add your classes to the timetable.',
                            icon: Icons.class_outlined,
                          )
                        : filtered.isEmpty
                            ? EmptyState(
                                title: 'No Classes Found',
                                message:
                                    'No class matches "$_searchQuery"',
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
                                    onTap: () => context.push(
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
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CLASS CARD
// ─────────────────────────────────────────
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
            // ─── Icon badge ───
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.teacherColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.class_rounded,
                color: AppColors.teacherColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // ─── Class info ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cls.displayName,
                    style: AppTypography.labelLarge.copyWith(
                      color:
                          isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (cls.grade.isNotEmpty) ...[
                        _Chip(cls.grade, AppColors.info),
                        const SizedBox(width: 6),
                      ],
                      _Chip(
                        '${cls.studentCount} students',
                        AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Arrow ───
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.teacherColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}