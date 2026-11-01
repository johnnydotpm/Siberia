import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/test_reminders.dart';

import 'support/profile_fakes.dart';

class _Shown {
  _Shown(this.title, this.body, this.id);
  final String title;
  final String body;
  final int? id;
}

class _Presenter implements SchoolNotificationPresenter {
  final shown = <_Shown>[];

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
  }) async => shown.add(_Shown(title, body, id));

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

const _parent = SchoolProfile(
  id: 'p-parent',
  account: 'a',
  synergiaLogin: 'child-parent',
  name: 'Uczeń Testowy',
  parent: true,
  slot: 2,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'app_locale_v1': 'en'}));

  test('a parent\'s profile is named in its notifications even alone; a '
      'student\'s alone is not', () {
    const student = SchoolProfile(
      id: 'p-student',
      account: 'a',
      synergiaLogin: 'u',
      name: 'Uczeń Testowy',
    );
    expect(notificationName(_parent, [_parent]), 'Uczeń Testowy');
    expect(notificationName(student, [student]), isNull);
    expect(notificationName(student, [student, _parent]), 'Uczeń Testowy');
  });

  test('"All" in the setup gives a parent what a parent hears of', () async {
    SharedPreferences.setMockInitialValues({
      'auto_sync_on_open_v1': false,
      'app_locale_v1': 'en',
    });
    final world = FakeLibrusWorld()..syncedAt = DateTime.now;
    final repository = world.repository();
    final found = await repository.signIn(username: parentEmail, password: 'x');
    final added = await repository.addProfiles(found.students);
    await repository.switchProfile(
      added.firstWhere((profile) => profile.parent).id,
    );
    final controller = AppController(
      repository,
      updatesEnabled: false,
      notifications: SchoolNotificationService(_Presenter()),
    );
    await controller.bootstrap();
    expect(controller.isParent, isTrue);
    await controller.useAllNotifications();
    final settings = controller.notificationSettings;
    expect(settings.isAllFor(parent: true), isTrue);
    expect(settings.everything, isFalse);
    expect(settings.allows(SchoolNotificationCategory.homework), isFalse);
    expect(settings.attendanceKinds, {
      AttendanceKind.absent,
      AttendanceKind.late,
    });
    expect(settings.allows(SchoolNotificationCategory.events), isFalse);
    expect(settings.reminders.any, isFalse);

    await controller.switchProfile(
      added.firstWhere((profile) => !profile.parent).id,
    );
    await controller.useAllNotifications();
    expect(controller.notificationSettings.everything, isTrue);
  });

  testWidgets('a parent\'s notification settings change the quiet hours and '
      'the summary of the open profile', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auto_sync_on_open_v1': false,
      'app_design_v1': 'classic',
      'app_locale_v1': 'en',
    });
    final world = FakeLibrusWorld()..syncedAt = DateTime.now;
    final repository = world.repository();
    final found = await repository.signIn(username: parentEmail, password: 'x');
    final added = await repository.addProfiles(found.students);
    final parent = added.firstWhere((profile) => profile.parent);
    await repository.switchProfile(parent.id);
    final controller = AppController(
      repository,
      updatesEnabled: false,
      notifications: SchoolNotificationService(_Presenter()),
    );
    await controller.bootstrap();
    controller.selectTab(9);
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    // A parent's sections come first, so the row may start below the fold.
    final row = find.byKey(const ValueKey('settings-notifications'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // At the top, clear of the bottom bar, the tap lands on the row.
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    // Quiet hours start on, the summary off.
    for (final key in ['notify-quiet', 'notify-digest']) {
      final tile = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();
    }
    final preferences = controller.profileOf(parent.id)!.parentPreferences;
    expect((preferences.quiet, preferences.digest), (false, true));
    final saved = (await repository.loadProfiles(reload: true))
        .firstWhere((profile) => profile.id == parent.id)
        .parentPreferences;
    expect((saved.quiet, saved.digest), (false, true));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
