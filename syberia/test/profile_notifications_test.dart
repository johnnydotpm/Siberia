import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/background_notifications.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/homework_done.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/test_reminders.dart';

import 'support/profile_fakes.dart';

class _Shown {
  const _Shown(this.category, this.title, this.id, this.target, this.channel);
  final SchoolNotificationCategory category;
  final String title;
  final int? id;
  final NotificationTarget? target;
  final String? channel;
}

class _Presenter implements SchoolNotificationPresenter {
  @override
  Future<List<String>> scheduledReminders() async => const [];

  final shown = <_Shown>[];
  List<TestReminder> scheduled = const [];

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
  }) async => shown.add(_Shown(category, title, id, target, channelName));

  @override
  Future<NotificationTarget?> launchTarget() async => null;

  @override
  void onTap(void Function(NotificationTarget) callback) {}

  @override
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  }) async => scheduled = reminders;
}

SchoolProfile _profile(String id, {int slot = 0, String name = 'Uczeń'}) =>
    SchoolProfile(
      id: id,
      account: familyAccount,
      synergiaLogin: id,
      name: name,
      slot: slot,
    );

AppSnapshot _withGrades(String studentId, List<String> grades) {
  final base = studentSnapshot(studentId, 'x');
  return AppSnapshot(
    profile: base.profile,
    lessons: const [],
    grades: [
      for (final id in grades)
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
    notices: const [],
    lastSync: base.lastSync,
  );
}

AppSnapshot _withTest(String studentId, String id, DateTime day) =>
    studentSnapshot(studentId, 'x').copyWith(
      events: [
        SchoolEvent(
          id: id,
          title: 'Sprawdzian',
          subject: 'Matematyka',
          date: day,
          kind: EventKind.exam,
        ),
        SchoolEvent(
          id: 'hw-$id',
          title: 'Zadanie',
          subject: 'Fizyka',
          date: day,
          kind: EventKind.homework,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'app_locale_v1': 'en'}));

  group('notifications of a profile', () {
    test('with two profiles a title starts with the name, the numbers stay '
        'apart and a tap opens the profile', () async {
      final presenter = _Presenter();
      final service = SchoolNotificationService(presenter);
      final second = _profile('p-music', slot: 1, name: 'Szkoła muzyczna');
      await service.processSnapshot(
        _withGrades('s', ['g1']),
        profile: second,
        name: second.displayName,
      );
      final found = await service.processSnapshot(
        _withGrades('s', ['g1', 'g2']),
        profile: second,
        name: second.displayName,
      );
      expect(found, isTrue);
      final shown = presenter.shown.single;
      expect(shown.title, 'Szkoła muzyczna · New grades');
      expect(shown.channel, 'New grades', reason: 'one channel per kind');
      expect(shown.id, 11 + SchoolNotificationCategory.grades.index);
      expect(
        shown.target,
        const NotificationTarget(
          SchoolNotificationCategory.grades,
          profileId: 'p-music',
        ),
      );
    });

    test('the first profile keeps the numbers it had, and one profile '
        'shows no name', () async {
      final presenter = _Presenter();
      final service = SchoolNotificationService(presenter);
      final first = _profile('p-regular');
      await service.processSnapshot(_withGrades('s', ['g1']), profile: first);
      await service.processSnapshot(
        _withGrades('s', ['g1', 'g2']),
        profile: first,
      );
      expect(presenter.shown.single.title, 'New grades');
      expect(
        presenter.shown.single.id,
        SchoolNotificationCategory.grades.index + 1,
      );
      expect(
        notificationId(SchoolNotificationCategory.timetable, slot: 98),
        lessThan(1000),
        reason: 'below the reminders',
      );
    });

    test('what was seen before profiles carries over to the profile', () async {
      final presenter = _Presenter();
      final service = SchoolNotificationService(presenter);
      await service.processSnapshot(_withGrades('librus-7', ['g1']));
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.containsKey('school_notifications_seen_v1_librus-7'),
        isTrue,
      );

      // g1 was seen; only g2 is new.
      await service.processSnapshot(
        _withGrades('librus-7', ['g1', 'g2']),
        profile: _profile('p-regular'),
      );
      expect(presenter.shown, hasLength(1));
      expect(
        preferences.containsKey('school_notifications_seen_v1_librus-7'),
        isFalse,
      );
      expect(
        preferences.containsKey('school_notifications_seen_v1_p-regular'),
        isTrue,
      );
    });

    test('a profile with notifications off only marks what it saw', () async {
      final presenter = _Presenter();
      final service = SchoolNotificationService(presenter);
      final profile = _profile('p');
      await service.processSnapshot(_withGrades('s', ['g1']), profile: profile);
      expect(
        await service.processSnapshot(
          _withGrades('s', ['g1', 'g2']),
          profile: profile,
          quiet: true,
        ),
        isFalse,
      );
      await service.processSnapshot(
        _withGrades('s', ['g1', 'g2']),
        profile: profile,
      );
      expect(presenter.shown, isEmpty, reason: 'g2 is not replayed');
    });

    test('a tap names its page and profile', () {
      expect(
        NotificationTarget.parse('grades'),
        const NotificationTarget(SchoolNotificationCategory.grades),
      );
      expect(
        NotificationTarget.parse('events|p-1'),
        const NotificationTarget(
          SchoolNotificationCategory.events,
          profileId: 'p-1',
        ),
      );
      expect(NotificationTarget.parse('nothing'), isNull);
      expect(
        const NotificationTarget(
          SchoolNotificationCategory.events,
          profileId: 'p-1',
        ).payload,
        'events|p-1',
      );
    });
  });

  test('the reminders of every profile come as one list, each with its '
      'name, profile and own homework marks', () async {
    final presenter = _Presenter();
    final service = SchoolNotificationService(presenter);
    await service.saveSettings(
      const SchoolNotificationSettings(
        reminders: TestReminderSettings(
          evening: false,
          morning: true,
          homework: true,
        ),
      ),
    );
    final now = DateTime(2026, 10, 19, 12);
    final regular = _profile('p-regular', name: 'Szkoła podstawowa');
    final music = _profile('p-music', slot: 1, name: 'Szkoła muzyczna');
    await HomeworkDoneStore.write(
      await SharedPreferences.getInstance(),
      {'hw-t2': DateTime(2026, 10, 21)},
      now: now,
      key: HomeworkDoneStore.keyFor(music.id),
    );
    await service.updateAllReminders([
      ReminderSource(
        _withTest('s1', 't1', DateTime(2026, 10, 22)),
        profile: regular,
        name: regular.displayName,
      ),
      ReminderSource(
        _withTest('s2', 't2', DateTime(2026, 10, 21)),
        profile: music,
        name: music.displayName,
      ),
    ], now: now);
    final reminders = presenter.scheduled;
    expect(
      [for (final reminder in reminders) reminder.profileId],
      ['p-music', 'p-regular'],
    );
    expect(reminders.first.title, 'Szkoła muzyczna · Today at school');
    expect(reminders.first.body, isNot(contains('Fizyka')), reason: 'done');
    expect(reminders.last.body, contains('Fizyka'));
  });

  group('the app', () {
    Future<(AppController, AppRepository, FakeLibrusWorld, _Presenter)>
    twoProfiles({DateTime Function()? syncedAt, bool autoSync = false}) async {
      SharedPreferences.setMockInitialValues({
        'app_locale_v1': 'en',
        'auto_sync_on_open_v1': autoSync,
        'app_design_v1': 'classic',
      });
      final world = FakeLibrusWorld()..syncedAt = syncedAt ?? DateTime.now;
      final repository = world.repository();
      final found = await repository.signIn(
        username: familyEmail,
        password: 'x',
      );
      for (final profile in await repository.addProfiles(found.students)) {
        await repository.syncProfile(profile.id);
      }
      final presenter = _Presenter();
      final controller = AppController(
        repository,
        updatesEnabled: false,
        notifications: SchoolNotificationService(presenter),
      );
      await controller.bootstrap();
      return (controller, repository, world, presenter);
    }

    SchoolProfile byLogin(AppController controller, String login) => controller
        .profiles
        .firstWhere((profile) => profile.synergiaLogin == login);

    test('a tapped notification opens its profile and page', () async {
      final (controller, _, _, _) = await twoProfiles();
      final music = byLogin(controller, 'kid-music');
      await controller.openNotification(
        NotificationTarget(
          SchoolNotificationCategory.grades,
          profileId: music.id,
        ),
      );
      expect(controller.activeProfile!.id, music.id);
      expect(controller.tabIndex, SchoolNotificationCategory.grades.tabIndex);

      await controller.openNotification(
        const NotificationTarget(
          SchoolNotificationCategory.messages,
          profileId: 'p-removed',
        ),
      );
      expect(controller.activeProfile!.id, music.id);
      expect(controller.tabIndex, SchoolNotificationCategory.messages.tabIndex);
    });

    test('the background check stops when every profile has notifications '
        'off', () async {
      final (_, repository, _, _) = await twoProfiles(autoSync: true);
      final calls = <bool>[];
      final scheduled = AppController(
        repository,
        updatesEnabled: false,
        backgroundScheduling: (enabled) async => calls.add(enabled),
      );
      await scheduled.bootstrap();
      await scheduled.configureBackground();
      for (final profile in scheduled.profiles) {
        await scheduled.setProfileNotify(profile.id, false);
      }
      expect(calls.first, isTrue);
      expect(calls.last, isFalse);
    });

    test('the background check goes through the profiles with notifications '
        'on, and news of one not open puts a dot on it', () async {
      // The saved data is an hour old, so the check fetches again.
      final (controller, repository, world, presenter) = await twoProfiles(
        syncedAt: () => DateTime.now().subtract(const Duration(hours: 1)),
        autoSync: true,
      );
      final regular = byLogin(controller, 'kid-regular');
      final music = byLogin(controller, 'kid-music');
      // Each profile has seen its saved data.
      final service = SchoolNotificationService(presenter);
      for (final profile in [regular, music]) {
        await service.processSnapshot(
          await repository.loadProfileSnapshot(profile.id),
          profile: profile,
        );
      }
      presenter.shown.clear();
      world.fetches.clear();

      final background = world.repository();
      await checkProfilesInBackground(
        background,
        service,
        const SchoolNotificationSettings(),
      );
      expect(world.fetches.toSet(), {'kid-regular', 'kid-music'});
      expect(presenter.shown.map((shown) => shown.title).toSet(), {
        'Uczeń Testowy · New grades',
      });
      expect(presenter.shown.map((shown) => shown.target!.profileId).toSet(), {
        regular.id,
        music.id,
      });
      expect(await repository.loadProfileNews(reload: true), {
        music.id,
      }, reason: 'the open profile gets no dot');
    });

    testWidgets('notification settings have a switch for each profile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (controller, _, _, _) = await twoProfiles();
      final music = byLogin(controller, 'kid-music');
      controller.selectTab(9);
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-notifications')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notification-profiles')), findsOne);
      await tester.tap(
        find.byKey(ValueKey('notification-profile-${music.id}')),
      );
      await tester.pumpAndSettle();
      expect(byLogin(controller, 'kid-music').notify, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('adding a profile says its notifications are on', (
      tester,
    ) async {
      final (controller, repository, _, _) = await twoProfiles();
      await repository.removeProfile(byLogin(controller, 'kid-music').id);
      await controller.refreshProfiles();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profiles-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-student-kid-music')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Notifications for Uczeń Testowy are on. Change it in '
          'Settings → Notifications.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
