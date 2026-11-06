import 'librus_error.dart';

enum EventKind { exam, homework, event }

/// A student in a Librus login: one Synergia account, which can become a
/// profile.
class LinkedSynergiaAccount {
  const LinkedSynergiaAccount({
    required this.login,
    required this.name,
    required this.selected,
    this.account = '',
    this.parent = false,
  });
  final String login;
  final String name;

  /// Whether the phone has a profile for it.
  final bool selected;

  /// The Librus login it is in, as the phone names it.
  final String account;

  /// Whether it is a parent's account rather than the student's own.
  final bool parent;

  LinkedSynergiaAccount copyWith({bool? selected}) => LinkedSynergiaAccount(
    login: login,
    name: name,
    selected: selected ?? this.selected,
    account: account,
    parent: parent,
  );
}

/// What logging in to a Librus account found: the login, as the phone
/// names it, and the students in it.
class LibrusSignIn {
  const LibrusSignIn({required this.account, required this.students});
  final String account;
  final List<LinkedSynergiaAccount> students;
}

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.name,
    required this.school,
    required this.provider,
    this.pluginId,
  });
  final String id;
  final String name;
  final String school;
  final String provider;
  final String? pluginId;
  bool get connected => provider == 'Librus Synergia' || pluginId != null;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'school': school,
    'provider': provider,
    if (pluginId != null) 'pluginId': pluginId,
  };
  factory StudentProfile.fromJson(Map<String, Object?> json) => StudentProfile(
    id: json['id']! as String,
    name: json['name']! as String,
    school: json['school']! as String,
    provider: json['provider']! as String,
    pluginId: json['pluginId'] as String?,
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
    this.source,
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

  /// The profile it comes from when every profile is shown together, its
  /// id then begun with that profile's; null in a single profile's view.
  final String? source;

  Lesson copyWith({DateTime? end}) => withSource(source, id: id, end: end);

  /// This lesson as [source]'s, under [id].
  Lesson withSource(String? source, {required String id, DateTime? end}) =>
      Lesson(
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
        source: source,
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
    this.countsToAverage = true,
    this.assessment = 'current',
    this.previousGrades = const [],
    this.source,
  });
  final String id;
  final String subject;
  final String value;
  final String description;
  final DateTime date;
  final double weight;
  final int semester;
  final String category;
  final bool countsToAverage;
  final String assessment;

  /// Earlier grade records, ordered from oldest to newest.
  final List<Grade> previousGrades;

  List<String> get replacedValues => [
    for (final grade in previousGrades) grade.value,
  ];

  bool get wasChanged => previousGrades.isNotEmpty;

  /// The profile it comes from when every profile is shown together, its
  /// id then begun with that profile's; null in a single profile's view.
  final String? source;

  Grade copyWith({List<Grade>? previousGrades}) =>
      withSource(source, id: id, previousGrades: previousGrades);

  /// This grade as [source]'s, under [id].
  Grade withSource(
    String? source, {
    required String id,
    List<Grade>? previousGrades,
  }) => Grade(
    id: id,
    subject: subject,
    value: value,
    description: description,
    date: date,
    weight: weight,
    semester: semester,
    category: category,
    countsToAverage: countsToAverage,
    assessment: assessment,
    previousGrades: previousGrades ?? this.previousGrades,
    source: source,
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
    this.source,
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

  /// The profile it comes from when every profile is shown together, its
  /// id then begun with that profile's; null in a single profile's view.
  final String? source;

  /// This event as [source]'s, under [id].
  SchoolEvent withSource(String? source, {required String id}) => SchoolEvent(
    id: id,
    title: title,
    subject: subject,
    date: date,
    kind: kind,
    description: description,
    typeLabel: typeLabel,
    lessonNumber: lessonNumber,
    source: source,
  );
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
    this.sent = false,
    this.recipients = const [],
    this.recipientRead,
    this.source,
  });
  final String id;
  final String sender;
  final String subject;
  final String preview;

  /// When it was sent; for a received message, when it came.
  final DateTime receivedAt;
  final bool unread;
  final bool hasAttachments;

  /// Written by the student. Sent messages have [recipients] and no sender.
  final bool sent;
  final List<String> recipients;

  /// Whether the recipients have read a sent message, or null when Librus
  /// does not say.
  final bool? recipientRead;

  /// The profile it comes from when every profile is shown together, its
  /// id then begun with that profile's; null in a single profile's view.
  final String? source;

  SchoolMessage copyWith({
    bool? unread,
    List<String>? recipients,
    bool? recipientRead,
  }) => SchoolMessage(
    id: id,
    sender: sender,
    subject: subject,
    preview: preview,
    receivedAt: receivedAt,
    unread: unread ?? this.unread,
    hasAttachments: hasAttachments,
    sent: sent,
    recipients: recipients ?? this.recipients,
    recipientRead: recipientRead ?? this.recipientRead,
    source: source,
  );

  /// This message as [source]'s, under [id].
  SchoolMessage withSource(String? source, {required String id}) =>
      SchoolMessage(
        id: id,
        sender: sender,
        subject: subject,
        preview: preview,
        receivedAt: receivedAt,
        unread: unread,
        hasAttachments: hasAttachments,
        sent: sent,
        recipients: recipients,
        recipientRead: recipientRead,
        source: source,
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
    this.recipients = const [],
  });
  final String id;
  final String sender;
  final String subject;
  final String body;
  final DateTime receivedAt;
  final List<MessageAttachment> attachments;

  /// Who a sent message went to; empty for received ones.
  final List<MessageReceiver> recipients;
}

