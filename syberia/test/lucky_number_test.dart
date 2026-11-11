import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/librus/librus_logins.dart';
import 'package:syberia/src/data/librus/librus_plugin.dart';
import 'package:syberia/src/data/librus/reference_cache.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/domain/together.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

AppSnapshot _data({
  List<LuckyNumber> numbers = const [],
  Map<String, Object?> providerData = const {},
}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'student',
    name: 'Student',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: const [],
  grades: const [],
  events: const [],
  messages: const [],
  attendance: const [],
  announcements: const [],
  notices: const [],
  luckyNumbers: numbers,
  providerData: providerData,
  lastSync: DateTime.now(),
);

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;
  @override
  Future<AppSnapshot> load() async => data;
  @override
  Future<String?> fetchLatestReleaseVersion() async => 'v99.0.0';
}

class _Client extends LibrusClient {
  AppSnapshot response = _data();
  @override
  Future<AppSnapshot?> restoreAndFetch({Set<LibrusPart>? parts}) async =>
      response;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'app_design_v1': 'classic',
      'app_locale_v1': 'en',
      'auto_sync_on_open_v1': false,
    }),
  );

  test('draw dates stay calendar dates through caching, and invalid optional data cannot erase a snapshot', () {
    final day = DateTime(2026, 11, 11);
    final snapshot = _data(numbers: [LuckyNumber(number: 7, day: day)]);
    final encoded = SnapshotCache.encode(snapshot);
    expect(jsonDecode(encoded)['luckyNumbers'][0]['day'], '2026-11-11');
    final restored = SnapshotCache.decode(encoded)!;
    expect(
      restored.luckyNumbers.single.isFor(DateTime(2026, 11, 11, 23, 59)),
      isTrue,
    );
    expect(restored.luckyNumbers.single.isFor(DateTime(2026, 11, 12)), isFalse);
    expect(restored.copyWith(messages: []).luckyNumbers.single.number, 7);
    for (final bad in [
      {'number': 0, 'day': '2026-11-11'},
      {'number': -1, 'day': '2026-11-11'},
      {'number': 7.5, 'day': '2026-11-11'},
      {'number': 7, 'day': '2026-02-30'},
      {'number': 7, 'day': 'unknown'},
      {'number': 7},
    ]) {
      final cached = jsonDecode(encoded) as Map;
      cached['luckyNumbers'] = [bad];
      final decoded = SnapshotCache.decode(jsonEncode(cached));
      expect(decoded, isNotNull);
      expect(decoded!.profile.id, 'student');
      expect(decoded.luckyNumbers, isEmpty);
    }
    final legacy = jsonDecode(encoded) as Map..remove('luckyNumbers');
    expect(SnapshotCache.decode(jsonEncode(legacy))!.luckyNumbers, isEmpty);
  });

  test('native partial synchronization preserves the draw, failed reads retain it and explicit empty draws clear it', () async {
    final client = _Client();
    final plugin = LibrusDiaryPlugin(
      logins: LibrusLogins(),
      references: LibrusReferenceCache(),
      client: client,
    );
    const profile = SchoolProfile(
      id: 'p',
      account: 'account',
      synergiaLogin: 'child',
      name: 'Student',
    );
    final session = plugin.session(profile);
    final previous = _data(
      numbers: [LuckyNumber(number: 7, day: DateTime(2026, 11, 11))],
    );
    expect(
      (await session.sync(
        previous,
        parts: {LibrusPart.messages},
      ))!.luckyNumbers.single.number,
      7,
    );
    client.response = _data(providerData: const {'luckyNumbers': {}});
    expect((await session.sync(previous))!.luckyNumbers.single.number, 7);
    client.response = _data(
      providerData: const {
        'luckyNumbers': {'LuckyNumber': null},
      },
    );
    expect((await session.sync(previous))!.luckyNumbers, isEmpty);
  });

  test('draws keep their profile when snapshots are combined', () {
    const first = SchoolProfile(
      id: 'p1',
      account: 'a',
      synergiaLogin: 'c1',
      name: 'First',
    );
    const second = SchoolProfile(
      id: 'p2',
      account: 'a',
      synergiaLogin: 'c2',
      name: 'Second',
    );
    final day = DateTime(2026, 11, 11);
    final merged = mergeSnapshots([
      (first, _data(numbers: [LuckyNumber(number: 7, day: day)])),
      (second, _data(numbers: [LuckyNumber(number: 12, day: day)])),
    ]);
    expect(merged.luckyNumbers.map((n) => (n.source, n.number)), [
      ('p1', 7),
      ('p2', 12),
    ]);
  });

  testWidgets(
    'only today is shown and the block can be hidden without losing the draw',
    (tester) async {
      final now = DateTime.now();
      final controller = AppController(
        _Repository(
          _data(
            numbers: [
              LuckyNumber(number: 7, day: now),
              LuckyNumber(
                number: 12,
                day: DateTime(now.year, now.month, now.day - 1),
              ),
              LuckyNumber(
                number: 23,
                day: DateTime(now.year, now.month, now.day + 1),
              ),
            ],
          ),
        ),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('today-lucky-numbers'));
      expect(
        find.descendant(of: card, matching: find.text('7')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('12')),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.text('23')),
        findsNothing,
      );
      await controller.setTodayLayout(TodayLayout.decode(['-luckyNumber']));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(controller.snapshot.luckyNumbers, hasLength(3));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('unavailable or stale draws do not show a card', (tester) async {
    final now = DateTime.now();
    for (final numbers in <List<LuckyNumber>>[
      [],
      [LuckyNumber(number: 7, day: DateTime(now.year, now.month, now.day - 1))],
    ]) {
      final controller = AppController(
        _Repository(_data(numbers: numbers)),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-lucky-numbers')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('the lucky number fits a narrow phone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = AppController(
      _Repository(
        _data(numbers: [LuckyNumber(number: 7, day: DateTime.now())]),
      ),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await controller.setTodayLayout(
      const TodayLayout([(block: TodayBlock.luckyNumber, visible: true)]),
    );
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-lucky-numbers')), findsOneWidget);
    expect(find.text('Lucky number'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('each profile shows its own draw, together and after switching', (
    tester,
  ) async {
    final world = FakeLibrusWorld()..syncedAt = DateTime.now;
    world.changes['kid-regular'] = (data) => data.copyWith(
      luckyNumbers: [LuckyNumber(number: 7, day: DateTime.now())],
    );
    world.changes['kid-music'] = (data) => data.copyWith(
      luckyNumbers: [LuckyNumber(number: 12, day: DateTime.now())],
    );
    final repo = world.repository();
    final found = await repo.signIn(username: familyEmail, password: 'x');
    final profiles = await repo.addProfiles(found.students);
    for (final profile in profiles) {
      await repo.syncProfile(profile.id);
    }
    final controller = AppController(repo, updatesEnabled: false);
    await controller.bootstrap();
    await controller.openTogether();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('today-lucky-numbers'));
    expect(find.descendant(of: card, matching: find.text('7')), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('12')),
      findsOneWidget,
    );
    await controller.switchProfile(profiles[1].id);
    await tester.pumpAndSettle();
    expect(find.descendant(of: card, matching: find.text('7')), findsNothing);
    expect(
      find.descendant(of: card, matching: find.text('12')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'tapping the update banner opens the latest release, while closing only dismisses it',
    (tester) async {
      final opened = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          opened.add((call.arguments as Map)['url'] as String);
        }
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final controller = AppController(
        _Repository(_data()),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      await controller.checkForUpdate();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      final banner = find.byKey(const ValueKey('update-banner'));
      await tester.tap(find.text('This version of SiberiaGB is outdated'));
      await tester.pumpAndSettle();
      expect(opened, [
        'https://github.com/johnnydotpm/Siberia/releases/latest',
      ]);
      expect(controller.updateAvailable, isTrue);
      await tester.tap(
        find.descendant(of: banner, matching: find.byIcon(Icons.close_rounded)),
      );
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(controller.updateAvailable, isFalse);
      expect(banner, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
