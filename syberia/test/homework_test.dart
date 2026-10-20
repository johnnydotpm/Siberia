import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

SchoolEvent _homework(
  String id,
  String title,
  DateTime date, {
  String subject = 'Matematyka',
  String description = '',
}) => SchoolEvent(
  id: id,
  title: title,
  typeLabel: 'Zadanie domowe',
  subject: subject,
  date: date,
  kind: EventKind.homework,
  description: description,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  testWidgets('homework is grouped by due date, filtered and searchable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final controller = AppController(
      _Repository(
        AppSnapshot(
          profile: const StudentProfile(
            id: 'test',
            name: 'Test',
            school: 'School',
            provider: 'Librus Synergia',
          ),
          lessons: const [],
          grades: const [],
          events: [
            _homework(
              'old',
              'Old task',
              today.subtract(const Duration(days: 3)),
            ),
            _homework(
              'later',
              'Project',
              today.add(const Duration(days: 20)),
              subject: 'Historia',
            ),
            _homework('today', 'Str. 12', today, description: 'Ćwiczenia 1-4'),
            _homework(
              'tomorrow',
              'Essay',
              today.add(const Duration(days: 1)),
              subject: 'Polski',
            ),
            // Without a topic or text Librus only gives the type.
            _homework(
              'generic',
              'Zadanie domowe',
              today.add(const Duration(days: 1)),
              subject: 'Fizyka',
            ),
          ],
          messages: const [],
          attendance: const [],
          announcements: const [],
          notices: const [],
          lastSync: now,
        ),
      ),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    controller.selectTab(4);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    // Upcoming work first, soonest at the top, in sections by due date.
    expect(find.text('Upcoming (4)'), findsOneWidget);
    expect(find.text('Past (1)'), findsOneWidget);
    for (final section in ['Today', 'Tomorrow', 'Later']) {
      expect(find.byKey(ValueKey('homework-section-$section')), findsOneWidget);
    }
    expect(find.text('Old task'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Str. 12')).dy,
      lessThan(tester.getTopLeft(find.text('Essay')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Essay')).dy,
      lessThan(tester.getTopLeft(find.text('Project')).dy),
    );
    // The assignment is the title, with the start of its text below.
    expect(find.text('Ćwiczenia 1-4'), findsOneWidget);
    expect(find.text('Homework'), findsWidgets);
    expect(find.text('Zadanie domowe'), findsNothing);

    await tester.tap(find.text('Str. 12'));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('homework-details-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.textContaining('Due: ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Ćwiczenia 1-4')),
      findsOneWidget,
    );
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('homework-search')),
      'polski',
    );
    await tester.pumpAndSettle();
    expect(find.text('Essay'), findsOneWidget);
    expect(find.text('Str. 12'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('homework-search')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Past (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Old task'), findsOneWidget);
    expect(find.text('Essay'), findsNothing);
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
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}
