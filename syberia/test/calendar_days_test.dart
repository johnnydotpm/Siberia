import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/domain/calendar_days.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/ui/app_shell.dart';

// The clock changes matter in a zone that has them: the suite also runs
// with TZ=Europe/Warsaw, where the clocks go forward on 28 March 2027 and
// back on 25 October 2026.
void main() {
  test('days are counted on the calendar across the clock changes', () {
    // The night before spring is 23 hours, the night before autumn 25.
    expect(
      calendarDaysBetween(DateTime(2027, 3, 28), DateTime(2027, 3, 29)),
      1,
    );
    expect(
      calendarDaysBetween(DateTime(2026, 10, 25), DateTime(2026, 10, 26)),
      1,
    );
    expect(
      calendarDaysBetween(
        DateTime(2027, 3, 28, 23, 59),
        DateTime(2027, 3, 29, 0, 1),
      ),
      1,
    );
    expect(
      calendarDaysBetween(DateTime(2027, 3, 22), DateTime(2027, 3, 29)),
      7,
    );
    expect(
      calendarDaysBetween(DateTime(2026, 12, 31, 23), DateTime(2027, 1, 1, 1)),
      1,
    );
    expect(
      calendarDaysBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 25)),
      -1,
    );
    expect(
      calendarDaysBetween(
        DateTime(2026, 10, 25, 1),
        DateTime(2026, 10, 25, 23),
      ),
      0,
    );
  });

  test('the day after the clocks go forward still has its yesterday', () {
    final now = DateTime(2027, 3, 29, 9);
    expect(
      messageSection(DateTime(2027, 3, 28, 18), now),
      MessageSection.yesterday,
    );
    expect(messageSection(DateTime(2027, 3, 29, 7), now), MessageSection.today);
    // Monday: last week's Tuesday is a week ago, not this week.
    expect(
      messageSection(DateTime(2027, 3, 23, 10), now),
      MessageSection.earlier,
    );
    expect(
      messageSection(DateTime(2027, 3, 31, 10), DateTime(2027, 4, 2, 9)),
      MessageSection.thisWeek,
    );
  });

  AppSnapshot snapshot({required List<Lesson> lessons, DateTime? lastSync}) =>
      AppSnapshot(
        profile: const StudentProfile(
          id: 'cache',
          name: 'Uczeń Testowy',
          school: '',
          provider: 'Librus Synergia',
        ),
        lessons: lessons,
        grades: const [],
        events: const [],
        messages: const [],
        attendance: const [],
        announcements: const [],
        notices: const [],
        lastSync: lastSync ?? DateTime(2026, 10, 21, 8),
      );

  test('the cache keeps the moment in the hour the clocks go back', () {
    // In Warsaw both are 02:30: first in summer time, then in winter time.
    final first = DateTime.utc(2026, 10, 25, 0, 30).toLocal();
    final second = DateTime.utc(2026, 10, 25, 1, 30).toLocal();
    final raw = SnapshotCache.encode(
      snapshot(
        lessons: [
          Lesson(
            id: 'night',
            subject: 'Matematyka',
            teacher: '',
            room: '',
            start: first,
            end: second,
          ),
        ],
        lastSync: second,
      ),
    );
    final restored = SnapshotCache.decode(raw)!;
    expect(restored.lessons.single.start, first);
    expect(restored.lessons.single.end, second, reason: 'not an hour early');
    expect(restored.lastSync, second);
    // The text names the moment, whatever zone reads it.
    expect((jsonDecode(raw) as Map)['lastSync'], endsWith('Z'));
  });

  test('a cache written before keeps its local times', () {
    final raw = jsonDecode(
      SnapshotCache.encode(snapshot(lessons: const [])),
    ) as Map<String, Object?>;
    raw['lastSync'] = '2026-10-21T08:00:00.000';
    expect(
      SnapshotCache.decode(jsonEncode(raw))!.lastSync,
      DateTime(2026, 10, 21, 8),
    );
  });
}
