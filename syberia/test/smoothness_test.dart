import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/sync_news.dart';
import 'package:syberia/src/state/app_controller.dart';

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

Lesson _lesson(String id, String subject, DateTime start, {int minutes = 45}) =>
    Lesson(
      id: id,
      subject: subject,
      teacher: 'Nauczyciel Testowy',
      room: '101',
      start: start,
      end: start.add(Duration(minutes: minutes)),
    );

SchoolEvent _homework(String id, String title) => SchoolEvent(
  id: id,
  title: title,
  subject: 'Matematyka',
  date: _day(_today, 1),
  kind: EventKind.homework,
);

Grade _grade(String id) => Grade(
  id: id,
  subject: 'Fizyka',
  value: '5',
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
  receivedAt: _now,
  unread: unread,
);

AppSnapshot _snapshot({
  List<Lesson> lessons = const [],
  List<Grade> grades = const [],
  List<SchoolEvent> events = const [],
  List<SchoolMessage> messages = const [],
  DateTime? lastSync,
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
  lastSync: lastSync ?? _now,
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

/// How much of [finder] shows while it unfolds or folds away: the size of
/// the row that holds it.
double _shownHeight(WidgetTester tester, Finder finder) => tester
    .getSize(
      find
          .ancestor(
            of: finder,
            matching: find.byWidgetPredicate(
              (widget) => '${widget.runtimeType}' == '_Unfold',
            ),
          )
          .first,
    )
    .height;

/// The timetable's heading for [day], with the year once it is another.
String _title(DateTime day) =>
    (day.year == DateTime.now().year
            ? DateFormat.MMMMEEEEd('en')
            : DateFormat.yMMMMEEEEd('en'))
        .format(day);

/// How far [day]'s chip in the strip is coloured as the selected one.
double _picked(WidgetTester tester, DateTime day) {
  final chip = find.byKey(
    ValueKey('timetable-day-${DateFormat('yyyy-MM-dd').format(day)}'),
  );
  return tester
      .widget<Material>(
        find.descendant(of: chip, matching: find.byType(Material)).first,
      )
      .color!
      .a;
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

  group('lists', () {
    testWidgets('done homework folds away, the group unfolds', (tester) async {
      await _pump(
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
      final card = find.byKey(const ValueKey('homework-hw1'));
      final full = _shownHeight(tester, card);
      await tester.tap(find.byKey(const ValueKey('homework-done-hw1')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 100));
      // On its way out: still there, smaller.
      expect(card, findsOneWidget);
      final folding = _shownHeight(tester, card);
      expect(folding, greaterThan(0));
      expect(folding, lessThan(full));
      await tester.pumpAndSettle();
      expect(card, findsNothing);

      await tester.tap(find.byKey(const ValueKey('homework-done-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final unfolding = _shownHeight(tester, card);
      expect(unfolding, greaterThan(0));
      expect(unfolding, lessThan(full));
      await tester.pumpAndSettle();
      expect(_shownHeight(tester, card), full);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a block of Today folds away when it has nothing left', (
      tester,
    ) async {
      final homework = _homework('hw1', 'Zadania');
      final controller = await _pump(
        tester,
        _Repository(_snapshot(events: [homework])),
      );
      final block = find.byKey(const ValueKey('today-homework'));
      final full = _shownHeight(tester, block);
      await controller.setHomeworkDone(homework, true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(block, findsOneWidget);
      expect(_shownHeight(tester, block), lessThan(full));
      await tester.pumpAndSettle();
      expect(block, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the unread dot fades once read', (tester) async {
      final controller = await _pump(
        tester,
        _Repository(_snapshot(messages: [_message('m1', unread: true)])),
        tab: 5,
      );
      final dot = find.byKey(const ValueKey('message-unread-m1'));
      expect(dot, findsOneWidget);
      await controller.markMessageRead(controller.snapshot.messages.single);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(dot, findsOneWidget);
      final fade = tester.widget(
        find
            .ancestor(
              of: dot,
              matching: find.byWidgetPredicate(
                (widget) => '${widget.runtimeType}' == '_LightOpacity',
              ),
            )
            .first,
      );
      expect((fade as dynamic).opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(dot, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('timetable', () {
    List<Lesson> week(DateTime monday) => [
      for (var day = 0; day < 5; day++)
        _lesson(
          'l$day-${monday.day}',
          'Przedmiot $day ${monday.day}',
          _day(monday, day).add(const Duration(hours: 8)),
        ),
    ];

    testWidgets('days swipe, and the week before loads when reached', (
      tester,
    ) async {
      final repository = _Repository(_snapshot(lessons: week(_monday)))
        ..week = Completer<List<Lesson>>();
      await _pump(tester, repository, tab: 1);
      expect(find.text(_title(_monday)), findsOneWidget);
      expect(find.text('Przedmiot 0 ${_monday.day}'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      final tuesday = _day(_monday, 1);
      expect(find.text(_title(tuesday)), findsOneWidget);
      expect(find.text('Przedmiot 1 ${_monday.day}'), findsOneWidget);
      expect(_picked(tester, tuesday), 1);
      expect(repository.fetched, isEmpty);

      // Back past Monday: last Friday, of a week not loaded yet.
      await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final lastMonday = _day(_monday, -7);
      final friday = _day(_monday, -3);
      expect(find.text(_title(friday)), findsOneWidget);
      expect(repository.fetched, [lastMonday]);
      // Grey lessons while it loads, not "no lessons".
      expect(find.byKey(const ValueKey('timetable-loading')), findsOneWidget);
      expect(find.text('No lessons'), findsNothing);
      // The strip shows that week now.
      expect(_picked(tester, friday), 1);

      repository.week!.complete(week(lastMonday));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timetable-loading')), findsNothing);
      expect(find.text('Przedmiot 4 ${lastMonday.day}'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a week a sync left out loads again; an empty one not', (
      tester,
    ) async {
      final repository = _Repository(_snapshot(lessons: week(_monday)));
      final controller = await _pump(tester, repository, tab: 1);
      final lastMonday = _day(_monday, -7);
      Future<void> back() async {
        await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
        await tester.pumpAndSettle();
      }

      Future<void> forward() async {
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
      }

      repository.weekLessons = week(lastMonday);
      await back();
      expect(repository.fetched, [lastMonday]);
      expect(find.text('Przedmiot 4 ${lastMonday.day}'), findsOneWidget);
      // A sync brings back only the weeks it fetches.
      repository.next = _snapshot(lessons: week(_monday));
      await controller.sync();
      await tester.pumpAndSettle();
      await forward();
      await back();
      expect(repository.fetched, [lastMonday, lastMonday]);
      expect(find.text('Przedmiot 4 ${lastMonday.day}'), findsOneWidget);

      // Two weeks back, the holidays: asked for once.
      repository.weekLessons = const [];
      for (var day = 0; day < 5; day++) {
        await back();
      }
      final holidays = _day(_monday, -14);
      expect(repository.fetched, [lastMonday, lastMonday, holidays]);
      await back();
      await forward();
      expect(repository.fetched, [lastMonday, lastMonday, holidays]);
      expect(find.text('No lessons'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the next week slides in as one band with the last', (
      tester,
    ) async {
      final next = _day(_monday, 7);
      await _pump(
        tester,
        _Repository(_snapshot(lessons: [...week(_monday), ...week(next)])),
        tab: 1,
      );
      for (var day = 0; day < 4; day++) {
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
      }
      Finder chip(DateTime day) => find.byKey(
        ValueKey('timetable-day-${DateFormat('yyyy-MM-dd').format(day)}'),
      );
      final friday = chip(_day(_monday, 4));
      final monday = chip(next);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      var frames = 0;
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (friday.evaluate().isEmpty || monday.evaluate().isEmpty) continue;
        frames++;
        // Monday comes right after Friday, as far as day from day: never
        // over it, never apart.
        final gap = tester.getRect(monday).left - tester.getRect(friday).right;
        expect(gap, closeTo(6, 0.5), reason: 'frame $frame');
      }
      expect(frames, greaterThan(5));
      await tester.pumpAndSettle();
      expect(_picked(tester, next), 1);

      // Back again: the week sliding away lets go of its day on the way,
      // so one day shows picked.
      await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
      double? leaving;
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (friday.evaluate().isEmpty || monday.evaluate().isEmpty) continue;
        leaving = _picked(tester, next);
        expect(_picked(tester, _day(_monday, 4)), greaterThan(0));
      }
      // Faded by the time it is gone.
      expect(leaving, lessThan(0.2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a day picked in the strip slides in, passing no other', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(_snapshot(lessons: week(_monday))),
        tab: 1,
      );
      final tuesday = _day(_monday, 1);
      final wednesday = _day(_monday, 2);
      await tester.tap(
        find.byKey(
          ValueKey(
            'timetable-day-${DateFormat('yyyy-MM-dd').format(wednesday)}',
          ),
        ),
      );
      var slid = false;
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        // The days on the way are never picked.
        expect(_picked(tester, tuesday), 0);
        if (find.text(_title(tuesday)).evaluate().isNotEmpty) slid = true;
      }
      // It slid past Tuesday, rather than showing Wednesday at once.
      expect(slid, isTrue);
      await tester.pumpAndSettle();
      expect(find.text(_title(wednesday)), findsOneWidget);
      expect(_picked(tester, wednesday), 1);
      expect(_picked(tester, tuesday), 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('today opens at the lesson on now', (tester) async {
      // Seven lessons before it and two after must fit in today.
      if (_now.hour < 9 || _now.hour >= 22) return;
      final current = _now.subtract(const Duration(minutes: 20));
      final lessons = [
        for (var index = 0; index < 10; index++)
          _lesson(
            'n$index',
            'Lekcja $index',
            current.add(Duration(minutes: 45 * (index - 7))),
            minutes: 40,
          ),
      ];
      await _pump(
        tester,
        _Repository(_snapshot(lessons: lessons)),
        tab: 1,
        // A phone's width. In the tests' font every letter is as wide as it
        // is tall, so the lesson's progress line must give way to fit.
        size: const Size(393, 700),
      );
      final card = find.byKey(const ValueKey('timeline-lesson-n7'));
      final scrollable = find.ancestor(
        of: card,
        matching: find.byType(Scrollable),
      );
      final view = tester.getRect(scrollable.first);
      final rect = tester.getRect(card);
      expect(rect.top, greaterThanOrEqualTo(view.top));
      expect(rect.bottom, lessThanOrEqualTo(view.bottom));
      // The first lesson scrolled away above.
      expect(
        tester.getRect(find.byKey(const ValueKey('timeline-lesson-n0'))).bottom,
        lessThan(view.top),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('loading', () {
    testWidgets('the Sent folder and a message load as grey lines', (
      tester,
    ) async {
      final repository = _Repository(_snapshot(messages: [_message('m1')]))
        ..sent = Completer<List<SchoolMessage>>()
        ..content = Completer<SchoolMessageContent>();
      await _pump(tester, repository, tab: 5);
      await tester.tap(find.text('Sent'));
      await tester.pump();
      final loading = find.byKey(const ValueKey('sent-loading'));
      expect(loading, findsOneWidget);
      expect(
        find.descendant(
          of: loading,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      repository.sent!.complete(const []);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temat m1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // What the list knows shows at once.
      final sheet = find.byKey(const ValueKey('message-loading'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Temat m1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Nauczyciel Testowy')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repository.content!.complete(
        SchoolMessageContent(
          id: 'm1',
          sender: 'Nauczyciel Testowy',
          subject: 'Temat m1',
          body: 'Pełna treść',
          receivedAt: _now,
        ),
      );
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.text('Pełna treść'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('what is new', () {
    test('counts what was not there, by kind', () {
      final before = _snapshot(
        grades: [_grade('g1')],
        events: [_homework('hw1', 'Zadania')],
        messages: [_message('m1')],
      );
      final after = _snapshot(
        grades: [_grade('g1'), _grade('g2'), _grade('g3')],
        events: [_homework('hw1', 'Zadania'), _homework('hw2', 'Nowe')],
        messages: [_message('m1'), _message('m2')],
      );
      final news = SyncNews.between(before, after);
      expect(news.grades, 2);
      expect(news.homework, 1);
      expect(news.messages, 1);
      expect(news.events, 0);
      expect(news.isEmpty, isFalse);
      expect(SyncNews.between(after, after).isEmpty, isTrue);
      // A kind only arriving is not news.
      expect(SyncNews.between(_snapshot(), after).isEmpty, isTrue);
      // Nor messages that could not be loaded before.
      final failed = AppSnapshot(
        profile: before.profile,
        lessons: const [],
        grades: before.grades,
        events: before.events,
        messages: before.messages,
        messagesError: const AppError(raw: 'offline'),
        attendance: const [],
        announcements: const [],
        notices: const [],
        lastSync: _now,
      );
      expect(SyncNews.between(failed, after).messages, 0);
    });

    testWidgets('a sync shows what it brought; a kind opens its page', (
      tester,
    ) async {
      final repository =
          _Repository(
              _snapshot(grades: [_grade('g1')], messages: [_message('m1')]),
            )
            ..next = _snapshot(
              grades: [_grade('g1'), _grade('g2')],
              messages: [_message('m1'), _message('m2', unread: true)],
            );
      final controller = await _pump(tester, repository);
      expect(find.byKey(const ValueKey('sync-news')), findsNothing);
      await controller.sync();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sync-news')), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('+1'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('sync-news-grades')));
      await tester.pumpAndSettle();
      expect(controller.tabIndex, 2);
      expect(controller.syncNews, isNull);
      expect(
        find.byKey(const ValueKey('sync-news-grades')).hitTestable(),
        findsNothing,
      );

      // Nothing new: nothing shown.
      await controller.sync();
      await tester.pumpAndSettle();
      expect(controller.syncNews, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the capsule leaves on its own, or swiped up', (tester) async {
      final repository = _Repository(_snapshot(grades: [_grade('g1')]))
        ..next = _snapshot(grades: [_grade('g1'), _grade('g2')]);
      final controller = await _pump(tester, repository);
      await controller.sync();
      await tester.pumpAndSettle();
      expect(controller.syncNews, isNotNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(controller.syncNews, isNull);

      repository.next = _snapshot(
        grades: [_grade('g1'), _grade('g2'), _grade('g3')],
      );
      await controller.sync();
      await tester.pumpAndSettle();
      expect(controller.syncNews, isNotNull);
      await tester.fling(
        find.byKey(const ValueKey('sync-news')),
        const Offset(0, -60),
        800,
      );
      await tester.pumpAndSettle();
      expect(controller.syncNews, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the first sync is no news', (tester) async {
      final repository = _Repository(
        _snapshot(
          grades: [_grade('g1')],
          lastSync: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      )..next = _snapshot(grades: [_grade('g1'), _grade('g2')]);
      final controller = await _pump(tester, repository);
      await controller.sync();
      await tester.pumpAndSettle();
      expect(controller.syncNews, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  AppSnapshot data;

  /// What the next sync brings.
  AppSnapshot? next;

  /// Holds back a week asked for, when set.
  Completer<List<Lesson>>? week;

  /// The lessons of a week asked for, when not held back.
  List<Lesson> weekLessons = const [];
  final fetched = <DateTime>[];

  Completer<List<SchoolMessage>>? sent;
  Completer<SchoolMessageContent>? content;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<AppSnapshot> sync(AppSnapshot current) async => data = next ?? current;

  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) {
    fetched.add(day);
    return week?.future ?? Future.value(weekLessons);
  }

  @override
  Future<List<SchoolMessage>> fetchSentMessages() =>
      sent?.future ?? Future.value(const []);

  @override
  Future<SchoolMessageContent> fetchMessageContent(SchoolMessage message) =>
      content?.future ??
      Future.value(
        SchoolMessageContent(
          id: message.id,
          sender: message.sender,
          subject: message.subject,
          body: 'Treść',
          receivedAt: message.receivedAt,
        ),
      );
}
