import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

/// Monday of next week: every day of it is still to come.
final _monday = DateTime(
  _today.year,
  _today.month,
  _today.day + 8 - _today.weekday,
);

DateTime _day(DateTime from, int days) =>
    DateTime(from.year, from.month, from.day + days);

Lesson _lesson(String id, String subject, DateTime start) => Lesson(
  id: id,
  subject: subject,
  teacher: 'Nauczyciel Testowy',
  room: '101',
  start: start,
  end: start.add(const Duration(minutes: 45)),
);

List<Lesson> _week(DateTime monday) => [
  for (var day = 0; day < 5; day++)
    _lesson(
      'l$day-${monday.day}',
      'Przedmiot $day',
      _day(monday, day).add(const Duration(hours: 8)),
    ),
];

SchoolEvent _homework(String id, String title) => SchoolEvent(
  id: id,
  title: title,
  subject: 'Matematyka',
  date: _day(_today, 1),
  kind: EventKind.homework,
);

Grade _grade(String id, String value) => Grade(
  id: id,
  subject: 'Fizyka',
  value: value,
  description: '',
  date: _today,
  weight: 1,
  semester: 1,
);

SchoolMessage _message(String id, {bool unread = false}) => SchoolMessage(
  id: id,
  sender: 'Nauczyciel Testowy',
  subject: 'Temat $id',
  preview: 'Treść',
  receivedAt: _now.subtract(Duration(minutes: int.parse(id.substring(1)))),
  unread: unread,
);

final _lastSync = _now.subtract(const Duration(minutes: 5));

AppSnapshot _snapshot({
  List<Lesson> lessons = const [],
  List<Grade> grades = const [],
  List<SchoolEvent> events = const [],
  List<SchoolMessage> messages = const [],
}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Demo Student',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: lessons,
  grades: grades,
  events: events,
  messages: messages,
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: _lastSync,
);

