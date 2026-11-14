import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syberia/src/ui/glass/glass_fade.dart';
import 'package:syberia/src/ui/glass/glass_items.dart';
import 'package:syberia/src/ui/glass/glass_material.dart';
import 'package:syberia/src/ui/glass/glass_plate.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';
import 'package:syberia/src/ui/glass/glass_shell.dart';

const _ratio = 2.0;
const _width = 400.0;

/// How far below the bar the edge lets go.
const _tail = 36.0;

/// A glass shell over a page that goes from black to white and back every
/// 32 points, so a row of the page shows how blurred it is: a slight blur
/// takes a little off the black and the white, a strong one leaves grey.
Future<void> _shell(WidgetTester tester, ScrollController scroll) async {
  GlassPlatform.debugSetBackend(GlassBackend.rendered);
  addTearDown(() => GlassPlatform.debugSetBackend(GlassBackend.none));
  tester.view.physicalSize = const Size(_width * _ratio, 700 * _ratio);
  tester.view.devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      child: MaterialApp(
        builder: (context, child) => GlassStyle(enabled: true, child: child!),
        home: GlassShell(
          pageIndex: 0,
          title: 'Page',
          largeTitle: true,
          tabs: const [
            GlassTab(label: 'One', symbol: GlassSymbol.house),
            GlassTab(label: 'Two', symbol: GlassSymbol.calendar),
          ],
          selectedTab: 0,
          onTabSelected: (_) {},
          menuLabel: 'Menu',
          actions: const [],
          drawer: const SizedBox.shrink(),
          body: ListView(
            controller: scroll,
            padding: EdgeInsets.zero,
            children: const [
              SizedBox(
                height: 3000,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment(-1 + 2 * 16 / _width, 0),
                      colors: [Colors.black, Colors.white],
                      tileMode: TileMode.mirror,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _edge => find.descendant(
  of: find.byWidgetPredicate((w) => '${w.runtimeType}' == '_ScrollEdge'),
  matching: find.byType(BackdropFilter),
);

/// How far apart the darkest and the lightest of the page are in each row
/// below the bar, from the top of the tail down: 0 where blurred to grey,
/// 255 where sharp.
Future<List<double>> _contrastDownTheTail(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final pixels = (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    final data = await image.toByteData();
    image.dispose();
    return data!;
  }))!;
  final width = (_width * _ratio).round();
  double luminance(int x, int y) {
    final at = (y * width + x) * 4;
    return 0.2126 * pixels.getUint8(at) +
        0.7152 * pixels.getUint8(at + 1) +
        0.0722 * pixels.getUint8(at + 2);
  }

  final bar = GlassPlatform.metrics.value.navigationBarHeight;
  return [
    for (
      var y = (bar * _ratio).round();
      y < ((bar + _tail) * _ratio).round();
      y++
    )
      () {
        // Away from the screen's sides, where a blur runs out of page.
        final row = [
          for (var x = width ~/ 5; x < width * 4 ~/ 5; x++) luminance(x, y),
        ];
        return row.reduce((a, b) => a > b ? a : b) -
            row.reduce((a, b) => a < b ? a : b);
      }(),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // As the app starts on Android, which loads the shader where it can run.
  setUpAll(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await GlassPlatform.ensureInitialized();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('content under the bar blurs, the most at the top', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _shell(tester, scroll);
    // At the top of the page nothing is under the bar, so nothing is blurred.
    expect(_edge, findsNothing);

    scroll.jumpTo(400);
    await tester.pumpAndSettle();
    // A few blurs letting go into each other where a shader can, or bands.
    expect(
      _edge,
      GlassFade.available ? findsNWidgets(4) : findsAtLeastNWidgets(6),
    );
    final contrast = await _contrastDownTheTail(tester);
    // Grey right below the bar, part way through half way down, and the
    // page as it is at the end.
    expect(contrast.first, lessThan(25));
    expect(contrast[contrast.length ~/ 2], inExclusiveRange(25, 200));
    expect(contrast.last, greaterThan(200));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the blur lets go smoothly, with no lines across it',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await _shell(tester, scroll);
      scroll.jumpTo(400);
      await tester.pumpAndSettle();
      final contrast = await _contrastDownTheTail(tester);
      final range = contrast.last - contrast.first;
      var steepest = 0.0;
      for (var index = 1; index < contrast.length; index++) {
        final step = (contrast[index] - contrast[index - 1]).abs();
        if (step > steepest) steepest = step;
      }
      // Bands of blur change it by leaps where one meets the next, by an
      // eighth of the way at once. Letting go smoothly, it changes by a few
      // hundredths from a row to the next.
      expect(steepest, lessThan(range * 0.08));
      await tester.pumpWidget(const SizedBox.shrink());
    },
    // Only the Impeller renderer runs the shader: flutter test
    // --enable-impeller.
    skip: !ui.ImageFilter.isShaderFilterSupported,
  );

  testWidgets('the veils under the bars ease in and out, with no kink '
      'where a line would show', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _shell(tester, scroll);
    scroll.jumpTo(400);
    await tester.pumpAndSettle();
    final veils = [
      for (final box in tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      ))
        if (box.decoration
            case BoxDecoration(gradient: final LinearGradient gradient)
            when gradient.colors.length > 8)
          gradient,
    ];
    // The one under the top bar and the one behind the tab bar.
    expect(veils, hasLength(2));
    for (final veil in veils) {
      final alphas = [for (final color in veil.colors) color.a];
      final stops = veil.stops!;
      final total = (alphas.first - alphas.last).abs();
      expect(total, greaterThan(0.3));
      // Where the fade starts and where it ends it is all but flat: the
      // first and the last steps change it by a hair of what the middle
      // ones do.
      double slope(int index) =>
          (alphas[index + 1] - alphas[index]).abs() /
          (stops[index + 1] - stops[index]);
      final fading = [
        for (var index = 0; index < alphas.length - 1; index++)
          if (stops[index + 1] > stops[index]) index,
      ];
      final steepest = fading.map(slope).reduce(math.max);
      final first = fading.firstWhere((index) => slope(index) > 0);
      expect(slope(first), lessThan(steepest * 0.15));
      expect(slope(fading.last), lessThan(steepest * 0.15));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the side menu is on liquid glass that lets the page show '
      'through, as iOS 26 sidebars are', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _shell(tester, scroll);
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    final plate = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(GlassPlate),
    );
    expect(plate, findsOneWidget);
    expect(
      tester.widget<GlassPlate>(plate).look,
      same(GlassMaterial.menu(Brightness.light)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
