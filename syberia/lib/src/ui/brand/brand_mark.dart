import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'brand_canvas.dart';
import 'brand_events.dart';
import 'keyframes.dart';

/// The book mark's shapes, in the 200-unit square of the supplied SVG
/// (assets/branding/source).
abstract final class MarkShapes {
  static final tile = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, 200, 200),
    const Radius.circular(45),
  );

  static final cover = Path()
    ..moveTo(100, 162)
    ..quadraticBezierTo(68, 146, 30, 148)
    ..lineTo(30, 84)
    ..lineTo(36, 84)
    ..lineTo(36, 138)
    ..quadraticBezierTo(68, 136, 98, 152)
    ..lineTo(102, 152)
    ..quadraticBezierTo(132, 136, 164, 138)
    ..lineTo(164, 84)
    ..lineTo(170, 84)
    ..lineTo(170, 148)
    ..quadraticBezierTo(132, 146, 100, 162)
    ..close();

  static final left = Path()
    ..moveTo(98, 152)
    ..quadraticBezierTo(68, 136, 36, 138)
    ..lineTo(36, 84)
    ..lineTo(64, 54)
    ..lineTo(98, 86)
    ..close();

  static final right = Path()
    ..moveTo(102, 152)
    ..quadraticBezierTo(132, 136, 164, 138)
    ..lineTo(164, 72)
    ..lineTo(138, 42)
    ..lineTo(102, 86)
    ..close();

  static final pages = Path()
    ..addPath(left, Offset.zero)
    ..addPath(right, Offset.zero);

  static final star = Path()
    ..moveTo(78, 20)
    ..lineTo(80.5, 27.5)
    ..lineTo(88, 30)
    ..lineTo(80.5, 32.5)
    ..lineTo(78, 40)
    ..lineTo(75.5, 32.5)
    ..lineTo(68, 30)
    ..lineTo(75.5, 27.5)
    ..close();

  static const starCentre = Offset(78, 30);

  /// The red of the waving flag: a wave along y = 100, 60 units long.
  static final wave = () {
    final path = Path()
      ..moveTo(-10, 100)
      ..quadraticBezierTo(5, 94, 20, 100);
    for (var x = 20.0, up = false; x < 260; x += 30, up = !up) {
      path.quadraticBezierTo(x + 15, up ? 94 : 106, x + 30, 100);
    }
    return path
      ..lineTo(260, 170)
      ..lineTo(-10, 170)
      ..close();
  }();

  /// The lines written on the constitution's pages.
  static final lines = [
    for (final (x0, y0, x1, y1, x2, y2) in const [
      (46.0, 96.0, 68.0, 94.0, 94.0, 108.0),
      (44.0, 110.0, 68.0, 108.0, 94.0, 122.0),
      (42.0, 124.0, 68.0, 122.0, 94.0, 136.0),
      (106.0, 108.0, 132.0, 94.0, 158.0, 96.0),
      (106.0, 122.0, 132.0, 108.0, 158.0, 110.0),
      (106.0, 136.0, 132.0, 122.0, 158.0, 124.0),
    ])
      Path()
        ..moveTo(x0, y0)
        ..quadraticBezierTo(x1, y1, x2, y2),
  ];

  static final tail = Path()
    ..moveTo(84, 23)
    ..lineTo(136, 4)
    ..lineTo(89, 33)
    ..close();

  static final bookmark = Path()
    ..moveTo(96, 150)
    ..lineTo(104, 150)
    ..lineTo(104, 178)
    ..lineTo(100, 173)
    ..lineTo(96, 178)
    ..close();
}

/// The colours of a mark.
typedef MarkColors = ({
  Color tile,
  Color cover,
  Color left,
  Color right,
  Color star,
});

