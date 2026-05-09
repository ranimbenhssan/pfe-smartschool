import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';

class AdminAttendanceByClassScreen extends ConsumerStatefulWidget {
  const AdminAttendanceByClassScreen({super.key});

  @override
  ConsumerState<AdminAttendanceByClassScreen> createState() =>
      _AdminAttendanceByClassScreenState();
}

class _AdminAttendanceByClassScreenState
    extends ConsumerState<AdminAttendanceByClassScreen> {
  String? _selectedClassId;
  String? _selectedClassName;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classesProvider);
    final today = ref.watch(todayStringProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance by Class'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: classes.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('Error: $e'),
              data:
                  (list) => Autocomplete<ClassModel>(
                    displayStringForOption: (c) => c.displayName,
                    optionsBuilder: (textValue) {
                      if (textValue.text.isEmpty) return list;
                      final q = textValue.text.toLowerCase();
                      return list.where(
                        (c) =>
                            c.displayName.toLowerCase().contains(q) ||
                            c.name.toLowerCase().contains(q) ||
                            c.grade.toLowerCase().contains(q) ||
                            c.level.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (cls) {
                      setState(() {
                        _selectedClassId = cls.id;
                        _selectedClassName = cls.displayName;
                      });
                    },
                    fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                      return TextField(
                        controller: ctrl,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search class...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon:
                              _selectedClassId != null
                                  ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      ctrl.clear();
                                      setState(() {
                                        _selectedClassId = null;
                                        _selectedClassName = null;
                                      });
                                    },
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
                      );
                    },
                    optionsViewBuilder:
                        (ctx, onSelected, options) => Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 250),
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                shrinkWrap: true,
                                children:
                                    options
                                        .map(
                                          (c) => ListTile(
                                            dense: true,
                                            title: Text(
                                              c.displayName,
                                              style: AppTypography.labelMedium,
                                            ),
                                            subtitle: Text(
                                              '${c.studentCount} students',
                                              style: AppTypography.caption,
                                            ),
                                            onTap: () => onSelected(c),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ),
                        ),
                  ),
            ),
          ),

          // ── Attendance list ───────────────────────────────────────────────
          Expanded(
            child:
                _selectedClassId == null
                    ? const EmptyState(
                      title: 'Select a Class',
                      message: 'Search for a class to view its attendance',
                      icon: Icons.class_outlined,
                    )
                    : _AttendanceList(
                      classId: _selectedClassId!,
                      className: _selectedClassName ?? '',
                      today: today,
                      isDark: isDark,
                    ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceList extends ConsumerWidget {
  final String classId, className, today;
  final bool isDark;
  const _AttendanceList({
    required this.classId,
    required this.className,
    required this.today,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(
      attendanceByDateAndClassProvider((date: today, classId: classId)),
    );

    return attendance.when(
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
                  ? EmptyState(
                    title: 'No Attendance',
                    message: 'No attendance records for $className today.',
                    icon: Icons.event_busy_rounded,
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final att = list[i];
                      final color =
                          att.status == AttendanceStatus.present
                              ? AppColors.success
                              : att.status == AttendanceStatus.late
                              ? AppColors.warning
                              : AppColors.error;
                      return GestureDetector(
                        onTap:
                            () => context.push(
                              AppRoutes.adminAttendanceEdit,
                              extra: att,
                            ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: color.withValues(alpha: 0.12),
                                child: Icon(
                                  att.status == AttendanceStatus.present
                                      ? Icons.check_circle_rounded
                                      : att.status == AttendanceStatus.late
                                      ? Icons.watch_later_rounded
                                      : Icons.cancel_rounded,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      att.studentName,
                                      style: AppTypography.labelMedium.copyWith(
                                        color:
                                            isDark
                                                ? AppColors.darkText
                                                : AppColors.lightText,
                                      ),
                                    ),
                                    if (att.subject.isNotEmpty)
                                      Text(
                                        att.subject,
                                        style: AppTypography.caption,
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  att.status.name.toUpperCase(),
                                  style: AppTypography.caption.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
    );
  }
}
