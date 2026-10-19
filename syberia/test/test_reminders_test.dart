import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/l10n/app_localizations.dart';
import 'package:syberia/src/test_reminders.dart';

const _l10n = AppLocalizations(Locale('en'));

SchoolEvent _event(
  String id,
  DateTime date, {
  String subject = 'Math',
  EventKind kind = EventKind.exam,
  String type = 'Test',
  int? lesson,
}) => SchoolEvent(
  id: id,
  title: 'Chapter 3',
  subject: subject,
  date: date,
  kind: kind,
  typeLabel: type,
  lessonNumber: lesson,
);

void main() {
  // Monday 12:00; tests on Wednesday and Thursday.
  final now = DateTime(2026, 10, 19, 12);
  final wednesday = DateTime(2026, 10, 21);
  final thursday = DateTime(2026, 10, 22, 8);

  test('reminds the evening before, once per day, listing every test', () {
    final reminders = buildTestReminders(
      [
        _event('a', wednesday, subject: 'Physics', lesson: 5),
        _event('b', wednesday, lesson: 2, type: 'Quiz'),
        _event('c', thursday, subject: 'History'),
      ],
      const TestReminderSettings(),
      now,
      _l10n,
    );
    expect(reminders, hasLength(2));
    expect(reminders.first.at, DateTime(2026, 10, 20, 19));
    expect(reminders.first.title, 'Tomorrow at school');
    // In lesson order.
    expect(
      reminders.first.body,
      'Math: Quiz · lesson 2\nPhysics: Test · lesson 5',
    );
    expect(reminders.last.at, DateTime(2026, 10, 21, 19));
    expect(reminders.last.body, 'History: Test');
  });

  test('the morning reminder, chosen times, and times already past', () {
    final reminders = buildTestReminders(
      [
        // Today: the evening before has passed, the morning too.
        _event('today', DateTime(2026, 10, 19)),
        // Tomorrow: this evening and tomorrow morning are still ahead.
        _event('tomorrow', DateTime(2026, 10, 20)),
      ],
      const TestReminderSettings(
        evening: true,
        morning: true,
        eveningMinutes: 20 * 60 + 30,
        morningMinutes: 6 * 60 + 45,
      ),
      now,
      _l10n,
    );
    expect(
      [for (final reminder in reminders) reminder.at],
      [DateTime(2026, 10, 19, 20, 30), DateTime(2026, 10, 20, 6, 45)],
    );
    expect(reminders.last.title, 'Today at school');
  });

  test('homework comes only when asked for, after the tests', () {
    final events = [
      _event('hw', wednesday, kind: EventKind.homework, subject: 'Biology'),
      _event('test', wednesday),
    ];
    final testsOnly = buildTestReminders(
      events,
      const TestReminderSettings(),
      now,
      _l10n,
    );
    expect(testsOnly.single.body, 'Math: Test');
    final withHomework = buildTestReminders(
      events,
      const TestReminderSettings(homework: true),
      now,
      _l10n,
    );
    expect(withHomework.single.body, 'Math: Test\nBiology: Homework');
  });

  test('nothing when off, nothing old, nothing far ahead', () {
    final events = [
      _event('past', DateTime(2026, 10, 10)),
      _event('far', DateTime(2026, 12, 1)),
    ];
    expect(
      buildTestReminders(events, const TestReminderSettings(), now, _l10n),
      isEmpty,
    );
    expect(
      buildTestReminders(
        [_event('soon', wednesday)],
        const TestReminderSettings(evening: false),
        now,
        _l10n,
      ),
      isEmpty,
    );
  });

  test('entries without a subject or type still read well', () {
    final reminders = buildTestReminders(
      [_event('trip', wednesday, subject: 'Librus', type: 'Trip')],
      const TestReminderSettings(),
      now,
      _l10n,
    );
    expect(reminders.single.body, 'Trip');
  });

  test('a busy month stays within the scheduling limit', () {
    final events = [
      for (var day = 0; day < 40; day++)
        _event('e$day', DateTime(2026, 10, 20).add(Duration(days: day))),
    ];
    final reminders = buildTestReminders(
      events,
      const TestReminderSettings(morning: true),
      now,
      _l10n,
      days: 60,
    );
    expect(reminders, hasLength(maxTestReminders));
  });
}
