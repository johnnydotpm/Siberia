import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_items.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';
import 'package:syberia/src/ui/profile_avatar.dart';

import 'support/profile_fakes.dart';

/// The phone after signing in to the family login: the student at the
/// regular school, open, and at the music school.
Future<(AppController, AppRepository, FakeLibrusWorld)> _twoProfiles({
  bool autoSync = false,
  DateTime Function()? syncedAt,
  bool both = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': autoSync,
    'app_design_v1': 'classic',
  });
  final world = FakeLibrusWorld()..syncedAt = syncedAt ?? DateTime.now;
  final repository = world.repository();
  final found = await repository.signIn(username: familyEmail, password: 'x');
  final added = await repository.addProfiles(
    both ? found.students : [found.students.first],
  );
  for (final profile in added) {
    await repository.syncProfile(profile.id);
  }
  world.fetches.clear();
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  return (controller, repository, world);
}

SchoolProfile _profile(AppController controller, String login) =>
    controller.profiles.firstWhere((profile) => profile.synergiaLogin == login);

/// The profile button of the top bar, in either design.
Finder _profileButton() => find.byWidgetPredicate(
  (widget) =>
      widget.key == const ValueKey('profile-button') ||
      widget.key == const ValueKey('glass-bar-button-account'),
);

Future<void> _openProfiles(WidgetTester tester) async {
  await tester.tap(_profileButton().first);
  await tester.pumpAndSettle();
}

