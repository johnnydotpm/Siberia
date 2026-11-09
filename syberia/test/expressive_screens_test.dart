import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/theme/app_symbols.dart';
import 'package:syberia/src/theme/wallpaper_colors.dart';
import 'package:syberia/src/ui/expressive/expressive.dart';

import 'support/profile_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WallpaperColors.ask = () async => null;
  });

  /// The app with a lesson on now (the second, 28 minutes in) and grades,
  /// in [design]. The wavy bar keeps moving, so frames are pumped by time.
  Future<AppController> pumpApp(
    WidgetTester tester, {
    AppDesign design = AppDesign.expressive,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository();
    await repository.saveDesign(design);
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await settle(tester);
    return controller;
  }

  testWidgets('Today opens with a large title and the lesson on now', (
    tester,
  ) async {
    await pumpApp(tester);
    final page = find.byType(ExpressiveLargeTitle);
    expect(page, findsOneWidget);
    expect(tester.widget<ExpressiveLargeTitle>(page).text, 'Today');
    // The bar's own title waits until the large one has scrolled away.
    final barTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(barTitle).opacity, 0);

    final card = find.byKey(const ValueKey('today-now-card'));
    expect(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('today-now-number')),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: card, matching: find.text('2')), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(WavyProgressIndicator)),
      findsOneWidget,
    );
    final number = tester.widget<ShapeBadge>(
      find.byKey(const ValueKey('today-now-number')),
    );
    expect(number.shape, ExpressiveShapes.cookie9);

    // The figures are tiles of their own.
    for (final key in const [
      'summary-grades',
      'summary-absences',
      'summary-messages',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Material),
        ),
        findsWidgets,
      );
    }
  });

  testWidgets('the bar takes the title once it scrolls away', (tester) async {
    final controller = await pumpApp(tester);
    // Settings are long enough to scroll.
    controller.selectTab(9);
    await settle(tester);
    final barTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(barTitle).opacity, 0);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await settle(tester);
    expect(tester.widget<AnimatedOpacity>(barTitle).opacity, 1);
  });

  testWidgets('icons are Material Symbols, filled where chosen', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byIcon(AppSymbols.sync), findsWidgets);
    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    expect(find.byIcon(AppSymbols.menu), findsOneWidget);
  });

  testWidgets('the timetable strip is a connected group with the wave', (
    tester,
  ) async {
    final controller = await pumpApp(tester);
    controller.selectTab(1);
    await settle(tester);
    expect(find.byType(ExpressiveLargeTitle), findsNothing);
    // Every day of the strip is a button of a connected group: its corners
    // are given by start and end, the outer ones fully round.
    final days = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('timetable-day-'),
    );
    expect(days, findsWidgets);
    final first = tester.widget<Material>(
      find.descendant(of: days.first, matching: find.byType(Material)).first,
    );
    final radius =
        (first.shape! as RoundedRectangleBorder).borderRadius
            as BorderRadiusDirectional;
    expect(radius.topStart, const Radius.circular(29));
    expect(find.byType(WavyProgressIndicator), findsWidgets);
  });

  testWidgets('grades: the average on a soft burst, semesters a group', (
    tester,
  ) async {
    final controller = await pumpApp(tester);
    controller.selectTab(2);
    await settle(tester);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ShapeBadge && widget.shape == ExpressiveShapes.softBurst,
      ),
      findsOneWidget,
    );
    expect(find.byType(SegmentedGroup<int>), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsNothing);
  });

  testWidgets('the classic design keeps its own look', (tester) async {
    await pumpApp(tester, design: AppDesign.classic);
    expect(find.byType(ExpressiveLargeTitle), findsNothing);
    expect(find.byType(WavyProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.sync_rounded), findsWidgets);
    expect(find.byIcon(AppSymbols.sync), findsNothing);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class _Repository extends AppRepository {
  @override
  Future<AppSnapshot> load() async {
    final now = DateTime.now();
    final base = studentSnapshot('s1', 'a');
    Lesson lesson(String id, String subject, int start, int number) => Lesson(
      id: id,
      subject: subject,
      teacher: 'Nauczyciel Testowy',
      room: '12',
      start: now.add(Duration(minutes: start)),
      end: now.add(Duration(minutes: start + 45)),
      lessonNumber: number,
    );
    return AppSnapshot(
      profile: base.profile,
      lessons: [
        lesson('l1', 'Język polski', -83, 1),
        lesson('l2', 'Matematyka', -28, 2),
        lesson('l3', 'Fizyka', 27, 3),
      ],
      grades: base.grades,
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
  }

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}
