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
    // ── FIX: use teacherClassIdsProvider (from teacher_provider.dart)
    //         instead of the nonexistent classesByTeacherAndDayProvider
    final classIds = ref.watch(teacherClassIdsProvider);
    final allClasses = ref.watch(classesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance — Name Call'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: classIds.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (ids) {
          if (ids.isEmpty) {
            return const EmptyState(
              title: 'No Classes Assigned',
              message: 'You have no classes assigned.\nContact the admin.',
              icon: Icons.class_outlined,
            );
          }

          return allClasses.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (allClassList) {
              // Filter all classes to only the teacher's assigned ones
              var myClasses =
                  allClassList.where((c) => ids.contains(c.id)).toList();

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                myClasses =
                    myClasses
                        .where(
                          (c) =>
                              c.displayName.toLowerCase().contains(q) ||
                              c.grade.toLowerCase().contains(q) ||
                              c.level.toLowerCase().contains(q),
                        )
                        .toList();
              }

              return Column(
                children: [
                  // ── Header banner ──────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.teacherColor.withValues(alpha: 0.7),
                          AppColors.teacherColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.how_to_reg_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select a class to start namecall',
                                style: AppTypography.labelLarge.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${myClasses.length} class${myClasses.length == 1 ? '' : 'es'} assigned',
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

                  // ── Search ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search classes...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
                            isDark ? AppColors.darkCard : AppColors.lightCard,
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
                  const SizedBox(height: 8),

                  // ── Class tiles ────────────────────────────────────────
                  Expanded(
                    child:
                        myClasses.isEmpty
                            ? const EmptyState(
                              title: 'No Results',
                              message: 'No classes match your search',
                              icon: Icons.search_off_rounded,
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              itemCount: myClasses.length,
                              itemBuilder: (context, i) {
                                final cls = myClasses[i];
                                return _ClassTile(
                                  cls: cls,
                                  isDark: isDark,
                                  onTap:
                                      () => context.push(
                                        AppRoutes.teacherNameCall,
                                        extra: {
                                          'classId': cls.id,
                                          'className': cls.displayName,
                                        },
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
//  CLASS TILE
// ─────────────────────────────────────────
class _ClassTile extends StatelessWidget {
  final ClassModel cls;
  final bool isDark;
  final VoidCallback onTap;

  const _ClassTile({
    required this.cls,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.teacherColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.class_rounded,
                color: AppColors.teacherColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
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
                  Text(
                    'Grade ${cls.grade} · Level ${cls.level}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.teacherColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.how_to_reg_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Namecall',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