/// Lets a sync started without waiting finish.
Future<void> _settle(AppController controller) async {
  for (var turn = 0; turn < 50 && controller.syncing; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the profile button opens the profiles, and a tap switches at '
      'once without the network', (tester) async {
    final (controller, _, world) = await _twoProfiles();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _profileButton(),
        matching: find.byType(ProfileAvatar),
      ),
      findsOneWidget,
    );

    await _openProfiles(tester);
    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('Szkoła Podstawowa'), findsOneWidget);
    expect(find.text('Szkoła Muzyczna'), findsOneWidget);
    expect(find.text('Sign out of all'), findsOneWidget);

    await tester.tap(find.text('Szkoła Muzyczna'));
    await tester.pumpAndSettle();
    expect(controller.activeProfile!.synergiaLogin, 'kid-music');
    expect(controller.snapshot.profile.id, 's-music');
    expect(world.fetches, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('switching to data older than 20 minutes syncs it when automatic '
      'sync is on', () async {
    var stamp = DateTime.now().subtract(const Duration(hours: 1));
    final (controller, _, world) = await _twoProfiles(
      autoSync: true,
      syncedAt: () => stamp,
    );
    final regular = _profile(controller, 'kid-regular');
    final music = _profile(controller, 'kid-music');
    stamp = DateTime.now();

    await controller.switchProfile(music.id);
    await _settle(controller);
    expect(world.fetches, ['kid-music'], reason: 'its data was an hour old');

    await controller.switchProfile(regular.id);
    await _settle(controller);
    expect(world.fetches, ['kid-music', 'kid-regular']);

    await controller.switchProfile(music.id);
    await _settle(controller);
    expect(world.fetches, ['kid-music', 'kid-regular'], reason: 'fresh');
  });

  test('a sync of the profile left behind saves its data but leaves the '
      'screen alone', () async {
    final (controller, repository, world) = await _twoProfiles();
    final regular = _profile(controller, 'kid-regular');
    final music = _profile(controller, 'kid-music');
    final before = (await repository.loadProfileSnapshot(regular.id))
        .grades
        .single
        .id;
    final hold = world.holds['kid-regular'] = Completer<void>();

    final sync = controller.sync();
    await Future<void>.delayed(Duration.zero);
    expect(controller.syncing, isTrue);
    await controller.switchProfile(music.id);
    expect(controller.syncing, isFalse, reason: 'the open profile is idle');
    hold.complete();
    await sync;

    expect(controller.snapshot.profile.id, 's-music');
    expect(controller.error, isNull);
    final saved = await repository.loadProfileSnapshot(regular.id);
    expect(saved.grades.single.id, isNot(before));
  });

  testWidgets('a profile is renamed, recoloured and removed from its actions', (
    tester,
  ) async {
    final (controller, _, world) = await _twoProfiles();
    final music = _profile(controller, 'kid-music');
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    Future<void> actions(String key) async {
      await _openProfiles(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('profile-${music.id}')),
          matching: find.byIcon(Icons.more_horiz_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    await actions('profile-rename');
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      'Szkoła muzyczna',
    );
    await tester.tap(find.byKey(const ValueKey('profile-name-save')));
    await tester.pumpAndSettle();
    expect(_profile(controller, 'kid-music').displayName, 'Szkoła muzyczna');
    expect(_profile(controller, 'kid-music').name, 'Uczeń Testowy');

    await actions('profile-color');
    await tester.tap(find.byKey(const ValueKey('profile-color-5')));
    await tester.pumpAndSettle();
    expect(_profile(controller, 'kid-music').color, 5);

    await actions('profile-remove');
    expect(find.textContaining('Szkoła muzyczna'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('profile-remove-confirm')));
    await tester.pumpAndSettle();
    expect(controller.profiles.map((profile) => profile.synergiaLogin), [
      'kid-regular',
    ]);
    expect(world.forgotten, [music.id]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a student of a saved login is added with one tap and opens', (
    tester,
  ) async {
    final (controller, _, world) = await _twoProfiles(both: false);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await _openProfiles(tester);
    await tester.tap(find.byKey(const ValueKey('profiles-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-student-kid-regular')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-student-kid-music')));
    await tester.pumpAndSettle();

    expect(controller.profiles, hasLength(2));
    expect(controller.activeProfile!.synergiaLogin, 'kid-music');
    expect(controller.snapshot.profile.id, 's-music');
    expect(world.fetches, ['kid-music']);
    expect(find.text('Add profile'), findsNothing, reason: 'the sheet closed');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('signing in to a login with a parent and a student account asks '
      'who to add, the student\'s own account checked', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app_design_v1': 'classic',
      'onboarding_done_v1': true,
    });
    final world = FakeLibrusWorld();
    final controller = AppController(world.repository(), updatesEnabled: false);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect Librus account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, parentEmail);
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text('Sign in and sync'));
    // The sign-in button spins under the question, so nothing settles.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Who to add?'), findsOneWidget);
    CheckboxListTile choice(String login) =>
        tester.widget(find.byKey(ValueKey('choose-$login')));
    expect(choice('child-parent').value, isFalse);
    expect(choice('child-u').value, isTrue);
    expect(find.text('Parent account'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('choose-students-add')));
    await tester.pumpAndSettle();

    expect(controller.profiles.map((profile) => profile.synergiaLogin), [
      'child-u',
    ]);
    expect(controller.snapshot.profile.id, 's-child');
    expect(find.text('Connect Librus account'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('without a choice to make, signing in adds the student\'s own '
      'account', () async {
    SharedPreferences.setMockInitialValues({});
    final world = FakeLibrusWorld();
    final controller = AppController(world.repository(), updatesEnabled: false);
    await controller.bootstrap();
    expect(
      await controller.loginLibrus(username: parentEmail, password: 'x'),
      isTrue,
    );
    expect(controller.profiles.single.synergiaLogin, 'child-u');
  });

  test('a sign-in whose first sync fails adds nothing', () async {
    final (controller, repository, world) = await _twoProfiles(both: false);
    final open = controller.activeProfile!.id;
    world.offline = true;
    expect(
      await controller.loginLibrus(username: otherEmail, password: 'x'),
      isFalse,
    );
    expect(controller.error, isNotNull);
    expect(controller.profiles.map((profile) => profile.id), [open]);
    expect(repository.activeProfile!.id, open);
    expect(controller.snapshot.profile.id, 's-regular');

    SharedPreferences.setMockInitialValues({});
    final fresh = AppController(world.repository(), updatesEnabled: false);
    await fresh.bootstrap();
    expect(
      await fresh.loginLibrus(username: familyEmail, password: 'x'),
      isFalse,
    );
    expect(fresh.profiles, isEmpty);
    expect(fresh.snapshot.profile.provider, 'Signed out');
  });

  testWidgets('another profile\'s news shows a dot, which goes once it is '
      'opened', (tester) async {
    final (controller, repository, _) = await _twoProfiles();
    final music = _profile(controller, 'kid-music');
    await repository.setProfileNews(music.id, true);
    await controller.refreshProfiles();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _profileButton(),
        matching: find.byKey(const ValueKey('profile-news-dot')),
      ),
      findsOneWidget,
    );

    await _openProfiles(tester);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('profile-${music.id}')),
        matching: find.byKey(const ValueKey('profile-news-dot')),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Szkoła Muzyczna'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-news-dot')), findsNothing);
    expect(await repository.loadProfileNews(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('UIKit draws the profile as its letter in its colour, with a '
      'dot for news', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final params = <Map<Object?, Object?>>[];
    GlassPlatform.debugSetBackend(GlassBackend.uikit);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      final arguments = call.arguments;
      if (call.method == 'create' &&
          arguments is Map &&
          arguments['viewType'] == 'siberia/glass_bar_buttons') {
        final bytes = arguments['params'] as Uint8List;
        params.add(
          const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(bytes),
          ) as Map<Object?, Object?>,
        );
      }
      return null;
    });
    addTearDown(() {
      GlassPlatform.debugSetBackend(GlassBackend.none);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    });
    final (controller, repository, _) = await _twoProfiles();
    await repository.setProfileNews(_profile(controller, 'kid-music').id, true);
    await controller.refreshProfiles();
    await controller.setDesign(AppDesign.glass);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    final account = (params.last['trailing'] as List)
        .cast<Map<Object?, Object?>>()
        .singleWhere((button) => button['id'] == 'account');
    expect(account['symbol'], 'u.circle.fill');
    expect(account['color'], isA<int>());
    expect(account['badge'], isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('signs', () {
    test('initials skip what is not a word', () {
      expect(profileInitials('Uczeń Testowy'), 'UT');
      expect(profileInitials('Uczeń · szkoła muzyczna'), 'US');
      expect(profileInitials('  '), '');
    });

    test('UIKit gets a letter it has, or a person', () {
      expect(GlassSymbol.profile('Uczeń').name, 'u.circle.fill');
      expect(GlassSymbol.profile('Świetlica').name, 's.circle.fill');
      expect(GlassSymbol.profile('Ученик').name, 'person.crop.circle.fill');
      expect(GlassSymbol.profile('').name, 'person.crop.circle.fill');
    });

    test('a parent\'s account is offered unchecked only beside the '
        'student\'s own', () {
      LinkedSynergiaAccount account(
        String login, {
        bool parent = false,
        String name = 'Uczeń Testowy',
      }) => LinkedSynergiaAccount(
        login: login,
        name: name,
        selected: false,
        parent: parent,
      );
      expect(defaultStudentChoice([account('p', parent: true), account('u')]), {
        'u',
      });
      expect(defaultStudentChoice([account('p', parent: true)]), {'p'});
      expect(
        defaultStudentChoice([
          account('p', parent: true, name: 'Pierwsze Dziecko'),
          account('u', name: 'Drugie Dziecko'),
        ]),
        {'p', 'u'},
      );
    });
  });
}
