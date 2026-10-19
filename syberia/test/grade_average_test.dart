import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

Grade _grade(String value, double weight) => Grade(
  id: value,
  subject: 'Matematyka',
  value: value,
  description: '',
  date: DateTime(2026, 10, 1),
  weight: weight,
  semester: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  test('plus and minus follow the chosen values', () {
    for (final (modifier, plus, minus) in const [
      (0.25, 3.25, 2.75),
      (0.5, 3.5, 2.5),
      (0.75, 3.75, 2.25),
    ]) {
      final settings = GradeAverageSettings(plus: modifier, minus: modifier);
      expect(settings.valueOf('3+'), plus);
      expect(settings.valueOf('3-'), minus);
    }
    const defaults = GradeAverageSettings();
    expect(defaults.valueOf('3+'), 3.5);
    expect(defaults.valueOf('3-'), 2.75);
    expect(defaults.valueOf('4'), 4);
    expect(defaults.valueOf('4,5'), 4.5);
    expect(defaults.valueOf('dobry'), 4);
    expect(defaults.valueOf('np'), isNull);
  });

  test('averages are simple or weighted and skip uncounted grades', () {
    final grades = [
      _grade('5', 3),
      _grade('2', 1),
      _grade('1', 0),
      _grade('np', 2),
    ];
    expect(const GradeAverageSettings().average(grades), 3.5);
    expect(const GradeAverageSettings(weighted: true).average(grades), 4.25);
    expect(const GradeAverageSettings().average(const []), isNull);
    expect(
      const GradeAverageSettings(weighted: true).average([_grade('3', 0)]),
      isNull,
    );
  });

  test('settings are saved and restored', () async {
    final controller = AppController(AppRepository(), updatesEnabled: false);
    await controller.bootstrap();
    expect(controller.gradeAverage, const GradeAverageSettings());
    const chosen = GradeAverageSettings(plus: 0.75, minus: 0.5, weighted: true);
    await controller.setGradeAverageSettings(chosen);

    final restored = AppController(AppRepository(), updatesEnabled: false);
    await restored.bootstrap();
    expect(restored.gradeAverage, chosen);
  });

  test('unknown saved values fall back to the defaults', () async {
    SharedPreferences.setMockInitialValues({
      'grade_plus_value_v1': 0.9,
      'grade_minus_value_v1': 0.5,
    });
    final settings = await AppRepository().loadGradeAverageSettings();
    expect(settings.plus, 0.5);
    expect(settings.minus, 0.5);
    expect(settings.weighted, isFalse);
  });

  testWidgets('settings change the plus value and the average type', (
    tester,
  ) async {
    final controller = AppController(
      _SignedInRepository(),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    controller.selectTab(9);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    final plus = find.byKey(const ValueKey('grade-plus'));
    await tester.scrollUntilVisible(plus, 300);
    // In the middle of the screen, clear of the bars drawn over the list.
    final centred = Scrollable.ensureVisible(
      tester.element(plus),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await centred;
    await tester.tap(find.descendant(of: plus, matching: find.text('3.75')));
    await tester.pumpAndSettle();
    expect(controller.gradeAverage.plus, 0.75);

    final weighted = find.byKey(const ValueKey('grade-weighted'));
    await tester.scrollUntilVisible(weighted, 300);
    await tester.tap(weighted);
    await tester.pumpAndSettle();
    expect(controller.gradeAverage.weighted, isTrue);
    expect(
      await AppRepository().loadGradeAverageSettings(),
      const GradeAverageSettings(plus: 0.75, weighted: true),
    );
    expect(tester.takeException(), isNull);
  });
}

class _SignedInRepository extends AppRepository {
  @override
  Future<AppSnapshot> load() async => AppSnapshot(
    profile: const StudentProfile(
      id: 'test',
      name: 'Test',
      school: 'School',
      provider: 'Librus Synergia',
    ),
    lessons: const [],
    grades: const [],
    events: const [],
    messages: const [],
    attendance: const [],
    announcements: const [],
    notices: const [],
    lastSync: DateTime.now(),
  );

  // The real one would reach Librus; the Today look-ahead asks for weeks.
  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}
