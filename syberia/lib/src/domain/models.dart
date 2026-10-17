import 'librus_error.dart';

enum EventKind { exam, homework, event }

class LinkedSynergiaAccount {
  const LinkedSynergiaAccount({
    required this.login,
    required this.name,
    required this.selected,
  });
  final String login;
  final String name;
  final bool selected;
}

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.name,
    required this.school,
    required this.provider,
  });
  final String id;
  final String name;
  final String school;
  final String provider;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'school': school,
    'provider': provider,
  };
  factory StudentProfile.fromJson(Map<String, Object?> json) => StudentProfile(
    id: json['id']! as String,
    name: json['name']! as String,
    school: json['school']! as String,
    provider: json['provider']! as String,
  );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.start,
    required this.end,
    this.cancelled = false,
    this.substitution = false,
    this.originalSubject = '',
    this.originalTeacher = '',
    this.originalRoom = '',
    this.movedTo,
    this.lessonNumber,
  });
  final String id;
  final String subject;
  final String teacher;
  final String room;
  final DateTime start;
  final DateTime end;
  final bool cancelled;
  final bool substitution;
  final String originalSubject;
  final String originalTeacher;
  final String originalRoom;
  final DateTime? movedTo;

  /// The lesson's number in the school day ("3. lekcja"), when Librus gives it.
  final int? lessonNumber;

  Lesson copyWith({DateTime? end}) => Lesson(
    id: id,
    subject: subject,
    teacher: teacher,
    room: room,
    start: start,
    end: end ?? this.end,
    cancelled: cancelled,
    substitution: substitution,
    originalSubject: originalSubject,
    originalTeacher: originalTeacher,
    originalRoom: originalRoom,
    movedTo: movedTo,
    lessonNumber: lessonNumber,
  );
}

class Grade {
  const Grade({
    required this.id,
    required this.subject,
    required this.value,
    required this.description,
    required this.date,
    required this.weight,
    required this.semester,
    this.category = '',
    this.previousGrades = const [],
  });
  final String id;
  final String subject;
  final String value;
  final String description;
  final DateTime date;
  final double weight;
  final int semester;
  final String category;

  /// Earlier grade records, ordered from oldest to newest.
  final List<Grade> previousGrades;

  List<String> get replacedValues => [
    for (final grade in previousGrades) grade.value,
  ];

  bool get wasChanged => previousGrades.isNotEmpty;

  Grade copyWith({List<Grade>? previousGrades}) => Grade(
    id: id,
    subject: subject,
    value: value,
    description: description,
    date: date,
    weight: weight,
    semester: semester,
    category: category,
    previousGrades: previousGrades ?? this.previousGrades,
  );
}

class SchoolEvent {
  const SchoolEvent({
    required this.id,
    required this.title,
    required this.subject,
    required this.date,
    required this.kind,
    this.description = '',
    this.typeLabel = '',
    this.lessonNumber,
  });
  final String id;
  final String title;
  final String subject;
  final DateTime date;
  final EventKind kind;
  final String description;
  final String typeLabel;

  /// The lesson of the day a test is written in, when Librus says.
  final int? lessonNumber;
}

class SchoolMessage {
  const SchoolMessage({
    required this.id,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.receivedAt,
    this.unread = false,
    this.hasAttachments = false,
  });
  final String id;
  final String sender;
  final String subject;
  final String preview;
  final DateTime receivedAt;
  final bool unread;
  final bool hasAttachments;
  SchoolMessage copyWith({bool? unread}) => SchoolMessage(
    id: id,
    sender: sender,
    subject: subject,
    preview: preview,
    receivedAt: receivedAt,
    unread: unread ?? this.unread,
    hasAttachments: hasAttachments,
  );
}

class SchoolMessageContent {
  const SchoolMessageContent({
    required this.id,
    required this.sender,
    required this.subject,
    required this.body,
    required this.receivedAt,
    this.attachments = const [],
  });
  final String id;
  final String sender;
  final String subject;
  final String body;
  final DateTime receivedAt;
  final List<MessageAttachment> attachments;
}

class MessageAttachment {
  const MessageAttachment({required this.id, required this.name});
  final String id;
  final String name;
}

