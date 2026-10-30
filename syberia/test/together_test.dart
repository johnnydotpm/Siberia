import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/domain/together.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

SchoolProfile _profile(String id) =>
    SchoolProfile(id: id, account: 'a', synergiaLogin: id, name: 'Uczeń');

/// One profile's data: a lesson at [hour], a grade, a test, a message, a
/// day off and a teacher's absence, all with the same ids in every profile.
AppSnapshot _snapshot({
  required int hour,
  required DateTime lastSync,
  String teacher = 'Nauczyciel',
  AppError? messagesError,
}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'student',
    name: 'Uczeń Testowy',
    school: 'Szkoła',
    provider: 'Librus Synergia',
  ),
  lessons: [
    Lesson(
      id: 'l1',
      subject: 'Przedmiot $hour',
      teacher: teacher,
      room: '1',
      start: DateTime(2026, 10, 26, hour),
      end: DateTime(2026, 10, 26, hour, 45),
    ),
  ],
  grades: [
    Grade(
      id: 'g1',
      subject: 'Przedmiot $hour',
      value: '5',
      description: '',
      date: DateTime(2026, 10, hour),
      weight: 1,
      semester: 1,
    ),
  ],
  events: [
    SchoolEvent(
      id: 'e1',
      title: 'Sprawdzian',
      subject: 'Przedmiot $hour',
      date: DateTime(2026, 10, 27),
      kind: EventKind.exam,
    ),
  ],
  messages: [
    SchoolMessage(
      id: 'm1',
      sender: 'Nauczyciel',
      subject: 'Temat $hour',
      preview: '',
      receivedAt: DateTime(2026, 10, 25, hour),
    ),
  ],
  messagesError: messagesError,
  attendance: const [],
  announcements: const [],
  notices: const [],
  freeDays: [
    FreeDay(
      id: 'f1',
      kind: FreeDayKind.teacher,
      name: '',
      from: DateTime(2026, 10, 26),
      to: DateTime(2026, 10, 26),
      teacher: teacher,
    ),
  ],
  lastSync: lastSync,
);

