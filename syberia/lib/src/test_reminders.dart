import 'domain/models.dart';
import 'l10n/app_localizations.dart';

/// When the app reminds the student of tests: the evening before, the
/// morning of, or both, and whether homework due that day comes along.
class TestReminderSettings {
  const TestReminderSettings({
    this.evening = true,
    this.morning = false,
    this.eveningMinutes = 19 * 60,
    this.morningMinutes = 7 * 60,
    this.homework = false,
  });

  final bool evening;
  final bool morning;

  /// Minutes after midnight.
  final int eveningMinutes;
  final int morningMinutes;
  final bool homework;

  bool get any => evening || morning;

  TestReminderSettings copyWith({
    bool? evening,
    bool? morning,
    int? eveningMinutes,
    int? morningMinutes,
    bool? homework,
  }) => TestReminderSettings(
    evening: evening ?? this.evening,
    morning: morning ?? this.morning,
    eveningMinutes: eveningMinutes ?? this.eveningMinutes,
    morningMinutes: morningMinutes ?? this.morningMinutes,
    homework: homework ?? this.homework,
  );

  @override
  bool operator ==(Object other) =>
      other is TestReminderSettings &&
      other.evening == evening &&
      other.morning == morning &&
      other.eveningMinutes == eveningMinutes &&
      other.morningMinutes == morningMinutes &&
      other.homework == homework;

  @override
  int get hashCode =>
      Object.hash(evening, morning, eveningMinutes, morningMinutes, homework);
}

/// One notification at a set time.
class TestReminder {
  const TestReminder({
    required this.at,
    required this.title,
    required this.body,
    this.profileId,
  });

  final DateTime at;
  final String title;
  final String body;

  /// The profile a tap opens, when the phone keeps profiles.
  final String? profileId;

  @override
  String toString() => 'TestReminder($at, $title, $body)';
}

/// At most this many reminders are scheduled; iOS keeps 64 at a time.
const maxTestReminders = 40;

/// The reminders for the tests (and, if asked, homework) of the next [days]
/// days: one notification per school day and time, listing everything due.
/// Times already past are skipped.
List<TestReminder> buildTestReminders(
  Iterable<SchoolEvent> events,
  TestReminderSettings settings,
  DateTime now,
  AppLocalizations l10n, {
  int days = 14,
}) {
  if (!settings.any) return const [];
  final today = DateTime(now.year, now.month, now.day);
  final last = DateTime(today.year, today.month, today.day + days);
  final byDay = <DateTime, List<SchoolEvent>>{};
  for (final event in events) {
    final wanted =
        event.kind == EventKind.exam ||
        (settings.homework && event.kind == EventKind.homework);
    if (!wanted) continue;
    final day = DateTime(event.date.year, event.date.month, event.date.day);
    if (day.isBefore(today) || day.isAfter(last)) continue;
    byDay.putIfAbsent(day, () => []).add(event);
  }
  final reminders = <TestReminder>[];
  for (final day in byDay.keys.toList()..sort()) {
    final items = byDay[day]!..sort(_bySchoolOrder);
    final body = [for (final event in items) _line(event, l10n)].join('\n');
    if (settings.evening) {
      // The calendar day before: the night the clocks go forward, 24 hours
      // back from a Monday land on the Saturday.
      final before = DateTime(day.year, day.month, day.day - 1);
      final at = DateTime(
        before.year,
        before.month,
        before.day,
        settings.eveningMinutes ~/ 60,
        settings.eveningMinutes % 60,
      );
      if (at.isAfter(now)) {
        reminders.add(
          TestReminder(
            at: at,
            title: l10n.text('reminderEveningTitle'),
            body: body,
          ),
        );
      }
    }
    if (settings.morning) {
      final at = DateTime(
        day.year,
        day.month,
        day.day,
        settings.morningMinutes ~/ 60,
        settings.morningMinutes % 60,
      );
      if (at.isAfter(now)) {
        reminders.add(
          TestReminder(
            at: at,
            title: l10n.text('reminderMorningTitle'),
            body: body,
          ),
        );
      }
    }
  }
  reminders.sort((a, b) => a.at.compareTo(b.at));
  return reminders.take(maxTestReminders).toList(growable: false);
}

/// Tests first, in lesson order, then homework.
int _bySchoolOrder(SchoolEvent a, SchoolEvent b) {
  final kind = (a.kind == EventKind.exam ? 0 : 1).compareTo(
    b.kind == EventKind.exam ? 0 : 1,
  );
  if (kind != 0) return kind;
  final lesson = (a.lessonNumber ?? 99).compareTo(b.lessonNumber ?? 99);
  return lesson != 0 ? lesson : a.subject.compareTo(b.subject);
}

/// "Matematyka: Sprawdzian · lekcja 3", or "Fizyka: Zadania domowe".
String _line(SchoolEvent event, AppLocalizations l10n) {
  final what = event.kind == EventKind.homework
      ? l10n.text('homework')
      : (event.typeLabel.isNotEmpty
            ? event.typeLabel
            : (event.title.isNotEmpty ? event.title : l10n.text('lessonTest')));
  final subject = event.subject.trim();
  final lesson = event.lessonNumber == null
      ? ''
      : ' · ${l10n.text('lessonNumber').replaceAll('{number}', '${event.lessonNumber}')}';
  // Entries without a subject come from the client as "Librus".
  return subject.isEmpty || subject == 'Librus' || subject == what
      ? '$what$lesson'
      : '$subject: $what$lesson';
}
