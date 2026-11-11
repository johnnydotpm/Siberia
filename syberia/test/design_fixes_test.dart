import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/theme/app_theme.dart';
import 'package:syberia/src/ui/expressive/expressive.dart';

import 'support/profile_fakes.dart';

/// The family login, synced just now with what [change] makes of each
/// profile's data, in [design] and English; both profiles together when
/// [together].
Future<AppController> _app({
  String design = 'classic',
  String locale = 'en',
  bool together = false,
  AppSnapshot Function(AppSnapshot data)? change,
}) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': design,
    'app_locale_v1': locale,
  });
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  if (change != null) {
    world.changes['kid-regular'] = change;
    world.changes['kid-music'] = change;
  }
  final repository = world.repository();
  final found = await repository.signIn(username: familyEmail, password: 'x');
  final added = await repository.addProfiles(
    together ? found.students : [found.students.first],
  );
  for (final profile in added) {
    await repository.syncProfile(profile.id);
  }
  await repository.switchProfile(added.first.id);
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  if (together) {
    for (final profile in added) {
      await controller.renameProfile(
        profile.id,
        'Bardzo długa nazwa profilu ${profile.id}',
      );
    }
    await controller.openTogether();
  }
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  AppController controller, {
  Size size = const Size(400, 900),
  double text = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
}

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

SchoolEvent _homework(String id, int days) => SchoolEvent(
  id: id,
  title: 'Zadanie z podręcznika',
  subject: 'Wychowanie fizyczne',
  date: _day(days),
  kind: EventKind.homework,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('together, long profile names fit a narrow phone with large '
      'text', (tester) async {
    final controller = await _app(
      together: true,
      change: (data) =>
          data.copyWith(events: [_homework('h1', 3), _homework('h2', 9)]),
    );
    await _pump(tester, controller, size: const Size(320, 780), text: 2);
    // Today's summary of each profile, then the homework with its marks.
    expect(
      find.byKey(const ValueKey('today-together-summary')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    controller.selectTab(4);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-mark')), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a due date that does not fit beside the subject goes under '
      'it', (tester) async {
    final controller = await _app(
      change: (data) => data.copyWith(events: [_homework('h1', 3)]),
    );
    controller.selectTab(4);
    await _pump(tester, controller, size: const Size(320, 780), text: 2);
    expect(tester.takeException(), isNull);
    final dueText = find.textContaining(
      '${DateFormat.E('en').format(_day(3))}, ',
    );
    final subject = tester.getRect(find.text('Wychowanie fizyczne').first);
    final due = tester.getRect(dueText.first);
    expect(due.top, greaterThanOrEqualTo(subject.bottom - 1));

    // With room enough, beside it as before.
    await _pump(tester, controller);
    final wideSubject = tester.getRect(find.text('Wychowanie fizyczne').first);
    final wideDue = tester.getRect(dueText.first);
    expect((wideDue.center.dy - wideSubject.center.dy).abs(), lessThan(4));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the last day of the strip ends where the cards do', (
    tester,
  ) async {
    final controller = await _app();
    controller.selectTab(1);
    await _pump(tester, controller);
    final chips = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('timetable-day-'),
    );
    final right = chips
        .evaluate()
        .map((element) => tester.getRect(find.byWidget(element.widget)).right)
        .reduce((a, b) => a > b ? a : b);
    expect(right, closeTo(400 - 16, 0.5));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the top bar fills once the page scrolls under it', (
    tester,
  ) async {
    final controller = await _app(
      change: (data) => data.copyWith(
        events: [for (var i = 0; i < 12; i++) _homework('h$i', i + 1)],
      ),
    );
    controller.selectTab(4);
    await _pump(tester, controller);
    Color bar() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;
    final colors = Theme.of(tester.element(find.byType(AppBar))).colorScheme;
    expect(bar(), isNot(colors.surfaceContainer));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(bar(), colors.surfaceContainer);
    // Another page starts with a bar of its own.
    controller.selectTab(0);
    await tester.pumpAndSettle();
    expect(bar(), isNot(colors.surfaceContainer));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a day with nothing planned takes a line, the calendar is the '
      'app\'s own', (tester) async {
    final controller = await _app();
    controller.selectTab(3);
    await _pump(tester, controller);
    final empty = find.byKey(const ValueKey('events-day-empty'));
    expect(empty, findsOneWidget);
    expect(tester.getSize(empty).height, lessThan(56));
    final calendar = find.byKey(const ValueKey('events-calendar'));
    expect(calendar, findsOneWidget);
    expect(
      find.descendant(of: calendar, matching: find.text('Mon')),
      findsOneWidget,
    );

    // The attendance calendar writes the days of the week the same way.
    controller.selectTab(6);
    await tester.pumpAndSettle();
    expect(find.text('Mon', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the fields of a new message are evenly spaced', (tester) async {
    final controller = await _app();
    controller.selectTab(5);
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('messages-compose')));
    await tester.pumpAndSettle();
    final recipient = tester.getRect(
      find.widgetWithText(TextField, 'Recipient'),
    );
    final subject = tester.getRect(
      find.byKey(const ValueKey('compose-subject')),
    );
    final body = tester.getRect(find.byKey(const ValueKey('compose-body')));
    expect(
      body.top - subject.bottom,
      closeTo(subject.top - recipient.bottom, 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Expressive: one size for the labels of the three tiles', (
    tester,
  ) async {
    // "Nieprzeczytane" is the longest; it set a smaller size for itself.
    final controller = await _app(design: 'expressive', locale: 'pl');
    await _pump(tester, controller, size: const Size(360, 800));
    // The size as drawn: the style's, times any scaling on the way.
    double size(String text) {
      final found = find.text(text);
      return tester.widget<Text>(found).style!.fontSize! *
          tester.getRect(found).width /
          tester.getSize(found).width;
    }

    final grades = size('Średnia ocen');
    expect(size('Frekwencja'), closeTo(grades, 0.01));
    expect(size('Nieprzeczytane'), closeTo(grades, 0.01));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('writing a message sits beside the title, or in the bar', (
    tester,
  ) async {
    final expressive = await _app(design: 'expressive');
    expressive.selectTab(5);
    await _pump(tester, expressive);
    final compose = tester.getRect(
      find.byKey(const ValueKey('messages-compose')),
    );
    final title = tester.getRect(find.byType(ExpressiveLargeTitle));
    expect(compose.bottom, closeTo(title.bottom, 12));
    expect(compose.size, const Size(56, 56));
    await tester.pumpWidget(const SizedBox.shrink());

    final classic = await _app();
    classic.selectTab(5);
    await _pump(tester, classic);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const ValueKey('messages-compose')),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('messages-compose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compose-subject')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Expressive fields are Material 3\'s filled ones', () {
    final theme = AppTheme.expressive(Brightness.light);
    expect(theme.inputDecorationTheme.filled, isTrue);
  });

  testWidgets('the timetable\'s date picker is the same calendar', (
    tester,
  ) async {
    final controller = await _app();
    controller.selectTab(1);
    await _pump(tester, controller);
    // The strip's Monday, and the calendar's in place of a lone "M".
    expect(find.text('Mon'), findsOneWidget);
    await tester.tap(find.byTooltip('Choose date'));
    await tester.pumpAndSettle();
    expect(find.text('Mon'), findsNWidgets(2));
    expect(find.text('M'), findsNothing);
    final month = DateFormat.yMMMM('en').format(DateTime.now());
    expect(find.text(month), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
