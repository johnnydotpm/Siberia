import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/home_widget.dart';
import 'package:syberia/src/state/app_controller.dart';

int _semester() {
  final month = DateTime.now().month;
  return month >= 2 && month <= 8 ? 2 : 1;
}

AppSnapshot _snapshot({List<SchoolEvent> events = const []}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Calendar days: the day the clocks change is not 24 hours long.
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  Lesson lesson(String id, String subject, int hour, int minute) => Lesson(
    id: id,
    subject: subject,
    teacher: 'Nauczyciel Testowy',
    room: '101',
    start: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute),
    end: DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      hour,
      minute + 45,
    ),
  );
  Grade grade(String id, String value, int daysAgo) => Grade(
    id: id,
    subject: 'język niemiecki',
    value: value,
    description: '',
    date: DateTime(now.year, now.month, now.day - daysAgo),
    weight: 1,
    semester: _semester(),
  );
  return AppSnapshot(
    profile: const StudentProfile(
      id: 'test',
      name: 'Demo Student',
      school: 'School',
      provider: 'Librus Synergia',
    ),
    lessons: [
      // Today's only lesson is over, whatever the time the test runs at.
      Lesson(
        id: 'today',
        subject: 'fizyka',
        teacher: 'Nauczyciel Testowy',
        room: '12',
        start: today,
        end: today.add(const Duration(seconds: 1)),
      ),
      lesson('t1', 'chemia', 8, 50),
      lesson('t2', 'matematyka', 9, 45),
      lesson('t3', 'historia', 10, 40),
    ],
    grades: [grade('g1', '5', 0), grade('g2', '3', 1)],
    events: events,
    messages: const [],
    attendance: const [],
    announcements: const [],
    notices: const [],
    lastSync: DateTime(now.year, now.month, now.day, 0, 5),
  );
}

SchoolEvent _event(String id, String title, String type, {String? subject}) {
  final now = DateTime.now();
  return SchoolEvent(
    id: id,
    title: title,
    subject: subject ?? 'fizyka',
    date: DateTime(now.year, now.month, now.day + 3),
    kind: EventKind.exam,
    typeLabel: type,
  );
}

