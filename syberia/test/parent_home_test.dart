import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

DateTime _day(int daysAgo, [int hour = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, hour);
}

AttendanceRecord _absence(String id, int daysAgo, int lesson) =>
    AttendanceRecord(
      id: id,
      date: _day(daysAgo),
      lessonNumber: lesson,
      subject: 'Matematyka',
      type: 'Nieobecność',
      symbol: 'nb',
      kind: AttendanceKind.absent,
    );

/// A child's data with what a parent's Today shows: two absences two days
/// ago and one a month ago, a note, a parents' meeting, homework and a
/// lesson on now followed by another.
AppSnapshot _childData(AppSnapshot data) {
  final now = DateTime.now();
  Lesson lesson(String id, DateTime start) => Lesson(
    id: id,
    subject: 'Matematyka',
    teacher: 'Nauczyciel',
    room: '1',
    start: start,
    end: start.add(const Duration(minutes: 45)),
  );
  final first = now.subtract(const Duration(minutes: 1));
  return AppSnapshot(
    profile: data.profile,
    grades: data.grades,
    messages: data.messages,
    announcements: data.announcements,
    freeDays: data.freeDays,
    lastSync: data.lastSync,
    lessons: [
      lesson('l1', first),
      lesson('l2', first.add(const Duration(minutes: 55))),
    ],
    attendance: [
      _absence('a1', 2, 1),
      _absence('a2', 2, 2),
      _absence('a3', 30, 1),
    ],
    notices: [
      StudentNotice(
        id: 'n1',
        text: 'Brak zadania',
        category: 'Uwaga',
        teacher: 'Nauczyciel',
        date: _day(1),
        tone: NoticeTone.negative,
      ),
    ],
    events: [
      SchoolEvent(
        id: 'e1',
        title: 'Zebranie z rodzicami',
        subject: 'Librus',
        date: _day(-5),
        kind: EventKind.event,
      ),
      SchoolEvent(
        id: 'hw1',
        title: 'Ćwiczenia',
        subject: 'Matematyka',
        date: _day(-2),
        kind: EventKind.homework,
      ),
    ],
  );
}

/// The parent's login, its parent's account open when [parent], else the
/// child's own; the app in English in its classic look.
Future<AppController> _app({required bool parent}) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  world.changes['child-parent'] = _childData;
  world.changes['child-u'] = _childData;
  final repository = world.repository();
  final found = await repository.signIn(username: parentEmail, password: 'x');
  final added = await repository.addProfiles(found.students);
  for (final profile in added) {
    await repository.syncProfile(profile.id);
  }
  await repository.switchProfile(
    added.firstWhere((profile) => profile.parent == parent).id,
  );
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  return controller;
}

Future<void> _pump(WidgetTester tester, AppController controller) async {
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
}

Finder _inBar(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a parent\'s Today shows what to excuse, notes and the next '
      'meeting, above the summary; a student\'s does not', (tester) async {
    final parent = await _app(parent: true);
    await _pump(tester, parent);
    for (final key in ['today-to-excuse', 'today-notices', 'today-meetings']) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    // The absence a month ago is past excusing.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('today-to-excuse-count')))
          .data,
      '2 lessons · 1 day',
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('today-to-excuse'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('summary-grades'))).dy,
      ),
    );
    expect(find.textContaining('Lessons until'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    final student = await _app(parent: false);
    await _pump(tester, student);
    for (final key in ['today-to-excuse', 'today-notices', 'today-meetings']) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
    }
    expect(find.textContaining('Lessons until'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a parent\'s bar has attendance where a student\'s has the '
      'timetable, and the settings choose its tabs', (tester) async {
    final parent = await _app(parent: true);
    await _pump(tester, parent);
    expect(parent.bottomTabs, [0, 6, 2, 5]);
    expect(_inBar('Attendance'), findsOneWidget);
    expect(_inBar('Timetable'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    final student = await _app(parent: false);
    student.selectTab(9);
    await _pump(tester, student);
    expect(_inBar('Timetable'), findsOneWidget);
    expect(_inBar('Attendance'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-bottom-tabs')));
    await tester.pumpAndSettle();
    FilledButton save() =>
        tester.widget(find.byKey(const ValueKey('bottom-tabs-save')));
    await tester.tap(find.byKey(const ValueKey('bottom-tab-1')));
    await tester.pump();
    expect(save().onPressed, isNull, reason: 'two chosen');
    await tester.tap(find.byKey(const ValueKey('bottom-tab-8')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bottom-tabs-save')));
    await tester.pumpAndSettle();
    expect(student.bottomTabs, [0, 2, 5, 8]);
    expect(_inBar('Remarks'), findsOneWidget);
    expect(_inBar('Timetable'), findsNothing);

    final again = AppController(
      FakeLibrusWorld().repository(),
      updatesEnabled: false,
    );
    await again.bootstrap();
    expect(again.bottomTabs, [0, 2, 5, 8], reason: 'kept');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a parent only looks at homework and has no grade calculator', (
    tester,
  ) async {
    for (final parent in [true, false]) {
      final controller = await _app(parent: parent);
      controller.selectTab(4);
      await _pump(tester, controller);
      expect(
        find.byKey(const ValueKey('homework-done-hw1')),
        parent ? findsNothing : findsOneWidget,
        reason: 'parent: $parent',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    Finder calculator() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'grade-calculator-open',
          ),
    );
    for (final parent in [true, false]) {
      final controller = await _app(parent: parent);
      controller.selectTab(2);
      await _pump(tester, controller);
      await tester.tap(find.byKey(const ValueKey('grades-subject-Matematyka')));
      await tester.pumpAndSettle();
      expect(
        calculator(),
        parent ? findsNothing : findsWidgets,
        reason: 'parent: $parent',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
