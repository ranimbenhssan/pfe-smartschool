import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class StudentAttendanceStatsScreen extends ConsumerStatefulWidget {
  const StudentAttendanceStatsScreen({super.key});

  @override
  ConsumerState<StudentAttendanceStatsScreen> createState() =>
      _StudentAttendanceStatsScreenState();
}

class _StudentAttendanceStatsScreenState
    extends ConsumerState<StudentAttendanceStatsScreen> {
  // ─── Filter: all / absent / late / present ───
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance Details'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: currentUser.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          final attendance = ref.watch(attendanceByStudentProvider(user.id));

          return attendance.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (list) {
              final present =
                  list
                      .where((a) => a.status == AttendanceStatus.present)
                      .length;
              final absent =
                  list.where((a) => a.status == AttendanceStatus.absent).length;
              final late =
                  list.where((a) => a.status == AttendanceStatus.late).length;
              final total = list.length;
              final rate = total > 0 ? ((present / total) * 100).toInt() : 0;

              // ─── Apply filter ───
              final filtered =
                  _filter == 'all'
                      ? list
                      : list.where((a) => a.status.name == _filter).toList();

              return Column(
                children: [
                  // ─── Stats summary ───
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // ─── Rate card ───
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.studentColor.withValues(alpha: 0.8),
                                AppColors.studentColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$rate%',
                                      style: AppTypography.displayLarge
                                          .copyWith(
                                            color: Colors.white,
                                            fontSize: 48,
                                          ),
                                    ),
                                    Text(
                                      'Attendance Rate',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  _MiniStat('Present', present, Colors.white),
                                  _MiniStat('Absent', absent, Colors.white70),
                                  _MiniStat('Late', late, Colors.white60),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Filter chips ───
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All ($total)',
                                isActive: _filter == 'all',
                                color: AppColors.info,
                                onTap: () => setState(() => _filter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Absent ($absent)',
                                isActive: _filter == 'absent',
                                color: AppColors.absent,
                                onTap: () => setState(() => _filter = 'absent'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Late ($late)',
                                isActive: _filter == 'late',
                                color: AppColors.late,
                                onTap: () => setState(() => _filter = 'late'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Present ($present)',
                                isActive: _filter == 'present',
                                color: AppColors.present,
                                onTap:
                                    () => setState(() => _filter = 'present'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── Attendance list ───
                  Expanded(
                    child:
                        filtered.isEmpty
                            ? EmptyState(
                              title: 'No Records',
                              message:
                                  _filter == 'all'
                                      ? 'No attendance records yet'
                                      : 'No $_filter records',
                              icon: Icons.event_busy_rounded,
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final record = filtered[index];
                                return _AttendanceDetailCard(
                                  record: record,
                                  isDark: isDark,
                                );
                              },
                            ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ATTENDANCE DETAIL CARD
// ─────────────────────────────────────────
class _AttendanceDetailCard extends StatelessWidget {
  final AttendanceModel record;
  final bool isDark;

  const _AttendanceDetailCard({required this.record, required this.isDark});

  String _formatDisplayDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor =
        record.status == AttendanceStatus.present
            ? AppColors.present
            : record.status == AttendanceStatus.late
            ? AppColors.late
            : AppColors.absent;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top row ───
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  record.status == AttendanceStatus.present
                      ? Icons.check_circle_rounded
                      : record.status == AttendanceStatus.late
                      ? Icons.watch_later_rounded
                      : Icons.cancel_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDisplayDate(record.date),
                      style: AppTypography.labelLarge.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (record.recordedAt != null)
                      Text(
                        DateFormat('HH:mm').format(record.recordedAt!),
                        style: AppTypography.caption,
                      ),
                  ],
                ),
              ),
              AttendanceBadge(status: record.status),
            ],
          ),

          // ─── Details section ───
          if (record.sessionName.isNotEmpty ||
              record.subject.isNotEmpty ||
              record.teacherName.isNotEmpty ||
              record.roomName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? AppColors.darkBackground
                        : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (record.sessionName.isNotEmpty)
                    _DetailRow(
                      icon: Icons.event_note_rounded,
                      label: 'Session',
                      value: record.sessionName,
                      color: AppColors.accent,
                      isDark: isDark,
                    ),
                  if (record.subject.isNotEmpty)
                    _DetailRow(
                      icon: Icons.menu_book_rounded,
                      label: 'Subject',
                      value: record.subject,
                      color: AppColors.info,
                      isDark: isDark,
                    ),
                  if (record.teacherName.isNotEmpty)
                    _DetailRow(
                      icon: Icons.person_rounded,
                      label: 'Recorded by',
                      value: record.teacherName,
                      color: AppColors.teacherColor,
                      isDark: isDark,
                    ),
                  if (record.roomName.isNotEmpty)
                    _DetailRow(
                      icon: Icons.meeting_room_rounded,
                      label: 'Room',
                      value: record.roomName,
                      color: AppColors.success,
                      isDark: isDark,
                    ),
                ],
              ),
            ),
          ],

          if (record.note != null && record.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.note_rounded,
                  size: 12,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(record.note!, style: AppTypography.caption),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: AppTypography.caption.copyWith(
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: AppTypography.caption.copyWith(color: color),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isActive ? color : null,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
