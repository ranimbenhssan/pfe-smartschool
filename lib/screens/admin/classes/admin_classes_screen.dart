import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminClassesScreen extends ConsumerWidget {
  const AdminClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Classes'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(AppRoutes.adminClassAdd),
          ),
        ],
      ),
      body: classes.when(
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
                      title: 'No Classes Found',
                      message: 'Add your first class to get started',
                      icon: Icons.class_outlined,
                      buttonLabel: 'Add Class',
                      onButtonTap: () => context.push(AppRoutes.adminClassAdd),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final cls = list[index];
                        return _ClassCard(
                          cls: cls,
                          isDark: isDark,
                          onTap:
                              () => context.push(
                                '${AppRoutes.adminClassDetail}/${cls.id}',
                              ),
                          onEdit:
                              () => context.push(
                                '${AppRoutes.adminClassEdit}/${cls.id}',
                              ),
                          onDelete: () => _confirmDelete(context, ref, cls),
                        );
                      },
                    ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.adminClassAdd),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ClassModel cls) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete Class'),
            // ─── FIX: use getFullName() in dialog ───
            content: Text(
              'Delete "${cls.getFullName}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref.read(firestoreServiceProvider).deleteClass(cls.id);
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

// ─────────────────────────────────────────
//  CLASS CARD
// ─────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final ClassModel cls;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClassCard({
    required this.cls,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
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
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            // ─── Icon badge ───
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  cls.name.isNotEmpty ? cls.name[0].toUpperCase() : 'C',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── PRIMARY LABEL: getFullName() → "3 IOT 1" ───
                  Text(
                    cls.getFullName,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // ─── Chips row ───
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (cls.grade.isNotEmpty)
                          _Badge('Grade ${cls.grade}', AppColors.info),
                        if (cls.grade.isNotEmpty) const SizedBox(width: 6),
                        _Badge(
                          '${cls.studentCount} students',
                          AppColors.success,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Teacher: ${cls.teacherName.isEmpty ? 'Not assigned' : cls.teacherName}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.teacherColor,
                    ),
                  ),
                ],
              ),
            ),

            // ─── 3-dot menu ───
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder:
                  (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 16),
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
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
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
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}
