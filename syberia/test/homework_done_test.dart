import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/homework_done.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/test_reminders.dart';

final _now = DateTime.now();
final _tomorrow = DateTime(_now.year, _now.month, _now.day + 1);

SchoolEvent _homework(String id, String subject, String title) => SchoolEvent(
  id: id,
  title: title,
  subject: subject,
  date: _tomorrow,
  kind: EventKind.homework,
);

final _maths = _homework('hw1', 'Matematyka', 'Zadania 1-5');
final _physics = _homework('hw2', 'Fizyka', 'Doświadczenie');

AppSnapshot _snapshot() => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Demo Student',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: const [],
  grades: const [],
  events: [_maths, _physics],
  messages: const [],
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: _now,
);

Future<AppController> _pump(
  WidgetTester tester, {
  int tab = 4,
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    ...saved,
  });
  tester.view.physicalSize = const Size(400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Made once the stored settings are in place, as it reads them.
  final controller = AppController(
    _Repository(_snapshot()),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  controller.selectTab(tab);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Finder _card(String id) => find.byKey(ValueKey('homework-$id'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('done homework leaves the list and can be taken back', (
    tester,
  ) async {
    final controller = await _pump(tester);
    expect(_card('hw1'), findsOneWidget);
    expect(find.text('Upcoming (2)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('homework-done-hw1')));
    await tester.pump();
    // As in Reminders: ticked at once, still in the list for a moment.
    expect(controller.isHomeworkDone(_maths), isFalse);
    expect(_card('hw1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(controller.isHomeworkDone(_maths), isTrue);
    // Out of what is to do, into a closed group of its own.
    expect(_card('hw1'), findsNothing);
    expect(find.text('Upcoming (1)'), findsOneWidget);
    expect(find.text('Done (1)'), findsOneWidget);
    expect(find.text('Marked as done'), findsOneWidget);

    // Taken back at once from the message.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(controller.isHomeworkDone(_maths), isFalse);
    expect(_card('hw1'), findsOneWidget);
    expect(find.text('Done (1)'), findsNothing);

    // A second tap within the moment takes the tick back.
    await tester.tap(find.byKey(const ValueKey('homework-done-hw1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('homework-done-hw1')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(controller.isHomeworkDone(_maths), isFalse);

    await tester.tap(find.byKey(const ValueKey('homework-done-hw1')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('homework-done-toggle')));
    await tester.pumpAndSettle();
    expect(_card('hw1'), findsOneWidget);
    final title = tester.widget<Text>(
      find.descendant(of: _card('hw1'), matching: find.text('Zadania 1-5')),
    );
    expect(title.style?.decoration, TextDecoration.lineThrough);
    // Kept on the phone.
    final preferences = await SharedPreferences.getInstance();
    expect(HomeworkDoneStore.read(preferences).keys, ['hw1']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Today leaves out done homework; the sheet marks it too', (
    tester,
  ) async {
    final controller = await _pump(tester, tab: 0);
    final block = find.byKey(const ValueKey('today-homework'));
    expect(find.descendant(of: block, matching: _card('hw1')), findsOneWidget);
    await controller.setHomeworkDone(_maths, true);
    await tester.pumpAndSettle();
    expect(find.descendant(of: block, matching: _card('hw1')), findsNothing);

    await tester.tap(_card('hw2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('homework-sheet-done')));
    await tester.pumpAndSettle();
    expect(controller.isHomeworkDone(_physics), isTrue);
    expect(
      find.byKey(const ValueKey('homework-sheet-not-done')),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(find.byKey(const ValueKey('homework-details-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    // Nothing left to do: no block.
    expect(block, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('marks are remembered, and long past ones dropped', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await HomeworkDoneStore.write(preferences, {
      'hw1': _tomorrow,
      'old': _now.subtract(const Duration(days: 61)),
    });
    expect(HomeworkDoneStore.read(preferences).keys, ['hw1']);

    final controller = await _pump(
      tester,
      saved: {
        'homework_done_v1': preferences.getStringList('homework_done_v1')!,
      },
    );
    expect(controller.isHomeworkDone(_maths), isTrue);
    expect(controller.isHomeworkDone(_physics), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('done homework is not reminded of', () async {
    SharedPreferences.setMockInitialValues({});
    final presenter = _Presenter();
    final service = SchoolNotificationService(presenter);
    await service.saveSettings(
      const SchoolNotificationSettings(
        reminders: TestReminderSettings(
          evening: false,
          morning: true,
          homework: true,
        ),
      ),
    );
    await service.updateReminders(_snapshot());
    expect(presenter.scheduled.single.body, contains('Matematyka'));
    expect(presenter.scheduled.single.body, contains('Fizyka'));

    await HomeworkDoneStore.write(await SharedPreferences.getInstance(), {
      'hw1': _tomorrow,
    });
    await service.updateReminders(_snapshot());
    expect(presenter.scheduled.single.body, isNot(contains('Matematyka')));
    expect(presenter.scheduled.single.body, contains('Fizyka'));
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
  }) async => const [];
}

class _Presenter implements SchoolNotificationPresenter {
  @override
  Future<List<String>> scheduledReminders() async => const [];

  List<TestReminder> scheduled = const [];

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
    int? id,
    NotificationTarget? target,
    String? channelName,
    bool silent = false,
  }) async {}
  @override
  Future<NotificationTarget?> launchTarget() async => null;
  @override
  void onTap(void Function(NotificationTarget) callback) {}
  @override
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  }) async => scheduled = reminders;
}
