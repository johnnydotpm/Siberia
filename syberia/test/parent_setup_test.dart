import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/test_reminders.dart';

import 'support/profile_fakes.dart';

class _Presenter implements SchoolNotificationPresenter {
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

  @override
  Future<List<String>> scheduledReminders() async => const [];
}

Finder _nextOn(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byKey(const ValueKey('onboarding-next')),
);

/// A new install on the setup's account step.
Future<AppController> _onAccount(
  WidgetTester tester,
  FakeLibrusWorld world,
) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(
    world.repository(),
    updatesEnabled: false,
    notifications: SchoolNotificationService(_Presenter()),
  );
  await controller.bootstrap();
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  await tester.tap(_nextOn('onboarding-welcome'));
  await tester.pumpAndSettle();
  await tester.tap(_nextOn('onboarding-appearance'));
  await tester.pumpAndSettle();
  return controller;
}

/// Signs in to [email], picks [role] when asked, and adds what is checked.
Future<void> _signIn(WidgetTester tester, String email, {String? role}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, 'secret');
  await tester.tap(find.text('Sign in and sync'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  if (role != null) {
    await tester.tap(find.byKey(ValueKey('choose-role-$role')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const ValueKey('choose-students-add')));
  await tester.pumpAndSettle();
}

/// Both accounts of the parent's login as parent's accounts: two children.
FakeLibrusWorld _twoChildren() {
  final world = FakeLibrusWorld();
  world.logins[parentAccount] = [
    linkedStudent('child-parent', account: parentAccount, parent: true),
    linkedStudent(
      'child-u',
      account: parentAccount,
      name: 'Drugie Dziecko',
      parent: true,
    ),
  ];
  return world;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a parent names the children after signing in, one step more '
      'than a student goes through', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = await _onAccount(tester, FakeLibrusWorld());
    await _signIn(tester, parentEmail, role: 'parent');
    expect(controller.parentView, isTrue);
    expect(find.byKey(const ValueKey('onboarding-children')), findsOneWidget);
    expect(find.bySemanticsLabel('Step 4 of 6'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-together')),
      findsNothing,
      reason: 'one child',
    );

    // A child's row opens what can be done with it.
    final child = controller.profiles.single;
    await tester.tap(find.byKey(ValueKey('child-${child.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-rename')), findsOneWidget);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    await tester.tap(_nextOn('onboarding-children'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('onboarding-notifications')),
      findsOneWidget,
    );
    await tester.tap(_nextOn('onboarding-notifications'));
    await tester.pumpAndSettle();
    for (final key in [
      'onboarding-tip-excuse',
      'onboarding-tip-children',
      'onboarding-tip-bottom-bar',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.byKey(const ValueKey('onboarding-tip-profiles')), findsNothing);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a student goes from signing in straight to notifications, in '
      'five steps as before', (tester) async {
    final semantics = tester.ensureSemantics();
    await _onAccount(tester, FakeLibrusWorld());
    await _signIn(tester, familyEmail);
    expect(find.byKey(const ValueKey('onboarding-children')), findsNothing);
    expect(
      find.byKey(const ValueKey('onboarding-notifications')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Step 4 of 5'), findsOneWidget);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('two children open all together, and the switch shows one', (
    tester,
  ) async {
    final controller = await _onAccount(tester, _twoChildren());
    await _signIn(tester, parentEmail);
    expect(controller.profiles, hasLength(2));
    expect(controller.together, isTrue);
    SwitchListTile together() =>
        tester.widget(find.byKey(const ValueKey('onboarding-together')));
    expect(together().value, isTrue);
    await tester.tap(find.byKey(const ValueKey('onboarding-together')));
    await tester.pumpAndSettle();
    expect(controller.together, isFalse);
    expect(together().value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a parent\'s settings list the children and leave out the '
      'homework reminder', (tester) async {
    for (final parent in [true, false]) {
      SharedPreferences.setMockInitialValues({
        'auto_sync_on_open_v1': false,
        'app_design_v1': 'classic',
        'app_locale_v1': 'en',
      });
      final world = FakeLibrusWorld()..syncedAt = DateTime.now;
      final repository = world.repository();
      final found = await repository.signIn(
        username: parentEmail,
        password: 'x',
      );
      await repository.addProfiles([
        found.students.firstWhere((student) => student.parent == parent),
      ]);
      final controller = AppController(
        repository,
        updatesEnabled: false,
        notifications: SchoolNotificationService(_Presenter()),
      );
      await controller.bootstrap();
      controller.selectTab(9);
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('child-rows')),
        parent ? findsOneWidget : findsNothing,
        reason: 'parent: $parent',
      );
      await tester.tap(find.text('Notifications').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reminder-homework')),
        parent ? findsNothing : findsOneWidget,
        reason: 'parent: $parent',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.binding.setSurfaceSize(null);
  });
}
