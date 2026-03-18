import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import 'app_routes.dart';
import '../../../models/models.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/shared/login_screen.dart';
import '../screens/shared/forgot_password_screen.dart';
import '../screens/admin/dashboard/admin_dashboard_screen.dart';
import '../screens/admin/students/admin_students_screen.dart';
import '../screens/admin/students/admin_student_form_screen.dart';
import '../screens/admin/students/admin_student_profile_screen.dart';
import '../screens/admin/teachers/admin_teachers_screen.dart';
import '../screens/admin/teachers/admin_teacher_form_screen.dart';
import '../screens/admin/teachers/admin_teacher_profile_screen.dart';
import '../screens/admin/classes/admin_classes_screen.dart';
import '../screens/admin/classes/admin_class_form_screen.dart';
import '../screens/admin/classes/admin_class_detail_screen.dart';
import '../screens/admin/rfid/admin_rfid_screen.dart';
import '../screens/admin/rfid/admin_rfid_unrecognized_screen.dart';
import '../screens/admin/attendance/admin_attendance_screen.dart';
import '../screens/admin/attendance/admin_attendance_by_date_screen.dart';
import '../screens/admin/attendance/admin_attendance_by_class_screen.dart';
import '../screens/admin/attendance/admin_attendance_edit_screen.dart';
import '../screens/admin/attendance/admin_attendance_stats_screen.dart';
import '../screens/admin/iot_monitor/admin_iot_screen.dart';
import '../screens/admin/iot_monitor/admin_room_detail_screen.dart';
import '../screens/admin/ai_alerts/admin_ai_alerts_screen.dart';
import '../screens/admin/ai_alerts/admin_alert_detail_screen.dart';
import '../screens/admin/ai_alerts/admin_alert_resolved_screen.dart';
import '../screens/admin/notifications/admin_notifications_screen.dart';
import '../screens/admin/notifications/admin_notification_send_screen.dart';
import '../screens/admin/timetable/admin_timetable_screen.dart';
import '../screens/admin/timetable/admin_timetable_form_screen.dart';
import '../screens/admin/settings/admin_settings_screen.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.splash;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      return null;
    },
    routes: [
      // ─── Shared ───
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ─── Admin ───
      GoRoute(
        path: AppRoutes.adminDashboard,
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminStudents,
        name: 'admin-students',
        builder: (context, state) => const AdminStudentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminStudentAdd,
        name: 'admin-student-add',
        builder: (context, state) => const AdminStudentFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.adminStudentEdit}/:id',
        name: 'admin-student-edit',
        builder:
            (context, state) =>
                AdminStudentFormScreen(studentId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '${AppRoutes.adminStudentProfile}/:id',
        name: 'admin-student-profile',
        builder:
            (context, state) => AdminStudentProfileScreen(
              studentId: state.pathParameters['id']!,
            ),
      ),
      GoRoute(
        path: AppRoutes.adminTeachers,
        name: 'admin-teachers',
        builder: (context, state) => const AdminTeachersScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminTeacherAdd,
        name: 'admin-teacher-add',
        builder: (context, state) => const AdminTeacherFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.adminTeacherEdit}/:id',
        name: 'admin-teacher-edit',
        builder:
            (context, state) =>
                AdminTeacherFormScreen(teacherId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '${AppRoutes.adminTeacherProfile}/:id',
        name: 'admin-teacher-profile',
        builder:
            (context, state) => AdminTeacherProfileScreen(
              teacherId: state.pathParameters['id']!,
            ),
      ),
      GoRoute(
        path: AppRoutes.adminClasses,
        name: 'admin-classes',
        builder: (context, state) => const AdminClassesScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminClassAdd,
        name: 'admin-class-add',
        builder: (context, state) => const AdminClassFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.adminClassEdit}/:id',
        name: 'admin-class-edit',
        builder:
            (context, state) =>
                AdminClassFormScreen(classId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '${AppRoutes.adminClassDetail}/:id',
        name: 'admin-class-detail',
        builder:
            (context, state) =>
                AdminClassDetailScreen(classId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.adminRfid,
        name: 'admin-rfid',
        builder: (context, state) => const AdminRfidScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminRfidUnrecognized,
        name: 'admin-rfid-unrecognized',
        builder: (context, state) => const AdminRfidUnrecognizedScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAttendance,
        name: 'admin-attendance',
        builder: (context, state) => const AdminAttendanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAttendanceByDate,
        name: 'admin-attendance-by-date',
        builder: (context, state) => const AdminAttendanceByDateScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAttendanceByClass,
        name: 'admin-attendance-by-class',
        builder: (context, state) => const AdminAttendanceByClassScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAttendanceEdit,
        name: 'admin-attendance-edit',
        builder:
            (context, state) => AdminAttendanceEditScreen(
              attendance: state.extra as AttendanceModel,
            ),
      ),
      GoRoute(
        path: AppRoutes.adminAttendanceStats,
        name: 'admin-attendance-stats',
        builder: (context, state) => const AdminAttendanceStatsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminIot,
        name: 'admin-iot',
        builder: (context, state) => const AdminIotScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.adminRoomDetail}/:id',
        name: 'admin-room-detail',
        builder:
            (context, state) =>
                AdminRoomDetailScreen(roomId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.adminAiAlerts,
        name: 'admin-ai-alerts',
        builder: (context, state) => const AdminAiAlertsScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.adminAlertDetail}/:id',
        name: 'admin-alert-detail',
        builder:
            (context, state) =>
                AdminAlertDetailScreen(flagId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.adminAlertResolved,
        name: 'admin-alert-resolved',
        builder: (context, state) => const AdminAlertResolvedScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminNotifications,
        name: 'admin-notifications',
        builder: (context, state) => const AdminNotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminNotificationSend,
        name: 'admin-notification-send',
        builder: (context, state) => const AdminNotificationSendScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminTimetable,
        name: 'admin-timetable',
        builder: (context, state) => const AdminTimetableScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminTimetableAdd,
        name: 'admin-timetable-add',
        builder: (context, state) => const AdminTimetableFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.adminTimetableEdit}/:id',
        name: 'admin-timetable-edit',
        builder:
            (context, state) =>
                AdminTimetableFormScreen(entryId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.adminSettings,
        name: 'admin-settings',
        builder: (context, state) => const AdminSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminSettingsRfid,
        name: 'admin-settings-rfid',
        builder: (context, state) => const AdminSettingsRfidScreen(),
      ),

      GoRoute(
        path: AppRoutes.adminSettingsSensors,
        name: 'admin-settings-sensors',
        builder: (context, state) => const AdminSettingsSensorsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminSettingsAi,
        name: 'admin-settings-ai',
        builder: (context, state) => const AdminSettingsAiScreen(),
      ),

      // ─── Teacher ───
      GoRoute(
        path: AppRoutes.teacherDashboard,
        name: 'teacher-dashboard',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Teacher Dashboard'),
      ),
      GoRoute(
        path: AppRoutes.teacherAttendance,
        name: 'teacher-attendance',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Attendance Overview'),
      ),
      GoRoute(
        path: AppRoutes.teacherAttendanceToday,
        name: 'teacher-attendance-today',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: "Today's Attendance"),
      ),
      GoRoute(
        path: AppRoutes.teacherAttendanceByDate,
        name: 'teacher-attendance-by-date',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Attendance by Date'),
      ),
      GoRoute(
        path: AppRoutes.teacherAttendanceEdit,
        name: 'teacher-attendance-edit',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Edit Attendance'),
      ),
      GoRoute(
        path: AppRoutes.teacherAttendanceStats,
        name: 'teacher-attendance-stats',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Attendance Stats'),
      ),
      GoRoute(
        path: AppRoutes.teacherIot,
        name: 'teacher-iot',
        builder:
            (context, state) => const PlaceholderScreen(title: 'Classroom IoT'),
      ),
      GoRoute(
        path: AppRoutes.teacherIotHistory,
        name: 'teacher-iot-history',
        builder:
            (context, state) => const PlaceholderScreen(title: 'IoT History'),
      ),
      GoRoute(
        path: AppRoutes.teacherStudents,
        name: 'teacher-students',
        builder:
            (context, state) => const PlaceholderScreen(title: 'My Students'),
      ),
      GoRoute(
        path: '${AppRoutes.teacherStudentProfile}/:id',
        name: 'teacher-student-profile',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Student Profile'),
      ),
      GoRoute(
        path: AppRoutes.teacherAiAlerts,
        name: 'teacher-ai-alerts',
        builder:
            (context, state) => const PlaceholderScreen(title: 'AI Alerts'),
      ),
      GoRoute(
        path: '${AppRoutes.teacherAlertDetail}/:id',
        name: 'teacher-alert-detail',
        builder:
            (context, state) => const PlaceholderScreen(title: 'Alert Detail'),
      ),
      GoRoute(
        path: AppRoutes.teacherTimetable,
        name: 'teacher-timetable',
        builder:
            (context, state) => const PlaceholderScreen(title: 'My Timetable'),
      ),
      GoRoute(
        path: '${AppRoutes.teacherTimetableDetail}/:id',
        name: 'teacher-timetable-detail',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Timetable Detail'),
      ),
      GoRoute(
        path: AppRoutes.teacherNotifications,
        name: 'teacher-notifications',
        builder:
            (context, state) => const PlaceholderScreen(title: 'Notifications'),
      ),

      // ─── Student ───
      GoRoute(
        path: AppRoutes.studentDashboard,
        name: 'student-dashboard',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Student Dashboard'),
      ),
      GoRoute(
        path: AppRoutes.studentAttendance,
        name: 'student-attendance',
        builder:
            (context, state) => const PlaceholderScreen(title: 'My Attendance'),
      ),
      GoRoute(
        path: AppRoutes.studentAttendanceStats,
        name: 'student-attendance-stats',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Attendance Stats'),
      ),
      GoRoute(
        path: AppRoutes.studentTimetable,
        name: 'student-timetable',
        builder:
            (context, state) => const PlaceholderScreen(title: 'My Timetable'),
      ),
      GoRoute(
        path: '${AppRoutes.studentTimetableDetail}/:id',
        name: 'student-timetable-detail',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Timetable Detail'),
      ),
      GoRoute(
        path: AppRoutes.studentIot,
        name: 'student-iot',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Classroom Environment'),
      ),
      GoRoute(
        path: AppRoutes.studentIotHistory,
        name: 'student-iot-history',
        builder:
            (context, state) =>
                const PlaceholderScreen(title: 'Environment History'),
      ),
      GoRoute(
        path: AppRoutes.studentNotifications,
        name: 'student-notifications',
        builder:
            (context, state) => const PlaceholderScreen(title: 'Notifications'),
      ),
    ],

    errorBuilder:
        (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  state.error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.splash),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
  );
});

class SplashRedirect extends ConsumerWidget {
  const SplashRedirect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userRole = ref.watch(userRoleProvider);

    return authState.when(
      loading: () => const _SplashLoadingScreen(),
      error: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(AppRoutes.login);
        });
        return const _SplashLoadingScreen();
      },
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(AppRoutes.login);
          });
          return const _SplashLoadingScreen();
        }
        return userRole.when(
          loading: () => const _SplashLoadingScreen(),
          error: (_, __) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(AppRoutes.login);
            });
            return const _SplashLoadingScreen();
          },
          data: (role) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              switch (role) {
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
            });
            return const _SplashLoadingScreen();
          },
        );
      },
    );
  }
}

class _SplashLoadingScreen extends StatelessWidget {
  const _SplashLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFD4A843),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Color(0xFF0A1628),
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SmartSchool',
              style: TextStyle(
                fontFamily: 'Playfair',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF0F4FF),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Smart. Connected. Efficient.',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: Color(0xFF8FA3C0),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFFD4A843),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
