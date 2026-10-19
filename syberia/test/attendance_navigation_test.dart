import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

AttendanceRecord _record(String id, DateTime date, AttendanceKind kind) =>
    AttendanceRecord(
      id: id,
      date: date,
      lessonNumber: 1,
      subject: 'Matematyka',
      type: 'Obecność',
      symbol: 'ob',
      kind: kind,
    );

Future<AppController> _pump(
  WidgetTester tester, {
  Locale? locale,
  List<AttendanceRecord>? attendance,
}) async {
  // Tall enough for the whole attendance page, narrow enough for the bar.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final controller = AppController(
    _Repository(
      AppSnapshot(
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
        attendance:
            attendance ??
            [
              _record('a1', day, AttendanceKind.present),
              _record('a2', day, AttendanceKind.absent),
            ],
        announcements: const [],
        notices: const [],
        lastSync: now,
      ),
    ),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  if (locale != null) await controller.setLocale(locale);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

NavigationBarThemeData _navigationTheme(WidgetTester tester) => tester
    .widget<NavigationBarTheme>(
      find
          .ancestor(
            of: find.byType(NavigationBar),
            matching: find.byType(NavigationBarTheme),
          )
          .first,
    )
    .data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  testWidgets('the attendance calendar and rate follow the app language', (
    tester,
  ) async {
    final controller = await _pump(tester, locale: const Locale('ru'));
    controller.selectTab(6);
    await tester.pumpAndSettle();

    final month = DateFormat.yMMMM('ru').format(DateTime.now());
    expect(
      find.text('${month[0].toUpperCase()}${month.substring(1)}'),
      findsOneWidget,
    );
    expect(find.text('Пн'), findsOneWidget);
    expect(find.text('Вс'), findsOneWidget);
    expect(find.text('Pn'), findsNothing);
    expect(find.textContaining('50,0'), findsWidgets);
    expect(find.textContaining('50.0'), findsNothing);
    expect(find.textContaining('урок 1'), findsWidgets);
    expect(find.textContaining('lekcja'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('attendance-calendar-legend')),
        matching: find.text('Частичное отсутствие'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'flat chart has visible proportional segments in AMOLED and an empty term stays valid',
    (tester) async {
      final date = DateTime.now();
      const counts = [129, 64, 17, 11];
      const kinds = [
        AttendanceKind.present,
        AttendanceKind.absent,
        AttendanceKind.absentExcused,
        AttendanceKind.late,
      ];
      final controller = await _pump(
        tester,
        locale: const Locale('pl'),
        attendance: [
          for (var kind = 0; kind < kinds.length; kind++)
            for (var index = 0; index < counts[kind]; index++)
              _record('$kind-$index', date, kinds[kind]),
        ],
      );
      await controller.setColorMode(AppColorMode.amoled);
      await controller.setAttendanceChartStyle(AttendanceChartStyle.bar);
      controller.selectTab(6);
      await tester.pumpAndSettle();
      final bar = find.byKey(const ValueKey('attendance-flat-chart'));
      final segments = find.descendant(
        of: bar,
        matching: find.byType(ColoredBox),
      );
      expect(segments, findsNWidgets(4));
      final size = tester.getSize(bar);
      for (var index = 0; index < counts.length; index++) {
        final segment = tester.getSize(segments.at(index));
        expect(segment.height, size.height);
        expect(segment.height, greaterThan(0));
        expect(segment.width, closeTo(size.width * counts[index] / 221, 0.01));
      }
      expect(find.textContaining('63,3%'), findsWidgets);
      await tester.tap(find.text('Semestr 2'));
      await tester.pumpAndSettle();
      expect(segments, findsOneWidget);
      expect(tester.getSize(segments).height, size.height);
      expect(find.textContaining('0,0%'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('a page from the menu leaves no tab selected', (tester) async {
    final controller = await _pump(tester);
    expect(_navigationTheme(tester).indicatorColor, isNot(Colors.transparent));

    for (final tab in [3, 4, 6, 7, 8, 9]) {
      controller.selectTab(tab);
      await tester.pumpAndSettle();
      expect(_navigationTheme(tester).indicatorColor, Colors.transparent);
    }

    // Today is still one tap away.
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 0);
    expect(_navigationTheme(tester).indicatorColor, isNot(Colors.transparent));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;
}
