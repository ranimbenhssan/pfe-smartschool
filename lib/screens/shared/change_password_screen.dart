import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../navigation/app_routes.dart'; // ← ADD THIS
import '../../models/models.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  Future<void> _changePassword() async {
    setState(() => _error = null);

    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (newPass.isEmpty) {
      setState(() => _error = 'Please enter a new password');
      return;
    }
    if (!_isStrongPassword(newPass)) {
      setState(
        () =>
            _error =
                'Password must be at least 8 characters, include an uppercase letter and a number',
      );
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _error = 'Not logged in');
        setState(() => _isLoading = false);
        return;
      }

      // ─── Update password in Firebase Auth ───
      await user.updatePassword(newPass);

      // ─── Set first_login to false in Firestore ───
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'first_login': false,
          'temp_password': newPass, // keep in sync with Firebase Auth
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully ✅'),
            backgroundColor: AppColors.success,
          ),
        );

        // ─── Navigate to correct dashboard ───
        final currentUser = await ref.read(currentUserProvider.future);
        if (!mounted) return;

        switch (currentUser?.role) {
          case UserRole.admin:
            context.go(AppRoutes.adminDashboard);
            break;
          case UserRole.teacher:
            context.go(AppRoutes.teacherDashboard);
            break;
          case UserRole.student:
            context.go(AppRoutes.studentDashboard);
            break;
          default:
            context.go(AppRoutes.login);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error =
            e.code == 'requires-recent-login'
                ? 'Session expired. Please log in again.'
                : e.message ?? 'Error changing password';
      });
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // ─── Header ───
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Set Your Password',
                style: AppTypography.headingLarge.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This is your first login. Please set a new secure password to continue.',
                style: AppTypography.bodyMedium.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // ─── Requirements ───
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password Requirements:',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• At least 8 characters',
                      style: AppTypography.caption,
                    ),
                    Text(
                      '• At least one uppercase letter',
                      style: AppTypography.caption,
                    ),
                    Text('• At least one number', style: AppTypography.caption),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ─── New password ───
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ─── Confirm password ───
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed:
                        () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // ─── Error ───
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // ─── Submit ───
              AppButton(
                label: _isLoading ? 'Saving...' : 'Set Password & Continue',
                onPressed: _isLoading ? () {} : _changePassword,
                isLoading: _isLoading,
                width: double.infinity,
                icon: Icons.arrow_forward_rounded,
              ),

              const SizedBox(height: 16),

              // ─── Logout option ───
              Center(
                child: TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      context.go(AppRoutes.login);
                    }
                  },
                  child: Text(
                    'Log out',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
