import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

Lesson _lesson(String id, String subject, DateTime start, {DateTime? end}) =>
    Lesson(
      id: id,
      subject: subject,
      teacher: 'Teacher',
      room: '21',
      start: start,
      end: end ?? start.add(const Duration(minutes: 45)),
    );

Grade _grade(
  String id,
  String value,
  DateTime date, {
  String subject = 'Math',
}) => Grade(
  id: id,
  subject: subject,
  value: value,
  description: '',
  date: date,
  weight: 1,
  semester: _semester(),
  category: 'Test',
);

int _semester() {
  final month = DateTime.now().month;
  return month >= 2 && month <= 8 ? 2 : 1;
}

AppSnapshot _snapshot({
  List<Lesson> lessons = const [],
  List<Grade> grades = const [],
  List<SchoolEvent> events = const [],
  List<SchoolMessage> messages = const [],
}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Test',
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
  lastSync: DateTime.now(),
);

Future<AppController> _pump(
  WidgetTester tester,
  AppSnapshot snapshot, {
  int tab = 0,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(
    _Repository(snapshot),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  controller.selectTab(tab);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Finder _inCard(Finder matching) => find.descendant(
  of: find.byKey(const ValueKey('today-now-card')),
  matching: matching,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  test('the Today layout survives unknown and missing blocks', () {
    expect(
      TodayLayout.decode(TodayLayout.defaults.encode()),
      TodayLayout.defaults,
    );
    final layout = TodayLayout.decode(['-grades', 'teleport', 'events']);
    expect(layout.blocks.first, (
      block: TodayBlock.currentLesson,
      visible: true,
    ));
    // The days off, added later, come right after the lesson card.
    expect(layout.blocks[1], (block: TodayBlock.freeDays, visible: true));
    expect(layout.blocks[2], (block: TodayBlock.grades, visible: false));
    expect(layout.blocks[3].block, TodayBlock.events);
    // Blocks the saved list did not know about come back, visible.
    expect(layout.blocks, hasLength(TodayBlock.values.length));
    expect(layout.visible, isNot(contains(TodayBlock.grades)));
  });

  testWidgets('the Now card shows the lesson under way and the next one', (
    tester,
  ) async {
    final now = DateTime.now();
    // A lesson cannot cross midnight; skip near it rather than fail.
    if (now.hour == 0 || now.hour == 23) return;
    final start = now.subtract(const Duration(minutes: 10));
    await _pump(
      tester,
      _snapshot(
        lessons: [
          _lesson('current', 'Physics', start),
          _lesson('next', 'History', start.add(const Duration(minutes: 50))),
        ],
      ),
    );

    expect(_inCard(find.text('Now')), findsOneWidget);
    expect(_inCard(find.text('Physics')), findsOneWidget);
    expect(_inCard(find.text('Ends in 35 min')), findsOneWidget);
    expect(_inCard(find.textContaining('Next · ')), findsOneWidget);
    expect(_inCard(find.textContaining('History')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('after the last lesson the Now card points to the next day', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1, 8);
    await _pump(
      tester,
      _snapshot(
        lessons: [
          // Over at any time of the day, even just after midnight.
          _lesson(
            'done',
            'Physics',
            today,
            end: today.add(const Duration(seconds: 1)),
          ),
          _lesson('tomorrow', 'History', tomorrow),
        ],
      ),
    );

    expect(_inCard(find.text('Lessons are over for today')), findsOneWidget);
    expect(_inCard(find.text('History')), findsOneWidget);
    expect(_inCard(find.textContaining('Tomorrow, ')), findsOneWidget);
    expect(_inCard(find.textContaining('08:00')), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Today shows its blocks and lets the student hide them', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final controller = await _pump(
      tester,
      _snapshot(
        grades: [_grade('g1', '5', now)],
        events: [
          SchoolEvent(
            id: 'h1',
            title: 'Essay',
            subject: 'Polish',
            date: DateTime(today.year, today.month, today.day + 1),
            kind: EventKind.homework,
          ),
          SchoolEvent(
            id: 'e1',
            title: 'Algebra test',
            subject: 'Math',
            date: DateTime(today.year, today.month, today.day + 3),
            kind: EventKind.exam,
            typeLabel: 'Test',
          ),
        ],
        messages: [
          SchoolMessage(
            id: 'm1',
            sender: 'Teacher Delta',
            subject: 'Trip',
            preview: '',
            receivedAt: now,
            unread: true,
          ),
        ],
      ),
    );

    for (final key in [
      'today-recent-grades',
      'today-homework',
      'today-events',
      'today-messages',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.text('Essay'), findsOneWidget);
    expect(find.text('Algebra test'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.byKey(const ValueKey('grade-chip-g1')), findsOneWidget);

    expect(find.byKey(const ValueKey('today-customize')), findsNothing);
    controller.selectTab(9);
    await tester.pumpAndSettle();
    final todaySettings = find.byKey(const ValueKey('settings-today-screen'));
    await tester.scrollUntilVisible(todaySettings, 300);
    await tester.tap(todaySettings);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-layout-sheet')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('today-block-grades')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.todayLayout.visible, isNot(contains(TodayBlock.grades)));
    expect(
      (await AppRepository().loadTodayLayout()).visible,
      isNot(contains(TodayBlock.grades)),
    );
    Navigator.of(
      tester.element(find.byKey(const ValueKey('today-layout-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    controller.selectTab(0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-recent-grades')), findsNothing);
    expect(find.byKey(const ValueKey('today-homework')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('grades are coloured by value, mark new ones, and switch view', (
    tester,
  ) async {
    final now = DateTime.now();
    final old = now.subtract(const Duration(days: 30));
    final controller = await _pump(
      tester,
      _snapshot(
        grades: [
          _grade('fresh', '6', now),
          _grade('low', '1', old),
          _grade('history', '4', old, subject: 'History'),
        ],
      ),
      tab: 2,
    );

    Color colourOf(String id) =>
        ((tester.widget<Container>(find.byKey(ValueKey('grade-chip-$id'))))
                    .decoration!
                as BoxDecoration)
            .color!;
    expect(colourOf('fresh'), isNot(colourOf('low')));
    expect(find.byKey(const ValueKey('grade-new-fresh')), findsOneWidget);
    expect(find.byKey(const ValueKey('grade-new-low')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('grades-overview')),
        matching: find.text('3 grades · 1 new'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('grades-view-toggle')));
    await tester.pumpAndSettle();
    expect(controller.gradesView, GradesView.cards);
    expect(await AppRepository().loadGradesView(), GradesView.cards);
    // Cards start closed: the grades show once a card is opened.
    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.text('Test'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('grades-subject-Math')));
    await tester.pumpAndSettle();
    expect(find.text('Test'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the selected Messages tab keeps its unread count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = AppController(
      _Repository(
        _snapshot(
          messages: [
            SchoolMessage(
              id: 'm1',
              sender: 'Teacher Delta',
              subject: 'Trip',
              preview: '',
              receivedAt: DateTime.now(),
              unread: true,
            ),
          ],
        ),
      ),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    Finder count() => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('1'),
    );
    expect(count(), findsOneWidget);
    controller.selectTab(5);
    await tester.pumpAndSettle();
    expect(count(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('while the Today blocks fit, a drag on them closes the sheet', (
    tester,
  ) async {
    await _pump(tester, _snapshot(), tab: 9);
    final todaySettings = find.byKey(const ValueKey('settings-today-screen'));
    await tester.scrollUntilVisible(todaySettings, 200);
    await tester.tap(todaySettings);
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('today-layout-sheet'));
    expect(sheet, findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('today-block-homework')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the Today layout sheet scrolls when it does not fit', (
    tester,
  ) async {
    final controller = await _pump(tester, _snapshot(), tab: 9);
    final todaySettings = find.byKey(const ValueKey('settings-today-screen'));
    await tester.scrollUntilVisible(todaySettings, 200);
    await tester.tap(todaySettings);
    await tester.pumpAndSettle();
    // The phone is turned sideways with the sheet open.
    tester.view.physicalSize = const Size(852, 393);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final last = find.byKey(const ValueKey('today-block-messages'));
    await tester.scrollUntilVisible(
      last,
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('today-layout-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
    // Wholly in view, not just its first pixels.
    final toggle = find.descendant(of: last, matching: find.byType(Switch));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      controller.todayLayout.visible,
      isNot(contains(TodayBlock.messages)),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;

  // The real one would reach Librus; the Today look-ahead asks for weeks.
  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}