/// A recipient of a sent message and whether they have read it.
class MessageReceiver {
  const MessageReceiver({required this.name, this.read, this.readAt});
  final String name;

  /// Null when Librus does not say.
  final bool? read;
  final DateTime? readAt;
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
    this.groupId = '',
    this.owner,
  });
  final Object id;
  final String? owner;
  final String name;

  /// The group's name, as Librus shows it ("Nauczyciele").
  final String group;

  /// The group's code, as Librus keeps it ("teachers").
  final String groupId;
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

/// The look of the app. [glass] needs a platform that can draw it; elsewhere
/// the app stays [classic] when it is chosen. [expressive] is Material 3
/// Expressive, Google's design, which any platform can draw.
enum AppDesign { glass, classic, expressive }

enum AppColorMode { system, light, dark, amoled }

/// How the timetable shows a day: on a time scale or as a list of lessons.
enum TimetableView { timeline, list }

/// How the message list looks: mail-style rows or compact cards.
enum MessageListStyle { list, cards }

/// How the grades of a subject are listed: one compact row each, or cards
/// that open to show every grade.
enum GradesView { compact, cards }

/// The configurable parts of the Today screen.
enum TodayBlock {
  currentLesson,
  freeDays,
  summary,
  grades,
  homework,
  events,
  messages,
  // A parent's: absences to excuse, notes, parents' meetings.
  toExcuse,
  notices,
  meetings;

  /// The blocks only a parent's Today has.
  static const parents = {toExcuse, notices, meetings};
}

/// Which Today blocks show, and in what order.
class TodayLayout {
  const TodayLayout(this.blocks);

  static const defaults = TodayLayout([
    (block: TodayBlock.currentLesson, visible: true),
    (block: TodayBlock.freeDays, visible: true),
    (block: TodayBlock.summary, visible: true),
    (block: TodayBlock.grades, visible: true),
    (block: TodayBlock.homework, visible: true),
    (block: TodayBlock.events, visible: true),
    (block: TodayBlock.messages, visible: true),
    // Shown only on a parent's Today, so a student never sees them.
    (block: TodayBlock.toExcuse, visible: true),
    (block: TodayBlock.notices, visible: true),
    (block: TodayBlock.meetings, visible: true),
  ]);

  /// A parent's Today: what to excuse first, homework last.
  static const parentDefaults = TodayLayout([
    (block: TodayBlock.currentLesson, visible: true),
    (block: TodayBlock.freeDays, visible: true),
    (block: TodayBlock.toExcuse, visible: true),
    (block: TodayBlock.summary, visible: true),
    (block: TodayBlock.grades, visible: true),
    (block: TodayBlock.notices, visible: true),
    (block: TodayBlock.meetings, visible: true),
    (block: TodayBlock.events, visible: true),
    (block: TodayBlock.messages, visible: true),
    (block: TodayBlock.homework, visible: true),
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
  /// layouts saved before it became configurable, and the days off right
  /// after it.
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
        } else if (block == TodayBlock.freeDays) {
          final lesson = blocks.indexWhere(
            (entry) => entry.block == TodayBlock.currentLesson,
          );
          blocks.insert(lesson + 1, (block: block, visible: true));
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
    // Only the scale from 1 to 6 is a grade: a "0" marks work not handed in,
    // and points are not grades, so neither counts.
    if (numeric != null) return numeric >= 1 && numeric <= 6 ? numeric : null;
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
    final (:sum, :total) = totals(grades);
    return total == 0 ? null : sum / total;
  }

  /// The sum of the counted grades' values, each times its weight when the
  /// average is weighted, and the sum of those weights.
  ({double sum, double total}) totals(Iterable<Grade> grades) {
    var sum = 0.0;
    var total = 0.0;
    for (final grade in grades) {
      if (grade.weight <= 0 ||
          !grade.countsToAverage ||
          grade.assessment != 'current') {
        continue;
      }
      final value = valueOf(grade.value);
      if (value == null) continue;
      final weight = weighted ? grade.weight : 1.0;
      sum += value * weight;
      total += weight;
    }
    return (sum: sum, total: total);
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
    this.source,
  });
  final String id;
  final DateTime date;
  final int lessonNumber;
  final String subject;
  final String type;
  final String symbol;
  final AttendanceKind kind;
  final int semester;

