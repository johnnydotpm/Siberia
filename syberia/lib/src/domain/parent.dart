import 'models.dart';

enum ProfileRole { student, parent }

/// Interface preferences never change the account used to authenticate mail.
class ParentPreferences {
  const ParentPreferences({
    this.quiet = true,
    this.quietStart = 1260,
    this.quietEnd = 420,
    this.digest = true,
    this.digestAt = 1140,
    this.studentTools = false,
  });
  final bool quiet;
  final int quietStart, quietEnd;
  final bool digest;
  final int digestAt;
  final bool studentTools;
  ParentPreferences copyWith({
    bool? quiet,
    int? quietStart,
    int? quietEnd,
    bool? digest,
    int? digestAt,
    bool? studentTools,
  }) => ParentPreferences(
    quiet: quiet ?? this.quiet,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    digest: digest ?? this.digest,
    digestAt: digestAt ?? this.digestAt,
    studentTools: studentTools ?? this.studentTools,
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
      digest: raw['digest'] != false,
      digestAt: minute('digestAt', 1140),
      studentTools: raw['studentTools'] == true,
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
  });
  final String id, profileId, messageId, subject, body, recipient;
  final DateTime at;
  final List<String> recordIds;
  final AbsenceRequestState state;
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
    );
  }
}

List<AttendanceRecord> unexcusedAbsences(Iterable<AttendanceRecord> records) =>
    records.where((item) => item.kind == AttendanceKind.absent).toList()
      ..sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date == 0 ? a.lessonNumber.compareTo(b.lessonNumber) : date;
      });