class MessageRecipient {
  const MessageRecipient({
    required this.id,
    required this.name,
    required this.group,
  });
  final int id;
  final String name;
  final String group;
}

enum AttendanceKind {
  present,
  absent,
  absentExcused,
  late,
  lateExcused,
  released,
  other,
}

enum AttendanceChartStyle { ring, pie, bar }

/// The look of the app's bars, sheets and menus. [glass] needs a platform
/// that can draw it; elsewhere the app stays [classic] whatever is chosen.
enum AppDesign { glass, classic }

enum AppColorMode { system, light, dark, amoled }

/// How the timetable shows a day: on a time scale or as a list of lessons.
enum TimetableView { timeline, list }

/// How the message list looks: mail-style rows or compact cards.
enum MessageListStyle { list, cards }

/// How the grades of a subject are listed: one compact row each, or cards
/// that open to show every grade.
enum GradesView { compact, cards }

/// The configurable parts of the Today screen.
enum TodayBlock { currentLesson, summary, grades, homework, events, messages }

/// Which Today blocks show, and in what order.
class TodayLayout {
  const TodayLayout(this.blocks);

  static const defaults = TodayLayout([
    (block: TodayBlock.currentLesson, visible: true),
    (block: TodayBlock.summary, visible: true),
    (block: TodayBlock.grades, visible: true),
    (block: TodayBlock.homework, visible: true),
    (block: TodayBlock.events, visible: true),
    (block: TodayBlock.messages, visible: true),
  ]);

  final List<({TodayBlock block, bool visible})> blocks;

  Iterable<TodayBlock> get visible =>
      blocks.where((entry) => entry.visible).map((entry) => entry.block);

  /// Block names in order, hidden ones prefixed with "-".
  List<String> encode() => [
    for (final entry in blocks)
      '${entry.visible ? '' : '-'}${entry.block.name}',
  ];

  /// Reads [encode]'s output. Unknown names are skipped and blocks added in
  /// a later version are visible. The lesson card is inserted first for
  /// layouts saved before it became configurable.
  factory TodayLayout.decode(List<String> saved) {
    final blocks = <({TodayBlock block, bool visible})>[];
    for (final item in saved) {
      final hidden = item.startsWith('-');
      final name = hidden ? item.substring(1) : item;
      final block = TodayBlock.values.where((value) => value.name == name);
      if (block.isEmpty || blocks.any((entry) => entry.block == block.first)) {
        continue;
      }
      blocks.add((block: block.first, visible: !hidden));
    }
    for (final block in TodayBlock.values) {
      if (!blocks.any((entry) => entry.block == block)) {
        if (block == TodayBlock.currentLesson) {
          blocks.insert(0, (block: block, visible: true));
        } else {
          blocks.add((block: block, visible: true));
        }
      }
    }
    return TodayLayout(List.unmodifiable(blocks));
  }

  @override
  bool operator ==(Object other) =>
      other is TodayLayout &&
      other.blocks.length == blocks.length &&
      [
        for (var index = 0; index < blocks.length; index++)
          other.blocks[index] == blocks[index],
      ].every((same) => same);

  @override
  int get hashCode => Object.hashAll(blocks);
}

/// How grades turn into numbers for the average: what a "+" adds, what a
/// "-" takes away, and whether each grade counts by its weight.
class GradeAverageSettings {
  const GradeAverageSettings({
    this.plus = 0.5,
    this.minus = 0.25,
    this.weighted = false,
  });

  static const modifierOptions = [0.25, 0.5, 0.75];

  final double plus;
  final double minus;
  final bool weighted;

  GradeAverageSettings copyWith({
    double? plus,
    double? minus,
    bool? weighted,
  }) => GradeAverageSettings(
    plus: plus ?? this.plus,
    minus: minus ?? this.minus,
    weighted: weighted ?? this.weighted,
  );

