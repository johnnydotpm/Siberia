import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_logins.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/homework_done.dart';

import 'support/profile_fakes.dart';

/// A secure storage that fails to read while [failing].
class _FlakyStorage extends TestFlutterSecureStoragePlatform {
  _FlakyStorage(super.data);
  bool failing = false;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (failing) throw StateError('keystore unavailable');
    return super.read(key: key, options: options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> secure;

  setUp(() {
    secure = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secure,
    );
    SharedPreferences.setMockInitialValues({});
  });

  /// What a version before profiles left on the phone.
  void seedLegacy({bool session = true}) {
    if (session) {
      secure[LibrusLogins.legacyKey] = jsonEncode({
        'email': familyEmail,
        'password': 'secret',
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'synergiaLogin': 'kid-regular',
      });
    }
    SharedPreferences.setMockInitialValues({
      'active_profile_v1': jsonEncode(testStudent('s-regular').toJson()),
      'last_librus_snapshot_v1': SnapshotCache.encode(
        studentSnapshot('s-regular', 'legacy'),
      ),
      HomeworkDoneStore.key: ['2026-10-21|hw-1'],
      'subject_short_names_v1': jsonEncode({'Matematyka': 'Mat'}),
      'grade_plus_value_v1': 0.25,
      'grade_weighted_average_v1': false,
      'app_design_v1': 'classic',
    });
  }

  group('moving from a version before profiles', () {
    test('the login becomes the first profile with its data and settings, '
        'and opening again changes nothing', () async {
      seedLegacy();
      final world = FakeLibrusWorld();
      final repository = world.repository();
      final opened = await repository.load();

      final profile = repository.profiles.single;
      expect(profile.slot, 0);
      expect(profile.account, familyAccount);
      expect(profile.synergiaLogin, 'kid-regular');
      expect(profile.name, 'Uczeń Testowy');
      expect(profile.school, 'Szkoła Testowa');
      expect(profile.studentId, 's-regular');
      expect(profile.notify, isTrue);
      expect(repository.activeProfile, profile);
      expect(opened.grades.single.id, 'g-legacy');
      expect(world.fetches, isEmpty, reason: 'it opens without the network');

      expect((await repository.loadDoneHomework()).keys, ['hw-1']);
      expect(await repository.loadSubjectShortNames(), {'Matematyka': 'Mat'});
      final average = await repository.loadGradeAverageSettings();
      expect(average.plus, 0.25);
      expect(average.weighted, isFalse);
      expect(await repository.loadDesign(), AppDesign.classic);

      final saved = (await LibrusLogins().all())[familyAccount]!;
      expect(saved.email, familyEmail);
      expect(saved.refreshToken, 'refresh');
      expect(secure.containsKey(LibrusLogins.legacyKey), isFalse);
      final preferences = await SharedPreferences.getInstance();
      for (final key in [
        'active_profile_v1',
        'last_librus_snapshot_v1',
        HomeworkDoneStore.key,
        'subject_short_names_v1',
        'grade_plus_value_v1',
        'grade_weighted_average_v1',
      ]) {
        expect(preferences.containsKey(key), isFalse, reason: key);
      }

      final before = {
        for (final key in preferences.getKeys()) key: preferences.get(key),
      };
      final again = world.repository();
      expect((await again.load()).grades.single.id, 'g-legacy');
      expect(again.profiles, [profile]);
      expect({
        for (final key in preferences.getKeys()) key: preferences.get(key),
      }, before);
    });

    test('a login the secure storage could not give at first joins the '
        'same profile later', () async {
      seedLegacy();
      final storage = _FlakyStorage(secure)..failing = true;
      FlutterSecureStoragePlatform.instance = storage;
      final world = FakeLibrusWorld();
      final first = world.repository();
      expect((await first.load()).grades.single.id, 'g-legacy');
      final profile = first.profiles.single;
      expect(profile.account, isEmpty);

      storage.failing = false;
      final later = world.repository();
      expect((await later.load()).grades.single.id, 'g-legacy');
      final joined = later.profiles.single;
      expect(joined.id, profile.id, reason: 'its data stays where it is');
      expect(joined.account, familyAccount);
      expect(joined.synergiaLogin, 'kid-regular');
      expect(await later.loadSubjectShortNames(), {'Matematyka': 'Mat'});
      expect(secure.containsKey(LibrusLogins.legacyKey), isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('active_profile_v1'), isFalse);
    });

    test('a profile without its login gives way to the student added '
        'again, with its settings', () async {
      seedLegacy(session: false);
      final world = FakeLibrusWorld()
        ..students['kid-regular'] = ('s-regular', 'Szkoła Testowa');
      final repository = world.repository();
      await repository.load();
      final stale = repository.profiles.single;
      expect(stale.account, isEmpty);

      final found = await repository.signIn(
        username: familyEmail,
        password: 'x',
      );
      final added = await repository.addProfiles([found.students.first]);
      await repository.switchProfile(added.single.id);
      await repository.syncProfile(added.single.id);
      expect(repository.profiles.map((profile) => profile.id), [
        added.single.id,
      ]);
      expect(repository.activeProfile!.id, added.single.id);
      expect(await repository.loadSubjectShortNames(), {'Matematyka': 'Mat'});
      expect((await repository.loadDoneHomework()).keys, ['hw-1']);
      expect(world.forgotten, [stale.id]);
    });

    test('a phone that never signed in gets no profile, without reading the '
        'secure storage', () async {
      FlutterSecureStoragePlatform.instance = _FlakyStorage(secure)
        ..failing = true;
      final repository = FakeLibrusWorld().repository();
      final opened = await repository.load();
      expect(repository.profiles, isEmpty);
      expect(opened.profile.provider, 'Signed out');
    });

    test('signing in on a phone without profiles drops logins an earlier '
        'install left in the keychain', () async {
      secure[LibrusLogins.legacyKey] = '{"email":"old@example.com"}';
      await LibrusLogins().write(
        LibrusLogin.keyOf('old@example.com'),
        const LibrusLogin(email: 'old@example.com', password: 'old'),
      );
      final repository = FakeLibrusWorld().repository();
      await repository.signIn(username: familyEmail, password: 'x');
      expect(secure, isEmpty, reason: 'the fake sign-in saves nothing');
    });
  });