  /// The profile it comes from when every profile is shown together, its
  /// id then begun with that profile's; null in a single profile's view.
  final String? source;

  bool get isPresence => kind.countsAsPresence;
  bool get isExcused => kind.isExcused;

  /// This record as [source]'s, under [id].
  AttendanceRecord withSource(String? source, {required String id}) =>
      AttendanceRecord(
        id: id,
        date: date,
        lessonNumber: lessonNumber,
        subject: subject,
        type: type,
        symbol: symbol,
        kind: kind,
        semester: semester,
        source: source,
      );
}

/// What gives a day off.
enum FreeDayKind {
  /// The whole school: holidays and days off.
  school,

  /// The student's class only, sometimes for some lessons only.
  classDay,

  /// A teacher's absence.
  teacher,
}

/// One or more days without (some) lessons: a school holiday, a day off for
/// the class, or a teacher's absence.
class FreeDay {
  const FreeDay({
    required this.id,
    required this.kind,
    required this.name,
    required this.from,
    required this.to,
    this.teacher = '',
    this.lessonFrom,
    this.lessonTo,
    this.timeFrom,
    this.timeTo,
    this.source,
  });

  final String id;
  final FreeDayKind kind;

  /// "Ferie zimowe", the kind of the class's day off or of the absence. May
  /// be empty.
  final String name;

  /// The first and the last day, both whole.
  final DateTime from;
  final DateTime to;

  /// Who is absent, for [FreeDayKind.teacher].
  final String teacher;

  /// The lessons a class's day off covers, when not all of them.
  final int? lessonFrom;
  final int? lessonTo;

  /// The part of a day a teacher is absent for, in minutes after midnight.
  final int? timeFrom;
  final int? timeTo;

  /// The profile it comes from when every profile is shown together, its
  /// id then begun with that profile's; null in a single profile's view.
  final String? source;

  /// These days as [source]'s, under [id].
  FreeDay withSource(String? source, {required String id}) => FreeDay(
    id: id,
    kind: kind,
    name: name,
    from: from,
    to: to,
    teacher: teacher,
    lessonFrom: lessonFrom,
    lessonTo: lessonTo,
    timeFrom: timeFrom,
    timeTo: timeTo,
    source: source,
  );

  /// Whether [day] is one of these days.
  bool covers(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return !date.isBefore(DateTime(from.year, from.month, from.day)) &&
        !date.isAfter(DateTime(to.year, to.month, to.day));
  }

  /// No lessons at all for the student on these days.
  bool get wholeDays =>
      kind != FreeDayKind.teacher && lessonFrom == null && lessonTo == null;

