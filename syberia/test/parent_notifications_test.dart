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
  _Shown(this.title, this.body, this.silent, this.id);
  final String title;
  final String body;
  final bool silent;
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
    bool silent = false,
  }) async => shown.add(_Shown(title, body, silent, id));

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

AppSnapshot _grades(List<String> ids, {List<String> notes = const []}) {
  final base = studentSnapshot('s', 'x');
  return AppSnapshot(
    profile: base.profile,
    lessons: const [],
    grades: [
      for (final id in ids)
        Grade(
          id: id,
          subject: 'Matematyka',
          value: '5',
          description: '',
          date: DateTime(2026, 10, 1),
          weight: 1,
          semester: 1,
        ),
    ],
    events: const [],
    messages: const [],
    attendance: const [],
    announcements: const [],
    notices: [
      for (final id in notes)
        StudentNotice(
          id: id,
          text: 'Treść',
          category: 'Uwaga',
          teacher: 'Nauczyciel',
          date: DateTime(2026, 10, 1),
          tone: NoticeTone.negative,
        ),
    ],
    lastSync: base.lastSync,
  );
}

Future<SchoolNotificationService> _service(
  _Presenter presenter,
  SchoolNotificationSettings settings,
) async {
  final service = SchoolNotificationService(presenter);
  await service.saveSettings(settings);
  // What was there before is only seen, not told of.
  await service.processSnapshot(_grades(['g0']), profile: _parent);
  return service;
}

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

  test('quiet hours run past midnight, and nothing is quiet with them off', () {
    const quiet = SchoolNotificationSettings(quietHours: true);
    expect(quiet.isQuiet(DateTime(2026, 10, 1, 22, 30)), isTrue);
    expect(quiet.isQuiet(DateTime(2026, 10, 1, 6, 59)), isTrue);
    expect(quiet.isQuiet(DateTime(2026, 10, 1, 7)), isFalse);
    expect(quiet.isQuiet(DateTime(2026, 10, 1, 12)), isFalse);
    const day = SchoolNotificationSettings(
      quietHours: true,
      quietFromMinutes: 12 * 60,
      quietToMinutes: 13 * 60,
    );
    expect(day.isQuiet(DateTime(2026, 10, 1, 12, 30)), isTrue);
    expect(day.isQuiet(DateTime(2026, 10, 1, 22)), isFalse);
    expect(
      const SchoolNotificationSettings().isQuiet(DateTime(2026, 10, 1, 23)),
      isFalse,
    );
  });

  test('in quiet hours a notification comes without sound, by day with it, '
      'and the settings keep the hours', () async {
    final presenter = _Presenter();
    final service = await _service(
      presenter,
      const SchoolNotificationSettings(
        quietHours: true,
        quietFromMinutes: 22 * 60,
      ),
    );
    final saved = await service.loadSettings();
    expect((saved.quietHours, saved.quietFromMinutes), (true, 22 * 60));

    await service.processSnapshot(
      _grades(['g0', 'g1']),
      profile: _parent,
      name: 'Uczeń Testowy',
      now: DateTime(2026, 10, 1, 23),
    );
    await service.processSnapshot(
      _grades(['g0', 'g1', 'g2']),
      profile: _parent,
      name: 'Uczeń Testowy',
      now: DateTime(2026, 10, 2, 10),
    );
    expect(presenter.shown.map((shown) => shown.silent), [true, false]);
    expect(presenter.shown.first.title, startsWith('Uczeń Testowy · '));
  });

  test('with the evening summary, the day\'s news comes once, as one '
      'notification', () async {
    final presenter = _Presenter();
    final service = await _service(
      presenter,
      const SchoolNotificationSettings(digest: true),
    );
    await service.processSnapshot(
      _grades(['g0', 'g1', 'g2']),
      profile: _parent,
      now: DateTime(2026, 10, 1, 10),
    );
    await service.processSnapshot(
      _grades(['g0', 'g1', 'g2'], notes: ['n1']),
      profile: _parent,
      now: DateTime(2026, 10, 1, 14),
    );
    expect(presenter.shown, isEmpty, reason: 'kept for the evening');

    String? name(SchoolProfile profile) => profile.displayName;
    await service.deliverDigests(
      [_parent],
      name: name,
      now: DateTime(2026, 10, 1, 18, 59),
    );
    expect(presenter.shown, isEmpty, reason: 'not yet 19:00');
    await service.deliverDigests(
      [_parent],
      name: name,
      now: DateTime(2026, 10, 1, 19, 5),
    );
    expect(presenter.shown, hasLength(1));
    final summary = presenter.shown.single;
    expect(summary.title, 'Uczeń Testowy · Summary of the day');
    expect(summary.body, contains(' 2'));
    expect(summary.body, contains(' · '));
    expect(summary.id, digestNotificationId(slot: 2));

    await service.deliverDigests(
      [_parent],
      name: name,
      now: DateTime(2026, 10, 1, 20),
    );
    expect(presenter.shown, hasLength(1), reason: 'once');
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
    expect(controller.parentView, isTrue);
    await controller.useAllNotifications();
    final settings = controller.notificationSettings;
    expect(settings.isAllFor(parent: true), isTrue);
    expect(settings.everything, isFalse);
    expect(settings.allows(SchoolNotificationCategory.homework), isFalse);
    expect(settings.attendanceKinds, {
      AttendanceKind.absent,
      AttendanceKind.late,
    });
    expect(settings.quietHours, isTrue);
    expect(settings.reminders.any, isFalse);

    await controller.switchProfile(
      added.firstWhere((profile) => !profile.parent).id,
    );
    await controller.useAllNotifications();
    expect(controller.notificationSettings.everything, isTrue);
  });

  testWidgets('the notification settings turn quiet hours and the summary on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auto_sync_on_open_v1': false,
      'app_design_v1': 'classic',
      'app_locale_v1': 'en',
    });
    final world = FakeLibrusWorld()..syncedAt = DateTime.now;
    final repository = world.repository();
    final found = await repository.signIn(username: familyEmail, password: 'x');
    await repository.addProfiles([found.students.first]);
    final service = SchoolNotificationService(_Presenter());
    final controller = AppController(
      repository,
      updatesEnabled: false,
      notifications: service,
    );
    await controller.bootstrap();
    controller.selectTab(9);
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications').first);
    await tester.pumpAndSettle();

    for (final key in ['notify-quiet', 'notify-digest']) {
      final tile = find.byKey(ValueKey(key));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();
    }
    expect(controller.notificationSettings.quietHours, isTrue);
    expect(controller.notificationSettings.digest, isTrue);
    final saved = await service.loadSettings();
    expect((saved.quietHours, saved.digest), (true, true));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
