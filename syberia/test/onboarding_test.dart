import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/test_reminders.dart';

import 'support/profile_fakes.dart';

class _Presenter implements SchoolNotificationPresenter {
  @override
  Future<List<String>> scheduledReminders() async => const [];

  _Presenter({this.allow = true});
  final bool allow;
  var asked = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allow;
  }

  @override
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
    int? id,
    NotificationTarget? target,
    String? channelName,
    bool silent = false,
  }) async {}

  @override
  Future<NotificationTarget?> launchTarget() async => null;

  @override
  void onTap(void Function(NotificationTarget) callback) {}

  @override
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  }) async {}
}

/// A fresh install with the fake Librus accounts, opened as `main` does it.
Future<(AppController, FakeLibrusWorld, _Presenter)> _open(
  WidgetTester tester, {
  Map<String, Object> saved = const {},
  bool allow = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
    ...saved,
  });
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  final presenter = _Presenter(allow: allow);
  final controller = AppController(
    world.repository(),
    updatesEnabled: false,
    notifications: SchoolNotificationService(presenter),
  );
  await controller.bootstrap();
  // As main() does once the app has opened.
  await controller.requestNotificationPermissionIfEnabled();
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return (controller, world, presenter);
}

Finder _next() => find.byKey(const ValueKey('onboarding-next')).last;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Signs in to the family login on the account step, adding both students.
Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, familyEmail);
  await tester.enterText(find.byType(TextFormField).last, 'secret');
  await tester.tap(find.text('Sign in and sync'));
  // The sign-in button spins under the question, so nothing settles.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await _tap(tester, find.byKey(const ValueKey('choose-students-add')));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new install opens on the setup, not the sign-in screen', (
    tester,
  ) async {
    final (controller, _, presenter) = await _open(tester);
    expect(controller.onboardingDone, isFalse);
    expect(find.byKey(const ValueKey('onboarding-welcome')), findsOneWidget);
    expect(find.text('Connect to Librus'), findsNothing);
    expect(presenter.asked, 0, reason: 'nothing asks before it is explained');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('someone using the app before the setup existed does not see '
      'it', (tester) async {
    final (controller, _, _) = await _open(
      tester,
      saved: {
        'active_profile_v1': jsonEncode(testStudent('s-regular').toJson()),
      },
    );
    expect(controller.onboardingDone, isTrue);
    expect(find.byKey(const ValueKey('onboarding')), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_done_v1'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the language and the look change at once', (tester) async {
    final (controller, _, _) = await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('onboarding-language-pl')));
    expect(controller.locale, const Locale('pl'));
    expect(find.text('Wybierz język'), findsOneWidget);
    expect(find.text('Polski'), findsOneWidget, reason: 'its own name');

    await _tap(tester, _next());
    expect(find.byKey(const ValueKey('onboarding-appearance')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('onboarding-theme-dark')));
    expect(controller.colorMode, AppColorMode.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('signing in stays in the setup, and the permission is asked '
      'only on the notifications step', (tester) async {
    final (controller, world, presenter) = await _open(tester);
    await _tap(tester, _next());
    await _tap(tester, _next());
    expect(find.byKey(const ValueKey('onboarding-account')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-next')),
      findsNothing,
      reason: 'not before signing in',
    );

    await _signIn(tester);
    expect(controller.profiles, hasLength(2));
    expect(world.signIns, [familyEmail]);
    expect(
      find.byKey(const ValueKey('onboarding-notifications')),
      findsOneWidget,
      reason: 'signing in moves on by itself',
    );
    expect(presenter.asked, 0, reason: 'not on signing in');
    // Choosing shows the full list, which profiles notify included.
    await _tap(tester, find.byKey(const ValueKey('notify-choose')));
    expect(find.byKey(const ValueKey('notification-profiles')), findsOneWidget);
    expect(presenter.asked, 0, reason: 'nor on choosing');

    await _tap(tester, _next());
    expect(presenter.asked, 1);
    expect(find.byKey(const ValueKey('onboarding-done')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-tip-permission')),
      findsNothing,
    );

    await _tap(tester, _next());
    expect(controller.onboardingDone, isTrue);
    expect(find.byKey(const ValueKey('onboarding')), findsNothing);
    expect(controller.tabIndex, 0, reason: 'Today');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_done_v1'), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('back from notifications shows the profiles, not the form '
      'again', (tester) async {
    await _open(tester);
    await _tap(tester, _next());
    await _tap(tester, _next());
    await _signIn(tester);
    await _tap(tester, find.byKey(const ValueKey('onboarding-back')));
    expect(find.byKey(const ValueKey('onboarding-account')), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(
      find.byKey(const ValueKey('onboarding-add-profile')),
      findsOneWidget,
    );
    await _tap(tester, _next());
    expect(
      find.byKey(const ValueKey('onboarding-notifications')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skipping notifications asks nothing', (tester) async {
    final (controller, _, presenter) = await _open(tester);
    await _tap(tester, _next());
    await _tap(tester, _next());
    await _signIn(tester);
    await _tap(tester, find.byKey(const ValueKey('onboarding-skip')));
    expect(presenter.asked, 0);
    expect(find.byKey(const ValueKey('onboarding-done')), findsOneWidget);
    expect(controller.notificationSettings.enabled, isTrue, reason: 'default');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a refused permission is pointed out at the end', (tester) async {
    await _open(tester, allow: false);
    await _tap(tester, _next());
    await _tap(tester, _next());
    await _signIn(tester);
    await _tap(tester, _next());
    expect(
      find.byKey(const ValueKey('onboarding-tip-permission')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('with large text a long word shrinks instead of breaking', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _open(tester);
    await _tap(tester, _next());
    final paragraph = tester.renderObject<RenderParagraph>(find.text('AMOLED'));
    final lines = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 6),
        )
        .map((box) => box.top)
        .toSet();
    expect(lines, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the system back button steps back', (tester) async {
    await _open(tester);
    await _tap(tester, _next());
    expect(find.byKey(const ValueKey('onboarding-appearance')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-welcome')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('run again from Settings, the account step shows the profiles, '
      'and back from the start leaves it', (tester) async {
    final (controller, _, _) = await _open(tester);
    await _tap(tester, _next());
    await _tap(tester, _next());
    await _signIn(tester);
    await _tap(tester, find.byKey(const ValueKey('onboarding-skip')));
    await _tap(tester, _next());
    expect(controller.onboardingDone, isTrue);

    controller.selectTab(9);
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-onboarding'));
    await tester.scrollUntilVisible(row, 300);
    // Clear of the tab bar at the bottom.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await _tap(tester, row);
    expect(find.byKey(const ValueKey('onboarding-welcome')), findsOneWidget);
    await _tap(tester, _next());
    await _tap(tester, _next());
    expect(
      find.byKey(const ValueKey('onboarding-add-profile')),
      findsOneWidget,
    );
    expect(find.text('Szkoła Muzyczna'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.widget<FilledButton>(_next()).onPressed, isNotNull);

    await _tap(tester, find.byKey(const ValueKey('onboarding-back')));
    await _tap(tester, find.byKey(const ValueKey('onboarding-back')));
    await _tap(tester, find.byKey(const ValueKey('onboarding-back')));
    expect(controller.onboardingDone, isTrue);
    expect(find.byKey(const ValueKey('onboarding')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('after signing out the sign-in screen opens, not the setup', (
    tester,
  ) async {
    final (controller, _, _) = await _open(tester);
    await _tap(tester, _next());
    await _tap(tester, _next());
    await _signIn(tester);
    await _tap(tester, find.byKey(const ValueKey('onboarding-skip')));
    await _tap(tester, _next());
    await controller.logout();
    await tester.pumpAndSettle();
    expect(find.text('Connect to Librus'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the demo from the logo leaves the setup until it ends', (
    tester,
  ) async {
    final (controller, _, _) = await _open(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('login-demo-logo'))),
    );
    await tester.pump(const Duration(seconds: 5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isDemo, isTrue);
    expect(find.byKey(const ValueKey('onboarding')), findsNothing);
    controller.selectTab(9);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-whats-new')),
      300,
    );
    expect(
      find.byKey(const ValueKey('settings-onboarding')),
      findsNothing,
      reason: 'it would wait unseen until the demo ends',
    );

    await controller.logout();
    await tester.pumpAndSettle();
    expect(controller.onboardingDone, isFalse);
    expect(find.byKey(const ValueKey('onboarding-welcome')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
