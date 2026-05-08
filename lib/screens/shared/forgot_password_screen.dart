import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _requestSent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final db = FirebaseFirestore.instance;

      // ── Look up the user by email ─────────────────────────────────────────
      final userSnap =
          await db
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (userSnap.docs.isEmpty) {
        setState(() {
          _error = 'No account found with this email.';
          _isLoading = false;
        });
        return;
      }

      final userDoc = userSnap.docs.first;
      final userId = userDoc.id;
      final userName = userDoc.data()['name']?.toString() ?? 'Unknown';
      final role = userDoc.data()['role']?.toString() ?? 'student';

      // ── Write / update the password reset request ─────────────────────────
      await db.collection('password_reset_requests').doc(userId).set({
        'userId': userId,
        'userName': userName,
        'email': email,
        'role': role,
        'status': 'pending', // pending | resolved
        'requestedAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'newPassword': null, // admin fills this in
      });

      // ── Notify the admin (in-app notification) ────────────────────────────
      // Find admin user
      final adminSnap =
          await db
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .limit(1)
              .get();

      if (adminSnap.docs.isNotEmpty) {
        await db.collection('notifications').add({
          'userId': adminSnap.docs.first.id,
          'senderId': userId,
          'senderName': userName,
          'senderRole': role,
          'title': 'Password Reset Request',
          'message': '$userName ($email) has requested a password reset.',
          'messageType': 'password_reset',
          'isRead': false,
          'attachments': [],
          'recipientLabel': 'Admin',
          'replyToId': '',
          'replyToTitle': '',
          'resetRequestId': userId, // link to the request doc
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _requestSent = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _requestSent ? _buildSuccess(isDark) : _buildForm(isDark),
      ),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccess(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: AppColors.success,
            size: 36,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Request Sent!',
          style: AppTypography.displaySmall.copyWith(
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your password reset request has been sent to the admin.\n\n'
          'The admin will generate a new password for you. '
          'You will be able to log in with the new password and '
          'will be prompted to change it.',
          style: AppTypography.bodyMedium.copyWith(
            color:
                isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        AppButton(
          label: 'Back to Login',
          onPressed: () => context.pop(),
          width: double.infinity,
          icon: Icons.arrow_back_rounded,
        ),
      ],
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────
  Widget _buildForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: AppColors.accent,
              size: 30,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Forgot Password?',
            style: AppTypography.displaySmall.copyWith(
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your school email address.\n'
            'The admin will receive your request and generate a new password for you.',
            style: AppTypography.bodyMedium.copyWith(
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Email field
          AppTextField(
            label: 'School Email',
            hint: 'your.name@smartschool.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, size: 18),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter your email';
              if (!v.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
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

          AppButton(
            label: 'Send Request to Admin',
            onPressed: _isLoading ? () {} : _sendRequest,
            isLoading: _isLoading,
            width: double.infinity,
            icon: Icons.send_rounded,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Back to Login',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
