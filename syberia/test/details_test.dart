import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

AppSnapshot _snapshot({
  List<Lesson> lessons = const [],
  List<SchoolEvent> events = const [],
  List<SchoolMessage> messages = const [],
  List<AttendanceRecord> attendance = const [],
}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Demo Student',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: lessons,
  grades: const [],
  events: events,
  messages: messages,
  attendance: attendance,
  announcements: const [],
  notices: const [],
  lastSync: _now,
);

Future<AppController> _pump(
  WidgetTester tester,
  AppSnapshot data, {
  int tab = 0,
  String locale = 'en',
  double width = 393,
}) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': locale,
  });
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(_Repository(data), updatesEnabled: false);
  await controller.bootstrap();
  controller.selectTab(tab);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

/// The haptic feedback asked of the system, by kind.
List<String> _haptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('"Next lesson" stays on one line beside the time', (
    tester,
  ) async {
    // A lesson in 17 minutes, which cannot cross midnight.
    if (_now.hour >= 23) return;
    final start = _now.add(const Duration(minutes: 17));
    await _pump(
      tester,
      _snapshot(
        lessons: [
          Lesson(
            id: 'l1',
            subject: 'Chemia',
            teacher: 'Nauczyciel Testowy',
            room: '101',
            start: start,
            end: start.add(const Duration(minutes: 45)),
          ),
        ],
      ),
      locale: 'ru',
      // Tests draw every letter as wide as it is tall. At this width the
      // label fits beside the time, but not in half of the room left, as
      // it had beside a Spacer.
      width: 600,
    );
    final card = find.byKey(const ValueKey('today-now-card'));
    final label = find.descendant(
      of: card,
      matching: find.text('Следующий урок'),
    );
    final time = find.descendant(
      of: card,
      matching: find.textContaining('Через'),
    );
    // One line: as tall as the time beside it, in the same style.
    expect(tester.getSize(label).height, tester.getSize(time).height);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the attendance legend leaves out kinds with no entries', (
    tester,
  ) async {
    AttendanceRecord record(String id, AttendanceKind kind) => AttendanceRecord(
      id: id,
      date: _today,
      lessonNumber: 1,
      subject: 'Fizyka',
      type: kind.name,
      symbol: kind.name.substring(0, 2),
      kind: kind,
    );
    await _pump(
      tester,
      _snapshot(
        attendance: [
          record('a1', AttendanceKind.present),
          record('a2', AttendanceKind.absent),
        ],
      ),
      tab: 6,
    );
    expect(find.text('Present: 1'), findsOneWidget);
    expect(find.textContaining(': 0'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty pages say what is missing', (tester) async {
    for (final (tab, text) in [
      (2, 'No grades this semester'),
      (4, 'No homework'),
      (6, 'No attendance yet'),
      (7, 'No announcements'),
      (8, 'No notes'),
      (5, 'No messages'),
    ]) {
      await _pump(tester, _snapshot(), tab: tab);
      expect(find.text(text), findsOneWidget, reason: 'tab $tab');
      expect(find.text('No data'), findsNothing, reason: 'tab $tab');
      // No average of nothing above it.
      expect(find.byKey(const ValueKey('grades-overview')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('all homework done, or no unread mail, is said as good news', (
    tester,
  ) async {
    final homework = SchoolEvent(
      id: 'hw1',
      title: 'Zadania',
      subject: 'Matematyka',
      date: DateTime(_today.year, _today.month, _today.day + 1),
      kind: EventKind.homework,
    );
    final controller = await _pump(
      tester,
      _snapshot(
        events: [homework],
        messages: [
          SchoolMessage(
            id: 'm1',
            sender: 'Nauczyciel Testowy',
            subject: 'Temat',
            preview: 'Treść',
            receivedAt: _now,
          ),
        ],
      ),
      tab: 4,
    );
    await controller.setHomeworkDone(homework, true);
    await tester.pumpAndSettle();
    expect(find.text('All done'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('homework-search')),
      'nothing like this',
    );
    await tester.pumpAndSettle();
    expect(find.text('All done'), findsNothing);

    controller.selectTab(5);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('messages-filter')));
    await tester.pumpAndSettle();
    expect(find.text('All read'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('messages-search')),
      'nothing like this',
    );
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings rows are divided from their text on', (tester) async {
    await _pump(tester, _snapshot(), tab: 9);
    final dividers = tester.widgetList<Divider>(
      find.descendant(of: find.byType(Card), matching: find.byType(Divider)),
    );
    expect(dividers, isNotEmpty);
    // 16 to the icon, 34 of icon, 16 to the text.
    expect(dividers.map((divider) => divider.indent).toSet(), {66.0});
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('choices and ticks are felt', (tester) async {
    final homework = SchoolEvent(
      id: 'hw1',
      title: 'Zadania',
      subject: 'Matematyka',
      date: DateTime(_today.year, _today.month, _today.day + 1),
      kind: EventKind.homework,
    );
    await _pump(tester, _snapshot(events: [homework]), tab: 4);
    final haptics = _haptics(tester);
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    await tester.tap(find.text('Upcoming (1)'));
    await tester.pumpAndSettle();
    haptics.clear();
    await tester.tap(find.byKey(const ValueKey('homework-done-hw1')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an event of next year stays inside its card with large text', (
    tester,
  ) async {
    // Its date then carries the year, and leaves the title less room.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      _snapshot(
        events: [
          SchoolEvent(
            id: 'meeting',
            title: 'Zebranie z rodzicami',
            subject: 'Wychowanie fizyczne',
            date: DateTime(_now.year + 1, 1, 4),
            kind: EventKind.event,
            typeLabel: 'Wywiadówka',
          ),
        ],
      ),
      tab: 3,
      width: 360,
    );
    expect(find.byKey(const ValueKey('event-label-meeting')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => data.lessons;
}
