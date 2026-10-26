import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/domain/together.dart';
import 'package:syberia/src/home_widget.dart';
import 'package:syberia/src/l10n/app_localizations.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/home_widget_settings.dart';

import 'support/profile_fakes.dart';

class _Bridge extends HomeWidgetBridge {
  final updates = <(String, Map<String, String>)>[];
  final saved = <int, HomeWidgetConfig>{};

  @override
  Future<void> update(
    String payload, {
    Map<String, String> profiles = const {},
  }) async => updates.add((payload, profiles));

  @override
  Future<void> clear() async {}

  @override
  Future<List<PlacedHomeWidget>> placedWidgets() async => const [
    PlacedHomeWidget(id: 7),
  ];

  @override
  Future<HomeWidgetConfig> loadConfig(int id) async =>
      saved[id] ?? const HomeWidgetConfig();

  @override
  Future<void> saveConfig(int id, HomeWidgetConfig config) async =>
      saved[id] = config;

  @override
  Future<bool> dynamicColorsSupported() async => true;

  @override
  Future<HomeWidgetStatus?> status() async =>
      const HomeWidgetStatus(shared: true);
}

/// The subjects of a widget payload's lessons.
List<String> _subjects(String payload) => [
  for (final lesson in (jsonDecode(payload) as Map)['lessons'] as List)
    (lesson as Map)['subject'] as String,
];

Future<(AppController, _Bridge)> _twoProfiles() async {
  SharedPreferences.setMockInitialValues({
    'app_locale_v1': 'en',
    'auto_sync_on_open_v1': false,
    'app_design_v1': 'classic',
  });
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  final repository = world.repository();
  final found = await repository.signIn(username: familyEmail, password: 'x');
  for (final profile in await repository.addProfiles(found.students)) {
    await repository.syncProfile(profile.id);
  }
  final bridge = _Bridge();
  final controller = AppController(
    repository,
    updatesEnabled: false,
    homeWidget: bridge,
  );
  await controller.bootstrap();
  return (controller, bridge);
}

SchoolProfile _byLogin(AppController controller, String login) =>
    controller.profiles.firstWhere((profile) => profile.synergiaLogin == login);

/// Lets queued widget writes finish.
Future<void> _flush() async {
  for (var turn = 0; turn < 20; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the widgets get the chosen profile\'s lessons, and on Android every '
      'profile\'s', () async {
    final (controller, bridge) = await _twoProfiles();
    await _flush();
    final regular = _byLogin(controller, 'kid-regular');
    final music = _byLogin(controller, 'kid-music');
    final (payload, profiles) = bridge.updates.last;
    expect(_subjects(payload), ['Lekcja s-regular'], reason: 'the first');
    expect(_subjects(profiles[regular.id]!), ['Lekcja s-regular']);
    expect(_subjects(profiles[music.id]!), ['Lekcja s-music']);

    await controller.switchProfile(music.id);
    await _flush();
    expect(_subjects(bridge.updates.last.$1), [
      'Lekcja s-regular',
    ], reason: 'opening a profile does not move the widget');

    await controller.setWidgetProfile(music.id);
    await _flush();
    expect(_subjects(bridge.updates.last.$1), ['Lekcja s-music']);
  });

  test('the widgets can show every profile together: their lessons in one '
      'list, and on Android a list of its own', () async {
    final (controller, bridge) = await _twoProfiles();
    final regular = _byLogin(controller, 'kid-regular');
    final music = _byLogin(controller, 'kid-music');
    await controller.setWidgetProfile(togetherId);
    await _flush();
    expect(controller.widgetProfileId, togetherId);
    final (payload, profiles) = bridge.updates.last;
    expect(_subjects(payload), ['Lekcja s-regular', 'Lekcja s-music']);
    expect(_subjects(profiles[togetherId]!), [
      'Lekcja s-regular',
      'Lekcja s-music',
    ]);
    expect(_subjects(profiles[music.id]!), ['Lekcja s-music']);

    // With one profile left in it there is nothing to show together.
    await controller.setProfileTogether(music.id, false);
    await _flush();
    expect(controller.widgetProfileId, regular.id);
    expect(_subjects(bridge.updates.last.$1), ['Lekcja s-regular']);
    expect(bridge.updates.last.$2.containsKey(togetherId), isFalse);
  });

  test('a widget\'s profile is kept with its settings', () {
    const config = HomeWidgetConfig(profileId: 'p-1');
    expect(config.toJson()['profileId'], 'p-1');
    expect(HomeWidgetConfig.fromJson(config.toJson()), config);
    expect(const HomeWidgetConfig().toJson().containsKey('profileId'), isFalse);
    expect(
      HomeWidgetConfig.fromJson(const {'profileId': ''}).profileId,
      isNull,
    );
  });

  testWidgets('an Android widget can be set to show another profile', (
    tester,
  ) async {
    final (controller, bridge) = await _twoProfiles();
    final music = _byLogin(controller, 'kid-music');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: HomeWidgetsSheet(
            bridge: bridge,
            profiles: controller.profiles,
            defaultProfileId: controller.widgetProfileId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('widget-profile-${music.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('widget-settings-save')));
    await tester.pumpAndSettle();
    expect(bridge.saved[7]!.profileId, music.id);
  });

  testWidgets('an Android widget can be set to show every profile together', (
    tester,
  ) async {
    final (controller, bridge) = await _twoProfiles();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: HomeWidgetsSheet(
            bridge: bridge,
            profiles: controller.profiles,
            defaultProfileId: controller.widgetProfileId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('widget-profile-$togetherId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('widget-settings-save')));
    await tester.pumpAndSettle();
    expect(bridge.saved[7]!.profileId, togetherId);
  });

  testWidgets('on iPhone the settings can choose every profile together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (controller, bridge) = await _twoProfiles();
    controller.selectTab(9);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-widget-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('widget-profile-$togetherId')));
    await tester.pumpAndSettle();
    expect(controller.widgetProfileId, togetherId);
    expect(_subjects(bridge.updates.last.$1), [
      'Lekcja s-regular',
      'Lekcja s-music',
    ]);
    expect(find.text('All together'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on iPhone the settings choose the widget\'s profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (controller, bridge) = await _twoProfiles();
    final music = _byLogin(controller, 'kid-music');
    controller.selectTab(9);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-widget-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('widget-profile-${music.id}')));
    await tester.pumpAndSettle();
    expect(controller.widgetProfileId, music.id);
    expect(bridge.updates.last.$2, isEmpty, reason: 'iOS needs one list');
    expect(_subjects(bridge.updates.last.$1), ['Lekcja s-music']);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
