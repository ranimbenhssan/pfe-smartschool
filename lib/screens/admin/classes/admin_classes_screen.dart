import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../navigation/app_routes.dart';

class AdminClassesScreen extends ConsumerStatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  ConsumerState<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends ConsumerState<AdminClassesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.adminClassAdd),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: classes.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (list) {
          // Apply search
          final filtered =
              _query.isEmpty
                  ? list
                  : list.where((c) {
                    final q = _query.toLowerCase();
                    return c.displayName.toLowerCase().contains(q) ||
                        c.name.toLowerCase().contains(q) ||
                        c.level.toLowerCase().contains(q) ||
                        c.grade.toLowerCase().contains(q) ||
                        c.group.toLowerCase().contains(q);
                  }).toList();

          return Column(
            children: [
              // ── Search bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search classes...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon:
                        _query.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
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

              // ── Count ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} class${filtered.length == 1 ? '' : 'es'}',
                    style: AppTypography.caption.copyWith(
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),

              // ── List ─────────────────────────────────────────────────
              Expanded(
                child:
                    filtered.isEmpty
                        ? EmptyState(
                          title:
                              _query.isEmpty
                                  ? 'No Classes Found'
                                  : 'No Results',
                          message:
                              _query.isEmpty
                                  ? 'Add your first class to get started'
                                  : 'No classes match "$_query"',
                          icon: Icons.class_outlined,
                          buttonLabel: _query.isEmpty ? 'Add Class' : null,
                          onButtonTap:
                              _query.isEmpty
                                  ? () => context.push(AppRoutes.adminClassAdd)
                                  : null,
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final cls = filtered[index];
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
                              onDelete: () => _delete(cls),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(cls) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Class'),
            content: Text('Delete "${cls.displayName}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await ref.read(firestoreServiceProvider).deleteClass(cls.id);
    }
  }
}

// ─────────────────────────────────────────
//  CLASS CARD  — name only, students count, teacher
// ─────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final dynamic cls;
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
    final initial =
        cls.displayName.isNotEmpty ? cls.displayName[0].toUpperCase() : 'C';

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
            // ── Avatar ─────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: AppTypography.headingSmall.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Info ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class display name (e.g. "3 IOT 1 TP 2")
                  Text(
                    cls.displayName,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Students count only — no grade/level badge
                      _Chip(
                        label:
                            '${cls.studentCount} student${cls.studentCount == 1 ? '' : 's'}',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
              ),
            ),

            // ── Menu ────────────────────────────────────────────────
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                size: 20,
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
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
