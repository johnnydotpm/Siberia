import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

/// One profile of the family login, synced just now, with what [change]
/// makes of its data; the app on it, in English.
Future<(AppController, FakeLibrusWorld)> _app({
  AppSnapshot Function(AppSnapshot data)? change,
}) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  if (change != null) world.changes['kid-regular'] = change;
  final repository = world.repository();
  final found = await repository.signIn(username: familyEmail, password: 'x');
  final added = await repository.addProfiles([found.students.first]);
  await repository.syncProfile(added.single.id);
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  return (controller, world);
}

Future<void> _pump(WidgetTester tester, AppController controller) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
}

SchoolMessage _message(String id, String subject, {bool unread = false}) =>
    SchoolMessage(
      id: id,
      sender: 'Nauczyciel Testowy',
      subject: subject,
      preview: 'Treść',
      receivedAt: DateTime.now().subtract(Duration(hours: id.hashCode % 5)),
      unread: unread,
    );

Lesson _lesson(String id, DateTime start) => Lesson(
  id: id,
  subject: 'Matematyka',
  teacher: 'Nauczyciel Testowy',
  room: '1',
  start: start,
  end: start.add(const Duration(minutes: 45)),
);

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

/// The day the timetable shows: its page on screen.
Finder _dayShown(DateTime day) => find
    .descendant(of: find.byType(PageView), matching: find.byKey(ValueKey(day)))
    .hitTestable();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Polish letters in a search', () {
    testWidgets('messages are found by words typed without them', (
      tester,
    ) async {
      final (controller, _) = await _app(
        change: (data) => data.copyWith(
          messages: [
            _message('m1', 'Wycieczka do Łodzi'),
            _message('m2', 'Zebranie z rodzicami'),
          ],
        ),
      );
      controller.selectTab(5);
      await _pump(tester, controller);
      final search = find.byKey(const ValueKey('messages-search'));
      for (final typed in ['lodz', 'ŁÓDŹ', 'Łodz']) {
        await tester.enterText(search, typed);
        await tester.pumpAndSettle();
        expect(find.text('Wycieczka do Łodzi'), findsOneWidget, reason: typed);
        expect(find.text('Zebranie z rodzicami'), findsNothing, reason: typed);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('homework is found by words typed without them', (
      tester,
    ) async {
      final soon = _dayOf(DateTime.now()).add(const Duration(days: 2));
      final (controller, _) = await _app(
        change: (data) => data.copyWith(
          events: [
            SchoolEvent(
              id: 'hw1',
              title: 'Ćwiczenia ze strony 12',
              subject: 'Matematyka',
              date: soon,
              kind: EventKind.homework,
            ),
            SchoolEvent(
              id: 'hw2',
              title: 'Wypracowanie',
              subject: 'Język polski',
              date: soon,
              kind: EventKind.homework,
            ),
          ],
        ),
      );
      controller.selectTab(4);
      await _pump(tester, controller);
      await tester.enterText(
        find.byKey(const ValueKey('homework-search')),
        'cwiczenia',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('wiczenia ze strony'), findsOneWidget);
      expect(find.textContaining('Wypracowanie'), findsNothing);

      // A subject is found the same way.
      await tester.enterText(
        find.byKey(const ValueKey('homework-search')),
        'jezyk',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Wypracowanie'), findsOneWidget);
      expect(find.textContaining('wiczenia ze strony'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a recipient is found by a name typed without them', (
      tester,
    ) async {
      final (controller, world) = await _app();
      world.recipients = const [
        MessageRecipient(id: 2, name: 'Łucja Testowa', group: 'Nauczyciele'),
        MessageRecipient(id: 3, name: 'Sekretariat', group: 'Administracja'),
      ];
      controller.selectTab(5);
      await _pump(tester, controller);
      await tester.tap(find.text('New message').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Recipient'),
        'lucja',
      );
      await tester.pumpAndSettle();
      expect(find.text('Łucja Testowa'), findsOneWidget);
      expect(find.text('Sekretariat'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('under "Unread", a message read stays, as read, until the '
      'filter, the folder or the tab changes', (tester) async {
    final (controller, _) = await _app(
      change: (data) => data.copyWith(
        messages: [
          _message('m1', 'Wycieczka', unread: true),
          _message('m2', 'Zebranie', unread: true),
          _message('m3', 'Plan lekcji'),
        ],
      ),
    );
    controller.selectTab(5);
    await _pump(tester, controller);
    final filter = find.byKey(const ValueKey('messages-filter'));
    Future<void> turnFilter() async {
      await tester.tap(filter);
      await tester.pumpAndSettle();
    }

    await turnFilter();
    expect(find.text('Plan lekcji'), findsNothing);

    // Opened, and swiped read: both stay where they were.
    await tester.tap(find.text('Wycieczka'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('message-m2')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.snapshot.unreadMessages, 0);
    expect(find.text('Wycieczka'), findsOneWidget);
    expect(find.text('Zebranie'), findsOneWidget);
    expect(find.text('Plan lekcji'), findsNothing);

    // The filter turned off and on again: they go.
    await turnFilter();
    await turnFilter();
    expect(find.text('Wycieczka'), findsNothing);
    expect(find.text('Zebranie'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a message read under "Unread" goes once the tab changes', (
    tester,
  ) async {
    final (controller, _) = await _app(
      change: (data) => data.copyWith(
        messages: [
          _message('m1', 'Wycieczka', unread: true),
          _message('m2', 'Zebranie', unread: true),
        ],
      ),
    );
    controller.selectTab(5);
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('messages-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wycieczka'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Wycieczka'), findsOneWidget);

    controller.selectTab(0);
    await tester.pumpAndSettle();
    controller.selectTab(5);
    await tester.pumpAndSettle();
    expect(find.text('Wycieczka'), findsNothing);
    expect(find.text('Zebranie'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the lesson on Today opens the timetable at its day, wherever '
      'the timetable was left', (tester) async {
    final now = DateTime.now();
    final today = _dayOf(now);
    // Another day of this week, with a lesson to pick it by.
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final other = today == monday
        ? monday.add(const Duration(days: 1))
        : monday;
    final (controller, _) = await _app(
      change: (data) => data.copyWith(
        lessons: [
          _lesson('now', now.subtract(const Duration(minutes: 1))),
          _lesson('other', other.add(const Duration(hours: 10))),
        ],
      ),
    );
    controller.selectTab(1);
    await _pump(tester, controller);
    expect(_dayShown(today), findsOneWidget);
    await tester.tap(
      find.byKey(
        ValueKey(
          'timetable-day-${other.year}-'
          '${'${other.month}'.padLeft(2, '0')}-'
          '${'${other.day}'.padLeft(2, '0')}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_dayShown(other), findsOneWidget);

    // Left and opened again, it stays where it was.
    controller.selectTab(0);
    await tester.pumpAndSettle();
    controller.selectTab(1);
    await tester.pumpAndSettle();
    expect(_dayShown(other), findsOneWidget);

    controller.selectTab(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('today-now-card')));
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 1);
    expect(_dayShown(today), findsOneWidget);
    expect(_dayShown(other), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a week that came back empty is asked for again after a sync', (
    tester,
  ) async {
    final today = _dayOf(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final (controller, world) = await _app(
      change: (data) => data.copyWith(
        lessons: [_lesson('mon', monday.add(const Duration(hours: 10)))],
      ),
    );
    controller.selectTab(1);
    await _pump(tester, controller);
    await tester.tap(
      find.byKey(
        ValueKey(
          'timetable-day-${monday.year}-'
          '${'${monday.month}'.padLeft(2, '0')}-'
          '${'${monday.day}'.padLeft(2, '0')}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_dayShown(monday), findsOneWidget);
    world.weeks.clear();

    // Back past Monday: last week, with no lessons, is asked for once.
    Future<void> swipe(double dx) async {
      await tester.fling(find.byType(PageView), Offset(dx, 0), 1000);
      await tester.pumpAndSettle();
    }

    await swipe(300);
    expect(world.weeks, ['kid-regular']);
    await swipe(-300);
    await swipe(300);
    expect(world.weeks, ['kid-regular'], reason: 'known to be empty');

    await swipe(-300);
    await controller.sync();
    await tester.pumpAndSettle();
    await swipe(300);
    expect(world.weeks, ['kid-regular', 'kid-regular']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
