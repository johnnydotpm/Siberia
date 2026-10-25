import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/subject_colors.dart';

Lesson _lesson(
  String id,
  String subject,
  DateTime start, {
  String room = '1',
  String teacher = 'Teacher',
  int? number,
}) => Lesson(
  id: id,
  subject: subject,
  teacher: teacher,
  room: room,
  start: start,
  end: start.add(const Duration(minutes: 45)),
  lessonNumber: number,
);

AppSnapshot _snapshot({
  List<Lesson> lessons = const [],
  List<SchoolMessage> messages = const [],
}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Test',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: lessons,
  grades: const [],
  events: const [],
  messages: messages,
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: DateTime.now(),
);

/// Tomorrow on the calendar: 24 hours on is still today once a year, in the
/// night the clocks go back.
DateTime _tomorrow() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  test('subject colours are stable and differ within a day', () {
    final subjects = [for (var i = 0; i < 12; i++) 'Subject $i'];
    final colors = SubjectColors.assign(subjects);
    expect(SubjectColors.assign(subjects.reversed), colors);
    final day = colors.forDay(subjects.take(8));
    expect(day.values.toSet(), hasLength(8));
    // More subjects than hues still keeps a day apart.
    final many = SubjectColors.assign([for (var i = 0; i < 30; i++) 'S$i']);
    final busyDay = many.forDay([for (var i = 0; i < 9; i++) 'S$i']);
    expect(busyDay.values.toSet(), hasLength(9));
    final light = SubjectColors.colors(3, Brightness.light);
    final dark = SubjectColors.colors(3, Brightness.dark);
    expect(light.background, isNot(dark.background));
  });

  test('lesson numbers survive the cache, and old caches still load', () {
    final start = DateTime(2026, 10, 16, 8);
    final snapshot = _snapshot(
      lessons: [_lesson('a', 'Math', start, number: 3)],
    );
    final decoded = SnapshotCache.decode(SnapshotCache.encode(snapshot))!;
    expect(decoded.lessons.single.lessonNumber, 3);

    final old = jsonDecode(SnapshotCache.encode(snapshot)) as Map;
    ((old['lessons'] as List).single as Map).remove('number');
    expect(
      SnapshotCache.decode(jsonEncode(old))!.lessons.single.lessonNumber,
      isNull,
    );
  });

  testWidgets('a double lesson is one block in both timetable views', (
    tester,
  ) async {
    final day = _tomorrow();
    final start = DateTime(day.year, day.month, day.day, 8);
    final controller = AppController(
      _Repository(
        _snapshot(
          lessons: [
            _lesson('a1', 'Programming', start, number: 1),
            _lesson(
              'a2',
              'Programming',
              start.add(const Duration(minutes: 50)),
              number: 2,
            ),
            _lesson(
              'b1',
              'Programming',
              start.add(const Duration(minutes: 100)),
              room: '2',
              number: 3,
            ),
          ],
        ),
      ),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await controller.setMergeTimetableLessons(true);
    controller.selectTab(1);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timeline-lesson-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-lesson-a2')), findsNothing);
    // A different room is a different lesson.
    expect(find.byKey(const ValueKey('timeline-lesson-b1')), findsOneWidget);
    expect(find.textContaining('2 lessons'), findsOneWidget);
    expect(find.text('1–2'), findsOneWidget);

    await controller.setTimetableView(TimetableView.list);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('timetable-row-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('timetable-row-a2')), findsNothing);
    expect(await AppRepository().loadTimetableView(), TimetableView.list);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tests of the day sit on the lessons they are written in', (
    tester,
  ) async {
    final day = _tomorrow();
    final start = DateTime(day.year, day.month, day.day, 8);
    SchoolEvent event(
      String id,
      String subject, {
      int? lessonNumber,
      String typeLabel = 'Kartkówka',
    }) => SchoolEvent(
      id: id,
      title: 'Rozdział 3',
      subject: subject,
      date: DateTime(day.year, day.month, day.day),
      kind: EventKind.exam,
      typeLabel: typeLabel,
      lessonNumber: lessonNumber,
    );
    final controller = AppController(
      _Repository(
        AppSnapshot(
          profile: const StudentProfile(
            id: 'test',
            name: 'Test',
            school: 'School',
            provider: 'Librus Synergia',
          ),
          lessons: [
            _lesson('m1', 'Math', start, number: 1),
            _lesson(
              'p2',
              'Physics',
              start.add(const Duration(minutes: 55)),
              number: 2,
            ),
            _lesson(
              'm3',
              'Math',
              start.add(const Duration(minutes: 110)),
              number: 3,
            ),
          ],
          grades: const [],
          events: [
            // The second Math lesson, by its number.
            event('e1', 'Math', lessonNumber: 3),
            // No number: the first lesson of the subject.
            event('e2', 'physics'),
            // Not a lesson at all.
            event('e3', 'Librus', typeLabel: 'Wycieczka'),
          ],
          messages: const [],
          attendance: const [],
          announcements: const [],
          notices: const [],
          lastSync: DateTime.now(),
        ),
      ),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    controller.selectTab(1);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    Finder on(String lesson, String test) => find.descendant(
      of: find.byKey(ValueKey(lesson)),
      matching: find.byKey(ValueKey('timetable-test-$test')),
    );
    expect(on('timeline-lesson-m3', 'e1'), findsOneWidget);
    expect(on('timeline-lesson-m1', 'e1'), findsNothing);
    expect(on('timeline-lesson-p2', 'e2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timetable-day-event-e3')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('timeline-lesson-m3')));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('lesson-test-e1'));
    expect(
      find.descendant(of: sheet, matching: find.text('Kartkówka')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Rozdział 3')),
      findsOneWidget,
    );
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    await controller.setTimetableView(TimetableView.list);
    await tester.pumpAndSettle();
    expect(on('timetable-row-m3', 'e1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the lesson sheet scrolls through long test descriptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final day = _tomorrow();
    final start = DateTime(day.year, day.month, day.day, 8);
    final long = List.filled(30, 'Rozdział 3, zadania z funkcji.').join(' ');
    SchoolEvent test(String id) => SchoolEvent(
      id: id,
      title: long,
      subject: 'Math',
      date: DateTime(day.year, day.month, day.day),
      kind: EventKind.exam,
      typeLabel: 'Sprawdzian',
      lessonNumber: 1,
    );
    final controller = AppController(
      _Repository(
        _snapshot(lessons: [_lesson('m1', 'Math', start, number: 1)])
            .copyWith(events: [test('t1'), test('t2')]),
      ),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    controller.selectTab(1);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('timeline-lesson-m1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final sheet = find.byKey(const ValueKey('lesson-details-sheet'));
    expect(tester.getSize(sheet).width, 360);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-test-t2')),
      200,
      // The sheet's own; each SelectableText has one too.
      scrollable: find
          .descendant(of: sheet, matching: find.byType(Scrollable))
          .first,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the lesson of a test survives the cache', () {
    final snapshot = _snapshot().copyWith(
      events: [
        SchoolEvent(
          id: 'e',
          title: 'Test',
          subject: 'Math',
          date: DateTime(2026, 10, 20),
          kind: EventKind.exam,
          lessonNumber: 4,
        ),
      ],
    );
    final decoded = SnapshotCache.decode(SnapshotCache.encode(snapshot))!;
    expect(decoded.events.single.lessonNumber, 4);
  });

  testWidgets('messages can be searched, filtered, grouped and swiped read', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = _Repository(
      _snapshot(
        messages: [
          SchoolMessage(
            id: 'm1',
            sender: 'Teacher Alpha',
            subject: 'Trip to Italy',
            preview: '',
            receivedAt: now,
            unread: true,
          ),
          SchoolMessage(
            id: 'm2',
            sender: 'Teacher Beta',
            subject: 'Chess contest',
            preview: 'Sign up by Friday',
            // Yesterday on the calendar: 24 hours back is two days back
            // in the night after the clocks go forward.
            receivedAt: DateTime(
              now.year,
              now.month,
              now.day - 1,
              now.hour,
              now.minute,
            ),
            unread: true,
          ),
          SchoolMessage(
            id: 'm3',
            sender: 'Teacher Gamma',
            subject: 'Civic education',
            preview: '',
            receivedAt: now.subtract(const Duration(days: 40)),
          ),
        ],
      ),
    );
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    controller.selectTab(5);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('messages-section-Today')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('messages-section-Yesterday')),
      findsOneWidget,
    );
    expect(find.text('Sign up by Friday'), findsOneWidget);
    expect(find.text('TA'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('messages-search')),
      'chess',
    );
    await tester.pumpAndSettle();
    expect(find.text('Chess contest'), findsOneWidget);
    expect(find.text('Trip to Italy'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('messages-search')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unread (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Civic education'), findsNothing);
    expect(find.text('Trip to Italy'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('message-m1')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();
    expect(repository.opened, ['m1']);
    expect(controller.snapshot.messages.first.unread, isFalse);
    expect(find.text('Unread (1)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('messages-style-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsWidgets);
    expect(
      await AppRepository().loadMessageListStyle(),
      MessageListStyle.cards,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;
  final opened = <String>[];

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage message,
  ) async {
    opened.add(message.id);
    return SchoolMessageContent(
      id: message.id,
      sender: message.sender,
      subject: message.subject,
      body: 'Body',
      receivedAt: message.receivedAt,
    );
  }

  // The real one would reach Librus; the Today look-ahead asks for weeks.
  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}
