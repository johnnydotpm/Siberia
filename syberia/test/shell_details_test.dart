import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/expressive/wavy_progress.dart';

import 'support/profile_fakes.dart';

/// One profile synced just now with [lessons], in [design] and English.
Future<AppController> _app(String design, List<Lesson> lessons) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': design,
    'app_locale_v1': 'en',
  });
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  world.changes['kid-regular'] = (data) => data.copyWith(lessons: lessons);
  final repository = world.repository();
  final found = await repository.signIn(username: familyEmail, password: 'x');
  final added = await repository.addProfiles([found.students.first]);
  await repository.syncProfile(added.single.id);
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  return controller;
}

Lesson _lesson(String id, DateTime start) => Lesson(
  id: id,
  subject: 'Matematyka',
  teacher: 'Nauczyciel Testowy',
  room: '1',
  start: start,
  end: start.add(const Duration(minutes: 45)),
);

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a free day picked in the strip opens as it is', (tester) async {
    final today = _dayOf(DateTime.now());
    // Next week, with lessons on Monday and Friday only.
    final monday = today.add(Duration(days: 8 - today.weekday));
    final wednesday = monday.add(const Duration(days: 2));
    final friday = monday.add(const Duration(days: 4));
    final controller = await _app('classic', [
      _lesson('mon', monday.add(const Duration(hours: 9))),
      _lesson('fri', friday.add(const Duration(hours: 9))),
    ]);
    controller.selectTab(1);
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    Finder shown(DateTime day) => find
        .descendant(
          of: find.byType(PageView),
          matching: find.byKey(ValueKey(day)),
        )
        .hitTestable();
    expect(shown(monday), findsOneWidget);
    await tester.tap(
      find.byKey(
        ValueKey('timetable-day-${DateFormat('yyyy-MM-dd').format(wednesday)}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(shown(wednesday), findsOneWidget);
    expect(shown(friday), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a page out of sight draws no frames', (tester) async {
    final now = DateTime.now();
    // A lesson under way: its wave moves on Today.
    final controller = await _app('expressive', [
      _lesson('now', now.subtract(const Duration(minutes: 10))),
    ]);
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SyberiaApp(controller: controller));
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(WavyProgressIndicator), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);

    controller.selectTab(3);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Today is kept, its wave with it, but nothing asks for frames.
    expect(
      find.byType(WavyProgressIndicator, skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
