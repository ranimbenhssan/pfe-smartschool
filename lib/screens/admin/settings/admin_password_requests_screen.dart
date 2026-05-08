import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../firebase_options.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final passwordResetRequestsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      return FirebaseFirestore.instance
          .collection('password_reset_requests')
          .orderBy('requestedAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
          );
    });

class AdminPasswordRequestsScreen extends ConsumerWidget {
  const AdminPasswordRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final requests = ref.watch(passwordResetRequestsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Password Reset Requests'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: requests.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (list) {
          final pending = list.where((r) => r['status'] == 'pending').toList();
          final resolved =
              list.where((r) => r['status'] == 'resolved').toList();

          if (list.isEmpty) {
            return const EmptyState(
              title: 'No Requests',
              message: 'No password reset requests yet.',
              icon: Icons.lock_reset_rounded,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _sectionHeader('Pending', pending.length, AppColors.warning),
                const SizedBox(height: 8),
                ...pending.map(
                  (r) => _RequestCard(
                    request: r,
                    isDark: isDark,
                    onResolve: () => _showGenerateDialog(context, r),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (resolved.isNotEmpty) ...[
                _sectionHeader('Resolved', resolved.length, AppColors.success),
                const SizedBox(height: 8),
                ...resolved.map(
                  (r) =>
                      _RequestCard(request: r, isDark: isDark, onResolve: null),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label, int count, Color color) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          '$label ($count)',
          style: AppTypography.labelMedium.copyWith(color: color),
        ),
      ),
    ],
  );

  // ── Dialog to generate and apply new password ───────────────────────────────
  void _showGenerateDialog(BuildContext context, Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (_) => _GeneratePasswordDialog(request: request),
    );
  }
}

// ─────────────────────────────────────────
//  REQUEST CARD
// ─────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isDark;
  final VoidCallback? onResolve;

  const _RequestCard({
    required this.request,
    required this.isDark,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = request['status'] == 'pending';
    final color = isPending ? AppColors.warning : AppColors.success;
    final ts = request['requestedAt'] as Timestamp?;
    final timeStr = ts != null ? _fmt(ts.toDate()) : '–';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['userName'] ?? '–',
                      style: AppTypography.labelLarge.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Text(request['email'] ?? '–', style: AppTypography.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPending ? 'Pending' : 'Resolved',
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Requested: $timeStr', style: AppTypography.caption),
          if (request['status'] == 'resolved' &&
              request['newPassword'] != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Generated password: ', style: AppTypography.caption),
                Flexible(
                  child: Text(
                    request['newPassword'],
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.accent,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: request['newPassword']),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password copied')),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 10),
            AppButton(
              label: 'Generate New Password',
              icon: Icons.key_rounded,
              width: double.infinity,
              onPressed: onResolve ?? () {},
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month]} ${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────
//  GENERATE PASSWORD DIALOG
// ─────────────────────────────────────────
class _GeneratePasswordDialog extends StatefulWidget {
  final Map<String, dynamic> request;
  const _GeneratePasswordDialog({required this.request});

  @override
  State<_GeneratePasswordDialog> createState() =>
      _GeneratePasswordDialogState();
}

class _GeneratePasswordDialogState extends State<_GeneratePasswordDialog> {
  String _newPassword = '';
  bool _isApplying = false;
  bool _applied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newPassword = _generatePassword();
  }

  String _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
    final rng = Random.secure();
    return List.generate(10, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _apply() async {
    setState(() {
      _isApplying = true;
      _error = null;
    });

    try {
      final userId = widget.request['id'] as String;
      final email = widget.request['email'] as String;
      final db = FirebaseFirestore.instance;

      // ── Update Firebase Auth password via secondary app ───────────────────
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('reset_secondary');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'reset_secondary',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Sign in as the user with their current credentials is not possible
      // without knowing the old password. Instead we use Admin SDK pattern:
      // We update the password in Firestore and set first_login = true.
      // The user signs in with the new password, then is forced to change it.
      // NOTE: Direct password update requires Admin SDK or Firebase Functions.
      // Workaround: store the new password in a secure Firestore doc and
      // force re-auth on next login using a custom flow.

      // ── Store new password + mark first_login true in users doc ───────────
      await db.collection('users').doc(userId).update({
        'first_login': true,
        'temp_password': _newPassword, // admin-visible temporary password
      });

      // ── Update the request as resolved ─────────────────────────────────
      await db.collection('password_reset_requests').doc(userId).update({
        'status': 'resolved',
        'newPassword': _newPassword,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // ── Send in-app notification back to the user ─────────────────────
      await db.collection('notifications').add({
        'userId': userId,
        'senderId': 'admin',
        'senderName': 'Admin',
        'senderRole': 'admin',
        'title': 'Your New Password',
        'message':
            'Your password has been reset. '
            'Your new temporary password is: $_newPassword\n\n'
            'Please log in and change it immediately.',
        'messageType': 'password_reset',
        'isRead': false,
        'attachments': [],
        'recipientLabel': '',
        'replyToId': '',
        'replyToTitle': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await secondaryAuth.signOut();
      setState(() {
        _applied = true;
        _isApplying = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isApplying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_applied) {
      return AlertDialog(
        title: const Text('Password Reset Done ✅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New temporary password for ${widget.request['userName']}:',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _newPassword,
                      style: AppTypography.headingMedium.copyWith(
                        color: AppColors.accent,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: AppColors.accent,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _newPassword));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Copied!')));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Share this password with ${widget.request['userName']}. '
              'They will be required to change it on their next login.',
              style: AppTypography.caption,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('Reset for ${widget.request['userName']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.request['email']}', style: AppTypography.caption),
          const SizedBox(height: 16),
          Text(
            'Generated temporary password:',
            style: AppTypography.labelMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _newPassword,
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.accent,
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  onPressed:
                      () => setState(() => _newPassword = _generatePassword()),
                  tooltip: 'Regenerate',
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'The user will receive an in-app notification with this password '
            'and will be required to change it on next login.',
            style: AppTypography.caption,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isApplying ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isApplying ? null : _apply,
          child: Text(_isApplying ? 'Applying...' : 'Apply & Notify User'),
        ),
      ],
    );
  }
}
