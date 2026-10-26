import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/startup.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/brand/brand_mark.dart';
import 'package:syberia/src/ui/brand/brand_wordmark.dart';
import 'package:syberia/src/ui/brand_logo.dart';

import 'support/profile_fakes.dart';

final _eventMark = find.byKey(const ValueKey('brand-event-mark'));
final _intro = find.byKey(const ValueKey('setup-intro'));
final _flight = find.byKey(const ValueKey('setup-intro-flight'));

/// The event and moment the startup mark is drawn at.
BrandMarkPainter _markPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_eventMark).painter! as BrandMarkPainter;

/// What [child] looks like, as pixels, and how wide the picture is.
Future<(ByteData, int)> _pixels(
  WidgetTester tester,
  Widget child, {
  required bool dark,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: Duration.zero,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: startupBackground(dark ? Brightness.dark : Brightness.light),
            child: Padding(padding: const EdgeInsets.all(40), child: child),
          ),
        ),
      ),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final picture = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    final width = image.width;
    image.dispose();
    return (data!, width);
  });
  return picture!;
}

void main() {
  setUpAll(() async {
    // The logo's own font, so letters are drawn as in the app.
    final font = FontLoader('Unbounded')
      ..addFont(rootBundle.load('assets/fonts/Unbounded.ttf'));
    await font.load();
  });

  group('the day', () {
    test('each holiday has its logo from the first moment of its day to the '
        'last, and the days around it are ordinary', () {
      const days = {
        (1, 1): BrandEvent.newYear,
        (1, 2): BrandEvent.ordinary,
        (5, 1): BrandEvent.ordinary,
        (5, 2): BrandEvent.plFlag,
        (5, 3): BrandEvent.plConstitution,
        (5, 4): BrandEvent.ordinary,
        (8, 22): BrandEvent.ordinary,
        (8, 23): BrandEvent.uaFlag,
        (8, 24): BrandEvent.uaIndependence,
        (8, 25): BrandEvent.ordinary,
        (8, 31): BrandEvent.ordinary,
        (9, 1): BrandEvent.schoolStart,
        (9, 2): BrandEvent.ordinary,
        (11, 10): BrandEvent.ordinary,
        (11, 11): BrandEvent.plIndependence,
        (11, 12): BrandEvent.ordinary,
        (12, 23): BrandEvent.ordinary,
        (12, 24): BrandEvent.christmas,
        (12, 25): BrandEvent.christmas,
        (12, 26): BrandEvent.christmas,
        (12, 27): BrandEvent.ordinary,
        (12, 30): BrandEvent.ordinary,
        (12, 31): BrandEvent.newYear,
      };
      for (final MapEntry(key: (month, day), :value) in days.entries) {
        for (final year in [2026, 2027, 2028]) {
          expect(BrandEvent.on(DateTime(year, month, day)), value);
          expect(BrandEvent.on(DateTime(year, month, day, 23, 59, 59)), value);
        }
      }
    });

    test('over a whole year each event has its own days, and every other '
        'day is ordinary', () {
      final counts = <BrandEvent, int>{};
      // 2028 is a leap year, so 29 February is counted too.
      for (
        var day = DateTime(2028);
        day.year == 2028;
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        counts.update(BrandEvent.on(day), (n) => n + 1, ifAbsent: () => 1);
      }
      expect(counts, {
        BrandEvent.ordinary: 366 - 11,
        BrandEvent.plFlag: 1,
        BrandEvent.plConstitution: 1,
        BrandEvent.uaFlag: 1,
        BrandEvent.uaIndependence: 1,
        BrandEvent.schoolStart: 1,
        BrandEvent.plIndependence: 1,
        BrandEvent.christmas: 3,
        BrandEvent.newYear: 2,
      });
    });

    test("today follows the phone's calendar, and the debug choice wins", () {
      BrandEvents.clock = () => DateTime(2026, 12, 31, 23, 59, 59);
      expect(BrandEvents.today(), BrandEvent.newYear);
      BrandEvents.clock = () => DateTime(2027, 1, 2);
      expect(BrandEvents.today(), BrandEvent.ordinary);
      BrandEvents.override = BrandEvent.christmas;
      expect(BrandEvents.today(), BrandEvent.christmas);
    });

    testWidgets('without a scope the logo is the ordinary one', (tester) async {
      late BrandEvent seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = BrandEventScope.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, BrandEvent.ordinary);
    });

    test('the debug choice is saved, read back and cleared', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = AppRepository();
      expect(await repository.loadBrandEventOverride(), isNull);
      await repository.saveBrandEventOverride('christmas');
      expect(await repository.loadBrandEventOverride(), 'christmas');
      await repository.saveBrandEventOverride(null);
      expect(await repository.loadBrandEventOverride(), isNull);
    });

    testWidgets('the debug choice is read at launch; a name the app does not '
        'know is ignored', (tester) async {
      for (final (saved, expected) in [
        ('newYear', BrandEvent.newYear),
        ('carnival', null),
      ]) {
        SharedPreferences.setMockInitialValues({
          'app_design_v1': 'classic',
          'debug_brand_event_v1': saved,
        });
        await tester.pumpWidget(
          StartupApp(
            initialize: () => Completer<AppController>().future,
            preferences: AppRepository(),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(BrandEvents.override, expected);
        if (expected == null) {
          expect(_eventMark, findsNothing);
        } else {
          expect(_markPainter(tester).event, expected);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('the logos', () {
    test('every moment of every animation draws, light and dark', () {
      for (final event in BrandEvent.values) {
        final layout = WordmarkLayout(56);
        for (final dark in [false, true]) {
          for (var step = 0; step <= 120; step++) {
            final phase = step / 120;
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            BrandMarkPainter(
              event: event,
              phase: phase,
              dark: dark,
            ).paint(canvas, const Size.square(128));
            for (final details in [false, true]) {
              BrandWordmarkPainter(
                event: event,
                phase: phase,
                dark: dark,
                layout: layout,
                accessories: details,
                clip: details,
              ).paint(canvas, layout.size);
            }
            recorder.endRecording().dispose();
          }
        }
        layout.dispose();
      }
    });

    testWidgets('every frame of every animation lays out', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final event in BrandEvent.values) {
        for (var step = 0; step <= 20; step++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: BrandLogoFrame(phase: step / 20, event: event),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$event $step');
        }
      }
    });

    testWidgets('the startup animation is the day’s, and with less motion it '
        'holds its resting frame', (tester) async {
      for (final event in [BrandEvent.christmas, BrandEvent.newYear]) {
        await tester.pumpWidget(
          MaterialApp(
            home: BrandEventScope(
              event: event,
              child: const Center(child: AnimatedBrandLogo()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1500));
        expect(_markPainter(tester).event, event);
        expect(_markPainter(tester).phase, closeTo(0.25, 0.01));

        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await tester.pump();
        final rest = LogoMotion.of(event).rest;
        expect(_markPainter(tester).phase, rest);
        await tester.pump(const Duration(seconds: 3));
        expect(_markPainter(tester).phase, rest);
        expect(tester.binding.hasScheduledFrame, isFalse);
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('"GB" is in the flag’s two colours on the national days and '
        'in one colour on the others', (tester) async {
      tester.view.physicalSize = const Size(1000, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const fontSize = 96.0;
      final layout = WordmarkLayout(fontSize);
      addTearDown(layout.dispose);
      for (final dark in [false, true]) {
        final (white, red) = (
          WordmarkColours.white(dark),
          WordmarkColours.red(dark),
        );
        final (blue, yellow) = (
          WordmarkColours.blue(dark),
          WordmarkColours.yellow(dark),
        );
        final expected = <BrandEvent, (Color, Color)>{
          BrandEvent.ordinary: (
            WordmarkColours.brand(dark),
            WordmarkColours.brand(dark),
          ),
          BrandEvent.schoolStart: (
            WordmarkColours.brand(dark),
            WordmarkColours.brand(dark),
          ),
          BrandEvent.plFlag: (white, red),
          BrandEvent.plConstitution: (white, red),
          BrandEvent.plIndependence: (white, red),
          BrandEvent.uaFlag: (blue, yellow),
          BrandEvent.uaIndependence: (blue, yellow),
          BrandEvent.christmas: WordmarkColours.gb(BrandEvent.christmas, dark),
          BrandEvent.newYear: WordmarkColours.gb(BrandEvent.newYear, dark),
        };
        for (final MapEntry(key: event, value: (upper, lower))
            in expected.entries) {
          final (pixels, width) = await _pixels(
            tester,
            BrandWordmark(event: event, fontSize: fontSize),
            dark: dark,
          );
          final gb = _GbArea(pixels, width, layout, dark: dark);
          final reason = '$event, ${dark ? 'dark' : 'light'}';
          expect(gb.top.count(upper), greaterThan(40), reason: reason);
          expect(gb.bottom.count(lower), greaterThan(40), reason: reason);
          if (upper != lower) {
            expect(gb.top.count(lower), 0, reason: reason);
            expect(gb.bottom.count(upper), 0, reason: reason);
          }
        }
      }
    });

    testWidgets('the letters sit in the line as in the mockups, and the '
        "flag's colours split them in the middle", (tester) async {
      tester.view.physicalSize = const Size(1000, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const fontSize = 96.0;
      final layout = WordmarkLayout(fontSize);
      addTearDown(layout.dispose);
      final (pixels, width) = await _pixels(
        tester,
        const BrandWordmark(event: BrandEvent.uaIndependence, fontSize: 96),
        dark: false,
      );
      final background = startupBackground(Brightness.light).toARGB32();
      Color at(int x, int y) {
        final offset = (y * width + x) * 4;
        return Color.fromARGB(
          255,
          pixels.getUint8(offset),
          pixels.getUint8(offset + 1),
          pixels.getUint8(offset + 2),
        );
      }

      // "Siberia": inside the wordmark's box, the padding of 40 around it.
      final siberia = [
        for (var y = 0; y < pixels.lengthInBytes ~/ 4 ~/ width; y++)
          for (var x = 40; x < 40 + layout.boxes[6].right; x++)
            if (at(x, y).toARGB32() != background) y,
      ];
      final top = siberia.reduce(math.min) - 40;
      final bottom = siberia.reduce(math.max) - 40;

      // Where Chromium draws the mockups' line: ink from 4.75 to 85.5 of
      // its 96 points.
      expect(top, closeTo(4.75 / 96 * fontSize, 2));
      expect(bottom, closeTo(85.5 / 96 * fontSize, 2));

      // "GB": blue above the middle of the letters, yellow below.
      final blue = WordmarkColours.blue(false);
      final yellow = WordmarkColours.yellow(false);
      bool near(Color a, Color b) =>
          (a.r - b.r).abs() < 0.02 &&
          (a.g - b.g).abs() < 0.02 &&
          (a.b - b.b).abs() < 0.02;
      int? firstBlue;
      int? firstYellow;
      int? lastYellow;
      for (var y = 0; y < pixels.lengthInBytes ~/ 4 ~/ width; y++) {
        for (
          var x = (40 + layout.boxes[7].left).round();
          x < 40 + layout.boxes[8].right;
          x++
        ) {
          final pixel = at(x, y);
          if (near(pixel, blue)) firstBlue ??= y;
          if (near(pixel, yellow)) {
            firstYellow ??= y;
            lastYellow = y;
          }
        }
      }
      // Half-way down the letters, as the mockup's gradient splits them.
      expect(
        (firstYellow! - firstBlue!) / (lastYellow! - firstBlue + 1),
        closeTo(0.5, 0.03),
      );
    });

    testWidgets('the details by the name are on the large wordmark only, and '
        'never on an ordinary day', (tester) async {
      tester.view.physicalSize = const Size(1000, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final event in BrandEvent.values) {
        final (plain, _) = await _pixels(
          tester,
          BrandWordmark(event: event, fontSize: 48),
          dark: false,
        );
        final (dressed, _) = await _pixels(
          tester,
          BrandWordmark(event: event, fontSize: 48, accessories: true),
          dark: false,
        );
        // 23 August has no detail by the name; its colours say enough.
        final hasDetail =
            event != BrandEvent.ordinary && event != BrandEvent.uaFlag;
        expect(!_same(plain, dressed), hasDetail, reason: '$event');
        if (event == BrandEvent.ordinary) {
          expect(
            find.byType(EventWordmark),
            findsNothing,
            reason: 'the ordinary wordmark is the supplied text',
          );
        }
      }
    });

    testWidgets('the menu and the sign-in show the day’s logo', (tester) async {
      BrandEvents.clock = () => DateTime(2026, 11, 11, 9);
      SharedPreferences.setMockInitialValues({
        'app_design_v1': 'classic',
        'app_locale_v1': 'en',
        'onboarding_done_v1': true,
      });
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = AppController(
        FakeLibrusWorld().repository(),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      final mark = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(AppLogo),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(
        (mark.painter! as BrandMarkPainter).event,
        BrandEvent.plIndependence,
      );
      final signIn = tester.widget<EventWordmark>(find.byType(EventWordmark));
      expect(signIn.event, BrandEvent.plIndependence);
      expect(signIn.accessories, isTrue, reason: 'the large sign-in wordmark');

      controller.startDemo();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      final menu = tester.widget<EventWordmark>(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(EventWordmark),
        ),
      );
      expect(menu.event, BrandEvent.plIndependence);
      expect(menu.accessories, isFalse, reason: 'too small for the details');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('the setup on a holiday', () {
    testWidgets('plays the day’s animation to the whole logo, then the mark '
        'flies and lands as the first step shows it', (tester) async {
      BrandEvents.clock = () => DateTime(2026, 12, 24, 18);
      SharedPreferences.setMockInitialValues({
        'app_design_v1': 'classic',
        'app_locale_v1': 'en',
      });
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = AppController(
        FakeLibrusWorld().repository(),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      final ready = Completer<AppController>();
      await tester.pumpWidget(
        StartupApp(
          initialize: () => ready.future,
          preferences: AppRepository(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(_markPainter(tester).event, BrandEvent.christmas);
      ready.complete(controller);
      await tester.pump();
      expect(_intro, findsOneWidget);
      expect(_markPainter(tester).event, BrandEvent.christmas);

      // Christmas rests whole until 0.72 of its six seconds: 4.32 s.
      await tester.pump(const Duration(milliseconds: 3900));
      expect(_flight, findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_flight, findsOneWidget);
      await tester.pumpAndSettle();
      expect(_intro, findsNothing);
      final landed = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(const ValueKey('login-demo-logo')),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = landed.painter! as BrandMarkPainter;
      expect(painter.event, BrandEvent.christmas);
      expect(painter.phase, LogoMotion.of(BrandEvent.christmas).rest);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

/// Whether two pictures are the same, pixel for pixel.
bool _same(ByteData a, ByteData b) {
  if (a.lengthInBytes != b.lengthInBytes) return false;
  for (var index = 0; index < a.lengthInBytes; index += 4) {
    if (a.getUint32(index) != b.getUint32(index)) return false;
  }
  return true;
}

/// The letters "GB" in a picture of the wordmark, split into the top and the
/// bottom quarter of their height.
class _GbArea {
  _GbArea(
    this._pixels,
    this._width,
    WordmarkLayout layout, {
    required bool dark,
  }) : _background = startupBackground(
         dark ? Brightness.dark : Brightness.light,
       ) {
    // The picture is the wordmark padded by 40 on every side.
    _left = (40 + layout.boxes[7].left).round();
    _right = (40 + layout.boxes[8].right).round();
    final height = _pixels.lengthInBytes ~/ 4 ~/ _width;
    final rows = [
      for (var y = 0; y < height; y++)
        if (_inked(y)) y,
    ];
    final top = rows.first;
    final bottom = rows.last;
    final quarter = (bottom - top) ~/ 4;
    this.top = _Band(this, top, top + quarter);
    this.bottom = _Band(this, bottom - quarter, bottom);
  }

  final ByteData _pixels;
  final int _width;
  final Color _background;
  late final int _left;
  late final int _right;
  late final _Band top;
  late final _Band bottom;

  Color _at(int x, int y) {
    final offset = (y * _width + x) * 4;
    return Color.fromARGB(
      _pixels.getUint8(offset + 3),
      _pixels.getUint8(offset),
      _pixels.getUint8(offset + 1),
      _pixels.getUint8(offset + 2),
    );
  }

  bool _inked(int y) {
    for (var x = _left; x < _right; x++) {
      if (_at(x, y).toARGB32() != _background.toARGB32()) return true;
    }
    return false;
  }
}

class _Band {
  _Band(this._area, this._from, this._to);

  final _GbArea _area;
  final int _from;
  final int _to;

  /// How many pixels in the band are [colour], give or take rounding.
  int count(Color colour) {
    var count = 0;
    for (var y = _from; y <= _to; y++) {
      for (var x = _area._left; x < _area._right; x++) {
        final pixel = _area._at(x, y);
        if ((pixel.r - colour.r).abs() < 0.02 &&
            (pixel.g - colour.g).abs() < 0.02 &&
            (pixel.b - colour.b).abs() < 0.02) {
          count++;
        }
      }
    }
    return count;
  }
}
