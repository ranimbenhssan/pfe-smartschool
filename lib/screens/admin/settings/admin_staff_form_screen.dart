import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';

class AdminStaffFormScreen extends ConsumerStatefulWidget {
  const AdminStaffFormScreen({super.key});

  @override
  ConsumerState<AdminStaffFormScreen> createState() =>
      _AdminStaffFormScreenState();
}

class _AdminStaffFormScreenState extends ConsumerState<AdminStaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  UserRole _selectedRole = UserRole.adminRH;
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await ref
          .read(authServiceProvider)
          .createUser(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
            role: _selectedRole,
          );

      if (!result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Error creating account')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      await ref.read(firestoreServiceProvider).updateUser(result.userId!, {
        'temp_password': _passCtrl.text.trim(),
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${_selectedRole.label} account created'),
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

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Add Staff Account'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff Role',
                style: AppTypography.labelLarge.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _RoleChip(
                    label: 'HR Staff',
                    subtitle: 'Manages teachers',
                    icon: Icons.manage_accounts_rounded,
                    color: AppColors.teacherColor,
                    selected: _selectedRole == UserRole.adminRH,
                    onTap:
                        () => setState(() => _selectedRole = UserRole.adminRH),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _RoleChip(
                    label: 'Registrar',
                    subtitle: 'Manages students\n& timetables',
                    icon: Icons.school_rounded,
                    color: AppColors.info,
                    selected: _selectedRole == UserRole.adminScolarite,
                    onTap:
                        () => setState(
                          () => _selectedRole = UserRole.adminScolarite,
                        ),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Full Name',
                hint: 'e.g. Sana Trabelsi',
                controller: _nameCtrl,
                prefixIcon: const Icon(Icons.person_rounded, size: 18),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Email',
                hint: 'staff@smartschool.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 18),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Temporary Password',
                hint: 'Min 8 characters',
                controller: _passCtrl,
                obscureText: _obscure,
                prefixIcon: const Icon(Icons.lock_outlined, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 8) return 'Min 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.info,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The staff member will be asked to change their '
                        'password on first login.',
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                label: _isLoading ? 'Creating...' : 'Create Account',
                onPressed: _isLoading ? () {} : _save,
                isLoading: _isLoading,
                width: double.infinity,
                icon: Icons.person_add_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                selected
                    ? color.withValues(alpha: 0.12)
                    : isDark
                    ? AppColors.darkCard
                    : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color:
                      selected
                          ? color
                          : isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTypography.caption),
            ],
          ),
        ),
      ),
    );
  }
}
