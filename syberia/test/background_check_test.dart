import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/background_notifications.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/school_notifications.dart';

const _profile = StudentProfile(
  id: 's1',
  name: 'Test',
  school: 'School',
  provider: 'Librus Synergia',
);

AppSnapshot _snapshot(String tag, DateTime lastSync) => AppSnapshot(
  profile: _profile,
  lessons: [
    Lesson(
      id: 'l-$tag',
      subject: tag,
      teacher: '',
      room: '',
      start: DateTime(2026, 10, 19, 8),
      end: DateTime(2026, 10, 19, 8, 45),
    ),
  ],
  grades: [
    Grade(
      id: 'g-$tag',
      subject: tag,
      value: '5',
      description: '',
      date: DateTime(2026, 10, 1),
      weight: 1,
      semester: 1,
    ),
  ],
  events: const [],
  messages: [
    SchoolMessage(
      id: 'm-$tag',
      sender: 'x',
      subject: tag,
      preview: '',
      receivedAt: DateTime(2026, 10, 1),
    ),
  ],
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: lastSync,
);

class _Client extends LibrusClient {
  _Client(this.response);
  final AppSnapshot response;
  final calls = <Set<LibrusPart>?>[];
  @override
  Future<AppSnapshot?> restoreAndFetch({Set<LibrusPart>? parts}) async {
    calls.add(parts);
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void seed(AppSnapshot saved) => SharedPreferences.setMockInitialValues({
    'active_profile_v1': jsonEncode(_profile.toJson()),
    'last_librus_snapshot_v1': SnapshotCache.encode(saved),
  });

  test('right after a sync the background check downloads nothing', () async {
    seed(_snapshot('old', DateTime.now().subtract(const Duration(minutes: 5))));
    final client = _Client(_snapshot('new', DateTime.now()));
    final repository = AppRepository(librusClient: client);
    expect(await repository.fetchBackgroundSnapshot(), isNull);
    expect(client.calls, isEmpty);
  });

  test('only enabled parts are downloaded, the rest is kept', () async {
    seed(_snapshot('old', DateTime.now().subtract(const Duration(hours: 1))));
    final client = _Client(_snapshot('new', DateTime.now()));
    final repository = AppRepository(librusClient: client);
    final live = (await repository.fetchBackgroundSnapshot(
      parts: {LibrusPart.grades},
    ))!;
    expect(client.calls.single, {LibrusPart.grades});
    expect(live.grades.single.id, 'g-new');
    expect(live.messages.single.id, 'm-old');
    expect(live.lessons.map((l) => l.id), ['l-old'], reason: 'no duplicates');
    final saved = await AppRepository().load();
    expect(saved.grades.single.id, 'g-new');
    expect(saved.messages.single.id, 'm-old');
  });

  test('without a saved snapshot everything is downloaded', () async {
    SharedPreferences.setMockInitialValues({
      'active_profile_v1': jsonEncode(_profile.toJson()),
    });
    final client = _Client(_snapshot('new', DateTime.now()));
    final repository = AppRepository(librusClient: client);
    await repository.fetchBackgroundSnapshot(parts: {LibrusPart.grades});
    expect(client.calls.single, isNull);
  });

  test('parts follow the notification settings', () {
    expect(
      backgroundParts(const SchoolNotificationSettings()),
      LibrusPart.values.toSet(),
    );
    expect(
      backgroundParts(
        const SchoolNotificationSettings(
          categories: {
            SchoolNotificationCategory.grades: false,
            SchoolNotificationCategory.events: false,
            SchoolNotificationCategory.attendance: false,
          },
        ),
      ),
      {
        LibrusPart.messages,
        LibrusPart.announcements,
        LibrusPart.notices,
        LibrusPart.events,
        LibrusPart.homework,
        LibrusPart.timetable,
      },
    );
    expect(
      backgroundParts(const SchoolNotificationSettings(enabled: false)),
      isEmpty,
    );
  });
}