void main() {
  group('the data of every profile together', () {
    final school = _profile('p-school');
    final music = _profile('p-music');

    test('holds every item of each profile, marked with it, under ids that '
        'never meet', () {
      final merged = mergeSnapshots([
        (school, _snapshot(hour: 8, lastSync: DateTime(2026, 10, 26, 7))),
        (music, _snapshot(hour: 15, lastSync: DateTime(2026, 10, 26, 6))),
      ]);
      for (final items in <List<Object>>[
        merged.lessons,
        merged.grades,
        merged.events,
        merged.messages,
        merged.freeDays,
      ]) {
        expect(items, hasLength(2));
      }
      expect(merged.lessons.map((lesson) => lesson.id), [
        'p-school|l1',
        'p-music|l1',
      ]);
      expect(merged.lessons.map((lesson) => lesson.source), [
        'p-school',
        'p-music',
      ]);
      expect(merged.grades.map((grade) => grade.source).toSet(), {
        'p-school',
        'p-music',
      });
      expect(merged.messages.map((message) => message.id).toSet(), {
        'p-school|m1',
        'p-music|m1',
      });
      expect(merged.profile.id, togetherId);
      expect(merged.profile.provider, 'Librus Synergia');
    });

    test('comes in the order one profile does: lessons by time, grades and '
        'messages newest first, ties in the order of the profiles', () {
      final merged = mergeSnapshots([
        (music, _snapshot(hour: 15, lastSync: DateTime(2026, 10, 26))),
        (school, _snapshot(hour: 8, lastSync: DateTime(2026, 10, 26))),
      ]);
      expect(merged.lessons.map((lesson) => lesson.source), [
        'p-school',
        'p-music',
      ]);
      expect(merged.grades.map((grade) => grade.source), [
        'p-music',
        'p-school',
      ]);
      expect(merged.messages.map((message) => message.source), [
        'p-music',
        'p-school',
      ]);
      // The same day for both: the first profile's comes first.
      expect(merged.events.map((event) => event.source), [
        'p-music',
        'p-school',
      ]);
    });

    test('was last synced when the longest unsynced profile was; one never '
        'synced yet does not count', () {
      final never = DateTime.fromMillisecondsSinceEpoch(0);
      expect(
        mergeSnapshots([
          (school, _snapshot(hour: 8, lastSync: DateTime(2026, 10, 26, 9))),
          (music, _snapshot(hour: 15, lastSync: DateTime(2026, 10, 25, 20))),
        ]).lastSync,
        DateTime(2026, 10, 25, 20),
      );
      expect(
        mergeSnapshots([
          (school, _snapshot(hour: 8, lastSync: DateTime(2026, 10, 26, 9))),
          (music, _snapshot(hour: 15, lastSync: never)),
        ]).lastSync,
        DateTime(2026, 10, 26, 9),
      );
      expect(
        mergeSnapshots([
          (school, _snapshot(hour: 8, lastSync: never)),
          (music, _snapshot(hour: 15, lastSync: never)),
        ]).lastSync,
        never,
      );
    });

    test('keeps a profile\'s messages error', () {
      const error = AppError(errorCode: LibrusErrorCode.networkTimeout);
      final merged = mergeSnapshots([
        (school, _snapshot(hour: 8, lastSync: DateTime(2026, 10, 26))),
        (
          music,
          _snapshot(
            hour: 15,
            lastSync: DateTime(2026, 10, 26),
            messagesError: error,
          ),
        ),
      ]);
      expect(merged.messagesError, same(error));
    });

    test('an id of the view together leads back to its profile and its own '
        'id', () {
      expect(localId('p-music|m1', 'p-music'), 'm1');
      expect(localId('m1', null), 'm1');
      expect(localId('p-music|a|b', 'p-music'), 'a|b');
      expect(sourceOfId('p-music|m1', ['p-school', 'p-music']), 'p-music');
      expect(sourceOfId('p-other|m1', ['p-school', 'p-music']), isNull);
      expect(sourceOfId('m1', ['p-school', 'p-music']), isNull);
    });

    test('a teacher absent at one school is not absent at the other', () {
      final merged = mergeSnapshots([
        (school, _snapshot(hour: 8, lastSync: DateTime(2026, 10, 26))),
        (music, _snapshot(hour: 8, lastSync: DateTime(2026, 10, 26))),
      ]);
      final [schoolLesson, musicLesson] = merged.lessons;
      final schoolAbsence = merged.freeDays.firstWhere(
        (day) => day.source == 'p-school',
      );
      expect(schoolAbsence.absentFor(schoolLesson), isTrue);
      expect(
        schoolAbsence.absentFor(musicLesson),
        isFalse,
        reason: 'the same name, but another school',
      );
    });
  });

  group('the phone', () {
    Future<(AppRepository, FakeLibrusWorld, SchoolProfile, SchoolProfile)>
    signedIn() async {
      SharedPreferences.setMockInitialValues({});
      final world = FakeLibrusWorld();
      final repository = world.repository();
      final found = await repository.signIn(
        username: familyEmail,
        password: 'x',
      );
      final added = await repository.addProfiles(found.students);
      for (final profile in added) {
        await repository.syncProfile(profile.id);
      }
      await repository.switchProfile(added[0].id);
      return (repository, world, added[0], added[1]);
    }

    test('asks the profile named, not the open one', () async {
      final (repository, world, regular, music) = await signedIn();
      await repository.fetchTimetableWeek(DateTime(2026, 10, 26));
      await repository.fetchTimetableWeek(
        DateTime(2026, 10, 26),
        profileId: music.id,
      );
      expect(world.weeks, ['kid-regular', 'kid-music']);

      final recipients = await repository.fetchMessageRecipients(
        profileId: music.id,
      );
      expect(recipients.single.name, 'Nauczyciel kid-music');

      final message = SchoolMessage(
        id: 'm7',
        sender: 'Nauczyciel',
        subject: 'Temat',
        preview: '',
        receivedAt: DateTime(2026, 10, 25),
      );
      await repository.fetchMessageContent(message, profileId: music.id);
      expect(world.opened, ['kid-music:m7']);

      final sent = await repository.sendMessage(
        recipients: recipients,
        subject: 'Temat',
        body: 'Treść',
        profileId: music.id,
      );
      expect(sent.id, 'sent-kid-music');
      expect(
        (await repository.loadProfileSnapshot(music.id)).sentMessages.single.id,
        'sent-kid-music',
        reason: 'in the Sent folder of the profile it was sent from',
      );
      expect(
        (await repository.loadProfileSnapshot(regular.id)).sentMessages,
        isEmpty,
      );
    });

    test(
      'keeps the settings and homework marks of the profile named',
      () async {
        final (repository, _, regular, music) = await signedIn();
        await repository.saveDoneHomework({
          'e1': DateTime(2026, 10, 26),
        }, profileId: music.id);
        expect(await repository.loadDoneHomework(), isEmpty);
        expect((await repository.loadDoneHomework(profileId: music.id)).keys, [
          'e1',
        ]);

        await repository.saveGradeAverageSettings(
          const GradeAverageSettings(weighted: true),
          profileId: music.id,
        );
        expect((await repository.loadGradeAverageSettings()).weighted, isFalse);
        expect(
          (await repository.loadGradeAverageSettings(profileId: music.id))
              .weighted,
          isTrue,
        );

        await repository.saveSubjectShortNames({
          'Kształcenie słuchu': 'KS',
        }, profileId: music.id);
        expect(await repository.loadSubjectShortNames(), isEmpty);
        expect(await repository.loadSubjectShortNamesOf(music.id), {
          'Kształcenie słuchu': 'KS',
        });
        expect(repository.activeProfile?.id, regular.id);
      },
    );

    test('remembers which profiles are in the view together, and whether it '
        'was open', () async {
      final (repository, _, regular, music) = await signedIn();
      expect(repository.profiles.every((profile) => profile.together), isTrue);
      expect(await repository.loadTogether(), isFalse);

      await repository.setProfileTogether(music.id, false);
      await repository.saveTogether(true);

      final reopened = AppRepository(
        librusClients: (profile) =>
            FakeProfileClient(profile, FakeLibrusWorld()),
      );
      final profiles = await reopened.loadProfiles();
      expect(profiles.firstWhere((p) => p.id == regular.id).together, isTrue);
      expect(profiles.firstWhere((p) => p.id == music.id).together, isFalse);
      expect(await reopened.loadTogether(), isTrue);
    });

    test('a profile saved before the view together is in it', () {
      final saved = SchoolProfile.fromJson({
        'id': 'p-old',
        'account': 'a',
        'name': 'Uczeń',
      });
      expect(saved!.together, isTrue);
    });
  });

  group('the app together', () {
    /// Two profiles of one login, synced, the regular school open; and the
    /// app on them.
    Future<(AppController, FakeLibrusWorld, SchoolProfile, SchoolProfile)> app({
      bool together = true,
    }) async {
      SharedPreferences.setMockInitialValues({});
      // Synced just now, so opening it does not sync again behind the test.
      final world = FakeLibrusWorld()..syncedAt = DateTime.now;
      final repository = world.repository();
      final found = await repository.signIn(
        username: familyEmail,
        password: 'x',
      );
      final added = await repository.addProfiles(found.students);
      for (final profile in added) {
        await repository.syncProfile(profile.id);
      }
      await repository.switchProfile(added[0].id);
      final controller = AppController(repository, updatesEnabled: false);
      await controller.bootstrap();
      if (together) await controller.openTogether();
      addTearDown(controller.dispose);
      return (controller, world, added[0], added[1]);
    }

    test('shows the data of both profiles, each item marked with its own, '
        'and opens so again after a restart', () async {
      final (controller, world, regular, music) = await app();
      expect(controller.together, isTrue);
      expect(controller.snapshot.profile.id, togetherId);
      expect(controller.snapshot.grades.map((grade) => grade.source).toSet(), {
        regular.id,
        music.id,
      });
      expect(controller.profileOf(music.id)?.id, music.id);

      final reopened = AppController(world.repository(), updatesEnabled: false);
      addTearDown(reopened.dispose);
      await reopened.bootstrap();
      expect(reopened.together, isTrue);
      expect(reopened.snapshot.lessons, hasLength(2));
    });

    test('needs two profiles in it', () async {
      final (controller, _, _, music) = await app(together: false);
      await controller.setProfileTogether(music.id, false);
      expect(controller.canBeTogether, isFalse);
      await controller.openTogether();
      expect(controller.together, isFalse);
    });

    test('syncs the profiles one after another', () async {
      final (controller, world, _, _) = await app();
      world.fetches.clear();
      final hold = world.holds['kid-regular'] = Completer<void>();
      final sync = controller.sync();
      await Future<void>.delayed(Duration.zero);
      expect(controller.syncing, isTrue);
      expect(world.fetches, ['kid-regular'], reason: 'the second waits');
      hold.complete();
      await sync;
      expect(world.fetches, ['kid-regular', 'kid-music']);
      expect(controller.syncing, isFalse);
    });

    test('a profile that fails leaves the other\'s new data, and the error '
        'names it', () async {
      final (controller, world, regular, music) = await app();
      String gradeOf(String profileId) => controller.snapshot.grades
          .firstWhere((grade) => grade.source == profileId)
          .id;
      final regularBefore = gradeOf(regular.id);
      final musicBefore = gradeOf(music.id);
      // The first one in turn fails; the next one still syncs.
      world.failing.add('kid-regular');
      await controller.sync();
      expect(gradeOf(music.id), isNot(musicBefore), reason: 'synced');
      expect(gradeOf(regular.id), regularBefore, reason: 'kept as it was');
      expect(controller.error?.errorCode, LibrusErrorCode.networkTimeout);
      expect(controller.errorProfile?.id, regular.id);
    });

    test('opens a message, loads a timetable week and sends from the '
        'profile each belongs to', () async {
      final (controller, world, regular, music) = await app();
      final message = SchoolMessage(
        id: sourcedId(music.id, 'm9'),
        sender: 'Nauczyciel',
        subject: 'Temat',
        preview: '',
        receivedAt: DateTime(2026, 10, 25),
        source: music.id,
      );
      final content = await controller.fetchMessageContent(message);
      expect(world.opened, ['kid-music:m9']);
      expect(content.id, message.id, reason: 'its attachments come from it');

      await controller.fetchTimetableWeek(DateTime(2026, 10, 26));
      expect(world.weeks, ['kid-regular', 'kid-music']);

      final recipients = await controller.fetchMessageRecipients(
        profileId: music.id,
      );
      expect(recipients.single.name, 'Nauczyciel kid-music');
      await controller.sendMessage(
        recipients: recipients,
        subject: 'Temat',
        body: 'Treść',
        from: music.id,
      );
      final sent = controller.snapshot.sentMessages.single;
      expect(sent.source, music.id);
      expect(localId(sent.id, sent.source), 'sent-kid-music');
      expect(regular.id, isNot(music.id));
    });

    test('marks homework done in its own profile', () async {
      final (controller, _, regular, music) = await app();
      final homework = SchoolEvent(
        id: sourcedId(music.id, 'hw1'),
        title: 'Zadanie',
        subject: 'Fortepian',
        date: DateTime(2026, 10, 27),
        kind: EventKind.homework,
        source: music.id,
      );
      await controller.setHomeworkDone(homework, true);
      expect(controller.isHomeworkDone(homework), isTrue);
      final repository = FakeLibrusWorld().repository();
      expect((await repository.loadDoneHomework(profileId: music.id)).keys, [
        'hw1',
      ]);
      expect(await repository.loadDoneHomework(profileId: regular.id), isEmpty);
    });

    test('keeps each profile\'s grade average, and a change in the view '
        'together is both profiles\'', () async {
      final (controller, world, regular, music) = await app(together: false);
      await controller.setGradeAverageSettings(
        const GradeAverageSettings(weighted: true),
      );
      await controller.openTogether();
      expect(controller.gradeAverageFor(regular.id).weighted, isTrue);
      expect(controller.gradeAverageFor(music.id).weighted, isFalse);

      await controller.setGradeAverageSettings(
        const GradeAverageSettings(plus: 0.75),
      );
      expect(controller.gradeAverageFor(regular.id).plus, 0.75);
      expect(controller.gradeAverageFor(music.id).plus, 0.75);
      final saved = world.repository();
      for (final profile in [regular, music]) {
        final settings = await saved.loadGradeAverageSettings(
          profileId: profile.id,
        );
        expect(settings.plus, 0.75, reason: profile.id);
      }
    });

    test('a notification of a profile in it does not leave it', () async {
      final (controller, _, _, music) = await app();
      await controller.openNotification(
        NotificationTarget(
          SchoolNotificationCategory.grades,
          profileId: music.id,
        ),
      );
      expect(controller.together, isTrue);
      expect(controller.tabIndex, SchoolNotificationCategory.grades.tabIndex);
    });

    test('leaves for one profile when it is opened, when fewer than two are '
        'left in it, or when a profile is removed', () async {
      var (controller, world, regular, music) = await app();
      await controller.switchProfile(regular.id);
      expect(controller.together, isFalse);
      expect(controller.snapshot.profile.id, isNot(togetherId));
      expect(await world.repository().loadTogether(), isFalse);

      (controller, world, regular, music) = await app();
      await controller.setProfileTogether(music.id, false);
      expect(controller.together, isFalse);
      expect(controller.activeProfile?.id, regular.id);

      (controller, world, regular, music) = await app();
      await controller.removeProfile(music.id);
      expect(controller.together, isFalse);
      expect(controller.snapshot.profile.id, isNot(togetherId));
    });

    test('works in demo mode too', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(
        FakeLibrusWorld().repository(),
        updatesEnabled: false,
      );
      addTearDown(controller.dispose);
      await controller.bootstrap();
      controller.startDemo();
      await controller.openTogether();
      expect(controller.together, isTrue);
      final subjects = controller.snapshot.lessons
          .map((lesson) => lesson.subject)
          .toSet();
      expect(subjects, containsAll(['Mathematics', 'Piano']));
      final before = controller.snapshot.lastSync;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await controller.sync();
      expect(controller.snapshot.lastSync.isAfter(before), isTrue);
    });
  });
}