Future<AppController> _pump(
  WidgetTester tester,
  _Repository repository, {
  int tab = 0,
  Size size = const Size(400, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  controller.selectTab(tab);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

/// The timetable's heading for [day], with the year once it is another.
String _title(DateTime day) =>
    (day.year == DateTime.now().year
            ? DateFormat.MMMMEEEEd('en')
            : DateFormat.yMMMMEEEEd('en'))
        .format(day);

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// The haptic feedback asked of the system, by kind.
List<String> _haptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Before any repository is made, as it reads them when it is.
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'app_design_v1': 'classic',
      'app_locale_v1': 'en',
    }),
  );

  group('live numbers', () {
    testWidgets('a countdown rolls only the digit that changes', (
      tester,
    ) async {
      // A lesson in 18 minutes, then 17, which cannot cross midnight.
      if (_now.hour == 23 && _now.minute >= 30) return;
      DateTime inMinutes(int minutes) =>
          DateTime.now().add(Duration(minutes: minutes, seconds: -30));
      final repository = _Repository(
        _snapshot(lessons: [_lesson('l1', 'Chemia', inMinutes(18))]),
      );
      final controller = await _pump(tester, repository);
      final when = find.byKey(const ValueKey('today-now-when'));
      expect(
        find.descendant(of: when, matching: find.text('In 18 min')),
        findsOneWidget,
      );
      repository.next = _snapshot(
        lessons: [_lesson('l1', 'Chemia', inMinutes(17))],
      );
      await controller.sync();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // On its way: the words stay, the 8 leaves and the 7 comes.
      Finder part(String text) =>
          find.descendant(of: when, matching: find.text(text));
      expect(part('In 1'), findsOneWidget);
      expect(part(' min'), findsOneWidget);
      expect(part('8'), findsOneWidget);
      expect(part('7'), findsOneWidget);
      expect(
        tester.getTopLeft(part('7')).dy,
        greaterThan(tester.getTopLeft(part('In 1')).dy),
        reason: 'the new digit comes from below',
      );
      await tester.pumpAndSettle();
      expect(part('In 17 min'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the average counts its way to a new value', (tester) async {
      final repository = _Repository(_snapshot(grades: [_grade('g1', '5')]))
        ..next = _snapshot(grades: [_grade('g1', '5'), _grade('g2', '1')]);
      final controller = await _pump(tester, repository);
      String shown() => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('summary-grades')),
              matching: find.byType(Text),
            ),
          )
          .first
          .data!;
      expect(shown(), '5');
      await controller.sync();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final halfway = double.parse(shown());
      expect(halfway, inExclusiveRange(3, 5));
      await tester.pumpAndSettle();
      expect(shown(), '3');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the lesson bar glides to where the lesson is', (tester) async {
      // A lesson under way, which cannot cross midnight.
      if (_now.hour < 1 || _now.hour == 23) return;
      Lesson started(int minutesAgo) => _lesson(
        'l1',
        'Chemia',
        DateTime.now().subtract(Duration(minutes: minutesAgo)),
      );
      final repository = _Repository(_snapshot(lessons: [started(10)]))
        ..next = _snapshot(lessons: [started(30)]);
      final controller = await _pump(tester, repository);
      double bar() => tester
          .widget<LinearProgressIndicator>(
            find.descendant(
              of: find.byKey(const ValueKey('today-now-progress')),
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .value!;
      final before = bar();
      expect(before, closeTo(10 / 45, 0.02));
      await controller.sync();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(bar(), inExclusiveRange(before + 0.01, 30 / 45 - 0.01));
      await tester.pumpAndSettle();
      expect(bar(), closeTo(30 / 45, 0.02));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('today and back to the top', () {
    testWidgets('away from today, "Today" takes the timetable back', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(_snapshot(lessons: _week(_monday))),
        tab: 1,
      );
      final today = find.byKey(const ValueKey('timetable-today'));
      expect(find.text(_title(_monday)), findsOneWidget);
      expect(today, findsNothing);
      for (var day = 0; day < 2; day++) {
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
      }
      expect(find.text(_title(_day(_monday, 2))), findsOneWidget);
      final haptics = _haptics(tester);
      await tester.tap(today);
      await tester.pumpAndSettle();
      expect(find.text(_title(_monday)), findsOneWidget);
      expect(today, findsNothing);
      expect(haptics, ['HapticFeedbackType.selectionClick']);

      // The tab tapped again does the same.
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text(_title(_day(_monday, 1))), findsOneWidget);
      await tester.tap(_tab('Timetable'));
      await tester.pumpAndSettle();
      expect(find.text(_title(_monday)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the open tab tapped again goes back to the top', (
      tester,
    ) async {
      final controller = await _pump(
        tester,
        _Repository(
          _snapshot(messages: [for (var i = 1; i <= 40; i++) _message('m$i')]),
        ),
        tab: 5,
        size: const Size(400, 800),
      );
      ScrollPosition position() => tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .map((state) => state.position)
          .firstWhere(
            (position) =>
                position.axis == Axis.vertical && position.maxScrollExtent > 0,
          );
      await tester.fling(find.text('Temat m3'), const Offset(0, -600), 2000);
      await tester.pumpAndSettle();
      expect(position().pixels, greaterThan(300));
      await tester.tap(_tab('Messages'));
      await tester.pumpAndSettle();
      expect(position().pixels, 0);
      expect(controller.tabIndex, 5);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('gestures', () {
    testWidgets('a swipe marks homework done, and back', (tester) async {
      final controller = await _pump(
        tester,
        _Repository(
          _snapshot(
            events: [
              _homework('hw1', 'Zadania'),
              _homework('hw2', 'Wypracowanie'),
            ],
          ),
        ),
        tab: 4,
      );
      final work = controller.snapshot.events.first;
      await tester.drag(
        find.byKey(const ValueKey('homework-hw1')),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();
      expect(controller.isHomeworkDone(work), isTrue);
      expect(find.byKey(const ValueKey('homework-hw1')), findsNothing);
      expect(find.text('Marked as done'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('homework-done-toggle')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('homework-hw1')),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();
      expect(controller.isHomeworkDone(work), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a long press offers what can be done', (tester) async {
      final repository = _Repository(
        _snapshot(
          events: [_homework('hw1', 'Zadania')],
          messages: [_message('m1', unread: true)],
        ),
      );
      final controller = await _pump(tester, repository, tab: 4);
      final haptics = _haptics(tester);
      await tester.longPress(find.byKey(const ValueKey('homework-hw1')));
      await tester.pumpAndSettle();
      expect(haptics, contains('HapticFeedbackType.mediumImpact'));
      expect(
        find.byKey(const ValueKey('homework-action-open-hw1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('homework-action-done-hw1')));
      await tester.pumpAndSettle();
      expect(
        controller.isHomeworkDone(controller.snapshot.events.single),
        true,
      );

      controller.selectTab(5);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Temat m1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-read-m1')));
      await tester.pumpAndSettle();
      expect(repository.opened, ['m1']);
      expect(controller.snapshot.messages.single.unread, isFalse);
      // Read, it has nothing more than opening it.
      await tester.longPress(find.text('Temat m1'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('message-action-read-m1')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('message-action-open-m1')));
      await tester.pumpAndSettle();
      expect(find.text('Treść pełna'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('moving the list puts the search keyboard away', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(
          _snapshot(
            events: [
              for (var i = 0; i < 20; i++) _homework('hw$i', 'Zadania $i'),
            ],
          ),
        ),
        tab: 4,
        size: const Size(400, 800),
      );
      await tester.tap(find.byKey(const ValueKey('homework-search')));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.drag(find.text('Zadania 3'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('calm errors', () {
    for (final (code, line) in [
      (LibrusErrorCode.networkUnavailable, 'No internet'),
      (LibrusErrorCode.networkTimeout, 'Librus is not responding'),
    ]) {
      testWidgets('${code.name} is a quiet line, not a red card', (
        tester,
      ) async {
        final repository = _Repository(_snapshot())
          ..failure = LibrusException(code);
        final controller = await _pump(tester, repository);
        await controller.sync();
        await tester.pumpAndSettle();
        final time = DateFormat('HH:mm').format(_lastSync);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('today-last-sync')),
            matching: find.text('$line · data from $time'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('today-error')), findsNothing);
        // A tap tries again; once it works, the line says so.
        repository.failure = null;
        await tester.tap(find.byKey(const ValueKey('today-last-sync')));
        await tester.pumpAndSettle();
        expect(find.textContaining('data from'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('anything else still shows the error', (tester) async {
      final repository = _Repository(_snapshot())
        ..failure = const LibrusException(LibrusErrorCode.invalidCredentials);
      final controller = await _pump(tester, repository);
      await controller.sync();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-error')), findsOneWidget);
      expect(find.textContaining('data from'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a day of the timetable pulls to refresh', (tester) async {
      final repository = _Repository(_snapshot(lessons: _week(_monday)));
      await _pump(tester, repository, tab: 1);
      await tester.fling(find.text('Przedmiot 0'), const Offset(0, 400), 1500);
      await tester.pumpAndSettle();
      expect(repository.syncs, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final design in ['classic', 'glass']) {
      testWidgets('in $design, the pull shows at the top, over the strip', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'app_design_v1': design,
          'app_locale_v1': 'en',
        });
        if (design == 'glass') {
          GlassPlatform.debugSetBackend(GlassBackend.rendered);
          addTearDown(() => GlassPlatform.debugSetBackend(GlassBackend.none));
        }
        final repository = _Repository(_snapshot(lessons: _week(_monday)));
        await _pump(tester, repository, tab: 1);
        final pull = await tester.startGesture(
          tester.getCenter(find.text('Przedmiot 0')),
        );
        for (var step = 0; step < 8; step++) {
          await pull.moveBy(const Offset(0, 25));
          await tester.pump(const Duration(milliseconds: 16));
        }
        final spinner = find.byWidgetPredicate(
          (widget) =>
              widget is RefreshProgressIndicator ||
              widget is CupertinoActivityIndicator,
        );
        expect(spinner, findsOneWidget);
        // Up where it is on every page: above the end of the week strip,
        // not down by the lessons.
        final strip = tester.getRect(
          find.byKey(
            ValueKey(
              'timetable-day-${DateFormat('yyyy-MM-dd').format(_monday)}',
            ),
          ),
        );
        expect(tester.getCenter(spinner).dy, lessThan(strip.bottom));
        // Further, far enough to set it off.
        for (var step = 0; step < 20; step++) {
          await pull.moveBy(const Offset(0, 40));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await pull.up();
        await tester.pumpAndSettle();
        expect(repository.syncs, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('smoothness', () {
    testWidgets('passing the middle of a swipe draws no day again', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(_snapshot(lessons: _week(_monday))),
        tab: 1,
      );
      var drawn = 0;
      debugOnRebuildDirtyWidget = (element, _) {
        if ('${element.widget.runtimeType}' == '_TimetableTimeline') drawn++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      final swipe = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      for (var step = 0; step < 15; step++) {
        await swipe.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Past the middle: Tuesday is picked, and nothing on screen redrawn.
      // At most the day after it, coming into reach, is drawn ahead.
      expect(find.text(_title(_day(_monday, 1))), findsOneWidget);
      expect(drawn, lessThanOrEqualTo(1));
      await swipe.up();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('less motion', () {
    testWidgets('with animations off, changes show at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final next = _day(_monday, 7);
      final repository = _Repository(
        _snapshot(
          lessons: [..._week(_monday), ..._week(next)],
          grades: [_grade('g1', '5')],
          events: [_homework('hw1', 'Zadania'), _homework('hw2', 'Inne')],
        ),
      );
      final controller = await _pump(tester, repository, tab: 4);

      // Done homework goes at once.
      await tester.tap(find.byKey(const ValueKey('homework-done-hw1')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(find.byKey(const ValueKey('homework-hw1')), findsNothing);

      // A new week takes the strip's place at once.
      controller.selectTab(1);
      await tester.pumpAndSettle();
      for (var day = 0; day < 4; day++) {
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
      }
      Finder chip(DateTime day) => find.byKey(
        ValueKey('timetable-day-${DateFormat('yyyy-MM-dd').format(day)}'),
      );
      // By hand, in fine steps: Flutter itself runs animations 20 times
      // faster with them off, which whole frames would not catch.
      bool both() =>
          chip(_day(_monday, 4)).evaluate().isNotEmpty &&
          chip(next).evaluate().isNotEmpty;
      final swipe = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      for (var step = 0; step < 20; step++) {
        await swipe.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 1));
        expect(both(), isFalse, reason: 'step $step');
      }
      await swipe.up();
      for (var step = 0; step < 60; step++) {
        await tester.pump(const Duration(milliseconds: 1));
        expect(both(), isFalse, reason: 'after $step');
      }
      await tester.pumpAndSettle();

      // The news is there at once, and the average shows its new value.
      controller.selectTab(0);
      await tester.pumpAndSettle();
      repository.next = _snapshot(
        lessons: [..._week(_monday), ..._week(next)],
        grades: [_grade('g1', '5'), _grade('g2', '1')],
        events: [_homework('hw1', 'Zadania'), _homework('hw2', 'Inne')],
      );
      await controller.sync();
      await tester.pump();
      await tester.pump();
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('sync-news')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('summary-grades')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('a whole visit to the demo school goes without a fault', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = AppController(AppRepository(), updatesEnabled: false);
    addTearDown(controller.dispose);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    controller.startDemo();
    await tester.pumpAndSettle();
    expect(controller.isDemo, isTrue);
    expect(find.byKey(const ValueKey('today-now-card')), findsOneWidget);

    // A sync of the same data: nothing new, nothing wrong.
    await controller.sync();
    await tester.pumpAndSettle();
    expect(controller.syncNews, isNull);
    expect(controller.error, isNull);

    // The timetable: days and weeks swiped, back to today.
    await tester.tap(_tab('Timetable'));
    await tester.pumpAndSettle();
    for (var day = 0; day < 6; day++) {
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
    }
    for (var day = 0; day < 3; day++) {
      await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('timetable-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('timetable-today')), findsNothing);

    // Homework: swiped done, taken back, ticked, the done ones shown.
    controller.selectTab(4);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('homework-demo-event-0')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('homework-demo-event-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('homework-done-demo-event-2')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('homework-done-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('homework-demo-event-2')), findsOneWidget);

    // Messages: one marked read from its menu, one opened, Sent, a new one.
    await tester.tap(_tab('Messages'));
    await tester.pumpAndSettle();
    final unread = controller.snapshot.unreadMessages;
    await tester.longPress(
      find.byKey(const ValueKey('message-unread-demo-inbox-0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('message-action-read-demo-inbox-0')),
    );
    await tester.pumpAndSettle();
    expect(controller.snapshot.unreadMessages, unread - 1);
    await tester.tap(find.text('Project feedback').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sent-loading')), findsNothing);
    await tester.tap(find.text('New message'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recipients-loading')), findsNothing);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Every other page opens.
    for (final tab in [2, 3, 6, 7, 8, 9]) {
      controller.selectTab(tab);
      await tester.pumpAndSettle();
    }
    await tester.tap(_tab('Today'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-now-card')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Out of the demo, back at the login.
    await controller.logout();
    await tester.pumpAndSettle();
    expect(controller.isDemo, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  AppSnapshot data;

  /// What the next sync brings.
  AppSnapshot? next;

  /// What the next sync throws.
  Object? failure;
  var syncs = 0;
  final opened = <String>[];

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<AppSnapshot> sync(AppSnapshot current) async {
    syncs++;
    if (failure case final error?) throw error;
    return data = next ?? current;
  }

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];

  @override
  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage message, {
    String? profileId,
  }) async {
    opened.add(message.id);
    return SchoolMessageContent(
      id: message.id,
      sender: message.sender,
      subject: message.subject,
      body: 'Treść pełna',
      receivedAt: message.receivedAt,
    );
  }
}
