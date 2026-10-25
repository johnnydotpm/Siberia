import 'dart:convert';

import '../domain/models.dart';
import '../domain/librus_error.dart';

/// Stores the last successful Librus response for offline and manual-only use.
abstract final class SnapshotCache {
  static String encode(AppSnapshot value) => jsonEncode({
    'profile': value.profile.toJson(),
    'lastSync': _date(value.lastSync),
    'lessons': [for (final item in value.lessons) _lesson(item)],
    'grades': [for (final item in value.grades) _grade(item)],
    'events': [for (final item in value.events) _event(item)],
    'messagesError': value.messagesError == null
        ? null
        : {
            'code': value.messagesError!.errorCode?.name,
            'detail': value.messagesError!.detail,
            'raw': value.messagesError!.raw,
          },
    'messages': [for (final item in value.messages) _message(item)],
    'sentMessages': [for (final item in value.sentMessages) _message(item)],
    'attendance': [for (final item in value.attendance) _attendance(item)],
    'announcements': [
      for (final item in value.announcements) _announcement(item),
    ],
    'notices': [for (final item in value.notices) _notice(item)],
    'freeDays': [for (final item in value.freeDays) _freeDay(item)],
  });

  static AppSnapshot? decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = _map(jsonDecode(raw));
      return AppSnapshot(
        profile: StudentProfile.fromJson(
          value['profile'] as Map<String, Object?>,
        ),
        lastSync: _parseDate(value['lastSync']),
        lessons: _list(value['lessons'], _readLesson),
        grades: _list(value['grades'], _readGrade),
        events: _list(value['events'], _readEvent),
        messages: _list(value['messages'], _readMessage),
        messagesError: value['messagesError'] is Map
            ? AppError(
                errorCode: LibrusErrorCode.values
                    .where(
                      (code) =>
                          code.name == (value['messagesError'] as Map)['code'],
                    )
                    .firstOrNull,
                detail: (value['messagesError'] as Map)['detail'] as String?,
                raw: (value['messagesError'] as Map)['raw'] as String?,
              )
            : null,
        // Caches written before the Sent folder have none.
        sentMessages: value['sentMessages'] == null
            ? const []
            : _list(value['sentMessages'], _readMessage),
        attendance: _list(value['attendance'], _readAttendance),
        announcements: _list(value['announcements'], _readAnnouncement),
        notices: _list(value['notices'], _readNotice),
        // Caches written before free days have none.
        freeDays: value['freeDays'] == null
            ? const []
            : _list(value['freeDays'], _readFreeDay),
      );
    } on Object {
      return null;
    }
  }

  static Map<String, Object?> _map(Object? value) =>
      (value as Map).cast<String, Object?>();
  static List<T> _list<T>(
    Object? value,
    T Function(Map<String, Object?>) read,
  ) => (value as List).map((item) => read(_map(item))).toList(growable: false);
  // In UTC: a local time alone is ambiguous in the hour the clocks go back,
  // and came back an hour early. Older caches hold local times, which parse
  // as before.
  static String _date(DateTime value) => value.toUtc().toIso8601String();
  static DateTime _parseDate(Object? value) =>
      DateTime.parse(value! as String).toLocal();
  static DateTime? _optionalDate(Object? value) =>
      value == null ? null : _parseDate(value);

  static Map<String, Object?> _lesson(Lesson item) => {
    'id': item.id,
    'subject': item.subject,
    'teacher': item.teacher,
    'room': item.room,
    'start': _date(item.start),
    'end': _date(item.end),
    'cancelled': item.cancelled,
    'substitution': item.substitution,
    'originalSubject': item.originalSubject,
    'originalTeacher': item.originalTeacher,
    'originalRoom': item.originalRoom,
    'movedTo': item.movedTo == null ? null : _date(item.movedTo!),
    'number': item.lessonNumber,
  };
  static Lesson _readLesson(Map<String, Object?> item) => Lesson(
    id: item['id']! as String,
    subject: item['subject']! as String,
    teacher: item['teacher']! as String,
    room: item['room']! as String,
    start: _parseDate(item['start']),
    end: _parseDate(item['end']),
    cancelled: item['cancelled'] as bool? ?? false,
    substitution: item['substitution'] as bool? ?? false,
    originalSubject: item['originalSubject'] as String? ?? '',
    originalTeacher: item['originalTeacher'] as String? ?? '',
    originalRoom: item['originalRoom'] as String? ?? '',
    movedTo: _optionalDate(item['movedTo']),
    lessonNumber: (item['number'] as num?)?.toInt(),
  );

  static Map<String, Object?> _grade(Grade item) => {
    'id': item.id,
    'subject': item.subject,
    'value': item.value,
    'description': item.description,
    'date': _date(item.date),
    'weight': item.weight,
    'semester': item.semester,
    'category': item.category,
    'previousGrades': [for (final old in item.previousGrades) _grade(old)],
  };
  static Grade _readGrade(Map<String, Object?> item) => Grade(
    id: item['id']! as String,
    subject: item['subject']! as String,
    value: item['value']! as String,
    description: item['description']! as String,
    date: _parseDate(item['date']),
    weight: (item['weight']! as num).toDouble(),
    semester: item['semester']! as int,
    category: item['category'] as String? ?? '',
    previousGrades: _list(item['previousGrades'] ?? const [], _readGrade),
  );

  static Map<String, Object?> _event(SchoolEvent item) => {
    'id': item.id,
    'title': item.title,
    'subject': item.subject,
    'date': _date(item.date),
    'kind': item.kind.name,
    'description': item.description,
    'typeLabel': item.typeLabel,
    'number': item.lessonNumber,
  };
  static SchoolEvent _readEvent(Map<String, Object?> item) => SchoolEvent(
    id: item['id']! as String,
    title: item['title']! as String,
    subject: item['subject']! as String,
    date: _parseDate(item['date']),
    kind: EventKind.values.byName(item['kind']! as String),
    description: item['description'] as String? ?? '',
    typeLabel: item['typeLabel'] as String? ?? '',
    lessonNumber: (item['number'] as num?)?.toInt(),
  );

  static Map<String, Object?> _message(SchoolMessage item) => {
    'id': item.id,
    'sender': item.sender,
    'subject': item.subject,
    'preview': item.preview,
    'receivedAt': _date(item.receivedAt),
    'unread': item.unread,
    'hasAttachments': item.hasAttachments,
    if (item.sent) ...{
      'sent': true,
      'recipients': item.recipients,
      'recipientRead': item.recipientRead,
    },
  };
  static SchoolMessage _readMessage(Map<String, Object?> item) => SchoolMessage(
    id: item['id']! as String,
    sender: item['sender']! as String,
    subject: item['subject']! as String,
    preview: item['preview']! as String,
    receivedAt: _parseDate(item['receivedAt']),
    unread: item['unread'] as bool? ?? false,
    hasAttachments: item['hasAttachments'] as bool? ?? false,
    sent: item['sent'] as bool? ?? false,
    recipients: [
      for (final name in item['recipients'] as List? ?? const []) '$name',
    ],
    recipientRead: item['recipientRead'] as bool?,
  );

  static Map<String, Object?> _attendance(AttendanceRecord item) => {
    'id': item.id,
    'date': _date(item.date),
    'lessonNumber': item.lessonNumber,
    'subject': item.subject,
    'type': item.type,
    'symbol': item.symbol,
    'kind': item.kind.name,
    'semester': item.semester,
  };
  static AttendanceRecord _readAttendance(Map<String, Object?> item) =>
      AttendanceRecord(
        id: item['id']! as String,
        date: _parseDate(item['date']),
        lessonNumber: item['lessonNumber']! as int,
        subject: item['subject']! as String,
        type: item['type']! as String,
        symbol: item['symbol']! as String,
        kind: AttendanceKind.values.byName(item['kind']! as String),
        semester: item['semester'] as int? ?? 1,
      );

  static Map<String, Object?> _announcement(SchoolAnnouncement item) => {
    'id': item.id,
    'title': item.title,
    'content': item.content,
    'author': item.author,
    'createdAt': _date(item.createdAt),
    'validUntil': item.validUntil == null ? null : _date(item.validUntil!),
    'read': item.read,
  };
  static SchoolAnnouncement _readAnnouncement(Map<String, Object?> item) =>
      SchoolAnnouncement(
        id: item['id']! as String,
        title: item['title']! as String,
        content: item['content']! as String,
        author: item['author']! as String,
        createdAt: _parseDate(item['createdAt']),
        validUntil: _optionalDate(item['validUntil']),
        read: item['read'] as bool? ?? false,
      );

  static Map<String, Object?> _notice(StudentNotice item) => {
    'id': item.id,
    'text': item.text,
    'category': item.category,
    'teacher': item.teacher,
    'date': _date(item.date),
    'tone': item.tone.name,
  };
  static StudentNotice _readNotice(Map<String, Object?> item) => StudentNotice(
    id: item['id']! as String,
    text: item['text']! as String,
    category: item['category']! as String,
    teacher: item['teacher']! as String,
    date: _parseDate(item['date']),
    tone: NoticeTone.values.byName(item['tone']! as String),
  );

  static Map<String, Object?> _freeDay(FreeDay item) => {
    'id': item.id,
    'kind': item.kind.name,
    'name': item.name,
    'from': _date(item.from),
    'to': _date(item.to),
    'teacher': item.teacher,
    'lessonFrom': item.lessonFrom,
    'lessonTo': item.lessonTo,
    'timeFrom': item.timeFrom,
    'timeTo': item.timeTo,
  };
  static FreeDay _readFreeDay(Map<String, Object?> item) => FreeDay(
    id: item['id']! as String,
    kind: FreeDayKind.values.byName(item['kind']! as String),
    name: item['name']! as String,
    from: _parseDate(item['from']),
    to: _parseDate(item['to']),
    teacher: item['teacher'] as String? ?? '',
    lessonFrom: item['lessonFrom'] as int?,
    lessonTo: item['lessonTo'] as int?,
    timeFrom: item['timeFrom'] as int?,
    timeTo: item['timeTo'] as int?,
  );
}