  double? valueOf(String label) {
    final value = label.trim().toLowerCase();
    final numeric = double.tryParse(value.replaceFirst(',', '.'));
    if (numeric != null) return numeric;
    final match = RegExp(r'^([1-6])([+-])$').firstMatch(value);
    if (match != null) {
      final base = double.parse(match.group(1)!);
      return match.group(2) == '+' ? base + plus : base - minus;
    }
    return const {
      'niedostateczny': 1.0,
      'f': 1.0,
      'dopuszczający': 2.0,
      'e': 2.0,
      'dostateczny': 3.0,
      'd': 3.0,
      'dobry': 4.0,
      'c': 4.0,
      'bardzo dobry': 5.0,
      'b': 5.0,
      'celujący': 6.0,
      'a': 6.0,
    }[value];
  }

  /// Grades that do not count towards the average have weight 0 and are
  /// left out, as are grades without a numeric value.
  double? average(Iterable<Grade> grades) {
    var sum = 0.0;
    var total = 0.0;
    for (final grade in grades) {
      if (grade.weight <= 0) continue;
      final value = valueOf(grade.value);
      if (value == null) continue;
      final weight = weighted ? grade.weight : 1.0;
      sum += value * weight;
      total += weight;
    }
    return total == 0 ? null : sum / total;
  }

  @override
  bool operator ==(Object other) =>
      other is GradeAverageSettings &&
      other.plus == plus &&
      other.minus == minus &&
      other.weighted == weighted;

  @override
  int get hashCode => Object.hash(plus, minus, weighted);
}

extension AttendanceKindDetails on AttendanceKind {
  bool get countsAsPresence => switch (this) {
    AttendanceKind.present ||
    AttendanceKind.late ||
    AttendanceKind.lateExcused ||
    AttendanceKind.released ||
    AttendanceKind.other => true,
    AttendanceKind.absent || AttendanceKind.absentExcused => false,
  };

  bool get isExcused =>
      this == AttendanceKind.absentExcused ||
      this == AttendanceKind.lateExcused;
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.lessonNumber,
    required this.subject,
    required this.type,
    required this.symbol,
    required this.kind,
    this.semester = 1,
  });
  final String id;
  final DateTime date;
  final int lessonNumber;
  final String subject;
  final String type;
  final String symbol;
  final AttendanceKind kind;
  final int semester;
  bool get isPresence => kind.countsAsPresence;
  bool get isExcused => kind.isExcused;
}

class SchoolAnnouncement {
  const SchoolAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.createdAt,
    required this.validUntil,
    required this.read,
  });
  final String id;
  final String title;
  final String content;
  final String author;
  final DateTime createdAt;
  final DateTime? validUntil;
  final bool read;
}

enum NoticeTone { positive, neutral, negative }

class StudentNotice {
  const StudentNotice({
    required this.id,
    required this.text,
    required this.category,
    required this.teacher,
    required this.date,
    required this.tone,
  });
  final String id;
  final String text;
  final String category;
  final String teacher;
  final DateTime date;
  final NoticeTone tone;
}

class AppSnapshot {
  const AppSnapshot({
    required this.profile,
    required this.lessons,
    required this.grades,
    required this.events,
    required this.messages,
    required this.attendance,
    required this.announcements,
    required this.notices,
    required this.lastSync,
    this.messagesError,
  });
  final StudentProfile profile;
  final List<Lesson> lessons;
  final List<Grade> grades;
  final List<SchoolEvent> events;
  final List<SchoolMessage> messages;
  final AppError? messagesError;
  final List<AttendanceRecord> attendance;
  final List<SchoolAnnouncement> announcements;
  final List<StudentNotice> notices;
  final DateTime lastSync;
  int get unreadMessages => messages.where((item) => item.unread).length;
  int get absences => attendance
      .where(
        (item) =>
            item.kind == AttendanceKind.absent ||
            item.kind == AttendanceKind.absentExcused,
      )
      .length;
  AppSnapshot copyWith({
    List<Lesson>? lessons,
    List<SchoolEvent>? events,
    List<SchoolMessage>? messages,
    DateTime? lastSync,
  }) => AppSnapshot(
    profile: profile,
    lessons: lessons ?? this.lessons,
    grades: grades,
    events: events ?? this.events,
    messages: messages ?? this.messages,
    messagesError: messagesError,
    attendance: attendance,
    announcements: announcements,
    notices: notices,
    lastSync: lastSync ?? this.lastSync,
  );
}
