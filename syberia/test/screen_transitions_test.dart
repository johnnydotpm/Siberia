import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/screen_transitions.dart';

final _picture = find.byKey(const ValueKey('screen-transition'));

/// A button that runs [onTap] under a [ScreenTransitions], as the app has one.
Future<void> _harness(
  WidgetTester tester,
  void Function(BuildContext context) onTap, {
  bool enabled = true,
  ValueNotifier<bool>? revealing,
}) => tester.pumpWidget(
  MaterialApp(
    builder: (context, child) => ScreenTransitions(
      enabled: enabled,
      revealing: revealing,
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => onTap(context),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  ),
);

/// The app, signed in, on Settings.
Future<AppController> _settings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(
    _Repository(
      AppSnapshot(
        profile: const StudentProfile(
          id: 'test',
          name: 'Uczeń Testowy',
          school: 'Liceum nr 1',
          provider: 'Librus Synergia',
        ),
        lessons: const [],
        grades: const [],
        events: const [],
        messages: const [],
        attendance: const [],
        announcements: const [],
        notices: const [],
        lastSync: DateTime.now(),
      ),
    ),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  controller.selectTab(9);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

dynamic _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(of: _picture, matching: find.byType(CustomPaint)),
    )
    .painter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the old frame stays as a picture while the change happens '
      'beneath it, then goes', (tester) async {
    var changed = 0;
    await _harness(
      tester,
      (context) => ScreenTransitions.run(
        context,
        ScreenChange.dissolve,
        () => changed++,
      ),
    );
    await tester.tap(find.text('go'));
    expect(changed, 0, reason: 'the picture comes first');
    await tester.pump();
    expect(changed, 1);
    await tester.pump();
    expect(_picture, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_picture, findsOneWidget, reason: 'still dissolving');
    await tester.pumpAndSettle();
    expect(_picture, findsNothing);
    expect(changed, 1);
  });

  testWidgets('with less motion, or where no picture can be taken, the '
      'change happens at once', (tester) async {
    var changed = 0;
    void run(BuildContext context) =>
        ScreenTransitions.run(context, ScreenChange.zoom, () => changed++);

    await _harness(tester, run, enabled: false);
    await tester.tap(find.text('go'));
    expect(changed, 1);
    await tester.pump();
    expect(_picture, findsNothing);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _harness(tester, run);
    await tester.tap(find.text('go'));
    expect(changed, 2);
    await tester.pump();
    expect(_picture, findsNothing);
  });

  testWidgets('changes asked for before the picture keep their order', (
    tester,
  ) async {
    final changes = <String>[];
    await _harness(tester, (context) {
      ScreenTransitions.run(
        context,
        ScreenChange.dissolve,
        () => changes.add('first'),
      );
      ScreenTransitions.run(
        context,
        ScreenChange.dissolve,
        () => changes.add('second'),
      );
    });
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(changes, ['first', 'second']);
    await tester.pumpAndSettle();
  });

  testWidgets('the theme stops fading on its own only while a circle '
      'spreads', (tester) async {
    final revealing = ValueNotifier(false);
    addTearDown(revealing.dispose);
    var kind = ScreenChange.reveal;
    await _harness(
      tester,
      (context) => ScreenTransitions.run(context, kind, () {}),
      revealing: revealing,
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(revealing.value, isTrue);
    await tester.pumpAndSettle();
    expect(revealing.value, isFalse);

    kind = ScreenChange.dissolve;
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(revealing.value, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('a new theme spreads in a circle from the preview tapped', (
    tester,
  ) async {
    final controller = await _settings(tester);
    final dark = find.byKey(const ValueKey('settings-theme-dark'));
    final center = tester.getCenter(dark);
    await tester.tap(dark);
    await tester.pump();
    expect(controller.colorMode, AppColorMode.dark);
    await tester.pump();
    expect(_picture, findsOneWidget);
    expect(_painter(tester).kind, ScreenChange.reveal);
    expect(_painter(tester).origin, center);
    // Beneath the circle the new theme is there at once, not fading in.
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    await tester.pumpAndSettle();
    expect(_picture, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('another language dissolves in as its sheet closes', (
    tester,
  ) async {
    final controller = await _settings(tester);
    await tester.tap(find.byKey(const ValueKey('settings-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-pl')));
    await tester.pump();
    expect(controller.locale, const Locale('pl'));
    await tester.pump();
    expect(_painter(tester).kind, ScreenChange.dissolve);
    await tester.pumpAndSettle();
    expect(_picture, findsNothing);
    expect(find.byKey(const ValueKey('language-sheet')), findsNothing);
    expect(find.text('Wygląd'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the setup run again comes forward as Settings move back', (
    tester,
  ) async {
    await _settings(tester);
    final row = find.byKey(const ValueKey('settings-onboarding'));
    await tester.scrollUntilVisible(row, 300);
    await tester.tap(row);
    await tester.pump();
    await tester.pump();
    expect(_painter(tester).kind, ScreenChange.zoom);
    await tester.pumpAndSettle();
    expect(_picture, findsNothing);
    expect(find.byKey(const ValueKey('onboarding')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;
}
