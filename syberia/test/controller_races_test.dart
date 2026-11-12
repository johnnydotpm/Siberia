import 'dart:async';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

/// What happens while the app waits on Librus: another profile opened, a
/// message read, the user signed out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SharedPreferences.setMockInitialValues({});
  });

  AppSnapshot withMail(AppSnapshot data) => data.copyWith(
    messages: [
      for (final id in ['1', '2'])
        SchoolMessage(
          id: id,
          sender: 'Nauczyciel',
          subject: 'Temat $id',
          preview: '',
          receivedAt: DateTime.now(),
          unread: true,
        ),
    ],
  );

  /// Two profiles of one login, synced once, and a controller over them.
  Future<(FakeLibrusWorld, AppController, List<SchoolProfile>)> open() async {
    final world = FakeLibrusWorld()..syncedAt = DateTime.now;
    world.changes['kid-regular'] = withMail;
    world.changes['kid-music'] = withMail;
    final repository = world.repository();
    final login = await repository.signIn(username: familyEmail, password: 'x');
    final profiles = await repository.addProfiles(login.students);
    for (final profile in profiles) {
      await repository.syncProfile(profile.id);
    }
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    addTearDown(controller.dispose);
    return (world, controller, profiles);
  }

  test(
    'a week that arrives after another profile opened stays out of it',
    () async {
      final (world, controller, profiles) = await open();
      final first = controller.activeProfile!;
      final other = profiles.firstWhere((profile) => profile.id != first.id);
      final login = first.synergiaLogin!;
      final day = DateTime.now().add(const Duration(days: 21));
      world.weekLessons[login] = [
        Lesson(
          id: 'far',
          subject: 'Lekcja z innego profilu',
          teacher: '',
          room: '',
          start: day,
          end: day.add(const Duration(minutes: 45)),
        ),
      ];
      final hold = world.weekHolds[login] = Completer<void>();

      final week = controller.fetchTimetableWeek(day);
      await controller.switchProfile(other.id);
      hold.complete();
      expect(await week, hasLength(1));

      expect(controller.activeProfile!.id, other.id);
      expect(
        controller.snapshot.lessons.map((lesson) => lesson.subject),
        isNot(contains('Lekcja z innego profilu')),
      );
    },
  );

  test('a message read while a sync ran stays read after it', () async {
    final (world, controller, _) = await open();
    final login = controller.activeProfile!.synergiaLogin!;
    final message = controller.snapshot.messages.first;
    expect(message.unread, isTrue);

    final hold = world.holds[login] = Completer<void>();
    final syncing = controller.sync();
    await controller.fetchMessageContent(message);
    expect(_find(controller, message.id).unread, isFalse);
    hold.complete();
    await syncing;

    expect(_find(controller, message.id).unread, isFalse);
    // The other one, untouched, comes as Librus has it.
    expect(
      controller.snapshot.messages.where((other) => other.unread),
      hasLength(1),
    );
  });

  test(
    'together too, a message read while its profile synced stays read',
    () async {
      final (world, controller, _) = await open();
      await controller.openTogether();
      final message = controller.snapshot.messages.firstWhere(
        (message) => message.unread,
      );
      final hold = world.holds['kid-regular'] = Completer<void>();
      final hold2 = world.holds['kid-music'] = Completer<void>();
      final syncing = controller.sync();
      await controller.fetchMessageContent(message);
      hold.complete();
      hold2.complete();
      await syncing;

      expect(_find(controller, message.id).unread, isFalse);
      expect(
        controller.snapshot.messages.where((other) => other.unread),
        hasLength(3),
      );
    },
  );

  test('signing out or removing a profile forgets its excuse notes', () async {
    final (_, controller, profiles) = await open();
    Future<void> note(String profileId) => controller.recordExcuse(
      'r-$profileId',
      const [],
      subject: 'Usprawiedliwienie',
      body: 'Treść',
      recipient: 'Wychowawca',
      sent: true,
      profileId: profileId,
    );
    await note(profiles[0].id);
    await note(profiles[1].id);
    expect(controller.absenceHistoryOf(profiles[0].id), hasLength(1));
    expect(controller.absenceHistoryOf(profiles[1].id), hasLength(1));

    await controller.removeProfile(profiles[1].id);
    expect(controller.absenceHistoryOf(profiles[1].id), isEmpty);
    expect(controller.absenceHistoryOf(profiles[0].id), hasLength(1));

    await controller.logout();
    expect(controller.absenceHistoryOf(profiles[0].id), isEmpty);
  });

  test('together, the short names are merged once for each change', () async {
    final (_, controller, _) = await open();
    await controller.openTogether();
    final names = controller.subjectShortNames;
    expect(identical(controller.subjectShortNames, names), isTrue);
    await controller.setSubjectShortName('Matematyka', 'Mat');
    expect(controller.subjectShortNames['Matematyka'], 'Mat');
    expect(identical(controller.subjectShortNames, names), isFalse);
  });

  test('resetting the settings takes the wallpaper colours back', () async {
    final repository = AppRepository();
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    addTearDown(controller.dispose);
    await controller.setUseWallpaperColors(false);
    expect(await repository.loadUseWallpaperColors(), isFalse);

    await controller.resetSettings();
    expect(controller.useWallpaperColors, isTrue);
    expect(await repository.loadUseWallpaperColors(), isTrue);
  });
}

SchoolMessage _find(AppController controller, String id) =>
    controller.snapshot.messages.firstWhere((message) => message.id == id);