/// The book mark as [event] draws it at [phase] of its animation.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
    required this.event,
    required this.phase,
    required this.dark,
  });

  final BrandEvent event;
  final double phase;
  final bool dark;

  static const _cycle = Duration(seconds: 6);

  static MarkColors colours(BrandEvent event, bool dark) => switch (event) {
    BrandEvent.plConstitution =>
      dark
          ? (
              tile: const Color(0xFF1F1517),
              cover: const Color(0xFFB23A4A),
              left: const Color(0xFFF7EDD3),
              right: const Color(0xFFDCC58F),
              star: const Color(0xFFF2C94C),
            )
          : (
              tile: const Color(0xFFF1E9DA),
              cover: const Color(0xFF8E1B2C),
              left: const Color(0xFFF7EDD3),
              right: const Color(0xFFEAD9AE),
              star: const Color(0xFFC9961A),
            ),
    BrandEvent.plIndependence => (
      tile: dark ? const Color(0xFF0C1C27) : const Color(0xFFE3EEF2),
      cover: dark ? const Color(0xFF3E7A92) : const Color(0xFF0B3A4F),
      left: const Color(0xFFFFFFFF),
      right: _red,
      star: const Color(0xFFFFFFFF),
    ),
    BrandEvent.uaIndependence =>
      dark
          ? (
              tile: const Color(0xFF0C1C27),
              cover: const Color(0xFF5B8FD6),
              left: const Color(0xFF9CC3F5),
              right: const Color(0xFF6FA8EE),
              star: const Color(0xFFFFD24A),
            )
          : (
              tile: const Color(0xFFE3EEF2),
              cover: const Color(0xFF0B2E5C),
              left: const Color(0xFF2F6FC4),
              right: const Color(0xFF0057B7),
              star: const Color(0xFFFFC72C),
            ),
    BrandEvent.christmas =>
      dark
          ? (
              tile: const Color(0xFF0C1C27),
              cover: const Color(0xFF3F8F6B),
              left: const Color(0xFFFFFFFF),
              right: const Color(0xFFCFE6DA),
              star: const Color(0xFFF2C94C),
            )
          : (
              tile: const Color(0xFFD3E4EC),
              cover: const Color(0xFF1E4D3A),
              left: const Color(0xFFFFFFFF),
              right: const Color(0xFFE3EFE8),
              star: const Color(0xFFE5A21A),
            ),
    BrandEvent.newYear => (
      tile: dark ? const Color(0xFF16224A) : const Color(0xFF101C3D),
      cover: const Color(0xFFC9A227),
      left: const Color(0xFFF4D77A),
      right: const Color(0xFFE3B93C),
      star: const Color(0xFFFFF4D6),
    ),
    _ =>
      dark
          ? (
              tile: const Color(0xFF0C1C27),
              cover: const Color(0xFF3E7A92),
              left: const Color(0xFFFFFFFF),
              right: const Color(0xFF9FCDE0),
              star: const Color(0xFFF2B544),
            )
          : (
              tile: const Color(0xFFE3EEF2),
              cover: const Color(0xFF0B3A4F),
              left: const Color(0xFF176B8F),
              right: const Color(0xFF0F4C66),
              star: const Color(0xFFE59A2E),
            ),
  };

  static const _red = Color(0xFFDC143C);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 200);
    final c = colours(event, dark);
    switch (event) {
      case BrandEvent.ordinary:
        _tile(canvas, c.tile);
        _book(canvas, c);
        _fill(canvas, MarkShapes.star, c.star);
      case BrandEvent.schoolStart:
        _schoolStart(canvas, c);
      case BrandEvent.plFlag:
        _popped(canvas, () => _plFlag(canvas, c));
      case BrandEvent.plConstitution:
        _plConstitution(canvas, c);
      case BrandEvent.plIndependence:
        _plIndependence(canvas, c);
      case BrandEvent.uaFlag:
        _popped(canvas, () => _uaFlag(canvas, c));
      case BrandEvent.uaIndependence:
        _uaIndependence(canvas, c);
      case BrandEvent.christmas:
        _popped(canvas, () => _christmas(canvas, c));
      case BrandEvent.newYear:
        _popped(canvas, () => _newYear(canvas, c));
    }
    canvas.restore();
  }

  // The whole mark pops in and shrinks away, as the supplied animation's.
  static const _popScale = Track([
    KF(0, 0.6),
    KF(0.08, 1.06),
    KF(0.13, 1),
    KF(0.88, 1, Css.leave),
    KF(0.97, 0.6),
    KF(1, 0.6),
  ], Css.pop);
  static const _popOpacity = Track([
    KF(0, 0),
    KF(0.08, 1),
    KF(0.13, 1),
    KF(0.88, 1, Css.leave),
    KF(0.97, 0),
    KF(1, 0),
  ], Css.pop);

  void _popped(Canvas canvas, VoidCallback draw) => canvas.faded(
    _popOpacity.at(phase),
    () =>
        canvas.moved(const Offset(100, 100), draw, scale: _popScale.at(phase)),
  );

  void _book(Canvas canvas, MarkColors c) {
    _fill(canvas, MarkShapes.cover, c.cover);
    _fill(canvas, MarkShapes.left, c.left);
    _fill(canvas, MarkShapes.right, c.right);
  }

  // 1 September: the book opens from its spine, the star spins in.
  static const _coverOpen = Track([
    KF(0, 0),
    KF(0.04, 0),
    KF(0.14, 1),
    KF(0.88, 1, Css.leave),
    KF(0.96, 0),
    KF(1, 0),
  ], Css.pop);
  static const _pageOpen = Track([
    KF(0, 0),
    KF(0.10, 0),
    KF(0.24, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.pop);
  static const _starInScale = Track([
    KF(0, 0),
    KF(0.26, 0),
    KF(0.34, 1.35),
    KF(0.40, 1),
    KF(0.84, 1, Css.leave),
    KF(0.90, 0),
    KF(1, 0),
  ], Css.pop);
  static const _starInTurn = Track([
    KF(0, -120),
    KF(0.26, -120),
    KF(0.34, 12),
    KF(0.40, 0),
    KF(0.84, 0, Css.leave),
    KF(0.90, 90),
    KF(1, 90),
  ], Css.pop);
  static const _starInOpacity = Track([
    KF(0, 0),
    KF(0.26, 0),
    KF(0.34, 1),
    KF(0.84, 1, Css.leave),
    KF(0.90, 0),
    KF(1, 0),
  ], Css.pop);

  void _schoolStart(Canvas canvas, MarkColors c) {
    _tile(canvas, c.tile);
    canvas.moved(
      const Offset(100, 162),
      () => _fill(canvas, MarkShapes.cover, c.cover),
      scaleY: _coverOpen.at(phase),
    );
    canvas.moved(
      const Offset(98, 103),
      () => _fill(canvas, MarkShapes.left, c.left),
      scaleX: _pageOpen.at(phase),
    );
    canvas.moved(
      const Offset(102, 97),
      () => _fill(canvas, MarkShapes.right, c.right),
      scaleX: _pageOpen.at(
        delayed(phase, const Duration(milliseconds: 150), _cycle),
      ),
    );
    canvas.faded(
      _starInOpacity.at(phase),
      () => canvas.moved(
        MarkShapes.starCentre,
        () => _fill(canvas, MarkShapes.star, c.star),
        scale: _starInScale.at(phase),
        turn: _starInTurn.at(phase),
      ),
    );
  }

  // 2 May: the pages are the flag, waving.
  void _plFlag(Canvas canvas, MarkColors c) {
    _tile(canvas, c.tile);
    _fill(canvas, MarkShapes.cover, c.cover);
    canvas.save();
    canvas.clipPath(MarkShapes.pages);
    canvas.drawRect(
      const Rect.fromLTWH(30, 36, 140, 124),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final along =
        -60 * looping(phase, const Duration(milliseconds: 1400), _cycle);
    canvas.drawPath(
      MarkShapes.wave.shift(Offset(along, 0)),
      Paint()..color = _red,
    );
    canvas.restore();
    _fill(canvas, MarkShapes.star, c.star);
  }

  // 3 May: lines write themselves on the pages, the star seals them.
  static const _bookDrop = Track([
    KF(0, -18),
    KF(0.02, -18),
    KF(0.14, 0),
    KF(0.88, 0, Css.leave),
    KF(0.97, 10),
    KF(1, 10),
  ], Css.pop);
  static const _bookDropOpacity = Track([
    KF(0, 0),
    KF(0.02, 0),
    KF(0.14, 1),
    KF(0.88, 1, Css.leave),
    KF(0.97, 0),
    KF(1, 0),
  ], Css.pop);
  static const _lineLeft = Track([
    KF(0, 1),
    KF(0.16, 1),
    KF(0.28, 0),
    KF(0.86, 0, Css.leave),
    KF(0.94, 1),
    KF(1, 1),
  ], Css.easeInOut);
  static const _sealScale = Track([
    KF(0, 0),
    KF(0.46, 0),
    KF(0.53, 1.5),
    KF(0.59, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.settle);
  static const _sealOpacity = Track([
    KF(0, 0),
    KF(0.46, 0),
    KF(0.53, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.settle);
  static const _sealGlowScale = Track([
    KF(0, 0.4),
    KF(0.51, 0.4),
    KF(0.74, 2.4),
    KF(1, 2.4),
  ], Css.easeOut);
  static const _sealGlowOpacity = Track([
    KF(0, 0),
    KF(0.51, 0),
    KF(0.56, 0.5),
    KF(0.74, 0),
    KF(1, 0),
  ], Css.easeOut);

  void _plConstitution(Canvas canvas, MarkColors c) {
    _tile(canvas, c.tile);
    canvas.faded(
      _bookDropOpacity.at(phase),
      () => canvas.moved(Offset.zero, () {
        _book(canvas, c);
        final ink = Paint()
          ..color = const Color(0xFF8E1B2C).withValues(alpha: dark ? 0.4 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        for (final (index, line) in MarkShapes.lines.indexed) {
          final left = _lineLeft.at(
            delayed(phase, Duration(milliseconds: 300 * index), _cycle),
          );
          canvas.drawPart(line, 1 - left, ink);
        }
      }, move: Offset(0, _bookDrop.at(phase))),
    );
    canvas.moved(MarkShapes.starCentre, () {
      canvas.faded(
        _sealGlowOpacity.at(phase),
        () => canvas.moved(
          MarkShapes.starCentre,
          () => canvas.drawCircle(
            MarkShapes.starCentre,
            12,
            Paint()
              ..color = dark
                  ? const Color(0xFFF2C94C)
                  : const Color(0xFFE5B13A),
          ),
          scale: _sealGlowScale.at(phase),
        ),
      );
      canvas.faded(
        _sealOpacity.at(phase),
        () => canvas.moved(
          MarkShapes.starCentre,
          () => _fill(canvas, MarkShapes.star, c.star),
          scale: _sealScale.at(phase),
        ),
      );
    }, scale: 1.25);
  }

  // 11 November: the book rises; a cockade arcs up in place of the star.
  static const _bookRise = Track([
    KF(0, 28),
    KF(0.04, 28),
    KF(0.18, 0),
    KF(0.86, 0, Css.leave),
    KF(0.94, 14),
    KF(1, 14),
  ], Css.pop);
  static const _bookRiseOpacity = Track([
    KF(0, 0),
    KF(0.04, 0),
    KF(0.18, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.pop);
  static const _cockadeX = Track([
    KF(0, 64),
    KF(0.16, 64),
    KF(0.36, 0),
    KF(1, 0),
  ], Css.settle);
  static const _cockadeY = Track([
    KF(0, 120),
    KF(0.16, 120),
    KF(0.36, 0),
    KF(0.84, 0, Css.leave),
    KF(0.92, -30),
    KF(1, -30),
  ], Css.settle);
  static const _cockadeScale = Track([
    KF(0, 0.4),
    KF(0.16, 0.4),
    KF(0.36, 1.35),
    KF(0.42, 1),
    KF(0.48, 1.15),
    KF(0.54, 1),
    KF(0.84, 1, Css.leave),
    KF(0.92, 0.6),
    KF(1, 0.6),
  ], Css.settle);
  static const _cockadeTurn = Track([
    KF(0, -180),
    KF(0.16, -180),
    KF(0.36, 0),
    KF(1, 0),
  ], Css.settle);
  static const _cockadeOpacity = Track([
    KF(0, 0),
    KF(0.16, 0),
    KF(0.36, 1),
    KF(0.84, 1, Css.leave),
    KF(0.92, 0),
    KF(1, 0),
  ], Css.settle);

  void _plIndependence(Canvas canvas, MarkColors c) {
    _tile(canvas, c.tile);
    canvas.faded(
      _bookRiseOpacity.at(phase),
      () => canvas.moved(
        Offset.zero,
        () => _book(canvas, c),
        move: Offset(0, _bookRise.at(phase)),
      ),
    );
    canvas.faded(
      _cockadeOpacity.at(phase),
      () => canvas.moved(
        MarkShapes.starCentre,
        () => _cockade(canvas),
        move: Offset(_cockadeX.at(phase), _cockadeY.at(phase)),
        scale: _cockadeScale.at(phase),
        turn: _cockadeTurn.at(phase),
      ),
    );
  }

  void _cockade(Canvas canvas) {
    const centre = MarkShapes.starCentre;
    canvas.drawCircle(centre, 13, Paint()..color = const Color(0xFFFFFFFF));
    // Pleats: dashes of 1.2 with gaps of 1.6 around the ring.
    const radius = 10.4;
    final pleat = Paint()
      ..color = dark ? const Color(0xFFDDE3E6) : const Color(0xFFD3DADE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final ring = Rect.fromCircle(center: centre, radius: radius);
    for (var along = 0.0; along < 2 * math.pi * radius; along += 2.8) {
      canvas.drawArc(ring, along / radius, 1.2 / radius, false, pleat);
    }
    canvas.drawCircle(centre, 7, Paint()..color = _red);
  }

  // 23 August: the flag is hoisted up the empty pages.
  static const _hoist = Track([
    KF(0, 124),
    KF(0.12, 124, Css.hoist),
    KF(0.34, 0),
    KF(0.88, 0, Css.leave),
    KF(0.96, 124),
    KF(1, 124),
  ], Css.rise);
  static const _hoistStarScale = Track([
    KF(0, 0),
    KF(0.32, 0),
    KF(0.39, 1.4),
    KF(0.45, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.settle);
  static const _hoistStarTurn = Track([
    KF(0, -90),
    KF(0.32, -90),
    KF(0.39, 10),
    KF(0.45, 0),
    KF(1, 0),
  ], Css.settle);
  static const _hoistStarOpacity = Track([
    KF(0, 0),
    KF(0.32, 0),
    KF(0.39, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.settle);

  void _uaFlag(Canvas canvas, MarkColors c) {
    _tile(canvas, c.tile);
    _fill(canvas, MarkShapes.cover, c.cover);
    _fill(
      canvas,
      MarkShapes.left,
      dark ? const Color(0xFF163042) : const Color(0xFFF4F7F9),
    );
    _fill(
      canvas,
      MarkShapes.right,
      dark ? const Color(0xFF122838) : const Color(0xFFEAF0F3),
    );
    canvas.save();
    canvas.clipPath(MarkShapes.pages);
    canvas.translate(0, _hoist.at(phase));
    canvas.drawRect(
      const Rect.fromLTWH(30, 36, 140, 64),
      Paint()..color = dark ? const Color(0xFF2E7DE0) : const Color(0xFF0057B7),
    );
    canvas.drawRect(
      const Rect.fromLTWH(30, 100, 140, 60),
      Paint()..color = const Color(0xFFFFD700),
    );
    canvas.restore();
    canvas.faded(
      _hoistStarOpacity.at(phase),
      () => canvas.moved(
        MarkShapes.starCentre,
        () => _fill(canvas, MarkShapes.star, c.star),
        scale: _hoistStarScale.at(phase),
        turn: _hoistStarTurn.at(phase),
      ),
    );
  }

  // 24 August: a sunflower opens in place of the star.
  static const _bookFade = Track([
    KF(0, 0),
    KF(0.08, 1),
    KF(0.88, 1, Css.leave),
    KF(0.96, 0),
    KF(1, 0),
  ], Css.ease);
  static const _sunTurn = Track([
    KF(0, -90),
    KF(0.04, -90),
    KF(0.30, 0),
    KF(0.86, 0, Css.leave),
    KF(0.96, 40),
    KF(1, 40),
  ], Css.pop);
  static const _sunScale = Track([
    KF(0, 0.6),
    KF(0.04, 0.6),
    KF(0.30, 1),
    KF(0.86, 1, Css.leave),
    KF(0.96, 0.6),
    KF(1, 0.6),
  ], Css.pop);
  static const _sunOpacity = Track([
    KF(0, 0),
    KF(0.04, 0),
    KF(0.08, 1),
    KF(0.86, 1, Css.leave),
    KF(0.96, 0),
    KF(1, 0),
  ], Css.pop);
  static const _petal = Track([
    KF(0, 0),
    KF(0.08, 0),
    KF(0.22, 1.15),
    KF(0.28, 1),
    KF(0.86, 1, Css.leave),
    KF(0.96, 0),
    KF(1, 0),
  ], Css.pop);
  static const _seeds = Track([
    KF(0, 0),
    KF(0.10, 0),
    KF(0.18, 1.25),
    KF(0.24, 1),
    KF(0.86, 1, Css.leave),
    KF(0.96, 0),
    KF(1, 0),
  ], Css.settle);

  void _uaIndependence(Canvas canvas, MarkColors c) {
    _tile(canvas, c.tile);
    canvas.faded(_bookFade.at(phase), () => _book(canvas, c));
    const centre = Offset(78, 28);
    canvas.faded(
      _sunOpacity.at(phase),
      () => canvas.moved(
        centre,
        () {
          final petal = Paint()..color = c.star;
          for (var index = 0; index < 12; index++) {
            final grown = _petal.at(
              delayed(phase, Duration(milliseconds: 40 * index), _cycle),
            );
            if (grown <= 0) continue;
            canvas.save();
            canvas.translate(centre.dx, centre.dy);
            canvas.rotate(index * math.pi / 6);
            // Each petal grows from its end nearest the middle.
            canvas.translate(0, -3.5);
            canvas.scale(grown);
            canvas.translate(0, 3.5);
            canvas.drawOval(
              Rect.fromCenter(
                center: const Offset(0, -10),
                width: 6.8,
                height: 13,
              ),
              petal,
            );
            canvas.restore();
          }
          canvas.moved(centre, () {
            canvas.drawCircle(
              centre,
              6.5,
              Paint()
                ..color = dark
                    ? const Color(0xFF6B3E1E)
                    : const Color(0xFF5A3212),
            );
            canvas.drawCircle(
              centre,
              3.4,
              Paint()..color = const Color(0xFF3A1F0A),
            );
          }, scale: _seeds.at(phase));
        },
        scale: _sunScale.at(phase),
        turn: _sunTurn.at(phase),
      ),
    );
  }

  // Christmas: snow falls, a star with a tail flies in and shines.
  static const _flakes = [
    (38.0, 28.0, 2.2, -400, 4800),
    (150.0, 58.0, 1.8, -2100, 5600),
    (122.0, 18.0, 2.0, -3300, 4800),
    (28.0, 72.0, 1.6, -1500, 5200),
    (176.0, 34.0, 2.2, -4100, 4800),
    (56.0, 12.0, 1.6, -2700, 6000),
    (184.0, 96.0, 1.6, -900, 5400),
    (16.0, 104.0, 1.8, -3800, 4800),
    (96.0, 10.0, 1.5, -1100, 5800),
    (160.0, 12.0, 1.7, -4600, 5100),
  ];
  static const _flakeOpacity = Track([
    KF(0, 0),
    KF(0.10, 1),
    KF(0.88, 1, Css.leave),
    KF(1, 0),
  ]);
  static const _cometX = Track([
    KF(0, 60),
    KF(0.10, 60),
    KF(0.26, 0),
    KF(1, 0),
  ], Css.pop);
  static const _cometY = Track([
    KF(0, -44),
    KF(0.10, -44),
    KF(0.26, 0),
    KF(1, 0),
  ], Css.pop);
  static const _cometScale = Track([
    KF(0, 0.5),
    KF(0.10, 0.5),
    KF(0.26, 1.05),
    KF(0.30, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0.8),
    KF(1, 0.8),
  ], Css.pop);
  static const _cometOpacity = Track([
    KF(0, 0),
    KF(0.10, 0),
    KF(0.26, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.pop);
  static const _tailOpacity = Track([
    KF(0, 0),
    KF(0.12, 0),
    KF(0.22, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.ease);
  static const _shineScale = Track([
    KF(0, 0.4),
    KF(0.26, 0.4),
    KF(0.46, 2.2),
    KF(0.58, 0.4),
    KF(0.78, 2),
    KF(1, 2),
  ], Css.easeInOut);
  static const _shineOpacity = Track([
    KF(0, 0),
    KF(0.26, 0),
    KF(0.32, 0.55),
    KF(0.46, 0),
    KF(0.58, 0),
    KF(0.64, 0.4),
    KF(0.78, 0),
    KF(1, 0),
  ], Css.easeInOut);

  /// The middle of the comet: its tail and the star, enlarged.
  static final _cometCentre = MarkShapes.tail
      .getBounds()
      .expandToInclude(
        Rect.fromCenter(
          center: MarkShapes.starCentre,
          width: 20 * 1.35,
          height: 20 * 1.35,
        ),
      )
      .center;

  void _christmas(Canvas canvas, MarkColors c) {
    _tile(canvas, c.tile);
    canvas.save();
    canvas.clipRRect(MarkShapes.tile);
    final flake = Paint();
    for (final (x, y, radius, delay, period) in _flakes) {
      final fall = looping(
        phase,
        Duration(milliseconds: period),
        _cycle,
        delay: Duration(milliseconds: delay),
      );
      flake.color = const Color(0xFFFFFFFF)
          .withValues(alpha: _flakeOpacity.at(fall));
      canvas.drawCircle(Offset(x, y - 120 + 240 * fall), radius, flake);
    }
    canvas.restore();
    _book(canvas, c);
    _fill(
      canvas,
      MarkShapes.bookmark,
      dark ? const Color(0xFFE0314B) : const Color(0xFFC8102E),
    );
    canvas.faded(
      _cometOpacity.at(phase),
      () => canvas.moved(
        _cometCentre,
        () {
          canvas.faded(
            _tailOpacity.at(phase),
            () => canvas.drawPath(
              MarkShapes.tail,
              Paint()
                ..shader = ui.Gradient.linear(
                  const Offset(84, 28),
                  const Offset(136, 4),
                  [c.star.withValues(alpha: 0.9), c.star.withValues(alpha: 0)],
                ),
            ),
          );
          canvas.moved(MarkShapes.starCentre, () {
            canvas.faded(
              _shineOpacity.at(phase),
              () => canvas.moved(
                MarkShapes.starCentre,
                () => canvas.drawCircle(
                  MarkShapes.starCentre,
                  10,
                  Paint()..color = const Color(0xFFF2C94C),
                ),
                scale: _shineScale.at(phase),
              ),
            );
            _fill(canvas, MarkShapes.star, c.star);
          }, scale: 1.35);
        },
        move: Offset(_cometX.at(phase), _cometY.at(phase)),
        scale: _cometScale.at(phase),
      ),
    );
  }

  // New Year: the star shoots up, bursts into sparks and gathers again.
  static const _trailLeft = Track([
    KF(0, 1),
    KF(0.10, 1),
    KF(0.22, 0),
    KF(1, 0),
  ], Css.easeOut);
  static const _trailOpacity = Track([
    KF(0, 1),
    KF(0.22, 1),
    KF(0.30, 0),
    KF(1, 0),
  ], Css.easeOut);
  static const _sparkOut = Track([
    KF(0, 0),
    KF(0.23, 0),
    KF(0.36, -12),
    KF(0.42, -16),
    KF(0.44, -14),
    KF(0.52, 0),
    KF(1, 0),
  ], Css.pop);
  static const _sparkOpacity = Track([
    KF(0, 0),
    KF(0.23, 0),
    KF(0.25, 1),
    KF(0.36, 1),
    KF(0.42, 0),
    KF(0.44, 0),
    KF(0.46, 0.9),
    KF(0.52, 0),
    KF(1, 0),
  ], Css.pop);
  static const _dotOut = Track([
    KF(0, 0),
    KF(0.60, 0),
    KF(0.72, -9),
    KF(1, 0),
  ], Css.easeOut);
  static const _dotOpacity = Track([
    KF(0, 0),
    KF(0.60, 0),
    KF(0.62, 1),
    KF(0.72, 0),
    KF(1, 0),
  ], Css.easeOut);
  static const _rocketX = Track([
    KF(0, 22),
    KF(0.10, 22),
    KF(0.22, 0),
    KF(1, 0),
  ], Css.settle);
  static const _rocketY = Track([
    KF(0, 74),
    KF(0.10, 74),
    KF(0.22, 0),
    KF(1, 0),
  ], Css.settle);
  static const _rocketScale = Track([
    KF(0, 0.6),
    KF(0.10, 0.6),
    KF(0.22, 1),
    KF(0.24, 1.6),
    KF(0.27, 0),
    KF(0.42, 0),
    KF(0.52, 1.25),
    KF(0.58, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0.6),
    KF(1, 0.6),
  ], Css.settle);
  static const _rocketOpacity = Track([
    KF(0, 0),
    KF(0.10, 0),
    KF(0.12, 1),
    KF(0.24, 1),
    KF(0.27, 0),
    KF(0.42, 0),
    KF(0.52, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.settle);

  void _newYear(Canvas canvas, MarkColors c) {
    _tile(canvas, c.tile);
    _book(canvas, c);
    const gold = Color(0xFFF2C94C);
    canvas.faded(
      _trailOpacity.at(phase),
      () => canvas.drawPart(
        Path()
          ..moveTo(100, 104)
          ..lineTo(78, 30),
        1 - _trailLeft.at(phase),
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      ),
    );
    final spark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final out = _sparkOut.at(phase);
    spark.color = gold.withValues(alpha: _sparkOpacity.at(phase));
    for (var index = 0; index < 8; index++) {
      canvas.save();
      canvas.translate(78, 30);
      canvas.rotate(index * math.pi / 4);
      canvas.drawLine(Offset(0, -8 + out), Offset(0, -14 + out), spark);
      canvas.restore();
    }
    void burst(
      Offset centre,
      double radius,
      int count,
      double first,
      double size,
      Duration delay,
    ) {
      final local = delayed(phase, delay, _cycle);
      final dot = Paint()
        ..color = gold.withValues(alpha: _dotOpacity.at(local));
      for (var index = 0; index < count; index++) {
        canvas.save();
        canvas.translate(centre.dx, centre.dy);
        canvas.rotate(first + index * 2 * math.pi / count);
        canvas.drawCircle(Offset(0, -radius + _dotOut.at(local)), size, dot);
        canvas.restore();
      }
    }

    burst(const Offset(152, 26), 4, 6, 0, 1.8, Duration.zero);
    burst(
      const Offset(36, 24),
      4,
      3,
      math.pi / 6,
      1.6,
      const Duration(milliseconds: 500),
    );
    canvas.faded(
      _rocketOpacity.at(phase),
      () => canvas.moved(
        MarkShapes.starCentre,
        () => _fill(canvas, MarkShapes.star, c.star),
        move: Offset(_rocketX.at(phase), _rocketY.at(phase)),
        scale: _rocketScale.at(phase),
      ),
    );
  }

  static void _tile(Canvas canvas, Color colour) =>
      canvas.drawRRect(MarkShapes.tile, Paint()..color = colour);

  static void _fill(Canvas canvas, Path path, Color colour) =>
      canvas.drawPath(path, Paint()..color = colour);

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.event != event ||
      oldDelegate.phase != phase ||
      oldDelegate.dark != dark;
}
