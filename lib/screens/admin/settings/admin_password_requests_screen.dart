import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../services/password_reset_service.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

final _resetRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final role = ref.watch(currentUserProvider).value?.role ?? UserRole.unknown;

  final query = FirebaseFirestore.instance
      .collection('password_reset_requests')
      .orderBy('requestedAt', descending: true);

  return query.snapshots().map((s) {
    final all = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();

    if (role == UserRole.superAdmin) {
      return all.where((r) {
        final r2 = r['role']?.toString() ?? '';
        return r2 == 'admin_rh' || r2 == 'admin_scolarite';
      }).toList();
    }

    if (role == UserRole.adminRH) {
      return all.where((r) => r['role']?.toString() == 'teacher').toList();
    }

    if (role == UserRole.adminScolarite) {
      return all.where((r) => r['role']?.toString() == 'student').toList();
    }

    return all;
  });
});

class AdminPasswordRequestsScreen extends ConsumerWidget {
  const AdminPasswordRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final requests = ref.watch(_resetRequestsProvider);

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
          if (list.isEmpty) {
            return const EmptyState(
              title: 'No Requests',
              message: 'No password reset requests.',
              icon: Icons.lock_reset_rounded,
            );
          }

          final pending = list.where((r) => r['status'] == 'pending').toList();
          final resolved =
              list.where((r) => r['status'] == 'resolved').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _label('Pending', pending.length, AppColors.warning),
                const SizedBox(height: 8),
                ...pending.map(
                  (r) => _Card(
                    req: r,
                    isDark: isDark,
                    isPending: true,
                    onGenerate: () => _showDialog(context, ref, r),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (resolved.isNotEmpty) ...[
                _label('Resolved', resolved.length, AppColors.success),
                const SizedBox(height: 8),
                ...resolved.map(
                  (r) => _Card(req: r, isDark: isDark, isPending: false),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _label(String text, int count, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            '$text ($count)',
            style: AppTypography.labelMedium.copyWith(color: color),
          ),
        ),
      ],
    ),
  );

  void _showDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> req,
  ) {
    showDialog(
      context: context,
      builder: (_) => _GenerateDialog(req: req, ref: ref),
    );
  }
}

// ─────────────────────────────────────────
class _Card extends StatelessWidget {
  final Map<String, dynamic> req;
  final bool isDark, isPending;
  final VoidCallback? onGenerate;

  const _Card({
    required this.req,
    required this.isDark,
    required this.isPending,
    this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPending ? AppColors.warning : AppColors.success;
    final ts = req['requestedAt'] as Timestamp?;
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
                      req['userName'] ?? '–',
                      style: AppTypography.labelLarge.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Text(req['email'] ?? '–', style: AppTypography.caption),
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
          const SizedBox(height: 6),
          Text('Requested: $timeStr', style: AppTypography.caption),

          // Show generated password for resolved requests
          if (!isPending && req['newPassword'] != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Temp password: ', style: AppTypography.caption),
                Flexible(
                  child: Text(
                    req['newPassword'],
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.accent,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: req['newPassword']));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: AppColors.accent,
                  ),
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
              onPressed: onGenerate ?? () {},
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
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────
//  GENERATE DIALOG
// ─────────────────────────────────────────
class _GenerateDialog extends StatefulWidget {
  final Map<String, dynamic> req;
  final WidgetRef ref;
  const _GenerateDialog({required this.req, required this.ref});

  @override
  State<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends State<_GenerateDialog> {
  late String _password;
  bool _applying = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password = PasswordResetService.generatePassword();
  }

  Future<void> _apply() async {
    setState(() {
      _applying = true;
      _error = null;
    });

    final err = await widget.ref
        .read(passwordResetServiceProvider)
        .applyNewPassword(
          userId: widget.req['id'] as String,
          newPassword: _password,
        );

    if (mounted) {
      setState(() {
        _applying = false;
        if (err != null) {
          _error = err;
        } else {
          _done = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _successDialog();
    return _inputDialog();
  }

  Widget _successDialog() => AlertDialog(
    title: const Text('Password Reset ✅'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'New temporary password for ${widget.req['userName']}:',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: 12),
        _passwordBox(),
        const SizedBox(height: 12),
        Text(
          'The user received an in-app notification.\n'
          'They must log in with this password and will be forced to change it.',
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

  Widget _inputDialog() => AlertDialog(
    title: Text('Reset — ${widget.req['userName']}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.req['email'] ?? '', style: AppTypography.caption),
        const SizedBox(height: 16),
        Text('Generated temporary password:', style: AppTypography.labelMedium),
        const SizedBox(height: 8),
        _passwordBox(),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'This will update their Firebase Auth password immediately. '
          'They will be notified in-app and must change it on next login.',
          style: AppTypography.caption,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _applying ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _applying ? null : _apply,
        child: Text(_applying ? 'Applying...' : 'Apply & Notify'),
      ),
    ],
  );

  Widget _passwordBox() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _password,
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
          tooltip: 'Regenerate',
          onPressed:
              () => setState(
                () => _password = PasswordResetService.generatePassword(),
              ),
        ),
        IconButton(
          icon: const Icon(
            Icons.copy_rounded,
            color: AppColors.accent,
            size: 16,
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _password));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Copied')));
          },
        ),
      ],
    ),
  );
}
