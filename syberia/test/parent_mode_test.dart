import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/parent.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/test_reminders.dart';

import 'support/profile_fakes.dart';

AppSnapshot _attendance(AppSnapshot data, {bool excused = false}) =>
    AppSnapshot(
      profile: data.profile,
      lessons: data.lessons,
      grades: data.grades,
      events: data.events,
      messages: data.messages,
      announcements: data.announcements,
      notices: data.notices,
      lastSync: DateTime.now(),
      attendance: [
        for (var i = 0; i < 2; i++)
          AttendanceRecord(
            id: 'nb-$i',
            date: DateTime.now().subtract(const Duration(days: 1)),
            lessonNumber: i + 1,
            subject: 'Matematyka',
            type: excused ? 'U' : 'NB',
            symbol: excused ? 'u' : 'nb',
            kind: excused
                ? AttendanceKind.absentExcused
                : AttendanceKind.absent,
          ),
      ],
    );

Future<(AppController, AppRepository, FakeLibrusWorld)> _parent() async {
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  world.changes['child-parent'] = _attendance;
  final repo = world.repository();
  final found = await repo.signIn(username: parentEmail, password: 'x');
  final profiles = await repo.addProfiles([
    found.students.firstWhere((student) => student.parent),
  ]);
  await repo.syncProfile(profiles.first.id);
  final controller = AppController(repo, updatesEnabled: false);
  await controller.bootstrap();
  return (controller, repo, world);
}

class _Deferred {
  _Deferred(this.title, this.body, this.at, this.target);
  final String title, body;
  final DateTime at;
  final NotificationTarget target;
}

class _Presenter
    implements
        SchoolNotificationPresenter,
        DeferredSchoolNotificationPresenter {
  final shown = <String>[];
  final pending = <int, _Deferred>{};
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<NotificationTarget?> launchTarget() async => null;
  @override
  void onTap(void Function(NotificationTarget) callback) {}
  @override
  Future<List<String>> scheduledReminders() async => [];
  @override
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  }) async {}
  @override
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
    int? id,
    NotificationTarget? target,
    String? channelName,
  }) async {
    shown.add(title);
  }

  @override
  Future<void> defer({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationTarget target,
    required String channelName,
  }) async {
    pending[id] = _Deferred(title, body, at, target);
  }

  @override
  Future<void> cancelDeferred(int id) async {
    pending.remove(id);
  }
}

