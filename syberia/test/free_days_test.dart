import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

final _now = DateTime.now();
DateTime _day(int offset) => DateTime(_now.year, _now.month, _now.day + offset);

FreeDay _holiday(int from, int to, {String name = 'Ferie zimowe'}) => FreeDay(
  id: 'school-1',
  kind: FreeDayKind.school,
  name: name,
  from: _day(from),
  to: _day(to),
);

AppSnapshot _snapshot({
  List<FreeDay> freeDays = const [],
  List<Lesson> lessons = const [],
}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Demo Student',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: lessons,
  grades: const [],
  events: const [],
  messages: const [],
  attendance: const [],
  announcements: const [],
  notices: const [],
  freeDays: freeDays,
  lastSync: _now,
);

Future<AppController> _pump(
  WidgetTester tester,
  AppSnapshot data, {
  int tab = 0,
  String locale = 'en',
}) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': locale,
  });
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(_Repository(data), updatesEnabled: false);
  await controller.bootstrap();
  controller.selectTab(tab);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

String _countdown(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('free-days-countdown')))
    .data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today counts the days to the next holiday', (tester) async {
    await _pump(
      tester,
      _snapshot(
        freeDays: [
          _holiday(12, 20),
          // A later one, and a teacher's absence, are not it.
          _holiday(60, 70, name: 'Ferie letnie'),
          FreeDay(
            id: 'teacher-1',
            kind: FreeDayKind.teacher,
            name: '',
            from: _day(1),
            to: _day(1),
            teacher: 'Nauczyciel Testowy',
          ),
        ],
      ),
    );
    final card = find.byKey(const ValueKey('today-free-days'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Ferie zimowe')),
      findsOneWidget,
    );
    expect(find.text('Ferie letnie'), findsNothing);
    expect(_countdown(tester), 'In 12 days');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('during a holiday it counts the days left', (tester) async {
    for (final (from, to, expected) in [
      (-2, 2, '3 days left'),
      (-2, 0, 'Last day'),
      (1, 5, 'Tomorrow'),
    ]) {
      await _pump(tester, _snapshot(freeDays: [_holiday(from, to)]));
      expect(_countdown(tester), expected, reason: '$from–$to');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    // Over, or none: no card.
    await _pump(tester, _snapshot(freeDays: [_holiday(-9, -1)]));
    expect(find.byKey(const ValueKey('today-free-days')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('days are counted in each language own forms', (tester) async {
    for (final (locale, days, expected) in [
      ('ru', 21, 'Через 21 день'),
      ('ru', 22, 'Через 22 дня'),
      ('ru', 25, 'Через 25 дней'),
      ('ru', 11, 'Через 11 дней'),
      ('uk', 3, 'Через 3 дні'),
      ('pl', 2, 'Za 2 dni'),
      ('pl', 5, 'Za 5 dni'),
      ('de', 5, 'Noch 5 Tage'),
      ('en', 2, 'In 2 days'),
    ]) {
      await _pump(
        tester,
        _snapshot(freeDays: [_holiday(days, days + 3)]),
        locale: locale,
      );
      expect(_countdown(tester), expected);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a holiday in the timetable says so, not "No data"', (
    tester,
  ) async {
    await _pump(tester, _snapshot(freeDays: [_holiday(-1, 3)]), tab: 1);
    expect(find.byKey(const ValueKey('free-day-school-1')), findsOneWidget);
    expect(find.text('No data'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an absent teacher is said to be, in the card and the sheet', (
    tester,
  ) async {
    final start = DateTime(_now.year, _now.month, _now.day, 8);
    Lesson lesson(String id, String teacher, int hour) => Lesson(
      id: id,
      subject: 'Fizyka',
      teacher: teacher,
      room: '12',
      start: start.add(Duration(hours: hour)),
      end: start.add(Duration(hours: hour, minutes: 45)),
    );
    await _pump(
      tester,
      _snapshot(
        lessons: [
          lesson('absent', 'Nauczyciel Testowy', 0),
          // After the absence ends at 9:00.
          lesson('back', 'Nauczyciel Testowy', 2),
          lesson('other', 'Inny Nauczyciel', 1),
        ],
        freeDays: [
          FreeDay(
            id: 'teacher-1',
            kind: FreeDayKind.teacher,
            name: 'szkolenie',
            from: _day(0),
            to: _day(0),
            teacher: 'Nauczyciel Testowy',
            timeTo: 9 * 60,
          ),
        ],
      ),
      tab: 1,
    );
    Finder text(String id, String value) => find.descendant(
      of: find.byKey(ValueKey('timeline-lesson-$id')),
      matching: find.textContaining(value),
    );
    expect(text('absent', 'Nauczyciel Testowy – absent'), findsOneWidget);
    expect(text('back', 'absent'), findsNothing);
    expect(text('other', 'absent'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('timeline-lesson-absent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-teacher-absent')), findsOneWidget);
    expect(find.text('Teacher absent'), findsOneWidget);
    expect(find.text('Szkolenie'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => data.lessons;
}