Future<AppController> _pump(
  WidgetTester tester, {
  String? locale,
  AppSnapshot? snapshot,
  // Made once the stored settings are in place: the repository reads them
  // as it is made.
  _Repository Function()? repository,
}) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'today_layout_v1': ['currentLesson', 'grades', 'events'],
    'app_locale_v1': ?locale,
  });
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(
    repository?.call() ?? _Repository(snapshot ?? _snapshot()),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('subjects show with a capital letter, short names as typed', () {
    expect(displaySubject('chemia', const {}), 'Chemia');
    expect(displaySubject('język polski', const {}), 'Język polski');
    expect(displaySubject('C#', const {}), 'C#');
    expect(displaySubject('', const {}), '');
    expect(displaySubject('chemia', const {'chemia': 'chem'}), 'chem');
  });

  testWidgets('after the last lesson the card shows tomorrow as a day', (
    tester,
  ) async {
    await _pump(tester);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    expect(find.text('Lessons are over for today'), findsOneWidget);
    expect(
      find.text(
        // With the year on 31 December.
        'Tomorrow, ${DateFormat(tomorrow.year == now.year ? 'dd.MM' : 'dd.MM.yyyy').format(tomorrow)} · first lesson',
      ),
      findsOneWidget,
    );
    expect(find.text('Chemia'), findsOneWidget);
    expect(find.textContaining('room 101'), findsOneWidget);
    expect(find.text('3 lessons in all · until 11:25'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the room reads in the language of the app', (tester) async {
    await _pump(tester, locale: 'ru');
    expect(find.textContaining('каб. 101'), findsOneWidget);
    expect(find.textContaining('s. 101'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, locale: 'pl');
    expect(find.textContaining('s. 101'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('recent grades say when, without the "new" dot', (tester) async {
    await _pump(tester);
    final row = find.byKey(const ValueKey('today-recent-grades'));
    expect(
      find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('grade-new-'),
        ),
      ),
      findsNothing,
    );
    Text when(String id) =>
        tester.widget<Text>(find.byKey(ValueKey('recent-grade-when-$id')));
    expect(when('g1').data, 'Today');
    expect(when('g2').data, 'Yesterday');
    expect(
      find.descendant(of: row, matching: find.text('Język niemiecki')),
      findsNWidgets(2),
    );
    // As wide as each other, so the row keeps one rhythm.
    expect(
      tester.getSize(find.byKey(const ValueKey('recent-grade-g1'))).width,
      tester.getSize(find.byKey(const ValueKey('recent-grade-g2'))).width,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('each kind of entry has its own icon, colour and label', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      snapshot: _snapshot(
        events: [
          _event('quiz', 'kartkówka--elektryzowanie, prawo Coulomba', 'inne'),
          _event('plain', 'Kartkowka bez akcentów', 'inne'),
          _event('exam', 'C# - od zadania 1 do 6', 'sprawdzian'),
          _event('oral', 'Rozdział 2', 'Odpowiedź ustna'),
          _event(
            'trip',
            'Wycieczka do Krakowa',
            'wycieczka',
            subject: 'Librus',
          ),
          _event('meeting', 'Zebranie z rodzicami', 'inne', subject: 'Librus'),
          _event('contest', 'Etap szkolny', 'Konkurs'),
          _event('other', 'Coś innego', 'inne'),
        ],
      ),
    );
    controller.selectTab(3);
    await tester.pumpAndSettle();
    Finder type(String id, String type) =>
        find.byKey(ValueKey('event-type-$id-$type'));
    expect(type('quiz', 'quiz'), findsOneWidget);
    expect(type('plain', 'quiz'), findsOneWidget);
    expect(type('exam', 'exam'), findsOneWidget);
    expect(type('oral', 'oral'), findsOneWidget);
    expect(type('trip', 'trip'), findsOneWidget);
    expect(type('meeting', 'meeting'), findsOneWidget);
    expect(type('contest', 'other'), findsOneWidget);
    expect(type('other', 'other'), findsOneWidget);

    Icon icon(String id, String kind) => tester.widget<Icon>(
      find.descendant(of: type(id, kind), matching: find.byType(Icon)),
    );
    expect(icon('quiz', 'quiz').icon, isNot(icon('exam', 'exam').icon));
    expect(icon('trip', 'trip').icon, isNot(icon('exam', 'exam').icon));
    Color tile(String id, String kind) =>
        (tester
                    .widget<Container>(
                      find.descendant(
                        of: type(id, kind),
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    expect(tile('quiz', 'quiz'), isNot(tile('exam', 'exam')));
    expect(tile('trip', 'trip'), isNot(tile('quiz', 'quiz')));

    Finder inEvent(String id, Finder finder) => find.descendant(
      of: find.byKey(ValueKey('event-$id')),
      matching: finder,
    );
    // The subject leads, the kind sits next to it, the text follows without
    // the word the kind came from.
    expect(inEvent('quiz', find.text('Fizyka')), findsOneWidget);
    expect(inEvent('quiz', find.text('Kartkówka')), findsOneWidget);
    expect(
      inEvent('quiz', find.text('Elektryzowanie, prawo Coulomba')),
      findsOneWidget,
    );
    expect(inEvent('plain', find.text('Kartkowka')), findsOneWidget);
    expect(inEvent('exam', find.text('Sprawdzian')), findsOneWidget);
    expect(
      inEvent('exam', find.text('C# - od zadania 1 do 6')),
      findsOneWidget,
    );
    expect(inEvent('contest', find.text('Konkurs')), findsOneWidget);
    // "inne" says nothing, and an entry of no subject is not labelled twice.
    expect(find.text('inne'), findsNothing);
    expect(find.text('Inne'), findsNothing);
    expect(find.byKey(const ValueKey('event-label-other')), findsNothing);
    expect(find.byKey(const ValueKey('event-label-trip')), findsNothing);
    expect(inEvent('trip', find.text('Wycieczka do Krakowa')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the date line says when data came, and a tap syncs', (
    tester,
  ) async {
    final gate = Completer<void>();
    // Released whatever happens, so a failure ends the test instead of
    // leaving a sync waiting.
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    late final _Repository repository;
    await _pump(
      tester,
      repository: () => repository = _Repository(_snapshot())..gate = gate,
    );
    expect(repository.syncs, 0);
    final line = find.byKey(const ValueKey('today-last-sync'));
    expect(
      find.descendant(of: line, matching: find.text('Updated at 00:05')),
      findsOneWidget,
    );
    await tester.tap(line);
    await tester.pump();
    expect(repository.syncs, 1);
    expect(
      find.descendant(of: line, matching: find.text('Updating…')),
      findsOneWidget,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Updated at'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;
  Completer<void>? gate;
  int syncs = 0;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<AppSnapshot> sync(AppSnapshot current) async {
    syncs++;
    await gate?.future;
    return current.copyWith(lastSync: DateTime.now());
  }

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}
