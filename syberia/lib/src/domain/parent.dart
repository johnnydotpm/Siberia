import 'models.dart';

enum ProfileRole { student, parent }

/// Interface preferences never change the account used to authenticate mail.
class ParentPreferences {
  const ParentPreferences({
    this.quiet = true,
    this.quietStart = 1260,
    this.quietEnd = 420,
    this.digest = false,
    this.digestAt = 1140,
    this.studentTools = false,
    this.excuseGreeting = '',
    this.excuseChild = 'child',
    this.excuseClosing = '',
  });
  final bool quiet;
  final int quietStart, quietEnd;
  final bool digest;
  final int digestAt;
  final bool studentTools;

  /// How the excuse notes of this child greet the class teacher; empty
  /// lets the app suggest it from the teacher's name.
  final String excuseGreeting;

  /// The [ExcuseChild] name the notes speak of the child as.
  final String excuseChild;

  /// How the notes end; empty is "Dziękuję za zrozumienie."
  final String excuseClosing;

  ParentPreferences copyWith({
    bool? quiet,
    int? quietStart,
    int? quietEnd,
    bool? digest,
    int? digestAt,
    bool? studentTools,
    String? excuseGreeting,
    String? excuseChild,
    String? excuseClosing,
  }) => ParentPreferences(
    quiet: quiet ?? this.quiet,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    digest: digest ?? this.digest,
    digestAt: digestAt ?? this.digestAt,
    studentTools: studentTools ?? this.studentTools,
    excuseGreeting: excuseGreeting ?? this.excuseGreeting,
    excuseChild: excuseChild ?? this.excuseChild,
    excuseClosing: excuseClosing ?? this.excuseClosing,
  );
  bool isQuiet(DateTime time) {
    if (!quiet || quietStart == quietEnd) return false;
    final minute = time.hour * 60 + time.minute;
    return quietStart < quietEnd
        ? minute >= quietStart && minute < quietEnd
        : minute >= quietStart || minute < quietEnd;
  }

  DateTime nextAllowed(DateTime now) {
    if (!isQuiet(now)) return now;
    final nextDay =
        quietStart > quietEnd && now.hour * 60 + now.minute >= quietStart;
    return DateTime(
      now.year,
      now.month,
      now.day + (nextDay ? 1 : 0),
      quietEnd ~/ 60,
      quietEnd % 60,
    );
  }

  Map<String, Object> toJson() => {
    'quiet': quiet,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
    'digest': digest,
    'digestAt': digestAt,
    'studentTools': studentTools,
    'excuseGreeting': excuseGreeting,
    'excuseChild': excuseChild,
    'excuseClosing': excuseClosing,
  };
  factory ParentPreferences.fromJson(Object? raw) {
    if (raw is! Map) return const ParentPreferences();
    int minute(String key, int fallback) =>
        raw[key] is int && raw[key] >= 0 && raw[key] < 1440
        ? raw[key] as int
        : fallback;
    return ParentPreferences(
      quiet: raw['quiet'] != false,
      quietStart: minute('quietStart', 1260),
      quietEnd: minute('quietEnd', 420),
      digest: raw['digest'] == true,
      digestAt: minute('digestAt', 1140),
      studentTools: raw['studentTools'] == true,
      excuseGreeting: raw['excuseGreeting'] is String
          ? raw['excuseGreeting'] as String
          : '',
      excuseChild: raw['excuseChild'] is String
          ? raw['excuseChild'] as String
          : 'child',
      excuseClosing: raw['excuseClosing'] is String
          ? raw['excuseClosing'] as String
          : '',
    );
  }
}

enum AbsenceRequestState { sent, uncertain }

/// A mailbox request is not proof that the school excused an absence.
class AbsenceRequest {
  const AbsenceRequest({
    required this.id,
    required this.profileId,
    required this.messageId,
    required this.at,
    required this.subject,
    required this.body,
    required this.recipient,
    required this.recordIds,
    required this.state,
    this.days = const [],
    this.reasons = const [],
    this.planned = false,
  });
  final String id, profileId, messageId, subject, body, recipient;
  final DateTime at;
  final List<String> recordIds;
  final AbsenceRequestState state;

  /// The days the note is about, and the [ExcuseReason] names given; none
  /// in notes kept before they were.
  final List<DateTime> days;
  final List<String> reasons;

  /// Whether it told of days to come rather than excused days gone.
  final bool planned;
  Map<String, Object> toJson() => {
    'id': id,
    'profileId': profileId,
    'messageId': messageId,
    'at': at.toIso8601String(),
    'subject': subject,
    'body': body,
    'recipient': recipient,
    'recordIds': recordIds,
    'state': state.name,
    'days': [for (final day in days) day.toIso8601String()],
    'reasons': reasons,
    'planned': planned,
  };
  static AbsenceRequest? fromJson(Object? raw) {
    if (raw is! Map || raw['profileId'] is! String || raw['at'] is! String) {
      return null;
    }
    final at = DateTime.tryParse(raw['at'] as String);
    if (at == null ||
        raw['subject'] is! String ||
        raw['body'] is! String ||
        raw['recipient'] is! String) {
      return null;
    }
    return AbsenceRequest(
      id: raw['id'] is String ? raw['id'] as String : raw['at'] as String,
      profileId: raw['profileId'] as String,
      messageId: raw['messageId'] is String ? raw['messageId'] as String : '',
      at: at,
      subject: raw['subject'] as String,
      body: raw['body'] as String,
      recipient: raw['recipient'] as String,
      recordIds:
          (raw['recordIds'] is List ? raw['recordIds'] as List : const [])
              .whereType<String>()
              .toList(),
      state: raw['state'] == 'sent'
          ? AbsenceRequestState.sent
          : AbsenceRequestState.uncertain,
      days: [
        for (final day in raw['days'] is List ? raw['days'] as List : const [])
          if (day is String) ?DateTime.tryParse(day),
      ],
      reasons: (raw['reasons'] is List ? raw['reasons'] as List : const [])
          .whereType<String>()
          .toList(),
      planned: raw['planned'] == true,
    );
  }
}

List<AttendanceRecord> unexcusedAbsences(Iterable<AttendanceRecord> records) =>
    records.where((item) => item.kind == AttendanceKind.absent).toList()
      ..sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date == 0 ? a.lessonNumber.compareTo(b.lessonNumber) : date;
      });
