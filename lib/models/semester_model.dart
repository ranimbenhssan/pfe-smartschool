import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FIXED HOLIDAY  (recurring every year — e.g. New Year, Independence Day)
//  Only month + day are stored. Year is inferred at runtime.
// ─────────────────────────────────────────────────────────────────────────────
class FixedHoliday {
  final int month; // 1–12
  final int day; // 1–31
  final String name;

  const FixedHoliday({
    required this.month,
    required this.day,
    required this.name,
  });

  factory FixedHoliday.fromMap(Map<String, dynamic> m) => FixedHoliday(
    month: (m['month'] as num).toInt(),
    day: (m['day'] as num).toInt(),
    name: m['name']?.toString() ?? '',
  );

  Map<String, dynamic> toMap() => {'month': month, 'day': day, 'name': name};

  /// Whether a given date matches this holiday (year-independent)
  bool matchesDate(DateTime date) => date.month == month && date.day == day;

  String get display {
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
    return '$name (${months[month]} $day)';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCHOOL CLOSURE  (admin-configured date range — e.g. mid-term break)
//  Can be 1 day, 3 days, 2 weeks — anything.
//  Shown school-wide as "NO CLASSES" on dashboards.
// ─────────────────────────────────────────────────────────────────────────────
class SchoolClosure {
  final String id; // UUID
  final String name; // e.g. "Spring Break", "Exam Week"
  final DateTime startDate;
  final DateTime endDate;

  const SchoolClosure({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  factory SchoolClosure.fromMap(Map<String, dynamic> m) => SchoolClosure(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? '',
    startDate: (m['startDate'] as Timestamp).toDate(),
    endDate: (m['endDate'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
  };

  bool containsDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  int get durationDays => endDate.difference(startDate).inDays + 1;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEMESTER MODEL
//
//  Firestore: semesters/{id}
//  {
//    name, startDate, endDate, firstWeekType, isActive,
//    fixedHolidays: [{month, day, name}, ...],
//    schoolClosures: [{id, name, startDate, endDate}, ...],
//  }
// ─────────────────────────────────────────────────────────────────────────────
class SemesterModel {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String firstWeekType; // 'A' or 'B'
  final List<FixedHoliday> fixedHolidays;
  final List<SchoolClosure> schoolClosures;
  final bool isActive;

  /// Default Tunisian / common fixed holidays — pre-populated for convenience.
  static const List<FixedHoliday> defaultFixedHolidays = [
    FixedHoliday(month: 1, day: 1, name: "New Year's Day"),
    FixedHoliday(month: 3, day: 20, name: "Independence Day"),
    FixedHoliday(month: 4, day: 9, name: "Martyrs' Day"),
    FixedHoliday(month: 5, day: 1, name: "Labour Day"),
    FixedHoliday(month: 7, day: 25, name: "Republic Day"),
    FixedHoliday(month: 8, day: 13, name: "Women's Day"),
    FixedHoliday(month: 10, day: 15, name: "Evacuation Day"),
  ];

  const SemesterModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.firstWeekType = 'A',
    this.fixedHolidays = const [],
    this.schoolClosures = const [],
    this.isActive = false,
  });

  factory SemesterModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SemesterModel(
      id: doc.id,
      name: d['name']?.toString() ?? '',
      startDate: (d['startDate'] as Timestamp).toDate(),
      endDate: (d['endDate'] as Timestamp).toDate(),
      firstWeekType: d['firstWeekType']?.toString() ?? 'A',
      isActive: d['isActive'] == true,
      fixedHolidays:
          (d['fixedHolidays'] as List<dynamic>? ?? [])
              .map(
                (e) =>
                    FixedHoliday.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
      schoolClosures:
          (d['schoolClosures'] as List<dynamic>? ?? [])
              .map(
                (e) =>
                    SchoolClosure.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'firstWeekType': firstWeekType,
    'isActive': isActive,
    'fixedHolidays': fixedHolidays.map((h) => h.toMap()).toList(),
    'schoolClosures': schoolClosures.map((c) => c.toMap()).toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  // ── Week type calculation ─────────────────────────────────────────────────
  String weekTypeFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    if (d.isBefore(s)) return firstWeekType;
    final weeks = d.difference(s).inDays ~/ 7;
    return weeks.isEven ? firstWeekType : (firstWeekType == 'A' ? 'B' : 'A');
  }

  // ── Holiday checks ────────────────────────────────────────────────────────
  bool isFixedHoliday(DateTime date) =>
      fixedHolidays.any((h) => h.matchesDate(date));

  bool isSchoolClosure(DateTime date) =>
      schoolClosures.any((c) => c.containsDate(date));

  bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  bool isSchoolDay(DateTime date) =>
      !isWeekend(date) && !isFixedHoliday(date) && !isSchoolClosure(date);

  /// Returns the closure that covers a date, or null
  SchoolClosure? closureFor(DateTime date) {
    for (final c in schoolClosures) {
      if (c.containsDate(date)) return c;
    }
    return null;
  }

  /// Returns the fixed holiday that matches a date, or null
  FixedHoliday? fixedHolidayFor(DateTime date) {
    for (final h in fixedHolidays) {
      if (h.matchesDate(date)) return h;
    }
    return null;
  }

  // ── School days list ──────────────────────────────────────────────────────
  List<DateTime> get schoolDays {
    final days = <DateTime>[];
    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    while (!current.isAfter(end)) {
      if (isSchoolDay(current)) days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  // ── Copy with closures or fixed holidays updated ─────────────────────────
  SemesterModel copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? firstWeekType,
    List<FixedHoliday>? fixedHolidays,
    List<SchoolClosure>? schoolClosures,
    bool? isActive,
  }) => SemesterModel(
    id: id,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    firstWeekType: firstWeekType ?? this.firstWeekType,
    fixedHolidays: fixedHolidays ?? this.fixedHolidays,
    schoolClosures: schoolClosures ?? this.schoolClosures,
    isActive: isActive ?? this.isActive,
  );
}
