import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/app_build_info.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';

int _semester() {
  final month = DateTime.now().month;
  return month >= 2 && month <= 8 ? 2 : 1;
}

Grade _grade(String id, String value, double weight) => Grade(
  id: id,
  subject: 'Math',
  value: value,
  description: '',
  date: DateTime.now().subtract(const Duration(days: 30)),
  weight: weight,
  semester: _semester(),
);

Future<AppController> _pump(
  WidgetTester tester, {
  String? latestVersion,
  List<Grade> grades = const [],
}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(
    _Repository(
      AppSnapshot(
        profile: const StudentProfile(
          id: 'test',
          name: 'Demo Student',
          school: 'Liceum nr 1',
          provider: 'Librus Synergia',
        ),
        lessons: const [],
        grades: grades,
        events: const [],
        messages: const [],
        attendance: const [],
        announcements: const [],
        notices: const [],
        lastSync: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      latestVersion: latestVersion,
    ),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  controller.selectTab(9);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  testWidgets('settings are grouped, with the account on top', (tester) async {
    await _pump(tester);

    final profile = find.byKey(const ValueKey('settings-profile'));
    for (final text in ['Demo Student', 'Liceum nr 1', 'Synced 5 min ago']) {
      expect(
        find.descendant(of: profile, matching: find.text(text)),
        findsOneWidget,
      );
    }
    for (final section in [
      'Appearance',
      'Sync and notifications',
      'Screens',
      'About',
    ]) {
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(find.text('On · 8 of 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('notification categories live in their own sheet', (
    tester,
  ) async {
    final controller = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('settings-notifications')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notification-grades')));
    await tester.pumpAndSettle();
    expect(
      controller.notificationSettings.allows(SchoolNotificationCategory.grades),
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('notifications-master')));
    await tester.pumpAndSettle();
    expect(controller.notificationSettings.enabled, isFalse);
    // With notifications off the categories cannot be changed.
    final messages = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('notification-messages')),
    );
    expect(messages.onChanged, isNull);

    Navigator.of(
      tester.element(find.byKey(const ValueKey('notification-settings-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('test reminders are set in the notifications sheet', (
    tester,
  ) async {
    final controller = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('settings-notifications')));
    await tester.pumpAndSettle();

    final morning = find.byKey(const ValueKey('reminder-morning'));
    await tester.ensureVisible(morning);
    await tester.pumpAndSettle();
    expect(find.text('7:00 AM · change time'), findsOneWidget);
    expect(find.text('7:00 PM · change time'), findsOneWidget);
    await tester.tap(
      find.descendant(of: morning, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    expect(controller.notificationSettings.reminders.morning, isTrue);
    expect(controller.notificationSettings.reminders.evening, isTrue);

    final homework = find.byKey(const ValueKey('reminder-homework'));
    await tester.ensureVisible(homework);
    await tester.tap(homework);
    await tester.pumpAndSettle();
    expect(controller.notificationSettings.reminders.homework, isTrue);

    // A tap on the row asks for the time.
    await tester.tap(find.text('The evening before'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.notificationSettings.reminders.eveningMinutes, 19 * 60);

    // With notifications off the reminders cannot be changed.
    await tester.ensureVisible(
      find.byKey(const ValueKey('notifications-master')),
    );
    await tester.tap(find.byKey(const ValueKey('notifications-master')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(morning);
    final disabled = tester.widget<Switch>(
      find.descendant(of: morning, matching: find.byType(Switch)),
    );
    expect(disabled.onChanged, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('language, theme and chart are picked with a tap', (
    tester,
  ) async {
    final controller = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('settings-theme-dark')));
    await tester.pumpAndSettle();
    expect(controller.colorMode, AppColorMode.dark);

    await tester.tap(find.byKey(const ValueKey('settings-chart-bar')));
    await tester.pumpAndSettle();
    expect(controller.attendanceChartStyle, AttendanceChartStyle.bar);

    await tester.tap(find.byKey(const ValueKey('settings-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-pl')));
    await tester.pumpAndSettle();
    expect(controller.locale, const Locale('pl'));
    expect(find.text('Wygląd'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the average preview follows the grade settings', (tester) async {
    await _pump(tester, grades: [_grade('a', '4+', 3), _grade('b', '3', 1)]);
    final preview = find.byKey(const ValueKey('settings-average-preview'));
    // 4+ counts as 4.5 by default: (4.5 + 3) / 2.
    expect(
      find.descendant(of: preview, matching: find.text('3.75')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('grade-weighted')));
    await tester.pumpAndSettle();
    // Weighted: (4.5 × 3 + 3) / 4.
    expect(
      find.descendant(of: preview, matching: find.text('4.13')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a check for updates says whether there is a newer version', (
    tester,
  ) async {
    await _pump(tester, latestVersion: '99.0.0');
    await tester.tap(find.byKey(const ValueKey('settings-check-updates')));
    await tester.pumpAndSettle();
    expect(find.text('Version 99.0.0 is available'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    await _pump(tester, latestVersion: AppBuildInfo.version);
    await tester.tap(find.byKey(const ValueKey('settings-check-updates')));
    await tester.pumpAndSettle();
    expect(find.text('You have the latest version'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reset puts settings back but keeps short names', (tester) async {
    final controller = await _pump(tester);
    await controller.setColorMode(AppColorMode.amoled);
    await controller.setAttendanceChartStyle(AttendanceChartStyle.bar);
    await controller.setTodayLayout(TodayLayout.decode(['-grades']));
    await controller.setSubjectShortName('Matematyka', 'Mat');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-reset-confirm')));
    await tester.pumpAndSettle();

    expect(controller.colorMode, AppColorMode.system);
    expect(controller.attendanceChartStyle, AttendanceChartStyle.ring);
    expect(controller.todayLayout, TodayLayout.defaults);
    expect(controller.subjectShortNames, {'Matematyka': 'Mat'});
    expect(await AppRepository().loadColorMode(), AppColorMode.system);
    expect(find.text('Settings were reset'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data, {this.latestVersion});
  final AppSnapshot data;
  final String? latestVersion;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<String?> fetchLatestReleaseVersion() async => latestVersion;

  // The real one would reach Librus; the Today look-ahead asks for weeks.
  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}
