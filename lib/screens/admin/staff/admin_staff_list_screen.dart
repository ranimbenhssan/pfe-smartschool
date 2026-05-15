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

  void _openEdit(BuildContext context, UserModel staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditStaffSheet(staff: staff),
    );
  }

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
                                onEdit: () => _openEdit(context, filtered[i]),
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
//  STAFF CARD
// ─────────────────────────────────────────
class _StaffCard extends StatelessWidget {
  final UserModel staff;
  final bool isDark;
  final VoidCallback onEdit;
  const _StaffCard({
    required this.staff,
    required this.isDark,
    required this.onEdit,
  });

  Color get _roleColor =>
      staff.role == UserRole.adminRH ? AppColors.teacherColor : AppColors.info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
                const SizedBox(height: 2),
                Text(
                  staff.email,
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            color:
                isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
            onPressed: onEdit,
            tooltip: 'Edit staff',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  EDIT STAFF BOTTOM SHEET
// ─────────────────────────────────────────
class _EditStaffSheet extends ConsumerStatefulWidget {
  final UserModel staff;
  const _EditStaffSheet({required this.staff});

  @override
  ConsumerState<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends ConsumerState<_EditStaffSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _rfidCtrl;
  late UserRole _role;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.staff.name);
    // Load current RFID tag from Firestore users doc
    _rfidCtrl = TextEditingController();
    _role = widget.staff.role;
    _loadRfid();
  }

  Future<void> _loadRfid() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.staff.id)
            .get();
    if (mounted) {
      _rfidCtrl.text = doc.data()?['rfidTag']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rfidCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.staff.id)
          .update({
            'name': name,
            'role': _role.firestoreValue,
            'rfidTag': _rfidCtrl.text.trim().toUpperCase(),
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff updated ✅'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _delete() async {
    // Confirm before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete Staff Account'),
            content: Text(
              'Are you sure you want to delete ${widget.staff.name}?\n'
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.staff.id)
          .delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.staff.name} deleted'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      // Push sheet above keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Edit Staff',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 20),

            // ── Name ──────────────────────────────────────────────────
            AppTextField(
              label: 'Full Name',
              controller: _nameCtrl,
              prefixIcon: const Icon(Icons.person_rounded, size: 18),
            ),
            const SizedBox(height: 14),

            // ── Role selector ─────────────────────────────────────────
            Text(
              'Role',
              style: AppTypography.labelMedium.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _RoleChip(
                  label: 'HR Staff',
                  icon: Icons.manage_accounts_rounded,
                  color: AppColors.teacherColor,
                  selected: _role == UserRole.adminRH,
                  isDark: isDark,
                  onTap: () => setState(() => _role = UserRole.adminRH),
                ),
                const SizedBox(width: 10),
                _RoleChip(
                  label: 'Registrar',
                  icon: Icons.school_rounded,
                  color: AppColors.info,
                  selected: _role == UserRole.adminScolarite,
                  isDark: isDark,
                  onTap: () => setState(() => _role = UserRole.adminScolarite),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── RFID Tag ──────────────────────────────────────────────
            AppTextField(
              label: 'RFID Tag',
              hint: 'e.g. A1B2C3D4 (leave blank if none)',
              controller: _rfidCtrl,
              prefixIcon: const Icon(Icons.nfc_rounded, size: 18),
            ),
            const SizedBox(height: 24),

            AppButton(
              label: _isSaving ? 'Saving...' : 'Save Changes',
              onPressed: _isSaving ? () {} : _save,
              isLoading: _isSaving,
              width: double.infinity,
              icon: Icons.save_rounded,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Delete Account',
              onPressed: _isSaving ? () {} : _delete,
              width: double.infinity,
              icon: Icons.delete_rounded,
              isOutlined: true,
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ROLE CHIP
// ─────────────────────────────────────────
class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color:
              selected
                  ? color.withValues(alpha: 0.1)
                  : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected
                    ? color
                    : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color:
                    selected
                        ? color
                        : isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