  /// Whether this is [lesson]'s teacher being absent while it is on. A
  /// teacher of another profile's school is someone else.
  bool absentFor(Lesson lesson) {
    if (kind != FreeDayKind.teacher ||
        lesson.source != source ||
        teacher.isEmpty ||
        lesson.teacher != teacher ||
        !covers(lesson.start)) {
      return false;
    }
    final start = lesson.start.hour * 60 + lesson.start.minute;
    final end = lesson.end.hour * 60 + lesson.end.minute;
    return (timeFrom == null || timeFrom! < end) &&
        (timeTo == null || timeTo! > start);
  }
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
    this.source,
  });
  final String id;
  final String title;
  final String content;
  final String author;
  final DateTime createdAt;
  final DateTime? validUntil;
  final bool read;

  /// The profile it comes from when every profile is shown together, its
  /// id then begun with that profile's; null in a single profile's view.
  final String? source;

  /// This announcement as [source]'s, under [id].
  SchoolAnnouncement withSource(String? source, {required String id}) =>
      SchoolAnnouncement(
        id: id,
        title: title,
        content: content,
        author: author,
        createdAt: createdAt,
        validUntil: validUntil,
        read: read,
        source: source,
      );
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
    this.source,
  });
  final String id;
  final String text;
  final String category;
  final String teacher;
  final DateTime date;
  final NoticeTone tone;

  /// The profile it comes from when every profile is shown together, its
  /// id then begun with that profile's; null in a single profile's view.
  final String? source;

  /// This notice as [source]'s, under [id].
  StudentNotice withSource(String? source, {required String id}) =>
      StudentNotice(
        id: id,
        text: text,
        category: category,
        teacher: teacher,
        date: date,
        tone: tone,
        source: source,
      );
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
    this.providerData = const {},
    this.moduleErrors = const {},
    this.attendanceComplete = true,
    this.sentMessages = const [],
    this.freeDays = const [],
  });
  final StudentProfile profile;
  final Map<String, Object?> providerData;
  final Map<String, String> moduleErrors;
  final bool attendanceComplete;
  final List<Lesson> lessons;
  final List<Grade> grades;
  final List<SchoolEvent> events;
  final List<SchoolMessage> messages;
  final AppError? messagesError;

  /// Loaded when the Sent folder is opened; a sync leaves them as they are.
  final List<SchoolMessage> sentMessages;
  final List<AttendanceRecord> attendance;
  final List<SchoolAnnouncement> announcements;
  final List<StudentNotice> notices;

  /// Holidays, the class's days off and teachers' absences.
  final List<FreeDay> freeDays;
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
    List<SchoolMessage>? sentMessages,
    List<FreeDay>? freeDays,
    DateTime? lastSync,
  }) => AppSnapshot(
    profile: profile,
    providerData: providerData,
    moduleErrors: moduleErrors,
    attendanceComplete: attendanceComplete,
    lessons: lessons ?? this.lessons,
    grades: grades,
    events: events ?? this.events,
    messages: messages ?? this.messages,
    messagesError: messagesError,
    sentMessages: sentMessages ?? this.sentMessages,
    attendance: attendance,
    announcements: announcements,
    notices: notices,
    freeDays: freeDays ?? this.freeDays,
    lastSync: lastSync ?? this.lastSync,
  );

  /// [message] just sent, at the top of the Sent folder.
  AppSnapshot withSent(SchoolMessage message) => copyWith(
    sentMessages: [
      message,
      ...sentMessages.where((item) => item.id != message.id),
    ],
  );

  /// After [message] was opened: a received one is read now, and a sent one
  /// learns all its recipients and whether they have read it.
  AppSnapshot withOpened(SchoolMessage message, SchoolMessageContent content) {
    if (!message.sent) {
      return copyWith(
        messages: [
          for (final item in messages)
            item.id == message.id ? item.copyWith(unread: false) : item,
        ],
      );
    }
    if (content.recipients.isEmpty) return this;
    final states = content.recipients.map((item) => item.read);
    final read = states.contains(null)
        ? null
        : states.every((value) => value == true);
    return copyWith(
      sentMessages: [
        for (final item in sentMessages)
          item.id == message.id
              ? item.copyWith(
                  recipients: [
                    for (final recipient in content.recipients) recipient.name,
                  ],
                  // An unknown state leaves what the list said.
                  recipientRead: read,
                )
              : item,
      ],
    );
  }
}

/// How the school answered an excuse note sent through the diary's own
/// e-Usprawiedliwienia module.
enum JustificationState { pending, accepted, rejected, unknown }

/// The state a diary's status word stands for, whichever language it is in;
/// [JustificationState.unknown] for a word not known yet.
JustificationState justificationState(String status) {
  final word = status.toLowerCase();
  bool any(List<String> parts) => parts.any(word.contains);
  if (any(['accept', 'approv', 'zaakcept', 'zatwierdz', 'uwzgl'])) {
    return JustificationState.accepted;
  }
  if (any(['reject', 'denied', 'decline', 'odrzu', 'odmow', 'odmów'])) {
    return JustificationState.rejected;
  }
  if (any(['pend', 'wait', 'new', 'sent', 'oczek', 'nowe', 'wysł', 'wysl'])) {
    return JustificationState.pending;
  }
  return JustificationState.unknown;
}

/// An excuse note the diary's own module keeps: sent from the diary's site
/// or app, with the school's answer.
class SchoolJustification {
  const SchoolJustification({
    required this.id,
    required this.message,
    required this.status,
    this.postedAt,
    this.from,
    this.to,
    this.justified = 0,
    this.teachers = const [],
    this.lessons = 0,
  });

  final String id;
  final String message;

  /// The status as the diary words it.
  final String status;
  final DateTime? postedAt;
  final DateTime? from;
  final DateTime? to;

  /// How many absences it excused.
  final int justified;

  /// The teachers told of it, by name when the diary gives one.
  final List<String> teachers;
  final int lessons;

  JustificationState get state => justificationState(status);
}