AppSnapshot _grades(int count) => AppSnapshot(
  profile: testStudent('child'),
  lessons: const [],
  grades: [
    for (var i = 0; i < count; i++)
      Grade(
        id: 'g$i',
        subject: 'Math',
        value: '5',
        description: '',
        date: DateTime(2026, 10, 30),
        weight: 1,
        semester: 1,
      ),
  ],
  events: const [],
  messages: const [],
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: DateTime(2026, 10, 30),
);
const _profile = SchoolProfile(
  id: 'parent-profile',
  account: 'family',
  synergiaLogin: 'parent-login',
  name: 'Anna',
  label: 'Music school',
  parent: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SharedPreferences.setMockInitialValues({
      'app_design_v1': 'classic',
      'app_locale_v1': 'en',
      'auto_sync_on_open_v1': false,
      'onboarding_done_v1': true,
    });
  });
  test('role overrides round-trip without changing mailbox identity', () {
    expect(_profile.role, ProfileRole.parent);
    final changed = _profile.copyWith(
      roleOverride: () => ProfileRole.student,
      tabs: [0, 6, 2, 5],
    );
    final restored = SchoolProfile.fromJson(changed.toJson())!;
    expect(restored, changed);
    expect(restored.parent, isTrue);
    expect(restored.synergiaLogin, 'parent-login');
    expect(restored.role, ProfileRole.student);
    expect(
      restored.copyWith(roleOverride: () => null).role,
      ProfileRole.parent,
    );
    final invalid = SchoolProfile.fromJson({
      ..._profile.toJson(),
      'roleOverride': 'unknown',
      'tabs': [0, 0, 20, 5],
    })!;
    expect(invalid.bottomTabs, [0, 6, 2, 5]);
    expect(
      defaultStudentChoice([
        linkedStudent('own'),
        linkedStudent('parent', parent: true),
      ], role: ProfileRole.parent),
      {'parent'},
    );
  });
  test(
    'overnight quiet hours respect calendar rollover and inclusive boundaries',
    () {
      const settings = ParentPreferences();
      expect(settings.isQuiet(DateTime(2026, 10, 31, 21)), isTrue);
      expect(settings.isQuiet(DateTime(2026, 11, 1, 7)), isFalse);
      expect(
        settings.nextAllowed(DateTime(2026, 10, 31, 23)),
        DateTime(2026, 11, 1, 7),
      );
      expect(
        settings.nextAllowed(DateTime(2026, 11, 1, 2)),
        DateTime(2026, 11, 1, 7),
      );
      expect(
        ParentPreferences.fromJson({'quietStart': -1, 'quietEnd': 3000})
            .quietStart,
        1260,
      );
    },
  );
  test(
    'parent defaults preserve explicitly chosen notification settings',
    () async {
      final service = SchoolNotificationService(_Presenter());
      final settings = await service.settingsForProfile(_profile);
      expect(settings.attendanceKinds, {
        AttendanceKind.absent,
        AttendanceKind.late,
      });
      expect(settings.timetableChanges, {TimetableChange.cancelled});
      expect(settings.reminders.any, isFalse);
      expect(settings.allows(SchoolNotificationCategory.homework), isFalse);
      await service.saveSettings(
        settings.copyWith(
          reminders: const TestReminderSettings(evening: true),
          category: SchoolNotificationCategory.homework,
          categoryEnabled: true,
        ),
      );
      final saved = await service.settingsForProfile(_profile);
      expect(saved.reminders.evening, isTrue);
      expect(saved.allows(SchoolNotificationCategory.homework), isTrue);
    },
  );
  test(
    'quiet alerts are scheduled and profile mute cancels pending notifications',
    () async {
      final presenter = _Presenter();
      final service = SchoolNotificationService(
        presenter,
        clock: () => DateTime(2026, 10, 30, 22),
      );
      await service.processSnapshot(_grades(0), profile: _profile);
      await service.processSnapshot(_grades(1), profile: _profile);
      expect(presenter.shown, isEmpty);
      final next =
          presenter.pending[3000 + SchoolNotificationCategory.grades.index]!;
      expect(next.at, DateTime(2026, 10, 31, 7));
      expect(next.title, contains('Anna'));
      expect(next.target.profileId, _profile.id);
      await service.processSnapshot(_grades(2), profile: _profile);
      expect(
        presenter.pending[3000 + SchoolNotificationCategory.grades.index]!.body,
        contains('2'),
      );
      await service.processSnapshot(_grades(2), profile: _profile, quiet: true);
      expect(presenter.pending, isEmpty);
    },
  );
  test(
    'evening digest accumulates changes per child and schedules once per day',
    () async {
      final presenter = _Presenter();
      var now = DateTime(2026, 10, 30, 17);
      final service = SchoolNotificationService(presenter, clock: () => now);
      await service.processSnapshot(_grades(0), profile: _profile);
      await service.processSnapshot(_grades(1), profile: _profile);
      await service.processSnapshot(_grades(3), profile: _profile);
      expect(presenter.pending[5000]!.body, contains('3'));
      expect(presenter.pending[5000]!.at, DateTime(2026, 10, 30, 19));
      expect(presenter.pending[5000]!.title, contains('Anna'));
      now = DateTime(2026, 10, 30, 20);
      final before = presenter.shown.length;
      await service.processSnapshot(_grades(3), profile: _profile);
      expect(presenter.shown.length, before);
    },
  );
  test(
    'role change persists and does not change the mailbox used for sending',
    () async {
      final (controller, repo, _) = await _parent();
      final id = controller.activeProfile!.id;
      expect(controller.isParent, isTrue);
      expect(controller.bottomTabs, [0, 6, 2, 5]);
      await controller.setProfileRole(id, ProfileRole.student);
      expect(controller.isParent, isFalse);
      expect(controller.activeProfile!.parent, isTrue);
      expect(controller.activeProfile!.synergiaLogin, 'child-parent');
      expect(
        (await controller.fetchMessageRecipients()).first.name,
        contains('child-parent'),
      );
      expect(
        (await repo.loadProfiles(reload: true)).first.role,
        ProfileRole.student,
      );
      await controller.setProfileRole(id, ProfileRole.parent);
      expect(controller.canUseStudentTools, isFalse);
      await controller.setParentPreferences(
        id,
        const ParentPreferences(studentTools: true),
      );
      expect(controller.canUseStudentTools, isTrue);
      controller.dispose();
    },
  );
  test(
    'confirmed absence mail is journaled without changing attendance locally',
    () async {
      final (controller, _, world) = await _parent();
      final id = controller.activeProfile!.id;
      final recipient = (await controller.fetchMessageRecipients()).first;
      await controller.sendAbsenceRequest(
        profileId: id,
        recordIds: {'nb-0'},
        recipient: recipient,
        subject: 'Absence request',
        body: 'Please excuse this lesson.',
      );
      final sent = await controller.absenceRequests(id);
      expect(sent, hasLength(1));
      expect(sent.single.state, AbsenceRequestState.sent);
      expect(sent.single.messageId, contains('child-parent'));
      expect(controller.snapshot.attendance.first.kind, AttendanceKind.absent);
      world.changes['child-parent'] = (data) =>
          _attendance(data, excused: true);
      await controller.sync();
      expect(
        controller.snapshot.attendance.first.kind,
        AttendanceKind.absentExcused,
      );
      controller.dispose();
    },
  );
  test(
    'uncertain sends remain in history and cannot be double-submitted',
    () async {
      final (controller, _, world) = await _parent();
      final id = controller.activeProfile!.id;
      final recipient = (await controller.fetchMessageRecipients()).first;
      final hold = Completer<void>();
      world.sending = hold.future;
      final sending = controller.sendAbsenceRequest(
        profileId: id,
        recordIds: {'nb-0'},
        recipient: recipient,
        subject: 'Request',
        body: 'Reason',
      );
      while ((await controller.absenceRequests(id)).isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        controller.sendAbsenceRequest(
          profileId: id,
          recordIds: {'nb-0'},
          recipient: recipient,
          subject: 'Request',
          body: 'Reason',
        ),
        throwsStateError,
      );
      hold.completeError(StateError('connection interrupted'));
      await expectLater(sending, throwsStateError);
      expect(
        (await controller.absenceRequests(id)).single.state,
        AbsenceRequestState.uncertain,
      );
      expect(controller.snapshot.attendance.first.kind, AttendanceKind.absent);
      controller.dispose();
    },
  );
  test(
    'stale absence IDs and foreign recipients are rejected before sending',
    () async {
      final (controller, _, _) = await _parent();
      final id = controller.activeProfile!.id;
      final recipient = (await controller.fetchMessageRecipients()).first;
      await expectLater(
        controller.sendAbsenceRequest(
          profileId: id,
          recordIds: {'stale'},
          recipient: recipient,
          subject: 'Request',
          body: 'Reason',
        ),
        throwsStateError,
      );
      await expectLater(
        controller.sendAbsenceRequest(
          profileId: id,
          recordIds: {'nb-0'},
          recipient: const MessageRecipient(
            id: 999,
            name: 'Other school',
            group: '',
          ),
          subject: 'Request',
          body: 'Reason',
        ),
        throwsStateError,
      );
      expect(await controller.absenceRequests(id), isEmpty);
      controller.dispose();
    },
  );
  test(
    'switching profiles during a send keeps mail in its originating profile',
    () async {
      final (controller, repo, world) = await _parent();
      final parentId = controller.activeProfile!.id;
      final found = await repo.availableStudents();
      final child = found.firstWhere((student) => student.login == 'child-u');
      await repo.addProfiles([child]);
      await controller.refreshProfiles();
      final recipient = (await controller.fetchMessageRecipients()).first;
      final hold = Completer<void>();
      world.sending = hold.future;
      final sending = controller.sendAbsenceRequest(
        profileId: parentId,
        recordIds: {'nb-0'},
        recipient: recipient,
        subject: 'Request',
        body: 'Reason',
      );
      while ((await controller.absenceRequests(parentId)).isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final own = controller.profiles.firstWhere(
        (profile) => profile.synergiaLogin == 'child-u',
      );
      await controller.switchProfile(own.id);
      hold.complete();
      await sending;
      expect(controller.activeProfile!.id, own.id);
      expect(controller.snapshot.sentMessages, isEmpty);
      expect(
        (await controller.absenceRequests(parentId)).single.messageId,
        contains('child-parent'),
      );
      controller.dispose();
    },
  );

  testWidgets(
    'parent dashboard, tabs, preview confirmation and request history work together',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (controller, _, _) = await _parent();
      final id = controller.activeProfile!.id;
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        (nav.destinations[1] as NavigationDestination).label,
        'Attendance',
      );
      await tester.tap(find.byKey(ValueKey('parent-absences-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('absence-row-nb-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('absence-recipient-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nauczyciel child-parent').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('absence-reason')),
        'Medical appointment',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('absence-preview')));
      await tester.tap(find.byKey(const ValueKey('absence-preview')));
      await tester.pumpAndSettle();
      expect(await controller.absenceRequests(id), isEmpty);
      expect(find.textContaining('Medical appointment'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('absence-send-confirm')));
      await tester.pumpAndSettle();
      expect(
        (await controller.absenceRequests(id)).single.state,
        AbsenceRequestState.sent,
      );
      expect(controller.snapshot.attendance.first.kind, AttendanceKind.absent);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
