import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/debug/diagnostics.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/test_reminders.dart';
import 'package:syberia/src/ui/brand_logo.dart';

import 'support/profile_fakes.dart';

final _menu = find.byKey(const ValueKey('debug-menu'));

class _Presenter implements SchoolNotificationPresenter {
  final shown = <(SchoolNotificationCategory, String, String)>[];

  @override
  Future<List<String>> scheduledReminders() async => const [
    'Sprawdzian jutro: Matematyka',
  ];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
    int? id,
    NotificationTarget? target,
    String? channelName,
  }) async => shown.add((category, title, channelName ?? ''));

  @override
  Future<NotificationTarget?> launchTarget() async => null;

  @override
  void onTap(void Function(NotificationTarget target) callback) {}

  @override
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  }) async {}
}

/// The app in demo mode, with the side menu open.
Future<(AppController, _Presenter)> _openSideMenu(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
    'onboarding_done_v1': true,
  });
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final presenter = _Presenter();
  final controller = AppController(
    FakeLibrusWorld().repository(),
    updatesEnabled: false,
    notifications: SchoolNotificationService(presenter),
  );
  await controller.bootstrap();
  controller.startDemo();
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  return (controller, presenter);
}

/// Holds the side menu's wordmark for [time], and lets go.
Future<void> _hold(WidgetTester tester, Duration time) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(const ValueKey('debug-menu-gesture'))),
  );
  await tester.pump(time);
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _openDebugMenu(WidgetTester tester) async {
  await _hold(tester, const Duration(seconds: 10));
  expect(_menu, findsOneWidget);
}

/// Scrolls the debug menu until [target] is wholly on screen.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.descendant(of: _menu, matching: find.byType(Scrollable)),
  );
  await tester.ensureVisible(target);
  await tester.pump();
}

void main() {
  setUp(Diagnostics.instance.clear);
  tearDown(() => timeDilation = 1);

  testWidgets('opens after ten seconds of holding the wordmark in the side '
      'menu, not before', (tester) async {
    await _openSideMenu(tester);
    await _hold(tester, const Duration(seconds: 5));
    expect(_menu, findsNothing);
    await _hold(tester, const Duration(milliseconds: 9900));
    expect(_menu, findsNothing);
    await _hold(tester, const Duration(seconds: 10));
    expect(_menu, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('copies a report without the names and schools of the '
      'profiles', (tester) async {
    final (controller, _) = await _openSideMenu(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    Diagnostics.instance.recordError(
      StateError('sync of ${controller.snapshot.profile.name} failed'),
      null,
      source: 'sync',
    );
    await _openDebugMenu(tester);
    expect(find.textContaining('StateError'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('debug-copy-report')));
    await tester.pumpAndSettle();
    expect(copied, contains('SiberiaGB diagnostics'));
    expect(copied, contains('Profiles: ${controller.profiles.length}'));
    expect(copied, contains('[sync] StateError'));
    expect(controller.profiles, isNotEmpty);
    for (final profile in controller.profiles) {
      expect(copied, isNot(contains(profile.name)));
      expect(copied, isNot(contains(profile.school)));
    }
    expect(find.textContaining('Report copied'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows the latest requests, and clears them', (tester) async {
    await _openSideMenu(tester);
    Diagnostics.instance.recordRequest(
      DiagnosticRequest(
        at: DateTime(2026, 10, 25, 9),
        method: 'GET',
        host: 'api.librus.pl',
        path: '/2.0/Grades',
        took: const Duration(milliseconds: 80),
        status: 200,
      ),
    );
    await _openDebugMenu(tester);
    final line = find.textContaining('api.librus.pl/2.0/Grades 200 80 ms');
    await _scrollTo(tester, find.text('Clear'));
    expect(line, findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(line, findsNothing);
    expect(Diagnostics.instance.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sends a sample of each kind of notification and lists the '
      'reminders', (tester) async {
    final (_, presenter) = await _openSideMenu(tester);
    await _openDebugMenu(tester);
    for (final category in SchoolNotificationCategory.values) {
      final button = find.byKey(ValueKey('debug-notify-${category.name}'));
      await _scrollTo(tester, button);
      await tester.tap(button);
      await tester.pump();
    }
    expect(presenter.shown.map((each) => each.$1), [
      ...SchoolNotificationCategory.values,
    ]);
    // In the category's own channel, as a real one comes.
    expect(presenter.shown.first.$2, 'New grades');
    expect(presenter.shown.first.$3, 'New grades');
    expect(find.text('Sprawdzian jutro: Matematyka'), findsOneWidget);

    final check = find.byKey(const ValueKey('debug-background-check'));
    await _scrollTo(tester, check);
    await tester.tap(check);
    // The logo preview further down never settles; a second is enough.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Nothing fetched'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps a chosen logo for every launch until switched off, and '
      'slows the animations only while open', (tester) async {
    await _openSideMenu(tester);
    await _openDebugMenu(tester);
    final chip = find.byKey(const ValueKey('debug-logo-christmas'));
    await _scrollTo(tester, chip);
    await tester.tap(chip);
    await tester.pump();
    final keep = find.byKey(const ValueKey('debug-keep-logo'));
    await _scrollTo(tester, keep);
    await tester.tap(keep);
    await tester.pump(const Duration(milliseconds: 500));
    expect(BrandEvents.override, BrandEvent.christmas);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('debug_brand_event_v1'), 'christmas');

    await tester.tap(keep);
    await tester.pump(const Duration(milliseconds: 500));
    expect(BrandEvents.override, isNull);
    expect(preferences.getString('debug_brand_event_v1'), isNull);

    final slow = find.byKey(const ValueKey('debug-slow-motion'));
    await _scrollTo(tester, slow);
    await tester.tap(slow);
    await tester.pump();
    expect(timeDilation, 5);
    // Back to the app: the animations run at their speed again.
    await tester.pageBack();
    await tester.pump();
    // Five times slower, the way back takes a while too.
    await tester.pump(const Duration(seconds: 5));
    expect(_menu, findsNothing);
    expect(timeDilation, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
