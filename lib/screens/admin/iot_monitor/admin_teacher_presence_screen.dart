// lib/screens/admin/iot_monitor/admin_teacher_presence_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/iot_provider.dart';
import '../../../navigation/app_routes.dart';
import '../../../services/iot_service.dart';

class AdminTeacherPresenceScreen extends ConsumerWidget {
  const AdminTeacherPresenceScreen({super.key});

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtDate() {
    final now = DateTime.now();
    const months = [
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
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday]} ${now.day} ${months[now.month]} ${now.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presence = ref.watch(todayTeacherPresenceProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Teacher Presence'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: Column(
        children: [
          // ── Date + stats banner ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: isDark ? AppColors.darkSurface : Colors.white,
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.teacherColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _fmtDate(),
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.teacherColor,
                  ),
                ),
                const Spacer(),
                presence.when(
                  data: (list) {
                    final inCount = list.where((t) => t.status == 'in').length;
                    final outCount =
                        list.where((t) => t.status == 'out').length;
                    return Row(
                      children: [
                        _Chip('$inCount present', AppColors.success),
                        const SizedBox(width: 6),
                        if (outCount > 0)
                          _Chip('$outCount left', AppColors.info),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),

          // ── Info pill ─────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.info,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resets automatically each day.\n'
                    '● Present = entered (1st scan)    '
                    '✓ Done = also exited (2nd scan)',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),

          // ── Teacher list ──────────────────────────────────────────────────
          Expanded(
            child: presence.when(
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
                          ? const EmptyState(
                            title: 'No Teachers Present',
                            message: 'No teacher has scanned in today yet.',
                            icon: Icons.person_off_rounded,
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: list.length,
                            itemBuilder: (ctx, i) {
                              final t = list[i];
                              final isIn = t.status == 'in';
                              final color =
                                  isIn ? AppColors.success : AppColors.info;

                              return Container(
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? AppColors.darkCard
                                          : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.3),
                                    width: isIn ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: color,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.teacherName,
                                            style: AppTypography.labelLarge
                                                .copyWith(
                                                  color:
                                                      isDark
                                                          ? AppColors.darkText
                                                          : AppColors.lightText,
                                                ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.login_rounded,
                                                size: 12,
                                                color: AppColors.success,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'In: ${_fmtTime(t.entryTime)}',
                                                style: AppTypography.caption,
                                              ),
                                              if (t.exitTime != null) ...[
                                                const SizedBox(width: 12),
                                                const Icon(
                                                  Icons.logout_rounded,
                                                  size: 12,
                                                  color: AppColors.info,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Out: ${_fmtTime(t.exitTime!)}',
                                                  style: AppTypography.caption,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  '${t.exitTime!.difference(t.entryTime).inMinutes}min',
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                        color: AppColors.info,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isIn ? '● Present' : '✓ Done',
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: AppTypography.caption.copyWith(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
