import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../navigation/app_routes.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Appearance ───
            _SectionHeader(isDark: isDark, title: 'Appearance'),
            const SizedBox(height: 8),
            _SettingsCard(
              isDark: isDark,
              children: [
                _ToggleTile(
                  isDark: isDark,
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark Mode',
                  value: themeMode == ThemeMode.dark,
                  onChanged: (_) {
                    final current = ref.read(themeModeProvider);
                    ref.read(themeModeProvider.notifier).state =
                        current == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Devices ───
            _SectionHeader(isDark: isDark, title: 'IoT Devices'),
            const SizedBox(height: 8),
            _SettingsCard(
              isDark: isDark,
              children: [
                _NavigationTile(
                  isDark: isDark,
                  icon: Icons.nfc_rounded,
                  label: 'RFID Devices',
                  color: AppColors.info,
                  onTap: () => context.push(AppRoutes.adminSettingsRfid),
                ),
                const Divider(height: 1),
                _NavigationTile(
                  isDark: isDark,
                  icon: Icons.sensors_rounded,
                  label: 'Sensor Devices',
                  color: AppColors.success,
                  onTap: () => context.push(AppRoutes.adminSettingsSensors),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── AI Config ───
            _SectionHeader(isDark: isDark, title: 'AI Configuration'),
            const SizedBox(height: 8),
            _SettingsCard(
              isDark: isDark,
              children: [
                _NavigationTile(
                  isDark: isDark,
                  icon: Icons.tune_rounded,
                  label: 'AI Alert Thresholds',
                  color: AppColors.warning,
                  onTap: () => context.push(AppRoutes.adminSettingsAi),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── About ───
            _SectionHeader(isDark: isDark, title: 'About'),
            const SizedBox(height: 8),
            _SettingsCard(
              isDark: isDark,
              children: [
                _InfoTile(
                  isDark: isDark,
                  icon: Icons.info_outline_rounded,
                  label: 'App Version',
                  value: '1.0.0',
                ),
                const Divider(height: 1),
                _InfoTile(
                  isDark: isDark,
                  icon: Icons.school_rounded,
                  label: 'Project',
                  value: 'PFE 2026',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Settings Sub-Screens ───
class AdminSettingsRfidScreen extends StatelessWidget {
  const AdminSettingsRfidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('RFID Devices'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: const EmptyState(
        title: 'RFID Devices',
        message: 'Connect your ESP32 RFID readers here',
        icon: Icons.nfc_rounded,
      ),
    );
  }
}

class AdminSettingsSensorsScreen extends StatelessWidget {
  const AdminSettingsSensorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Sensor Devices'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: const EmptyState(
        title: 'Sensor Devices',
        message: 'Connect your ESP32 sensor nodes here',
        icon: Icons.sensors_rounded,
      ),
    );
  }
}

class AdminSettingsAiScreen extends ConsumerStatefulWidget {
  const AdminSettingsAiScreen({super.key});

  @override
  ConsumerState<AdminSettingsAiScreen> createState() =>
      _AdminSettingsAiScreenState();
}

class _AdminSettingsAiScreenState extends ConsumerState<AdminSettingsAiScreen> {
  double _absenceThreshold = 3;
  double _lateThreshold = 4;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('AI Thresholds'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Absence Alert Threshold',
              style: AppTypography.labelLarge.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            Text(
              'Flag student after ${_absenceThreshold.toInt()} absences in 30 days',
              style: AppTypography.bodySmall.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            Slider(
              value: _absenceThreshold,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.error,
              label: _absenceThreshold.toInt().toString(),
              onChanged: (val) => setState(() => _absenceThreshold = val),
            ),
            const SizedBox(height: 24),
            Text(
              'Late Arrival Threshold',
              style: AppTypography.labelLarge.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            Text(
              'Flag student after ${_lateThreshold.toInt()} late arrivals in 30 days',
              style: AppTypography.bodySmall.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            Slider(
              value: _lateThreshold,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.warning,
              label: _lateThreshold.toInt().toString(),
              onChanged: (val) => setState(() => _lateThreshold = val),
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Save Thresholds',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thresholds saved successfully'),
                  ),
                );
              },
              width: double.infinity,
              icon: Icons.save_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ───
class _SectionHeader extends StatelessWidget {
  final bool isDark;
  final String title;

  const _SectionHeader({required this.isDark, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        color:
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _SettingsCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleTile({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavigationTile({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: AppTypography.labelLarge.copyWith(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.accent, size: 18),
      ),
      title: Text(
        label,
        style: AppTypography.labelLarge.copyWith(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      trailing: Text(
        value,
        style: AppTypography.bodySmall.copyWith(
          color:
              isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}
