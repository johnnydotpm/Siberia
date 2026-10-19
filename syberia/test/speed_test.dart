import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/data/snapshot_store.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/frame_rate.dart';
import 'package:syberia/src/state/app_controller.dart';

AppSnapshot _snapshot(String id, {List<SchoolMessage> messages = const []}) =>
    AppSnapshot(
      profile: StudentProfile(
        id: id,
        name: 'Test',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: const [],
      grades: const [],
      events: const [],
      messages: messages,
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: DateTime(2026, 10, 1),
    );

SchoolMessage _message(String id, String subject) => SchoolMessage(
  id: id,
  sender: 'Teacher Delta',
  subject: subject,
  preview: '',
  receivedAt: DateTime(2026, 10, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('refresh rate', () {
    const channel = MethodChannel('test/frame_rate');
    late List<String> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test(
      'quick frames raise the rate and a quiet moment releases it',
      () async {
        final booster = FrameRateBooster(
          channel: channel,
          idleDelay: const Duration(milliseconds: 40),
        );
        // A clock ticking once a second is not movement.
        booster.onFrame(const Duration(seconds: 1));
        booster.onFrame(const Duration(seconds: 2));
        await pumpEventQueue();
        expect(calls, isEmpty);
        expect(booster.boosted, isFalse);

        // Scrolling: frames 8 ms apart.
        for (var frame = 1; frame <= 5; frame++) {
          booster.onFrame(Duration(milliseconds: 2000 + frame * 8));
        }
        await pumpEventQueue();
        expect(booster.boosted, isTrue);
        expect(calls, ['boost']);

        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(booster.boosted, isFalse);
        expect(calls, ['boost', 'release']);
      },
    );

    test('frames that keep coming keep the rate up', () async {
      final booster = FrameRateBooster(
        channel: channel,
        idleDelay: const Duration(milliseconds: 60),
      );
      var time = const Duration(seconds: 1);
      for (var step = 0; step < 6; step++) {
        booster.onFrame(time);
        time += const Duration(milliseconds: 8);
        booster.onFrame(time);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(calls, ['boost']);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(calls, ['boost', 'release']);
    });

    test('leaving the app releases the rate at once', () async {
      final booster = FrameRateBooster(channel: channel);
      booster.onFrame(const Duration(seconds: 1));
      booster.onFrame(const Duration(milliseconds: 1008));
      booster.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      expect(calls, ['boost', 'release']);
      expect(booster.boosted, isFalse);
    });
  });

  group('snapshot file', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('syberia_snapshot');
    });
    tearDown(() => directory.delete(recursive: true));

    test(
      'moves an older snapshot out of preferences and keeps it in a file',
      () async {
        SharedPreferences.setMockInitialValues({
          SnapshotStore.preferencesKey: SnapshotCache.encode(
            _snapshot('legacy'),
          ),
        });
        final preferences = SharedPreferences.getInstance();
        SnapshotStore store() => SnapshotStore(
          preferences: preferences,
          directory: () async => directory,
        );

        expect((await store().read())!.profile.id, 'legacy');
        expect(
          (await preferences).getString(SnapshotStore.preferencesKey),
          isNull,
        );
        final file = File(
          '${directory.path}${Platform.pathSeparator}${SnapshotStore.fileName}',
        );
        expect(file.existsSync(), isTrue);

        final reopened = store();
        expect((await reopened.read())!.profile.id, 'legacy');
        await reopened.write(_snapshot('first'));
        await reopened.write(_snapshot('second'));
        expect((await reopened.read())!.profile.id, 'second');
        expect(
          directory.listSync().where((entry) => entry.path.endsWith('.tmp')),
          isEmpty,
        );

        await reopened.clear();
        expect(file.existsSync(), isFalse);
        expect(await reopened.read(), isNull);
      },
    );

    test('the repository opens on the snapshot from the file', () async {
      final saved = _snapshot('student-1');
      SharedPreferences.setMockInitialValues({
        'active_profile_v1':
            '{"id":"student-1","name":"Test",'
            '"school":"School","provider":"Librus Synergia"}',
      });
      final store = SnapshotStore(
        preferences: SharedPreferences.getInstance(),
        directory: () async => directory,
      );
      await store.write(saved);
      final repository = AppRepository(snapshotStore: store);
      expect((await repository.load()).profile.id, 'student-1');
    });

    test(
      'without an app directory the snapshot stays in preferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = SnapshotStore(
          preferences: SharedPreferences.getInstance(),
          directory: () => Future.error(MissingPluginException()),
        );
        await store.write(_snapshot('kept'));
        final raw = (await SharedPreferences.getInstance()).getString(
          SnapshotStore.preferencesKey,
        );
        expect(SnapshotCache.decode(raw)!.profile.id, 'kept');
        expect((await store.read())!.profile.id, 'kept');
        await store.clear();
        expect(await store.read(), isNull);
      },
    );
  });

  testWidgets('a page is built when first opened and fresh when shown again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository(
      _snapshot('student-1', messages: [_message('m1', 'Trip')]),
      _snapshot('student-1', messages: [_message('m2', 'Exam week')]),
    );
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    final search = find.byKey(
      const ValueKey('messages-search'),
      skipOffstage: false,
    );
    expect(search, findsNothing);

    controller.selectTab(5);
    await tester.pumpAndSettle();
    expect(search, findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);

    // Hidden, the page keeps its state but is not rebuilt by the sync…
    controller.selectTab(0);
    await tester.pumpAndSettle();
    expect(search, findsOneWidget);
    await controller.sync();
    await tester.pumpAndSettle();

    // …and shows the new data as soon as it is open again.
    controller.selectTab(5);
    await tester.pumpAndSettle();
    expect(find.text('Exam week'), findsOneWidget);
    expect(find.text('Trip'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data, this.synced);
  final AppSnapshot data;
  final AppSnapshot synced;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<AppSnapshot> sync(AppSnapshot current) async => synced;
}
