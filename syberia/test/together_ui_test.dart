import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/domain/together.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/profile_avatar.dart';

import 'support/profile_fakes.dart';

/// The family login's two profiles, the regular school open, synced just
/// now with what [changes] makes of each login's data; together when
/// [together].
Future<(AppController, FakeLibrusWorld, SchoolProfile, SchoolProfile)> _family({
  Map<String, AppSnapshot Function(AppSnapshot)> changes = const {},
  bool together = true,
  bool both = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': 'classic',
  });
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  world.changes.addAll(changes);
  final repository = world.repository();
  final found = await repository.signIn(username: familyEmail, password: 'x');
  final added = await repository.addProfiles(
    both ? found.students : [found.students.first],
  );
  for (final profile in added) {
    await repository.syncProfile(profile.id);
  }
  await repository.switchProfile(added[0].id);
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  if (together) await controller.openTogether();
  return (controller, world, added[0], added.length > 1 ? added[1] : added[0]);
}

Future<void> _pump(WidgetTester tester, AppController controller) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
}

Future<void> _openProfiles(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-button')));
  await tester.pumpAndSettle();
}

/// Today at [hour]:[minute].
DateTime _today(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

Lesson _lesson(String id, int hour, int minute, {String teacher = 'Pan'}) =>
    Lesson(
      id: id,
      subject: 'Matematyka',
      teacher: teacher,
      room: '1',
      start: _today(hour, minute),
      end: _today(hour, minute).add(const Duration(minutes: 45)),
    );

/// The marks of the profiles that name [name].
Finder _markOf(String name) => find.descendant(
  of: find.byKey(const ValueKey('profile-mark')),
  matching: find.text(name),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('"All together" opens the view of both profiles, each item '
      'marked with its school, and a profile opens alone again', (
    tester,
  ) async {
    final (controller, _, regular, music) = await _family(together: false);
    await _pump(tester, controller);
    expect(find.byKey(const ValueKey('profile-mark')), findsNothing);

    await _openProfiles(tester);
    expect(find.text('All together'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profiles-together')));
    await tester.pumpAndSettle();
    expect(controller.together, isTrue);
    // The bar shows both profiles' signs.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-button')),
        matching: find.byType(ProfileAvatar),
      ),
      findsNWidgets(2),
    );

    controller.selectTab(2);
    await tester.pumpAndSettle();
    // One child at two schools: the marks name what tells the schools
    // apart, "Szkoła" being the same in both.
    for (final profile in [regular, music]) {
      expect(
        find.byKey(ValueKey('grades-subject-${profile.id}|Matematyka')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('grades-overview-${profile.id}')),
        findsOneWidget,
      );
    }
    expect(_markOf('Muzyczna'), findsWidgets);
    expect(_markOf('Podstawowa'), findsWidgets);
    expect(_markOf('Szkoła Muzyczna'), findsNothing);

    await _openProfiles(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profiles-together')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(ValueKey('profile-${music.id}')));
    await tester.pumpAndSettle();
    expect(controller.together, isFalse);
    expect(controller.activeProfile?.id, music.id);
    expect(find.byKey(const ValueKey('profile-mark')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('with one profile there is no "All together", and with one '
      'left in it the row says how to add another', (tester) async {
    var (controller, _, _, _) = await _family(together: false, both: false);
    await _pump(tester, controller);
    await _openProfiles(tester);
    expect(find.byKey(const ValueKey('profiles-together')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    final (two, _, _, music) = await _family(together: false);
    controller = two;
    await _pump(tester, controller);
    await _openProfiles(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('profile-${music.id}')),
        matching: find.byIcon(Icons.more_horiz_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-together')));
    await tester.pumpAndSettle();
    expect(controller.profileOf(music.id)?.together, isFalse);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    await _openProfiles(tester);
    expect(
      find.text(
        'Needs at least two profiles together — turn them on with ⋯ next '
        'to a profile',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('profiles-together')));
    await tester.pumpAndSettle();
    expect(controller.together, isFalse);
    expect(
      find.byKey(const ValueKey('profiles-together')),
      findsOneWidget,
      reason: 'the row does nothing, so the list stays',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lessons of two schools at the same time stand side by side, '
      'and a test goes on its own school\'s lesson', (tester) async {
    final (controller, _, regular, music) = await _family(
      changes: {
        'kid-regular': (data) => data.copyWith(lessons: [_lesson('r1', 10, 0)]),
        'kid-music': (data) => data.copyWith(
          lessons: [_lesson('m1', 10, 15)],
          events: [
            SchoolEvent(
              id: 't1',
              title: 'Sprawdzian',
              subject: 'Matematyka',
              date: _today(0),
              kind: EventKind.exam,
            ),
          ],
        ),
      },
    );
    await _pump(tester, controller);
    controller.selectTab(1);
    await tester.pumpAndSettle();
    final ofRegular = find.byKey(
      ValueKey('timeline-lesson-${sourcedId(regular.id, 'r1')}'),
    );
    final ofMusic = find.byKey(
      ValueKey('timeline-lesson-${sourcedId(music.id, 'm1')}'),
    );
    final left = tester.getRect(ofRegular);
    final right = tester.getRect(ofMusic);
    expect(left.right, lessThanOrEqualTo(right.left), reason: 'side by side');
    expect(right.top, greaterThan(left.top), reason: 'each at its own time');
    expect(left.width, lessThan(200));

    final test = find.byKey(
      ValueKey('timetable-test-${sourcedId(music.id, 't1')}'),
    );
    expect(find.descendant(of: ofMusic, matching: test), findsOneWidget);
    expect(find.descendant(of: ofRegular, matching: test), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('lessons of two schools one after another stay two, and a '
      'break counts from the lesson ending last', (tester) async {
    // r1 and r2 make one double lesson; m1, alike but of the other school,
    // stays a lesson of its own.
    final (controller, _, regular, music) = await _family(
      changes: {
        'kid-regular': (data) =>
            data.copyWith(lessons: [_lesson('r1', 9, 0), _lesson('r2', 9, 55)]),
        // Like the one before it but at the other school, and a short one
        // inside the first lesson.
        'kid-music': (data) => data.copyWith(
          lessons: [
            _lesson('m1', 10, 45),
            Lesson(
              id: 'm0',
              subject: 'Rytmika',
              teacher: 'Pani',
              room: '2',
              start: _today(9, 10),
              end: _today(9, 20),
            ),
          ],
        ),
      },
    );
    await controller.setShowTimetableBreaks(true);
    await controller.setMergeTimetableLessons(true);
    await _pump(tester, controller);
    controller.selectTab(1);
    await tester.pumpAndSettle();
    Finder card(SchoolProfile profile, String id) =>
        find.byKey(ValueKey('timeline-lesson-${sourcedId(profile.id, id)}'));
    expect(card(regular, 'r1'), findsOneWidget);
    expect(card(regular, 'r2'), findsNothing, reason: 'in the double lesson');
    expect(card(music, 'm1'), findsOneWidget);
    // From the end of the double lesson at 10:40, not of the short one at
    // 9:20.
    expect(find.text('Break 5 min'), findsOneWidget);
    expect(find.text('Break 85 min'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a short lesson keeps what it shows inside its card, alone or '
      'beside another', (tester) async {
    for (final together in [false, true]) {
      final (controller, _, _, _) = await _family(
        together: together,
        changes: {
          for (final (login, minute) in [('kid-regular', 0), ('kid-music', 5)])
            login: (data) => data.copyWith(
              lessons: [
                Lesson(
                  id: 'short',
                  subject: 'Matematyka',
                  teacher: 'Pan',
                  room: '1',
                  start: _today(10, minute),
                  end: _today(10, minute + 30),
                ),
              ],
            ),
        },
      );
      await _pump(tester, controller);
      controller.selectTab(1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'together: $together');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a day off of one school says which, and a teacher away there '
      'is not away at the other school', (tester) async {
    final (controller, _, regular, music) = await _family(
      changes: {
        'kid-regular': (data) => data.copyWith(lessons: [_lesson('r1', 9, 0)]),
        'kid-music': (data) => data.copyWith(
          lessons: [_lesson('m1', 12, 0)],
          freeDays: [
            FreeDay(
              id: 'away',
              kind: FreeDayKind.teacher,
              name: 'szkolenie',
              from: _today(0),
              to: _today(0),
              teacher: 'Pan',
            ),
            FreeDay(
              id: 'off',
              kind: FreeDayKind.classDay,
              name: 'Koncert',
              from: _today(0),
              to: _today(0),
            ),
          ],
        ),
      },
    );
    await _pump(tester, controller);
    controller.selectTab(1);
    await tester.pumpAndSettle();
    Finder text(String profileId, String id, String value) => find.descendant(
      of: find.byKey(ValueKey('timeline-lesson-${sourcedId(profileId, id)}')),
      matching: find.textContaining(value),
    );
    expect(text(music.id, 'm1', 'Pan – absent'), findsOneWidget);
    expect(text(regular.id, 'r1', 'absent'), findsNothing);
    final banner = find.byKey(
      ValueKey('free-day-${sourcedId(music.id, 'off')}'),
    );
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: _markOf('Muzyczna')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a new message asks which profile it goes from; another one '
      'brings its own school\'s teachers and sends from it', (tester) async {
    final (controller, _, regular, music) = await _family();
    await _pump(tester, controller);
    controller.selectTab(5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New message'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compose-from')), findsOneWidget);
    ChoiceChip chip(SchoolProfile profile) =>
        tester.widget(find.byKey(ValueKey('compose-from-${profile.id}')));
    expect(chip(regular).selected, isTrue, reason: 'the one open last');
    expect(chip(music).selected, isFalse);

    await tester.enterText(
      find.widgetWithText(TextField, 'Recipient'),
      'Naucz',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nauczyciel kid-regular').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Nauczyciel kid-regular'), findsOne);

    await tester.tap(find.byKey(ValueKey('compose-from-${music.id}')));
    await tester.pumpAndSettle();
    expect(chip(music).selected, isTrue);
    expect(find.byType(InputChip), findsNothing, reason: 'other teachers');
    expect(find.text('Recipients: Szkoła Muzyczna'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Recipient'),
      'Naucz',
    );
    await tester.pumpAndSettle();
    expect(find.text('Nauczyciel kid-regular'), findsNothing);
    await tester.tap(find.text('Nauczyciel kid-music').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Subject'), 'Próba');
    await tester.enterText(find.widgetWithText(TextField, 'Message'), 'Treść');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    final sent = controller.snapshot.sentMessages.single;
    expect(sent.source, music.id);
    expect(localId(sent.id, sent.source), 'sent-kid-music');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Today sums up each profile on a row of its own, and an error '
      'says which profile it came from', (tester) async {
    final (controller, world, regular, music) = await _family();
    await _pump(tester, controller);
    expect(
      find.byKey(const ValueKey('today-together-summary')),
      findsOneWidget,
    );
    for (final profile in [regular, music]) {
      expect(
        find.byKey(ValueKey('summary-profile-${profile.id}')),
        findsOneWidget,
      );
    }

    world.failing.add('kid-music');
    world.failingWith = LibrusErrorCode.serverReply;
    await controller.sync();
    await tester.pumpAndSettle();
    expect(find.textContaining('Muzyczna: '), findsOneWidget);
    expect(find.textContaining('Podstawowa: '), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('demo mode opens together from the profiles too', (tester) async {
    SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
    final controller = AppController(
      FakeLibrusWorld().repository(),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    controller.startDemo();
    await _pump(tester, controller);
    await _openProfiles(tester);
    await tester.tap(find.byKey(const ValueKey('profiles-together')));
    await tester.pumpAndSettle();
    expect(controller.together, isTrue);
    expect(find.byKey(const ValueKey('profile-mark')), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
