import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syberia/src/ui/glass/glass_material.dart';
import 'package:syberia/src/ui/glass/glass_modals.dart';
import 'package:syberia/src/ui/glass/glass_plate.dart';

/// A colour of this app's pages and what UIKit's glass on iOS 26 shows of it,
/// read off screenshots of the iPhone app.
typedef _Sample = ({Color page, Color seen});

_Sample _sample(int page, int seen) =>
    (page: Color(0xFF000000 | page), seen: Color(0xFF000000 | seen));

/// The lesson blocks of the timetable, a card and the page itself.
final _underLightPanel = [
  _sample(0xD83224, 0xE0D1DE),
  _sample(0xAD5B00, 0xD9D8D7),
  _sample(0x2446A8, 0xBED4F6),
  _sample(0x00796B, 0xBADDEC),
  _sample(0x7B1FA2, 0xCDCDF7),
  _sample(0xFFFFFF, 0xE9F0F6),
  _sample(0xF3F6F7, 0xE8EEF6),
];

final _underDarkPanel = [
  _sample(0xD83224, 0x2D1717),
  _sample(0xAD5B00, 0x251B11),
  _sample(0x2446A8, 0x131B2B),
  _sample(0x00796B, 0x0C2024),
  _sample(0x7B1FA2, 0x1E152C),
  _sample(0x1B2226, 0x13181B),
  _sample(0x101416, 0x141619),
];

/// A picture of the test's screen at three pixels a point, like the iPhone's
/// screenshots.
class _Picture {
  _Picture(this._bytes, this._width);

  static const double scale = 3;

  final ByteData _bytes;
  final int _width;

  /// The colour at [point], counted in points from the screen's middle.
  Color at(Offset point) {
    final size = Size(
      _width / scale,
      _bytes.lengthInBytes / 4 / _width / scale,
    );
    final spot = (size.center(Offset.zero) + point) * scale;
    final pixel = (spot.dy.floor() * _width + spot.dx.floor()) * 4;
    return Color.fromARGB(
      255,
      _bytes.getUint8(pixel),
      _bytes.getUint8(pixel + 1),
      _bytes.getUint8(pixel + 2),
    );
  }
}

void main() {
  /// Draws a piece of glass of [size] in the middle of a page of one colour.
  /// A panel comes up over a dimmed page.
  Future<_Picture> drawn(
    WidgetTester tester,
    GlassLook look,
    Color page, {
    bool dimmed = false,
    Size size = const Size.square(80),
    ShapeBorder shape = const RoundedRectangleBorder(),
  }) async {
    final screen = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: screen,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: page),
              if (dimmed) ColoredBox(color: glassBarrierColor),
              Center(
                child: SizedBox.fromSize(
                  size: size,
                  child: GlassPlate(look: look, shape: shape),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    late _Picture picture;
    await tester.runAsync(() async {
      final boundary =
          screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _Picture.scale);
      picture = _Picture((await image.toByteData())!, image.width);
      image.dispose();
    });
    return picture;
  }

  /// What shows in the middle of a piece of glass over a page of one colour.
  Future<Color> through(
    WidgetTester tester,
    GlassLook look,
    Color page, {
    bool dimmed = false,
  }) async => (await drawn(tester, look, page, dimmed: dimmed)).at(Offset.zero);

  /// Within [steps] of 255 on every channel.
  Matcher closeTo255(Color color, {int steps = 2}) => predicate<Color>(
    (seen) =>
        ((seen.r - color.r) * 255).abs() <= steps &&
        ((seen.g - color.g) * 255).abs() <= steps &&
        ((seen.b - color.b) * 255).abs() <= steps,
    'within $steps steps of $color',
  );

  testWidgets('the drawn tab bar shows the page the way iOS 26 does', (
    tester,
  ) async {
    expect(
      await through(
        tester,
        GlassMaterial.chrome(Brightness.light),
        const Color(0xFFF3F6F7),
      ),
      closeTo255(const Color(0xFFF8FAFB)),
    );
    expect(
      await through(
        tester,
        GlassMaterial.chrome(Brightness.dark),
        const Color(0xFF101416),
      ),
      closeTo255(const Color(0xFF16181A)),
    );
  });

  testWidgets('a drawn bar button shows the page the way iOS 26 does', (
    tester,
  ) async {
    expect(
      await through(
        tester,
        GlassMaterial.button(Brightness.light),
        const Color(0xFFF3F6F7),
      ),
      closeTo255(const Color(0xFFFAFCFD)),
    );
    expect(
      await through(
        tester,
        GlassMaterial.button(Brightness.dark),
        const Color(0xFF101416),
      ),
      closeTo255(const Color(0xFF15181A)),
    );
  });

  testWidgets('a drawn panel shows the page the way iOS 26 does', (
    tester,
  ) async {
    for (final (brightness, samples) in [
      (Brightness.light, _underLightPanel),
      (Brightness.dark, _underDarkPanel),
    ]) {
      for (final sample in samples) {
        expect(
          await through(
            tester,
            GlassMaterial.panel(brightness),
            sample.page,
            dimmed: true,
          ),
          closeTo255(sample.seen),
          reason: '${brightness.name} panel over ${sample.page}',
        );
      }
    }
  });

  testWidgets('the glint on a drawn button comes from the upper left', (
    tester,
  ) async {
    // The round menu button on the dark page. On iOS 26 its edge is
    // brightest towards the upper left and the lower right, half as bright
    // on the four sides, and has no glint where it faces the other two
    // corners.
    final picture = await drawn(
      tester,
      GlassMaterial.button(Brightness.dark),
      const Color(0xFF101416),
      size: const Size.square(44),
      shape: const StadiumBorder(),
    );
    // The brightest point of the edge in a direction, counted in degrees
    // anticlockwise from the right.
    Color edge(double degrees) {
      final turn = degrees * math.pi / 180;
      final outwards = Offset(math.cos(turn), -math.sin(turn));
      var brightest = const Color(0xFF000000);
      for (var inset = 0.0; inset <= 2; inset += 1 / 6) {
        final color = picture.at(outwards * (22 - inset));
        if (color.computeLuminance() > brightest.computeLuminance()) {
          brightest = color;
        }
      }
      return brightest;
    }

    const glass = Color(0xFF15181A);
    for (final degrees in [120.0, 150.0, 300.0, 330.0]) {
      expect(
        edge(degrees),
        closeTo255(const Color(0xFF373E41), steps: 4),
        reason: 'towards $degrees degrees',
      );
    }
    for (final degrees in [0.0, 90.0, 180.0, 270.0]) {
      expect(
        edge(degrees),
        closeTo255(const Color(0xFF303639), steps: 4),
        reason: 'towards $degrees degrees',
      );
    }
    for (final degrees in [45.0, 225.0]) {
      expect(
        edge(degrees),
        closeTo255(glass, steps: 2),
        reason: 'towards $degrees degrees',
      );
    }
  });

  testWidgets('glass that has not appeared yet leaves the page as it is', (
    tester,
  ) async {
    const page = Color(0xFF2446A8);
    for (final look in [
      GlassMaterial.chrome(Brightness.light),
      GlassMaterial.panel(Brightness.dark),
      GlassMaterial.lens(Brightness.light),
    ]) {
      expect(
        await through(tester, look.faded(0), page),
        closeTo255(page, steps: 0),
      );
    }
  });
}
