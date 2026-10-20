import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

var _next = 0;

AttendanceRecord _record(
  String subject,
  AttendanceKind kind, {
  int semester = 1,
}) => AttendanceRecord(
  id: 'r${_next++}',
  date: DateTime(2026, 10, 1).add(Duration(days: _next)),
  lessonNumber: 1,
  subject: subject,
  type: kind.name,
  symbol: kind.name.substring(0, 2),
  kind: kind,
  semester: semester,
);

List<AttendanceRecord> _records() => [
  // 3 of 4: 75 %.
  for (var index = 0; index < 3; index++)
    _record('Matematyka', AttendanceKind.present),
  _record('Matematyka', AttendanceKind.absent),
  // Present and late count as attended: 2 of 4, exactly 50 %.
  _record('Fizyka', AttendanceKind.present),
  _record('Fizyka', AttendanceKind.late),
  _record('Fizyka', AttendanceKind.absent),
  _record('Fizyka', AttendanceKind.absentExcused),
  // 1 of 4: 25 %, below the grading threshold.
  _record('Chemia', AttendanceKind.present),
  for (var index = 0; index < 3; index++)
    _record('Chemia', AttendanceKind.absent),
  // Entries without a subject count only in the summary.
  _record('', AttendanceKind.present),
  // The second semester.
  _record('Biologia', AttendanceKind.present, semester: 2),
];

Future<AppController> _pump(
  WidgetTester tester, {
  List<AttendanceRecord>? records,
  // Made once the stored settings are in place, as it reads them.
  _Repository Function(AppSnapshot data)? repository,
}) async {
  SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final data = AppSnapshot(
    profile: const StudentProfile(
      id: 'test',
      name: 'Demo Student',
      school: 'School',
      provider: 'Librus Synergia',
    ),
    lessons: const [],
    grades: const [],
    events: const [],
    messages: const [],
    attendance: records ?? _records(),
    announcements: const [],
    notices: const [],
    lastSync: DateTime.now(),
  );
  final controller = AppController(
    repository?.call(data) ?? _Repository(data),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  controller.selectTab(6);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Finder _row(String subject) =>
    find.byKey(ValueKey('attendance-subject-$subject'));

Text _rate(WidgetTester tester, String subject) => tester.widget<Text>(
  find.byKey(ValueKey('attendance-subject-rate-$subject')),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('each subject has its own attendance, the lowest first', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Attendance by subject'), findsOneWidget);
    expect(_rate(tester, 'Chemia').data, '25.0%');
    expect(_rate(tester, 'Fizyka').data, '50.0%');
    expect(_rate(tester, 'Matematyka').data, '75.0%');
    expect(_rate(tester, 'Biologia').data, '100.0%');
    // The lowest first.
    final tops = [
      for (final subject in ['Chemia', 'Fizyka', 'Matematyka', 'Biologia'])
        tester.getTopLeft(_row(subject)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    // Below half a student may not be graded; exactly half is still fine.
    final error = Theme.of(tester.element(_row('Chemia'))).colorScheme.error;
    expect(_rate(tester, 'Chemia').style?.color, error);
    expect(_rate(tester, 'Fizyka').style?.color, isNot(error));
    expect(
      find.descendant(
        of: _row('Fizyka'),
        matching: find.text('Absences: 2 · Late: 1 · Lessons: 4'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _row('Biologia'), matching: find.text('Lessons: 1')),
      findsOneWidget,
    );
    // No row for entries without a subject.
    expect(_row(''), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the semester choice applies to the subjects too', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Semester 2'));
    await tester.pumpAndSettle();
    expect(_row('Biologia'), findsOneWidget);
    expect(_row('Matematyka'), findsNothing);
    await tester.tap(find.text('Semester 1'));
    await tester.pumpAndSettle();
    expect(_row('Biologia'), findsNothing);
    expect(_row('Chemia'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a subject opens to its summary and entries', (tester) async {
    await _pump(tester);
    await tester.tap(_row('Fizyka'));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('subject-attendance-sheet'));
    expect(sheet, findsOneWidget);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet, matching: finder);
    expect(inSheet(find.text('Fizyka')), findsOneWidget);
    expect(inSheet(find.text('Attendance: 50.0%')), findsOneWidget);
    expect(inSheet(find.text('Absent: 1')), findsOneWidget);
    expect(inSheet(find.text('Excused absences: 1')), findsOneWidget);
    expect(inSheet(find.text('Late: 1')), findsOneWidget);
    // Its four entries, the latest first.
    final entries = inSheet(find.byType(ListTile));
    expect(entries, findsNWidgets(4));
    expect(
      find.descendant(of: entries.first, matching: find.text('absentExcused')),
      findsOneWidget,
    );
    // The subject is the title, so the entries do not repeat it.
    expect(inSheet(find.textContaining('Fizyka ·')), findsNothing);
    expect(inSheet(find.text('lesson 1')), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('entries without subjects say so and offer a sync', (
    tester,
  ) async {
    late final _Repository repository;
    await _pump(
      tester,
      records: [for (final record in _records()) _withoutSubject(record)],
      repository: (data) => repository = _Repository(data),
    );
    expect(find.byKey(const ValueKey('attendance-by-subject')), findsNothing);
    final note = find.byKey(const ValueKey('attendance-no-subjects'));
    expect(note, findsOneWidget);
    expect(
      find.descendant(
        of: note,
        matching: find.text(
          "Couldn't tell which subjects the entries are for.",
        ),
      ),
      findsOneWidget,
    );
    expect(repository.syncs, 0);
    await tester.tap(
      find.descendant(of: note, matching: find.byType(TextButton)),
    );
    await tester.pumpAndSettle();
    expect(repository.syncs, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

AttendanceRecord _withoutSubject(AttendanceRecord record) => AttendanceRecord(
  id: record.id,
  date: record.date,
  lessonNumber: record.lessonNumber,
  subject: '',
  type: record.type,
  symbol: record.symbol,
  kind: record.kind,
  semester: record.semester,
);

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;
  int syncs = 0;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<AppSnapshot> sync(AppSnapshot current) async {
    syncs++;
    return current;
  }

  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}