  group('two profiles', () {
    Future<(AppRepository, FakeLibrusWorld, SchoolProfile, SchoolProfile)>
    signedIn() async {
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
      return (repository, world, added[0], added[1]);
    }

    test('each keeps its own data and settings', () async {
      final (repository, _, regular, music) = await signedIn();
      expect(repository.activeProfile!.id, regular.id);
      expect(regular.slot, 0);
      expect(music.slot, 1);
      expect(regular.color, isNot(music.color));
      expect(
        [for (final profile in repository.profiles) profile.school],
        ['Szkoła Podstawowa', 'Szkoła Muzyczna'],
        reason: 'the first sync tells the school',
      );

      await repository.saveSubjectShortNames({'Matematyka': 'Mat'});
      await repository.saveDoneHomework({'hw-1': DateTime(2026, 10, 21)});
      await repository.saveGradeAverageSettings(
        const GradeAverageSettings(plus: 0.25, weighted: false),
      );

      final other = await repository.switchProfile(music.id);
      expect(other.profile.id, 's-music');
      expect(await repository.loadSubjectShortNames(), isEmpty);
      expect(await repository.loadDoneHomework(), isEmpty);
      expect(
        await repository.loadGradeAverageSettings(),
        const GradeAverageSettings(),
      );
      await repository.saveSubjectShortNames({'Matematyka': 'Matma'});

      final back = await repository.switchProfile(regular.id);
      expect(back.profile.id, 's-regular');
      expect(await repository.loadSubjectShortNames(), {'Matematyka': 'Mat'});
      expect((await repository.loadDoneHomework()).keys, ['hw-1']);
      expect((await repository.loadGradeAverageSettings()).plus, 0.25);

      final reopened = AppRepository(
        librusClients: (profile) =>
            FakeProfileClient(profile, FakeLibrusWorld()),
      );
      expect((await reopened.load()).profile.id, 's-regular');
      expect(reopened.profiles.map((profile) => profile.id), [
        regular.id,
        music.id,
      ]);
    });

    test('switching needs no network', () async {
      final (repository, world, regular, music) = await signedIn();
      world.offline = true;
      world.fetches.clear();
      expect((await repository.switchProfile(music.id)).profile.id, 's-music');
      expect(
        (await repository.switchProfile(regular.id)).profile.id,
        's-regular',
      );
      expect(world.fetches, isEmpty);
    });

    test('a sent message lands in its own profile after a switch', () async {
      final (repository, world, regular, music) = await signedIn();
      final sending = Completer<void>();
      world.sending = sending.future;
      final sent = repository.sendMessage(
        recipients: const [
          MessageRecipient(id: 1, name: 'Nauczyciel', group: 'Nauczyciele'),
        ],
        subject: 'Temat',
        body: 'Treść',
      );
      await Future<void>.delayed(Duration.zero);
      await repository.switchProfile(music.id);
      sending.complete();
      expect((await sent).id, 'sent-kid-regular');
      expect(
        (await repository.loadProfileSnapshot(regular.id))
            .sentMessages
            .single
            .id,
        'sent-kid-regular',
      );
      expect(
        (await repository.loadProfileSnapshot(music.id)).sentMessages,
        isEmpty,
      );
    });

    test('students of the login are offered, and another login adds its '
        'own', () async {
      final (repository, _, regular, music) = await signedIn();
      final offered = await repository.availableStudents();
      expect(
        [for (final student in offered) student.login],
        ['kid-regular', 'kid-music'],
      );
      expect(offered.every((student) => student.selected), isTrue);
      expect(await repository.addProfiles(offered), isEmpty);

      final other = await repository.signIn(
        username: 'other@example.com',
        password: 'x',
      );
      expect(other.students.single.selected, isFalse);
      final added = await repository.addProfiles(other.students);
      expect(added.single.slot, 2);
      expect(
        repository.activeProfile!.id,
        regular.id,
        reason: 'adding does not switch',
      );
      expect(repository.profiles.map((profile) => profile.id), [
        regular.id,
        music.id,
        added.single.id,
      ]);
    });

    test('removing a profile forgets its data; the login goes with its last '
        'profile', () async {
      final (repository, world, regular, music) = await signedIn();
      await LibrusLogins().write(
        familyAccount,
        const LibrusLogin(email: familyEmail, password: 'x'),
      );
      await repository.saveSubjectShortNames({'Matematyka': 'Mat'});
      final preferences = await SharedPreferences.getInstance();

      final left = await repository.removeProfile(regular.id);
      expect(world.forgotten, [regular.id]);
      expect(left.profile.id, 's-music', reason: 'the other one opens');
      expect(repository.activeProfile!.id, music.id);
      expect(
        preferences.getKeys().where((key) => key.contains(regular.id)),
        isEmpty,
      );
      expect(await LibrusLogins().read(familyAccount), isNotNull);

      final none = await repository.removeProfile(music.id);
      expect(none.profile.provider, 'Signed out');
      expect(repository.profiles, isEmpty);
      expect(await LibrusLogins().read(familyAccount), isNull);
    });

    test('logging out forgets every profile and login', () async {
      final (repository, world, regular, music) = await signedIn();
      await LibrusLogins().write(
        familyAccount,
        const LibrusLogin(email: familyEmail, password: 'x'),
      );
      await repository.saveDoneHomework({'hw-1': DateTime(2026, 10, 21)});
      final signedOut = await repository.logout();
      expect(signedOut.profile.provider, 'Signed out');
      expect(world.forgotten.toSet(), {regular.id, music.id});
      expect(repository.profiles, isEmpty);
      expect(secure, isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getKeys().where(
          (key) => key.contains(regular.id) || key.contains(music.id),
        ),
        isEmpty,
      );
    });

    test('the background check goes through the profiles with notifications '
        'on', () async {
      // The saved data is from days ago, so the check fetches again.
      final (repository, world, regular, music) = await signedIn();
      world.fetches.clear();
      await repository.setProfileNotify(music.id, false);
      final checked = await repository.fetchBackgroundSnapshots();
      expect([for (final (profile, _) in checked) profile.id], [regular.id]);
      expect(world.fetches, ['kid-regular']);
      expect(checked.single.$2.profile.id, 's-regular');
    });

    test(
      'resetting the settings resets every profile\'s grade average',
      () async {
        final (repository, _, _, music) = await signedIn();
        await repository.saveGradeAverageSettings(
          const GradeAverageSettings(plus: 0.25),
        );
        await repository.switchProfile(music.id);
        await repository.saveGradeAverageSettings(
          const GradeAverageSettings(minus: 0.5),
        );
        await repository.resetPreferences();
        expect(
          await repository.loadGradeAverageSettings(),
          const GradeAverageSettings(),
        );
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getKeys().where((key) => key.startsWith('grade_')),
          isEmpty,
        );
      },
    );
  });

  test('profile colours stay apart and slots fill gaps', () {
    SchoolProfile profile(String id, int color, int slot) => SchoolProfile(
      id: id,
      account: '',
      synergiaLogin: id,
      name: id,
      color: color,
      slot: slot,
    );
    expect(freeProfileColor(const [], 'Anna'), freeProfileColor([], 'Anna'));
    final first = profile('a', 3, 0);
    expect(freeProfileColor([first], 'x'), 11, reason: 'opposite hue');
    expect(freeProfileSlot([first, profile('c', 0, 2)]), 1);
    expect(SchoolProfile.fromJson(first.toJson()), first);
  });
}
