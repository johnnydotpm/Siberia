import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/domain/models.dart';

Lesson _lesson(String id, DateTime start) => Lesson(
  id: id,
  subject: id,
  teacher: 'Teacher',
  room: '1',
  start: start,
  end: start.add(const Duration(minutes: 45)),
);

AppSnapshot _snapshot(List<Lesson> lessons, {String profileId = 'librus-1'}) =>
    AppSnapshot(
      profile: StudentProfile(
        id: profileId,
        name: 'Test',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: lessons,
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: DateTime(2026, 10, 16),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final weekStart = librusSyncWeekStart(DateTime.now());
  final synced = _lesson('synced', weekStart.add(const Duration(hours: 8)));
  final stale = _lesson('stale', weekStart.add(const Duration(hours: 9)));
  final earlier = _lesson(
    'earlier',
    weekStart.subtract(const Duration(days: 3)),
  );
  final nextWeek = _lesson(
    'nextWeek',
    weekStart.add(const Duration(days: 7, hours: 8)),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('librusSyncWeekStart is this Monday, or the next one at weekends', () {
    expect(
      librusSyncWeekStart(DateTime(2026, 10, 16, 14)),
      DateTime(2026, 10, 12),
    );
    expect(librusSyncWeekStart(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
    expect(
      librusSyncWeekStart(DateTime(2026, 10, 17, 9)),
      DateTime(2026, 10, 19),
    );
    expect(
      librusSyncWeekStart(DateTime(2026, 10, 18, 23)),
      DateTime(2026, 10, 19),
    );
  });

  test('the weeks around a clock change start on their Mondays', () {
    // The weekend before the clocks go back in Poland: the next Monday, not
    // the Sunday that seven times 24 hours reach. The clocks change only
    // where the zone has them change, as on the phones:
    // TZ=Europe/Warsaw flutter test test/timetable_sync_test.dart
    expect(
      librusSyncWeekStart(DateTime(2026, 10, 24, 12)),
      DateTime(2026, 10, 26),
    );
    expect(
      librusSyncWeekStart(DateTime(2026, 10, 25, 23)),
      DateTime(2026, 10, 26),
    );
    // And every day of five years.
    for (
      var day = DateTime(2026);
      day.year < 2031;
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final noon = DateTime(day.year, day.month, day.day, 12);
      final start = librusSyncWeekStart(noon);
      expect(start.weekday, DateTime.monday, reason: '$noon');
      expect((start.hour, start.minute), (0, 0), reason: '$noon');
    }
  });

  test('a sync replaces its own week and keeps later weeks', () async {
    final repository = AppRepository(
      librusClient: _FakeLibrusClient(_snapshot([synced])),
    );
    final result = await repository.sync(_snapshot([earlier, stale, nextWeek]));
    expect(result.lessons.map((lesson) => lesson.id), ['synced', 'nextWeek']);
    final preferences = await SharedPreferences.getInstance();
    final cached = SnapshotCache.decode(
      preferences.getString('last_librus_snapshot_v1'),
    );
    expect(cached!.lessons.map((lesson) => lesson.id), ['synced', 'nextWeek']);
  });

  test('another account keeps nothing from the previous one', () async {
    final repository = AppRepository(
      librusClient: _FakeLibrusClient(_snapshot([synced])),
    );
    final result = await repository.sync(
      _snapshot([nextWeek], profileId: 'librus-2'),
    );
    expect(result.lessons.map((lesson) => lesson.id), ['synced']);
  });

  test('the background check keeps later weeks from the cache', () async {
    final cached = _snapshot([stale, nextWeek]);
    SharedPreferences.setMockInitialValues({
      'active_profile_v1': jsonEncode(cached.profile.toJson()),
      'last_librus_snapshot_v1': SnapshotCache.encode(cached),
    });
    final repository = AppRepository(
      librusClient: _FakeLibrusClient(_snapshot([synced])),
    );
    final live = await repository.fetchBackgroundSnapshot();
    expect(live!.lessons.map((lesson) => lesson.id), ['synced', 'nextWeek']);
  });
}

class _FakeLibrusClient extends LibrusClient {
  _FakeLibrusClient(this.response);
  final AppSnapshot response;

  @override
  Future<AppSnapshot?> restoreAndFetch({Set<LibrusPart>? parts}) async =>
      response;
}
