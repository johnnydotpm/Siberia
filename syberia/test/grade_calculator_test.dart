import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/grade_calculator.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

int _semester() {
  final month = DateTime.now().month;
  return month >= 2 && month <= 8 ? 2 : 1;
}

Grade _grade(String value, {double weight = 1, String id = ''}) => Grade(
  id: id.isEmpty ? 'grade-$value-$weight' : id,
  subject: 'Math',
  value: value,
  description: '',
  date: DateTime.now().subtract(const Duration(days: 30)),
  weight: weight,
  semester: _semester(),
  category: 'Test',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GradeProjection', () {
    const plain = GradeAverageSettings();
    const weighted = GradeAverageSettings(weighted: true);

    test('shows the average before and after the grades tried out', () {
      final projection = GradeProjection(
        plain,
        [_grade('4'), _grade('2')],
        [_grade('6', id: 'what-if')],
      );
      expect(projection.current, 3);
      expect(projection.projected, 4);
    });

    test('counts how many grades reach a target', () {
      final projection = GradeProjection(plain, [_grade('4'), _grade('2')]);
      // 3.0 now: two 4s give 3.5, one 5 gives 3.67.
      expect(projection.needed(target: 3.5, label: '4', weight: 1), 2);
      expect(projection.needed(target: 3.5, label: '5', weight: 1), 1);
      // Already there.
      expect(projection.needed(target: 3, label: '5', weight: 1), 0);
      // A grade at or below the target never gets there.
      expect(projection.needed(target: 4, label: '4', weight: 1), isNull);
      expect(projection.needed(target: 4, label: '3', weight: 1), isNull);
      // Too many to be useful.
      expect(
        projection.needed(target: 5.9, label: '6', weight: 1, limit: 30),
        isNull,
      );
    });

    test('weights count only when the average is weighted', () {
      final grades = [_grade('2', weight: 3), _grade('5')];
      // Weighted: (6 + 5) / 4 = 2.75. One 5 of weight 3: 26 / 7 = 3.71.
      final heavy = GradeProjection(weighted, grades);
      expect(heavy.current, 2.75);
      expect(heavy.needed(target: 3.5, label: '5', weight: 3), 1);
      expect(heavy.needed(target: 3.5, label: '5', weight: 1), 2);
      // Unweighted the weight is ignored: (2 + 5) / 2 = 3.5.
      final flat = GradeProjection(plain, grades);
      expect(flat.current, 3.5);
      expect(flat.needed(target: 4, label: '5', weight: 3), 1);
    });

    test('grades that do not count stay out', () {
      final projection = GradeProjection(plain, [
        _grade('1', weight: 0),
        _grade('np'),
        _grade('5'),
      ]);
      expect(projection.current, 5);
      expect(GradeProjection(plain, const []).current, isNull);
      // With no grades yet, one grade at or above the target is enough.
      expect(
        GradeProjection(
          plain,
          const [],
        ).needed(target: 4, label: '4', weight: 1),
        1,
      );
    });
  });

  test('grade labels, weights and the suggested target', () {
    expect(gradeLabel(5, 1), '5+');
    expect(gradeLabel(5, -1), '5-');
    expect(gradeLabel(6, 1), '6');
    expect(gradeLabel(1, -1), '1');
    expect(weightOptions(const []), [1, 2, 3]);
    expect(
      weightOptions([
        _grade('4', weight: 3),
        _grade('5'),
        _grade('3', weight: 0),
      ]),
      [1, 3],
    );
    expect(usualWeight(const []), 1);
    expect(
      usualWeight([
        _grade('4', weight: 2),
        _grade('5', weight: 2),
        _grade('3'),
      ]),
      2,
    );
    expect(suggestedTarget(null), 4);
    expect(suggestedTarget(4.12), 4.5);
    expect(suggestedTarget(4.5), 5);
    expect(suggestedTarget(5.9), 6);
  });

  testWidgets('the calculator opens from a subject and tries out grades', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = AppController(
      _Repository(
        AppSnapshot(
          profile: const StudentProfile(
            id: 'test',
            name: 'Demo Student',
            school: 'School',
            provider: 'Librus Synergia',
          ),
          lessons: const [],
          grades: [
            _grade('4', id: 'a'),
            _grade('2', id: 'b'),
          ],
          events: const [],
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
    controller.selectTab(2);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('grades-subject-Math')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grade-calculator-open')));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('grade-calculator-sheet'));
    expect(sheet, findsOneWidget);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet, matching: finder);

    // The average is 3 and the suggested target 3.5: two 4s, or one 5 or 6.
    expect(
      inSheet(find.byKey(const ValueKey('calculator-target'))),
      findsOneWidget,
    );
    expect(find.text('3.5'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calculator-needed-4')),
        matching: find.text('× 2'),
      ),
      findsOneWidget,
    );
    // Unweighted averages offer no weights.
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calculator-add-6')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calculator-projected')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calculator-delta')), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.byKey(const ValueKey('calculator-reached')), findsOneWidget);

    // With "-" every grade but 1 gets a minus.
    await tester.tap(find.text('−'));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('6-')), findsOneWidget);
    expect(inSheet(find.text('1')), findsOneWidget);
    expect(inSheet(find.text('1-')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calculator-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('what-if-0')), findsNothing);
    expect(find.byKey(const ValueKey('calculator-needed')), findsOneWidget);

    // A target of 6 cannot be reached with grades of at most 6.
    for (var step = 0; step < 10; step++) {
      await tester.tap(find.byKey(const ValueKey('calculator-target-up')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calculator-out-of-reach')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'with no counted grades yet, a grade equal to the target counts',
    (tester) async {
      SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = AppController(
        _Repository(
          AppSnapshot(
            profile: const StudentProfile(
              id: 'test',
              name: 'Demo Student',
              school: 'School',
              provider: 'Librus Synergia',
            ),
            lessons: const [],
            // Neither counts towards the average.
            grades: [
              _grade('np', id: 'a'),
              _grade('5', weight: 0, id: 'b'),
            ],
            events: const [],
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
      controller.selectTab(2);
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grades-subject-Math')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grade-calculator-open')));
      await tester.pumpAndSettle();

      // The target starts at 4: one 4, 5 or 6 reaches it.
      expect(find.text('4'), findsWidgets);
      for (final value in [4, 5, 6]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('calculator-needed-$value')),
            matching: find.text('× 1'),
          ),
          findsOneWidget,
          reason: '$value',
        );
      }
      for (var step = 0; step < 8; step++) {
        await tester.tap(find.byKey(const ValueKey('calculator-target-up')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      // A single 6 gives exactly 6.
      expect(
        find.byKey(const ValueKey('calculator-out-of-reach')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('calculator-needed-6')), findsOneWidget);
      expect(find.byKey(const ValueKey('calculator-needed-5')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
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
