import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/expressive/expressive.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';

import 'support/profile_fakes.dart';

/// One profile synced just now with what [change] makes of its data, in
/// [design] and English.
Future<AppController> _app({
  String design = 'classic',
  AppSnapshot Function(AppSnapshot data)? change,
}) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': design,
    'app_locale_v1': 'en',
  });
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  if (change != null) world.changes['kid-regular'] = change;
  final repository = world.repository();
  final found = await repository.signIn(username: familyEmail, password: 'x');
  final added = await repository.addProfiles([found.students.first]);
  await repository.syncProfile(added.single.id);
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  return controller;
}

Future<void> _pump(WidgetTester tester, AppController controller) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
}

SchoolMessage _message(String id, String subject, int hours) => SchoolMessage(
  id: id,
  sender: 'Nauczyciel Testowy',
  subject: subject,
  preview: 'Treść',
  receivedAt: DateTime.now().subtract(Duration(hours: hours)),
  unread: false,
);

AppSnapshot _mail(AppSnapshot data) => data.copyWith(
  messages: [
    _message('m1', 'Wycieczka', 1),
    _message('m2', 'Zebranie', 2),
    _message('m3', 'Konkurs', 3),
  ],
);

/// How opaque and how large [finder] is drawn, through every fade and
/// scale above it.
(double, double) _look(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  var scale = 1.0;
  tester.element(finder).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    if (widget is ScaleTransition) scale *= widget.scale.value;
    return true;
  });
  return (opacity, scale);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => GlassPlatform.debugSetBackend(GlassBackend.none));

  testWidgets('classic and Expressive tabs fade through one another', (
    tester,
  ) async {
    for (final design in ['classic', 'expressive']) {
      final controller = await _app(design: design, change: _mail);
      await _pump(tester, controller);
      controller.selectTab(5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final (opacity, scale) = _look(
        tester,
        find.byKey(const ValueKey('messages-search')),
      );
      expect(opacity, inExclusiveRange(0, 1), reason: design);
      expect(scale, inExclusiveRange(0.92, 1), reason: design);
      await tester.pumpAndSettle();
      expect(_look(tester, find.byKey(const ValueKey('messages-search'))), (
        1.0,
        1.0,
      ), reason: design);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('glass tabs, and any with less motion, switch at once', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    final glass = await _app(design: 'glass', change: _mail);
    await _pump(tester, glass);
    glass.selectTab(5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_look(tester, find.byKey(const ValueKey('messages-search'))), (
      1.0,
      1.0,
    ));
    await tester.pumpWidget(const SizedBox.shrink());
    GlassPlatform.debugSetBackend(GlassBackend.none);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final calm = await _app(change: _mail);
    await _pump(tester, calm);
    calm.selectTab(5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_look(tester, find.byKey(const ValueKey('messages-search'))), (
      1.0,
      1.0,
    ));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('picking messages moves no row, the bars fade into one '
      'another', (tester) async {
    for (final design in ['classic', 'expressive']) {
      final controller = await _app(design: design, change: _mail);
      controller.selectTab(5);
      await _pump(tester, controller);
      final row = find.byKey(const ValueKey('message-tile-m1'));
      final before = tester.getRect(row).top;
      await tester.longPress(find.text('Wycieczka'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // The way out of picking comes in as the page's bar goes.
      expect(
        find.byKey(const ValueKey('messages-selection-close')),
        findsOneWidget,
        reason: design,
      );
      expect(find.byKey(const ValueKey('app-bar-5')), findsOneWidget);
      if (design == 'expressive') {
        // The navigation bar is on its way down, not gone at once.
        final bar = find.byType(ExpressiveNavigationBar);
        expect(bar, findsOneWidget);
        final shown = tester
            .widget<SizeTransition>(
              find
                  .ancestor(of: bar, matching: find.byType(SizeTransition))
                  .first,
            )
            .sizeFactor
            .value;
        expect(shown, inExclusiveRange(0, 1));
      }
      await tester.pumpAndSettle();
      expect(tester.getRect(row).top, closeTo(before, 1), reason: design);
      if (design == 'expressive') {
        expect(find.byType(ExpressiveNavigationBar), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('a deleted message folds away; another folder fades in', (
    tester,
  ) async {
    final controller = await _app(change: _mail);
    controller.selectTab(5);
    await _pump(tester, controller);
    await tester.longPress(find.text('Zebranie'));
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('message-tile-m3'));
    final before = tester.getRect(next).top;
    await tester.tap(find.byKey(const ValueKey('messages-delete-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('messages-confirm-delete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The row below rises with the deleted one folding, not at once.
    final row = find.byKey(const ValueKey('message-tile-m2'));
    expect(row, findsOneWidget);
    final midway = tester.getRect(next).top;
    await tester.pumpAndSettle();
    final after = tester.getRect(next).top;
    expect(after, lessThan(before));
    expect(midway, inExclusiveRange(after, before));
    expect(row, findsNothing);
    expect(find.text('Wycieczka'), findsOneWidget);

    await tester.tap(find.text('Sent'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // The inbox fading out, before the Sent folder comes in.
    final (leaving, _) = _look(tester, find.text('Wycieczka'));
    expect(leaving, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.text('Wycieczka'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('another semester fades in, another month too', (tester) async {
    final controller = await _app();
    controller.selectTab(2);
    await _pump(tester, controller);
    await tester.tap(find.text('Semester 2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final (opacity, _) = _look(tester, find.text('No grades this semester'));
    expect(opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_look(tester, find.text('No grades this semester')).$1, 1);

    controller.selectTab(3);
    await tester.pumpAndSettle();
    final grids = find.descendant(
      of: find.byKey(const ValueKey('events-calendar')),
      matching: find.byType(GridView),
    );
    expect(grids, findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(grids, findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(grids, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
