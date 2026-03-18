import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';

class AdminStudentProfileScreen extends ConsumerStatefulWidget {
  final String studentId;

  const AdminStudentProfileScreen({super.key, required this.studentId});

  @override
  ConsumerState<AdminStudentProfileScreen> createState() =>
      _AdminStudentProfileScreenState();
}

class _AdminStudentProfileScreenState
    extends ConsumerState<AdminStudentProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final student = ref.watch(studentProvider(widget.studentId));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: student.when(
        loading: () => const Scaffold(body: LoadingWidget()),
        error:
            (e, _) => Scaffold(
              body: EmptyState(
                title: 'Error',
                message: e.toString(),
                icon: Icons.error_outline_rounded,
              ),
            ),
        data: (student) {
          if (student == null) {
            return const Scaffold(
              body: EmptyState(
                title: 'Student Not Found',
                message: 'This student does not exist',
                icon: Icons.person_off_rounded,
              ),
            );
          }
          return _buildProfile(context, isDark, student);
        },
      ),
    );
  }

  Widget _buildProfile(
    BuildContext context,
    bool isDark,
    StudentModel student,
  ) {
    return NestedScrollView(
      headerSliverBuilder:
          (context, _) => [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor:
                  isDark ? AppColors.darkSurface : AppColors.lightSurface,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed:
                      () => context.push(
                        '${AppRoutes.adminStudentEdit}/${student.id}',
                      ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.accent.withValues(
                          alpha: 0.2,
                        ),
                        backgroundImage:
                            student.photoUrl != null
                                ? NetworkImage(student.photoUrl!)
                                : null,
                        child:
                            student.photoUrl == null
                                ? Text(
                                  student.name.isNotEmpty
                                      ? student.name[0].toUpperCase()
                                      : '?',
                                  style: AppTypography.displayMedium.copyWith(
                                    color: AppColors.accent,
                                  ),
                                )
                                : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        student.name,
                        style: AppTypography.headingLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.className,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(text: 'Info'),
                  Tab(text: 'Attendance'),
                  Tab(text: 'RFID Logs'),
                ],
              ),
            ),
          ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _InfoTab(student: student),
          _AttendanceTab(studentId: student.id),
          _RfidLogsTab(studentId: student.id),
        ],
      ),
    );
  }
}

// ─── Info Tab ───
class _InfoTab extends StatelessWidget {
  final StudentModel student;

  const _InfoTab({required this.student});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _InfoCard(
        isDark: isDark,
        items: [
          _InfoItem(
            label: 'Full Name',
            value: student.name,
            icon: Icons.person_rounded,
          ),
          _InfoItem(
            label: 'Email',
            value: student.email,
            icon: Icons.email_rounded,
          ),
          _InfoItem(
            label: 'Class',
            value: student.className,
            icon: Icons.class_rounded,
          ),
          _InfoItem(
            label: 'RFID Tag',
            value: student.rfidTag.isEmpty ? 'Not assigned' : student.rfidTag,
            icon: Icons.nfc_rounded,
          ),
          _InfoItem(
            label: 'Joined',
            value: DateFormat('dd MMM yyyy').format(student.createdAt),
            icon: Icons.calendar_today_rounded,
          ),
        ],
      ),
    );
  }
}

// ─── Attendance Tab ───
class _AttendanceTab extends ConsumerWidget {
  final String studentId;

  const _AttendanceTab({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendance = ref.watch(attendanceByStudentProvider(studentId));

    return attendance.when(
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
            title: 'No Attendance Records',
            message: 'No attendance data for this student yet',
            icon: Icons.event_busy_rounded,
          );
        }

        final present =
            list.where((a) => a.status == AttendanceStatus.present).length;
        final absent =
            list.where((a) => a.status == AttendanceStatus.absent).length;
        final late =
            list.where((a) => a.status == AttendanceStatus.late).length;
        final total = list.length;
        final percentage = total > 0 ? ((present / total) * 100).toInt() : 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ─── Stats Row ───
              Row(
                children: [
                  Expanded(
                    child: _MiniStatCard(
                      label: 'Present',
                      value: present.toString(),
                      color: AppColors.present,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStatCard(
                      label: 'Absent',
                      value: absent.toString(),
                      color: AppColors.absent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStatCard(
                      label: 'Late',
                      value: late.toString(),
                      color: AppColors.late,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStatCard(
                      label: 'Rate',
                      value: '$percentage%',
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Attendance List ───
              ...list.map(
                (record) => Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.date,
                              style: AppTypography.labelLarge.copyWith(
                                color:
                                    isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                              ),
                            ),
                            if (record.entryTime != null)
                              Text(
                                'Entry: ${DateFormat('HH:mm').format(record.entryTime!)}',
                                style: AppTypography.caption,
                              ),
                          ],
                        ),
                      ),
                      AttendanceBadge(status: record.status),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── RFID Logs Tab ───
class _RfidLogsTab extends ConsumerWidget {
  final String studentId;

  const _RfidLogsTab({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logs = ref.watch(rfidLogsByStudentProvider(studentId));

    return logs.when(
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
                    title: 'No RFID Logs',
                    message: 'No RFID scan history for this student',
                    icon: Icons.nfc_rounded,
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final log = list[index];
                      final isIn = log.direction == RfidDirection.in_;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color:
                              isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color:
                                    isIn
                                        ? AppColors.success.withValues(
                                          alpha: 0.12,
                                        )
                                        : AppColors.error.withValues(
                                          alpha: 0.12,
                                        ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isIn
                                    ? Icons.login_rounded
                                    : Icons.logout_rounded,
                                color:
                                    isIn ? AppColors.success : AppColors.error,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isIn ? 'Entry' : 'Exit',
                                    style: AppTypography.labelLarge.copyWith(
                                      color:
                                          isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText,
                                    ),
                                  ),
                                  Text(
                                    'Door: ${log.doorId}',
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('dd/MM HH:mm').format(log.timestamp),
                              style: AppTypography.bodySmall.copyWith(
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
    );
  }
}

// ─── Helper Widgets ───
class _InfoCard extends StatelessWidget {
  final bool isDark;
  final List<_InfoItem> items;

  const _InfoCard({required this.isDark, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children:
            items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.icon,
                            color: AppColors.accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label, style: AppTypography.caption),
                              Text(
                                item.value,
                                style: AppTypography.labelLarge.copyWith(
                                  color:
                                      isDark
                                          ? AppColors.darkText
                                          : AppColors.lightText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < items.length - 1)
                    Divider(
                      height: 1,
                      color:
                          isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                    ),
                ],
              );
            }).toList(),
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.headingMedium.copyWith(color: color),
          ),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}
