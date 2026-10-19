import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'manual-only mode reads the cached snapshot without contacting Librus',
    () async {
      final saved = _snapshot();
      SharedPreferences.setMockInitialValues({
        'active_profile_v1': jsonEncode(saved.profile.toJson()),
        'last_librus_snapshot_v1': SnapshotCache.encode(saved),
        'auto_sync_on_open_v1': false,
      });
      final client = _CountingLibrusClient(saved);
      final repository = AppRepository(librusClient: client);

      final cached = await repository.load();
      expect(client.fetches, 0);
      expect(cached.grades.single.previousGrades.single.value, '1');
      expect(cached.announcements.single.title, 'School notice');
      expect(await repository.fetchBackgroundSnapshot(), isNull);
      expect(client.fetches, 0);

      await repository.sync(cached);
      expect(client.fetches, 1);

      // Opening the app never waits on Librus; the controller syncs after.
      await repository.saveAutoSyncOnOpen(true);
      await repository.load();
      expect(client.fetches, 1);
    },
  );

  test('the launch sync runs after the app opens, only when enabled', () async {
    final saved = _snapshot();
    SharedPreferences.setMockInitialValues({
      'active_profile_v1': jsonEncode(saved.profile.toJson()),
      'last_librus_snapshot_v1': SnapshotCache.encode(saved),
      'auto_sync_on_open_v1': false,
    });
    final client = _CountingLibrusClient(saved);
    final manual = AppController(
      AppRepository(librusClient: client),
      updatesEnabled: false,
    );
    await manual.bootstrap();
    await manual.startAutoSync();
    expect(client.fetches, 0);
    expect(manual.snapshot.grades.single.id, 'g1');

    await manual.setAutoSyncOnOpen(true);
    final automatic = AppController(
      AppRepository(librusClient: client),
      updatesEnabled: false,
    );
    await automatic.bootstrap();
    expect(client.fetches, 0);
    final sync = automatic.startAutoSync();
    expect(automatic.syncing, isTrue);
    await sync;
    expect(client.fetches, 1);
    expect(automatic.syncing, isFalse);
    expect(automatic.error, isNull);
  });

  test('without an account the launch sync does nothing', () async {
    SharedPreferences.setMockInitialValues({});
    final client = _CountingLibrusClient(_snapshot());
    final controller = AppController(
      AppRepository(librusClient: client),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await controller.startAutoSync();
    expect(client.fetches, 0);
  });

  test('mailbox failures preserve cached messages during foreground and background sync', () async {
    final saved = _snapshot().copyWith(
      messages: [
        SchoolMessage(
          id: 'm1',
          sender: 'Teacher',
          subject: 'Keep me',
          preview: '',
          receivedAt: DateTime(2026, 9, 29),
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'active_profile_v1': jsonEncode(saved.profile.toJson()),
      'last_librus_snapshot_v1': SnapshotCache.encode(saved),
      'auto_sync_on_open_v1': true,
    });
    final failed = _snapshot(
      messagesError: const AppError(
        errorCode: LibrusErrorCode.messageContentFailed,
      ),
    );
    final repository = AppRepository(
      librusClient: _CountingLibrusClient(failed),
    );
    final foreground = await repository.sync(await repository.load());
    expect(foreground.messages.single.id, 'm1');
    expect(foreground.messagesError, isNotNull);
    final background = (await repository.fetchBackgroundSnapshot())!;
    expect(background.messages.single.id, 'm1');
    expect(background.messagesError, isNotNull);
    final manual = await repository.sync(background);
    expect(manual.messages.single.id, 'm1');
    expect(manual.messagesError, isNotNull);
  });

  testWidgets('resuming the app only syncs automatically when enabled', (
    tester,
  ) async {
    final saved = _snapshot();
    SharedPreferences.setMockInitialValues({
      'active_profile_v1': jsonEncode(saved.profile.toJson()),
      'last_librus_snapshot_v1': SnapshotCache.encode(saved),
      'auto_sync_on_open_v1': false,
    });
    final client = _CountingLibrusClient(saved);
    final controller = AppController(
      AppRepository(librusClient: client),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    _sendToBackgroundAndBack(tester);
    await tester.pump();
    expect(client.fetches, 0);

    await controller.sync();
    expect(client.fetches, 1);
    await controller.setAutoSyncOnOpen(true);
    _sendToBackgroundAndBack(tester);
    await tester.pump();
    expect(client.fetches, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// Leaves the app and comes back through the states a phone goes through;
/// text fields check that the order is valid.
void _sendToBackgroundAndBack(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

AppSnapshot _snapshot({AppError? messagesError}) => AppSnapshot(
  messagesError: messagesError,
  profile: const StudentProfile(
    id: 'student-1',
    name: 'Uczeń testowy',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: [
    Lesson(
      id: 'l1',
      subject: 'Polski',
      teacher: 'Nauczyciel A',
      room: '2',
      start: DateTime(2026, 9, 29, 8),
      end: DateTime(2026, 9, 29, 8, 45),
      substitution: true,
      originalSubject: 'Matematyka',
    ),
  ],
  grades: [
    Grade(
      id: 'g1',
      subject: 'Polski',
      value: '4+',
      description: 'Test',
      date: DateTime(2026, 9, 29),
      weight: 2,
      semester: 1,
      previousGrades: [
        Grade(
          id: 'old',
          subject: 'Polski',
          value: '1',
          description: 'Test',
          date: DateTime(2026, 9, 20),
          weight: 2,
          semester: 1,
        ),
      ],
    ),
  ],
  events: const [],
  messages: const [],
  attendance: const [],
  announcements: [
    SchoolAnnouncement(
      id: 'a1',
      title: 'School notice',
      content: 'Text',
      author: 'School',
      createdAt: DateTime(2026, 9, 29),
      validUntil: null,
      read: false,
    ),
  ],
  notices: const [],
  lastSync: DateTime(2026, 9, 29),
);

class _CountingLibrusClient extends LibrusClient {
  _CountingLibrusClient(this.response);
  final AppSnapshot response;
  int fetches = 0;

  @override
  Future<AppSnapshot?> restoreAndFetch({Set<LibrusPart>? parts}) async {
    fetches++;
    return response;
  }
}
