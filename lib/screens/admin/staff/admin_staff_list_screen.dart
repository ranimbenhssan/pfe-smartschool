// lib/screens/admin/staff/admin_staff_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

// ── Staff list provider ──────────────────────────────────────────────────────
final staffListProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', whereIn: ['admin_rh', 'admin_scolarite'])
      .snapshots()
      .map(
        (s) =>
            s.docs.map(UserModel.fromFirestore).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );
});

// ─────────────────────────────────────────────────────────────────────────────
class AdminStaffListScreen extends ConsumerStatefulWidget {
  const AdminStaffListScreen({super.key});

  @override
  ConsumerState<AdminStaffListScreen> createState() =>
      _AdminStaffListScreenState();
}

class _AdminStaffListScreenState extends ConsumerState<AdminStaffListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Staff'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Import Staff',
            onPressed: () => context.push(AppRoutes.adminStaffImport),
          ),
        ],
      ),
      body: staffAsync.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (list) {
          final filtered =
              _query.isEmpty
                  ? list
                  : list
                      .where(
                        (s) =>
                            s.name.toLowerCase().contains(
                              _query.toLowerCase(),
                            ) ||
                            s.role.label.toLowerCase().contains(
                              _query.toLowerCase(),
                            ),
                      )
                      .toList();

          return Column(
            children: [
              // ── Search bar ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search staff...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon:
                        _query.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _query = ''),
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

              // ── Staff list ────────────────────────────────────────────
              Expanded(
                child:
                    filtered.isEmpty
                        ? const EmptyState(
                          title: 'No Staff Found',
                          message:
                              'No HR or Registrar accounts yet.\n'
                              'Use Import Staff to add them.',
                          icon: Icons.people_outline_rounded,
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder:
                              (ctx, i) => _StaffCard(
                                staff: filtered[i],
                                isDark: isDark,
                              ),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
class _StaffCard extends StatelessWidget {
  final UserModel staff;
  final bool isDark;
  const _StaffCard({required this.staff, required this.isDark});

  Color get _roleColor =>
      staff.role == UserRole.adminRH ? AppColors.teacherColor : AppColors.info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _roleColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                style: AppTypography.headingSmall.copyWith(color: _roleColor),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        staff.role.label,
                        style: AppTypography.caption.copyWith(
                          color: _roleColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(staff.email, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
