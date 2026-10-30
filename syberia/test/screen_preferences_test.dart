import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  test('new preferences default to separate lessons and hidden breaks, preserve the saved style and reset', () async {
    SharedPreferences.setMockInitialValues({
      'timetable_view_v1': 'list',
      'today_layout_v1': [
        '-grades',
        'summary',
        'homework',
        'events',
        'messages',
      ],
    });
    final controller = await _controller();
    expect(controller.timetableView, TimetableView.list);
    expect(controller.mergeTimetableLessons, isFalse);
    expect(controller.showTimetableBreaks, isFalse);
    expect(controller.todayLayout.blocks.first.block, TodayBlock.currentLesson);
    expect(controller.todayLayout.visible, isNot(contains(TodayBlock.grades)));
    await controller.setMergeTimetableLessons(true);
    await controller.setShowTimetableBreaks(true);
    final restored = await _controller();
    expect(restored.mergeTimetableLessons, isTrue);
    expect(restored.showTimetableBreaks, isTrue);
    await restored.resetSettings();
    expect(restored.timetableView, TimetableView.timeline);
    expect(restored.mergeTimetableLessons, isFalse);
    expect(restored.showTimetableBreaks, isFalse);
    expect(restored.todayLayout, TodayLayout.defaults);
    controller.dispose();
    restored.dispose();
  });

  Future<void> settings(
    WidgetTester tester,
    AppController controller,
    String key,
  ) async {
    controller.selectTab(9);
    await tester.pumpAndSettle();
    final entry = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      entry,
      250,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();
  }

  void closeSheet(WidgetTester tester, String key) =>
      Navigator.of(tester.element(find.byKey(ValueKey(key)))).pop();

  testWidgets(
    'Settings control both timetable styles, merging and even short breaks',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = await _controller();
      controller.selectTab(1);
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timetable-view-toggle')), findsNothing);
      expect(find.byKey(const ValueKey('timeline-lesson-a1')), findsOneWidget);
      expect(find.byKey(const ValueKey('timeline-lesson-a2')), findsOneWidget);
      expect(find.text('Break 5 min'), findsNothing);
      expect(find.text('Break 20 min'), findsNothing);

      await settings(tester, controller, 'settings-timetable');
      expect(find.text('Timetable style'), findsWidgets);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
      await tester.tap(find.text('Compact'));
      await tester.tap(find.byKey(const ValueKey('settings-merge-lessons')));
      await tester.tap(find.byKey(const ValueKey('settings-show-breaks')));
      await tester.pumpAndSettle();
      expect(controller.mergeTimetableLessons, isTrue);
      expect(controller.showTimetableBreaks, isTrue);
      closeSheet(tester, 'timetable-settings-sheet');
      controller.selectTab(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timetable-row-a1')), findsOneWidget);
      expect(find.byKey(const ValueKey('timetable-row-a2')), findsNothing);
      expect(find.text('Break 20 min'), findsOneWidget);

      await settings(tester, controller, 'settings-timetable');
      await tester.tap(find.byKey(const ValueKey('settings-merge-lessons')));
      closeSheet(tester, 'timetable-settings-sheet');
      controller.selectTab(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timetable-row-a2')), findsOneWidget);
      expect(find.text('Break 5 min'), findsOneWidget);
      expect(find.text('Break 20 min'), findsOneWidget);

      await settings(tester, controller, 'settings-timetable');
      await tester.tap(find.text('Classic'));
      closeSheet(tester, 'timetable-settings-sheet');
      controller.selectTab(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timeline-lesson-a2')), findsOneWidget);
      expect(find.text('Break 5 min'), findsOneWidget);
      expect(find.text('Break 20 min'), findsOneWidget);
      final first = tester.getRect(
        find.byKey(const ValueKey('timeline-lesson-a1')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('timeline-lesson-a2')),
      );
      final label = tester.getRect(find.text('Break 5 min'));
      expect(label.top, greaterThanOrEqualTo(first.bottom));
      expect(label.bottom, lessThanOrEqualTo(second.top));
      final restored = await _controller();
      expect(restored.timetableView, TimetableView.timeline);
      expect(restored.mergeTimetableLessons, isFalse);
      expect(restored.showTimetableBreaks, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'Today customisation lives in Settings and can hide and restore the lesson card',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = await _controller();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('today-current-lesson')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('today-customize')), findsNothing);
      await settings(tester, controller, 'settings-today-screen');
      final toggle = find.descendant(
        of: find.byKey(const ValueKey('today-block-currentLesson')),
        matching: find.byType(Switch),
      );
      expect(find.text('Current or next lesson'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      closeSheet(tester, 'today-layout-sheet');
      controller.selectTab(0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-current-lesson')), findsNothing);
      expect(
        (await AppRepository().loadTodayLayout()).visible,
        isNot(contains(TodayBlock.currentLesson)),
      );
      await settings(tester, controller, 'settings-today-screen');
      await tester.tap(toggle);
      closeSheet(tester, 'today-layout-sheet');
      controller.selectTab(0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('today-current-lesson')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}

Future<AppController> _controller() async {
  final controller = AppController(_Repository(), updatesEnabled: false);
  await controller.bootstrap();
  return controller;
}

class _Repository extends AppRepository {
  @override
  Future<AppSnapshot> load() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8);
    return AppSnapshot(
      profile: const StudentProfile(
        id: 'test',
        name: 'Test',
        school: '',
        provider: 'Librus Synergia',
      ),
      lessons: [
        for (final (id, subject, offset) in [
          ('a1', 'Programming', 0),
          ('a2', 'Programming', 50),
          ('b1', 'Math', 115),
        ])
          Lesson(
            id: id,
            subject: subject,
            teacher: 'Teacher',
            room: '1',
            start: start.add(Duration(minutes: offset)),
            end: start.add(Duration(minutes: offset + 45)),
          ),
      ],
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: DateTime.now(),
    );
  }

  // The real one would reach Librus; the Today look-ahead asks for weeks.
  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}
