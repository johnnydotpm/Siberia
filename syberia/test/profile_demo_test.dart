import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/demo_data.dart';
import 'package:syberia/src/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each week of the demo timetable is its own, across the clock '
      'change', () {
    // The clocks go back on 25 October 2026 in Poland: 7 × 24 hours from
    // that Monday's midnight is still the Sunday.
    final demo = DemoData(now: DateTime(2026, 10, 19, 10));
    final mondays = {
      for (final lesson in demo.snapshot.lessons)
        DateTime(
          lesson.start.year,
          lesson.start.month,
          lesson.start.day - lesson.start.weekday + 1,
        ),
    };
    expect(mondays, {
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 26),
      DateTime(2026, 11, 2),
    });
    expect(
      demo.snapshot.lessons.map((lesson) => lesson.id).toSet().length,
      demo.snapshot.lessons.length,
    );
  });

  test('the music school is the same student in the afternoon', () {
    final regular = DemoData(now: DateTime(2026, 10, 22, 10)).snapshot;
    final music = DemoData.music(now: DateTime(2026, 10, 22, 10)).snapshot;
    expect(music.profile.name, regular.profile.name);
    expect(music.profile.id, isNot(regular.profile.id));
    expect(music.lessons.every((lesson) => lesson.start.hour >= 15), isTrue);
    expect(
      music.lessons.map((lesson) => lesson.subject).toSet(),
      isNot(contains('Mathematics')),
    );
  });

  testWidgets('the demo shows two profiles of one student and switches '
      'between them', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app_design_v1': 'classic',
      'app_locale_v1': 'en',
    });
    final repository = AppRepository();
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    controller.startDemo();
    await tester.pumpAndSettle();

    expect(controller.profiles, hasLength(2));
    expect(
      controller.profiles.first.color,
      isNot(controller.profiles.last.color),
    );
    await tester.tap(find.byKey(const ValueKey('profile-button')));
    await tester.pumpAndSettle();
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.text('Demo Music School · fictional data'), findsOneWidget);
    expect(find.byKey(const ValueKey('profiles-add')), findsNothing);

    await tester.tap(find.text('Demo Music School · fictional data'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.profile.school, contains('Music'));
    expect(controller.snapshot.lessons.first.start.hour, 15);

    await tester.tap(find.byKey(const ValueKey('profile-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('profile-demo-music')),
        matching: find.byIcon(Icons.more_horiz_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-remove')), findsNothing);
    expect(find.byKey(const ValueKey('profile-rename')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const ValueKey('profile-rename'))))
        .pop();
    await tester.pumpAndSettle();

    await controller.switchProfile('demo-regular');
    await tester.pumpAndSettle();
    expect(controller.snapshot.profile.school, contains('Class 2A'));

    await controller.logout();
    await tester.pumpAndSettle();
    expect(controller.profiles, isEmpty);
    expect(repository.profiles, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getKeys().where((key) => key.contains('demo-')),
      isEmpty,
      reason: 'the demo writes nothing of its own',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
