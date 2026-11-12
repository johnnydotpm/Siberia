import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

const _lab = 'Pracownia programowania aplikacji desktopowych i mobilnych';

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}

Lesson _lesson(
  String id,
  String subject,
  DateTime start, {
  int minutes = 45,
  int? number,
}) => Lesson(
  id: id,
  subject: subject,
  teacher: 'Nauczyciel Testowy',
  room: '207',
  start: start,
  end: start.add(Duration(minutes: minutes)),
  lessonNumber: number,
);

SchoolEvent _test(String id, String label, DateTime day, int number) =>
    SchoolEvent(
      id: id,
      title: 'Rozdział 2',
      subject: '',
      date: DateTime(day.year, day.month, day.day),
      kind: EventKind.exam,
      typeLabel: label,
      lessonNumber: number,
    );

AppSnapshot _snapshot(
  List<Lesson> lessons, {
  List<SchoolEvent> events = const [],
}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Test',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: lessons,
  grades: const [],
  events: events,
  messages: const [],
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: DateTime.now(),
);

DateTime _tomorrowAt(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1, hour, minute);
}

Future<AppController> _open(WidgetTester tester, AppSnapshot snapshot) async {
  final controller = AppController(
    _Repository(snapshot),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  controller.selectTab(1);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Finder _card(String id) => find.byKey(ValueKey('timeline-lesson-$id'));

/// The opacity a lesson card is drawn at.
double _opacity(WidgetTester tester, String id) {
  final light = find.descendant(
    of: _card(id),
    matching: find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_LightOpacity',
    ),
  );
  return (tester.widget(light.first) as dynamic).opacity as double;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  for (final (scale, height) in [(1.0, 74.75), (1.5, 114.125), (3.0, 153.5)]) {
    testWidgets('a lesson grows with the system text size, at most twice: '
        '×$scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = await _open(
        tester,
        _snapshot([_lesson('a', _lab, _tomorrowAt(8), number: 1)]),
      );
      expect(tester.getSize(_card('a')).height, closeTo(height, 0.01));
      // Up to twice the size, the room and the teacher keep their line.
      if (scale <= 2) {
        expect(
          find.descendant(of: _card('a'), matching: find.textContaining('207')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('the line under the subject stands at one height on every card, '
      'short name or long, with a test or without', (tester) async {
    final day = _tomorrowAt(8);
    final controller = await _open(
      tester,
      _snapshot(
        [
          _lesson('short', 'Historia', day, number: 1),
          _lesson(
            'long',
            _lab,
            day.add(const Duration(minutes: 55)),
            number: 2,
          ),
          _lesson(
            'tested',
            'Matematyka',
            day.add(const Duration(minutes: 110)),
            number: 3,
          ),
        ],
        events: [_test('t', 'Sprawdzian', day, 3)],
      ),
    );
    double rowTop(String id) =>
        tester
            .getTopLeft(
              find.descendant(
                of: _card(id),
                matching: find.textContaining('207'),
              ),
            )
            .dy -
        tester.getTopLeft(_card(id)).dy;
    expect(rowTop('long'), closeTo(rowTop('short'), 0.01));
    expect(rowTop('tested'), closeTo(rowTop('short'), 0.01));
    expect(find.byKey(const ValueKey('timetable-test-t')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('tests on cards take the colour of their kind', (tester) async {
    final day = _tomorrowAt(8);
    final controller = await _open(
      tester,
      _snapshot(
        [
          _lesson('a', 'Historia', day, number: 1),
          _lesson(
            'b',
            'Fizyka',
            day.add(const Duration(minutes: 55)),
            number: 2,
          ),
          _lesson(
            'c',
            'Matematyka',
            day.add(const Duration(minutes: 110)),
            number: 3,
          ),
        ],
        events: [
          _test('quiz', 'Kartkówka', day, 1),
          _test('exam', 'Sprawdzian', day, 2),
          _test('other', 'Inne', day, 3),
        ],
      ),
    );
    Color colour(String id) =>
        ((tester.widget<DecoratedBox>(
                  find.byKey(ValueKey('timetable-test-$id')),
                )).decoration
                as BoxDecoration)
            .color!;
    expect({colour('quiz'), colour('exam'), colour('other')}, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('the rail puts the number above the start, and a short lesson '
      'drops it rather than overflow', (tester) async {
    final day = _tomorrowAt(8);
    final controller = await _open(
      tester,
      _snapshot([
        _lesson('full', 'Historia', day, number: 1),
        _lesson(
          'short',
          'Fizyka',
          day.add(const Duration(minutes: 55)),
          minutes: 30,
          number: 2,
        ),
      ]),
    );
    final numbers = find.byKey(const ValueKey('timeline-rail-number'));
    // Only the full lesson has room for its number.
    expect(numbers, findsOneWidget);
    expect(
      tester.getBottomLeft(numbers).dy,
      lessThan(tester.getTopLeft(find.text('08:00')).dy),
    );
    expect(find.text('08:55'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('today the lessons already over step back; the one on now and '
      'those to come do not', (tester) async {
    final now = DateTime.now();
    final first = now.subtract(const Duration(minutes: 70));
    final last = now.add(const Duration(minutes: 90));
    // A school day stays within one calendar day.
    if (!DateUtils.isSameDay(first, last)) return;
    final controller = await _open(
      tester,
      _snapshot([
        _lesson('over', 'Historia', first, number: 1),
        _lesson('now', 'Fizyka', now.subtract(const Duration(minutes: 15))),
        _lesson('next', 'Matematyka', now.add(const Duration(minutes: 40))),
      ]),
    );
    expect(_opacity(tester, 'over'), 0.55);
    expect(_opacity(tester, 'now'), 1);
    expect(_opacity(tester, 'next'), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('a day gone by is not drawn faded', (tester) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1, 8);
    final controller = AppController(
      _Repository(
        _snapshot([_lesson('old', 'Historia', yesterday, number: 1)]),
      ),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    controller.openTimetableDay(yesterday);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'old'), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
