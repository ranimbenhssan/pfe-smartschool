import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(firestore: ref.watch(firestoreProvider));
});

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({required FirebaseFirestore firestore})
    : _firestore = firestore;

  // ─────────────────────────────────────────
  //  STUDENTS
  // ─────────────────────────────────────────

  // Get all students stream
  Stream<List<StudentModel>> getStudents() {
    return _firestore
        .collection('students')
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => StudentModel.fromFirestore(doc)).toList(),
        );
  }

  // Get students by class
  Stream<List<StudentModel>> getStudentsByClass(String classId) {
    return _firestore
        .collection('students')
        .where('classId', isEqualTo: classId)
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => StudentModel.fromFirestore(doc)).toList(),
        );
  }

  // Get single student
  Future<StudentModel?> getStudent(String studentId) async {
    final doc = await _firestore.collection('students').doc(studentId).get();
    if (!doc.exists) return null;
    return StudentModel.fromFirestore(doc);
  }

  // Get student by RFID tag
  Future<StudentModel?> getStudentByRfid(String rfidTag) async {
    final snap =
        await _firestore
            .collection('students')
            .where('rfidTag', isEqualTo: rfidTag)
            .limit(1)
            .get();
    if (snap.docs.isEmpty) return null;
    return StudentModel.fromFirestore(snap.docs.first);
  }

  // Add student
  Future<void> addStudent(StudentModel student) async {
    debugPrint('📝 Adding student: ${student.id}');
    await _firestore
        .collection('students')
        .doc(student.id)
        .set(student.toFirestore());
    debugPrint('✅ Student added successfully');
  }

  // Update student
  Future<void> updateStudent(
    String studentId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('students').doc(studentId).update(data);
  }

  // Delete student
  Future<void> deleteStudent(String studentId) async {
    await _firestore.collection('students').doc(studentId).delete();
  }

  // ─────────────────────────────────────────
  //  TEACHERS
  // ─────────────────────────────────────────

  Stream<List<TeacherModel>> getTeachers() {
    return _firestore
        .collection('teachers')
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => TeacherModel.fromFirestore(doc)).toList(),
        );
  }

  Future<TeacherModel?> getTeacher(String teacherId) async {
    final doc = await _firestore.collection('teachers').doc(teacherId).get();
    if (!doc.exists) return null;
    return TeacherModel.fromFirestore(doc);
  }

  Future<void> addTeacher(TeacherModel teacher) async {
  debugPrint('📝 Adding teacher: ${teacher.id}');
  await _firestore
      .collection('teachers')
      .doc(teacher.id)
      .set(teacher.toFirestore());
  debugPrint('✅ Teacher added successfully');
}

  Future<void> updateTeacher(
    String teacherId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('teachers').doc(teacherId).update(data);
  }

  Future<void> deleteTeacher(String teacherId) async {
    await _firestore.collection('teachers').doc(teacherId).delete();
  }

  // ─────────────────────────────────────────
  //  CLASSES
  // ─────────────────────────────────────────

  Stream<List<ClassModel>> getClasses() {
    return _firestore
        .collection('classes')
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => ClassModel.fromFirestore(doc)).toList(),
        );
  }

  Future<ClassModel?> getClass(String classId) async {
    final doc = await _firestore.collection('classes').doc(classId).get();
    if (!doc.exists) return null;
    return ClassModel.fromFirestore(doc);
  }

  Future<void> addClass(ClassModel classModel) async {
    await _firestore
        .collection('classes')
        .doc(classModel.id)
        .set(classModel.toFirestore());
  }

  Future<void> updateClass(String classId, Map<String, dynamic> data) async {
    await _firestore.collection('classes').doc(classId).update(data);
  }

  Future<void> deleteClass(String classId) async {
    await _firestore.collection('classes').doc(classId).delete();
  }

  // ─────────────────────────────────────────
  //  ROOMS
  // ─────────────────────────────────────────

  Stream<List<RoomModel>> getRooms() {
    return _firestore
        .collection('rooms')
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => RoomModel.fromFirestore(doc)).toList(),
        );
  }

  Future<RoomModel?> getRoom(String roomId) async {
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    if (!doc.exists) return null;
    return RoomModel.fromFirestore(doc);
  }

  Future<void> addRoom(RoomModel room) async {
    await _firestore.collection('rooms').doc(room.id).set(room.toFirestore());
  }

  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    await _firestore.collection('rooms').doc(roomId).update(data);
  }

  // ─────────────────────────────────────────
  //  ATTENDANCE
  // ─────────────────────────────────────────

  // Get attendance by date (all classes)
  Stream<List<AttendanceModel>> getAttendanceByDate(String date) {
    return _firestore
        .collection('attendance')
        .where('date', isEqualTo: date)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => AttendanceModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get attendance by date and class
  Stream<List<AttendanceModel>> getAttendanceByDateAndClass(
    String date,
    String classId,
  ) {
    return _firestore
        .collection('attendance')
        .where('date', isEqualTo: date)
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => AttendanceModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get attendance by student (last 30 days)
  Stream<List<AttendanceModel>> getAttendanceByStudent(String studentId) {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _firestore
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => AttendanceModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Update attendance
  Future<void> updateAttendance(
    String attendanceId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('attendance').doc(attendanceId).update(data);
  }

  // Set attendance
  Future<void> setAttendance(AttendanceModel attendance) async {
    await _firestore
        .collection('attendance')
        .doc(attendance.id)
        .set(attendance.toFirestore());
  }

  // ─────────────────────────────────────────
  //  RFID LOGS
  // ─────────────────────────────────────────

  // Get all RFID logs (real-time)
  Stream<List<RfidLogModel>> getRfidLogs({int limit = 50}) {
    return _firestore
        .collection('rfid_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => RfidLogModel.fromFirestore(doc)).toList(),
        );
  }

  // Get RFID logs by student
  Stream<List<RfidLogModel>> getRfidLogsByStudent(
    String studentId, {
    int limit = 30,
  }) {
    return _firestore
        .collection('rfid_logs')
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => RfidLogModel.fromFirestore(doc)).toList(),
        );
  }

  // Get unrecognized RFID scans
  Stream<List<RfidLogModel>> getUnrecognizedRfidLogs() {
    return _firestore
        .collection('rfid_logs')
        .where('isRecognized', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => RfidLogModel.fromFirestore(doc)).toList(),
        );
  }

  // ─────────────────────────────────────────
  //  SENSOR DATA
  // ─────────────────────────────────────────

  // Get latest sensor reading for a room
  Stream<SensorModel?> getLatestSensorData(String roomId) {
    return _firestore
        .collection('sensor_data')
        .where('roomId', isEqualTo: roomId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return SensorModel.fromFirestore(snap.docs.first);
        });
  }

  // Get sensor history for a room
  Stream<List<SensorModel>> getSensorHistory(String roomId, {int limit = 50}) {
    return _firestore
        .collection('sensor_data')
        .where('roomId', isEqualTo: roomId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => SensorModel.fromFirestore(doc)).toList(),
        );
  }

  // ─────────────────────────────────────────
  //  AI FLAGS
  // ─────────────────────────────────────────

  // Get all active AI flags
  Stream<List<AiFlagModel>> getActiveAiFlags() {
    return _firestore
        .collection('ai_flags')
        .where('resolved', isEqualTo: false)
        .orderBy('detectedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => AiFlagModel.fromFirestore(doc)).toList(),
        );
  }

  // Get AI flags by class
  Stream<List<AiFlagModel>> getAiFlagsByClass(String classId) {
    return _firestore
        .collection('ai_flags')
        .where('classId', isEqualTo: classId)
        .where('resolved', isEqualTo: false)
        .orderBy('detectedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => AiFlagModel.fromFirestore(doc)).toList(),
        );
  }

  // Get AI flags by student
  Stream<List<AiFlagModel>> getAiFlagsByStudent(String studentId) {
    return _firestore
        .collection('ai_flags')
        .where('studentId', isEqualTo: studentId)
        .orderBy('detectedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => AiFlagModel.fromFirestore(doc)).toList(),
        );
  }

  // Get resolved AI flags
  Stream<List<AiFlagModel>> getResolvedAiFlags() {
    return _firestore
        .collection('ai_flags')
        .where('resolved', isEqualTo: true)
        .orderBy('resolvedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => AiFlagModel.fromFirestore(doc)).toList(),
        );
  }

  // Resolve AI flag
  Future<void> resolveAiFlag(String flagId) async {
    await _firestore.collection('ai_flags').doc(flagId).update({
      'resolved': true,
      'resolvedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ─────────────────────────────────────────
  //  NOTIFICATIONS
  // ─────────────────────────────────────────

  // Get notifications for a user
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => NotificationModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Mark notification as read
  Future<void> markNotificationRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsRead(String userId) async {
    final snap =
        await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Add notification
  Future<void> addNotification(NotificationModel notification) async {
    await _firestore
        .collection('notifications')
        .doc(notification.id)
        .set(notification.toFirestore());
  }

  // ─────────────────────────────────────────
  //  TIMETABLE
  // ─────────────────────────────────────────

  // Get timetable by class
  Stream<List<TimetableModel>> getTimetableByClass(String classId) {
    return _firestore
        .collection('timetable')
        .where('classId', isEqualTo: classId)
        .orderBy('dayOfWeek')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => TimetableModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get timetable by teacher
  Stream<List<TimetableModel>> getTimetableByTeacher(String teacherId) {
    return _firestore
        .collection('timetable')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('dayOfWeek')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => TimetableModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get full timetable (admin)
  Stream<List<TimetableModel>> getFullTimetable() {
    return _firestore
        .collection('timetable')
        .orderBy('dayOfWeek')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => TimetableModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Add timetable entry
  Future<void> addTimetableEntry(TimetableModel entry) async {
    await _firestore
        .collection('timetable')
        .doc(entry.id)
        .set(entry.toFirestore());
  }

  // Update timetable entry
  Future<void> updateTimetableEntry(
    String entryId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('timetable').doc(entryId).update(data);
  }

  // Delete timetable entry
  Future<void> deleteTimetableEntry(String entryId) async {
    await _firestore.collection('timetable').doc(entryId).delete();
  }

  // ─────────────────────────────────────────
  //  DASHBOARD STATS (Admin)
  // ─────────────────────────────────────────

  Future<Map<String, int>> getDashboardStats() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final results = await Future.wait([
      _firestore.collection('students').count().get(),
      _firestore.collection('teachers').count().get(),
      _firestore.collection('classes').count().get(),
      _firestore
          .collection('attendance')
          .where('date', isEqualTo: dateStr)
          .where('status', isEqualTo: 'present')
          .count()
          .get(),
      _firestore
          .collection('attendance')
          .where('date', isEqualTo: dateStr)
          .where('status', isEqualTo: 'absent')
          .count()
          .get(),
      _firestore
          .collection('ai_flags')
          .where('resolved', isEqualTo: false)
          .count()
          .get(),
    ]);

    return {
      'totalStudents': results[0].count ?? 0,
      'totalTeachers': results[1].count ?? 0,
      'totalClasses': results[2].count ?? 0,
      'presentToday': results[3].count ?? 0,
      'absentToday': results[4].count ?? 0,
      'activeFlags': results[5].count ?? 0,
    };
  }
}
