class AppRoutes {
  AppRoutes._();

  // ─── Shared ───
  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  // ─── Admin ───
  static const String adminDashboard = '/admin/dashboard';
  static const String adminStudents = '/admin/students';
  static const String adminStudentAdd = '/admin/students/add';
  static const String adminStudentEdit = '/admin/students/edit';
  static const String adminStudentProfile = '/admin/students/profile';
  static const String adminTeachers = '/admin/teachers';
  static const String adminTeacherAdd = '/admin/teachers/add';
  static const String adminTeacherEdit = '/admin/teachers/edit';
  static const String adminTeacherProfile = '/admin/teachers/profile';
  static const String adminClasses = '/admin/classes';
  static const String adminClassAdd = '/admin/classes/add';
  static const String adminClassEdit = '/admin/classes/edit';
  static const String adminClassDetail = '/admin/classes/detail';
  static const String adminRfid = '/admin/rfid';
  static const String adminRfidUnrecognized = '/admin/rfid/unrecognized';
  static const String adminAttendance = '/admin/attendance';
  static const String adminAttendanceByDate = '/admin/attendance/by-date';
  static const String adminAttendanceByClass = '/admin/attendance/by-class';
  static const String adminAttendanceEdit = '/admin/attendance/edit';
  static const String adminAttendanceStats = '/admin/attendance/stats';
  static const String adminIot = '/admin/iot';
  static const String adminRoomDetail = '/admin/iot/room';
  static const String adminAiAlerts = '/admin/ai-alerts';
  static const String adminAlertDetail = '/admin/ai-alerts/detail';
  static const String adminAlertResolved = '/admin/ai-alerts/resolved';
  static const String adminNotifications = '/admin/notifications';
  static const String adminNotificationSend = '/admin/notifications/send';
  static const String adminTimetable = '/admin/timetable';
  static const String adminTimetableAdd = '/admin/timetable/add';
  static const String adminTimetableEdit = '/admin/timetable/edit';
  static const String adminSettings = '/admin/settings';
  static const String adminSettingsRfid = '/admin/settings/rfid';
  static const String adminSettingsSensors = '/admin/settings/sensors';
  static const String adminSettingsAi = '/admin/settings/ai';

  // ─── Teacher ───
  static const String teacherDashboard = '/teacher/dashboard';
  static const String teacherAttendance = '/teacher/attendance';
  static const String teacherAttendanceToday = '/teacher/attendance/today';
  static const String teacherAttendanceNameCall =
      '/teacher/attendance/namecall'; // ← NEW
  static const String teacherAttendanceByDate = '/teacher/attendance/by-date';
  static const String teacherAttendanceEdit = '/teacher/attendance/edit';
  static const String teacherAttendanceStats = '/teacher/attendance/stats';
  static const String teacherIot = '/teacher/iot';
  static const String teacherIotHistory = '/teacher/iot/history';
  static const String teacherStudents = '/teacher/students';
  static const String teacherStudentProfile = '/teacher/students/profile';
  static const String teacherAiAlerts = '/teacher/ai-alerts';
  static const String teacherAlertDetail = '/teacher/ai-alerts/detail';
  static const String teacherTimetable = '/teacher/timetable';
  static const String teacherTimetableDetail = '/teacher/timetable/detail';
  static const String teacherNotifications = '/teacher/notifications';

  // ─── Student ───
  static const String studentDashboard = '/student/dashboard';
  static const String studentAttendance = '/student/attendance';
  static const String studentAttendanceStats = '/student/attendance/stats';
  static const String studentTimetable = '/student/timetable';
  static const String studentTimetableDetail = '/student/timetable/detail';
  static const String studentIot = '/student/iot';
  static const String studentIotHistory = '/student/iot/history';
  static const String studentNotifications = '/student/notifications';
  static const adminRooms = '/admin/rooms';
  static const teacherNotificationSend = '/teacher/notifications/send';
  static const studentNotificationSend = '/student/notifications/send';
  static const adminTimetableForm = '/admin/timetable/form';
  static const messageDetail = '/message-detail';
}
