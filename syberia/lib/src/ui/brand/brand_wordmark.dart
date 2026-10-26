import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'brand_canvas.dart';
import 'brand_events.dart';
import 'keyframes.dart';

/// "SiberiaGB" in the supplied Unbounded wordmark, laid out once for a size:
/// where each letter is, and each letter ready to paint in a colour.
class WordmarkLayout {
  WordmarkLayout(this.fontSize) {
    _whole = TextPainter(
      text: TextSpan(
        children: [
          for (var index = 0; index < text.length; index++)
            TextSpan(text: text[index], style: _style(index, null)),
        ],
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    // Selection boxes reach the font's full ascent and descent, but each
    // letter is painted on the line, so its box spans the line instead.
    boxes = [
      for (var index = 0; index < text.length; index++)
        _onLine(
          _whole.getBoxesForSelection(
            TextSelection(baseOffset: index, extentOffset: index + 1),
          ),
        ),
    ];
    baseline = _whole.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }

  static const text = 'SiberiaGB';

  Rect _onLine(List<TextBox> selection) => Rect.fromLTRB(
    selection.first.left,
    0,
    selection.first.right,
    _whole.height,
  );

  final double fontSize;
  late final TextPainter _whole;
  late final List<Rect> boxes;
  late final double baseline;
  final _glyphs = <(int, int), TextPainter>{};

  Size get size => _whole.size;

  /// Where "GB" is.
  Rect get gb => boxes[7].expandToInclude(boxes[8]);

  TextStyle _style(int index, Color? colour) => TextStyle(
    fontFamily: 'Unbounded',
    fontSize: fontSize,
    letterSpacing: -0.03 * fontSize,
    height: 1,
    // As the mockups' line-height: 1 places the letters in the line, so
    // the colours split them where the mockups do.
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: index < 7 ? FontWeight.w700 : FontWeight.w500,
    color: colour,
  );

  /// Paints letter [index] in [colour], where the whole word puts it.
  void paintLetter(Canvas canvas, int index, Color colour) {
    final glyph = _glyphs.putIfAbsent(
      (index, colour.toARGB32()),
      () => TextPainter(
        text: TextSpan(text: text[index], style: _style(index, colour)),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(),
    );
    glyph.paint(canvas, boxes[index].topLeft);
  }

  void dispose() {
    _whole.dispose();
    for (final glyph in _glyphs.values) {
      glyph.dispose();
    }
    _glyphs.clear();
  }
}

/// The colours the wordmark is drawn in.
abstract final class WordmarkColours {
  static Color ink(bool dark) =>
      dark ? const Color(0xFFFFFFFF) : const Color(0xFF10222C);
  static Color brand(bool dark) =>
      dark ? const Color(0xFF6CC3E6) : const Color(0xFF176B8F);

  /// The white of the Polish flag: on a light background a pale silver,
  /// which white would vanish against.
  static Color white(bool dark) =>
      dark ? const Color(0xFFFFFFFF) : const Color(0xFFE3E7EA);
  static Color red(bool dark) =>
      dark ? const Color(0xFFE8354F) : const Color(0xFFDC143C);
  static Color blue(bool dark) =>
      dark ? const Color(0xFF2E7DE0) : const Color(0xFF0057B7);

  /// The yellow of the Ukrainian flag, a little deeper on a light background.
  static Color yellow(bool dark) =>
      dark ? const Color(0xFFFFD700) : const Color(0xFFF2C200);

  /// The colours "GB" rests in: (upper half, lower half).
  static (Color, Color) gb(BrandEvent event, bool dark) => switch (event) {
    BrandEvent.plFlag ||
    BrandEvent.plConstitution ||
    BrandEvent.plIndependence => (white(dark), red(dark)),
    BrandEvent.uaFlag ||
    BrandEvent.uaIndependence => (blue(dark), yellow(dark)),
    BrandEvent.christmas => (
      dark ? const Color(0xFF7FD1A8) : const Color(0xFF1E6B4A),
      dark ? const Color(0xFF7FD1A8) : const Color(0xFF1E6B4A),
    ),
    BrandEvent.newYear => (
      dark ? const Color(0xFFF2C94C) : const Color(0xFF9A6F00),
      dark ? const Color(0xFFF2C94C) : const Color(0xFF9A6F00),
    ),
    _ => (brand(dark), brand(dark)),
  };
}

/// The wordmark as [event] draws it at [phase] of its animation. Lengths
/// from the 48-point mockups scale with the size.
class BrandWordmarkPainter extends CustomPainter {
  const BrandWordmarkPainter({
    required this.event,
    required this.phase,
    required this.dark,
    required this.layout,
    this.accessories = false,
    this.clip = false,
  });

  final BrandEvent event;
  final double phase;
  final bool dark;
  final WordmarkLayout layout;

  /// Whether the detail by the name is drawn: on the large wordmark only.
  final bool accessories;

  /// Whether letters coming in from outside are hidden there, as in the
  /// mockups' frames.
  final bool clip;

  static const _cycle = Duration(seconds: 6);

  double get _k => layout.fontSize / 48;
  double get _width => layout.size.width;
  double get _height => layout.fontSize;
  Color get _ink => WordmarkColours.ink(dark);

  @override
  void paint(Canvas canvas, Size size) {
    switch (event) {
      case BrandEvent.ordinary:
        for (var index = 0; index < 9; index++) {
          layout.paintLetter(
            canvas,
            index,
            index < 7 ? _ink : WordmarkColours.brand(dark),
          );
        }
      case BrandEvent.schoolStart:
        _schoolStart(canvas);
      case BrandEvent.plFlag:
        _plFlag(canvas);
      case BrandEvent.plConstitution:
        _plConstitution(canvas);
      case BrandEvent.plIndependence:
        _plIndependence(canvas);
      case BrandEvent.uaFlag:
        _uaFlag(canvas);
      case BrandEvent.uaIndependence:
        _uaIndependence(canvas);
      case BrandEvent.christmas:
        _christmas(canvas);
      case BrandEvent.newYear:
        _newYear(canvas);
    }
  }

  /// Inside the frame the mockup clips the word to, when [clip] is on.
  void _framed(Canvas canvas, EdgeInsets outside, VoidCallback draw) {
    if (!clip) return draw();
    canvas.clipped(
      Rect.fromLTRB(
        -outside.left * _k,
        -outside.top * _k,
        _width + outside.right * _k,
        _height + outside.bottom * _k,
      ),
      draw,
    );
  }

  /// Paints letter [index] in [upper], and in [lower] inside [lowerArea].
  void _twoTone(
    Canvas canvas,
    int index,
    Color upper,
    Color lower,
    Path lowerArea,
  ) {
    layout.paintLetter(canvas, index, upper);
    canvas.save();
    canvas.clipPath(lowerArea);
    layout.paintLetter(canvas, index, lower);
    canvas.restore();
  }

  /// The lower part of letter [index], from [fraction] of its height down.
  Path _below(int index, double fraction) {
    final box = layout.boxes[index];
    return Path()..addRect(
      Rect.fromLTRB(
        box.left - _height,
        box.top + _height * fraction,
        box.right + _height,
        box.bottom + _height,
      ),
    );
  }

  // 1 September: the name is revealed from the left; a mortarboard drops
  // onto the B.
  static const _a1Reveal = Track([
    KF(0, 0),
    KF(0.36, 0),
    KF(0.54, 1),
    KF(0.82, 1, Css.leave),
    KF(0.92, 0),
    KF(1, 0),
  ], Css.reveal);
  static const _capDrop = Track([
    KF(0, -46),
    KF(0.52, -46),
    KF(0.60, 3),
    KF(0.64, -6),
    KF(0.68, 0),
    KF(0.76, 0, Css.leave),
    KF(0.82, -14),
    KF(1, -14),
  ], Css.pop);
  static const _capTurn = Track([
    KF(0, -25),
    KF(0.52, -25),
    KF(0.60, 4),
    KF(0.64, -2),
    KF(0.68, 0),
    KF(0.76, 0, Css.leave),
    KF(0.82, -10),
    KF(1, -10),
  ], Css.pop);
  static const _capOpacity = Track([
    KF(0, 0),
    KF(0.52, 0),
    KF(0.54, 1),
    KF(0.76, 1, Css.leave),
    KF(0.82, 0),
    KF(1, 0),
  ], Css.pop);
  static const _tassel = Track([
    KF(0, 0),
    KF(0.63, 0),
    KF(0.66, 16),
    KF(0.69, -10),
    KF(0.72, 6),
    KF(0.75, 0),
    KF(1, 0),
  ], Css.easeInOut);

  void _schoolStart(Canvas canvas) {
    final shown = _a1Reveal.at(phase);
    final k = _k;
    canvas.clipped(
      Rect.fromLTRB(
        -4 * k,
        -6 * k,
        -4 * k + (_width + 8 * k) * shown,
        _height + 6 * k,
      ),
      () {
        for (var index = 0; index < 9; index++) {
          layout.paintLetter(
            canvas,
            index,
            index < 7 ? _ink : WordmarkColours.brand(dark),
          );
        }
      },
    );
    if (!accessories) return;
    final box = Rect.fromLTWH(
      _width + 20 * k - 44 * k,
      -18 * k,
      44 * k,
      34 * k,
    );
    canvas.faded(_capOpacity.at(phase), () {
      canvas.moved(box.center, () {
        canvas.save();
        canvas.translate(box.left, box.top);
        canvas.scale(k);
        canvas.moved(
          const Offset(22, 34),
          () {
            final base = dark
                ? const Color(0xFF3E7A92)
                : const Color(0xFF0B3A4F);
            final board = dark
                ? const Color(0xFF9FCDE0)
                : const Color(0xFF10222C);
            final gold = dark
                ? const Color(0xFFF2B544)
                : const Color(0xFFE59A2E);
            canvas.drawPath(
              Path()
                ..moveTo(10, 14)
                ..lineTo(10, 22)
                ..quadraticBezierTo(22, 28, 34, 22)
                ..lineTo(34, 14)
                ..lineTo(22, 19)
                ..close(),
              Paint()..color = base,
            );
            canvas.drawPath(
              Path()
                ..moveTo(22, 4)
                ..lineTo(42, 11)
                ..lineTo(22, 18)
                ..lineTo(2, 11)
                ..close(),
              Paint()..color = board,
            );
            canvas.drawCircle(const Offset(22, 11), 1.6, Paint()..color = gold);
            canvas.moved(const Offset(22, 11), () {
              canvas.drawPath(
                Path()
                  ..moveTo(22, 11)
                  ..lineTo(36, 13.5)
                  ..lineTo(36, 24),
                Paint()
                  ..color = gold
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.6
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round,
              );
              canvas.drawPath(
                Path()
                  ..moveTo(34.5, 23)
                  ..lineTo(37.5, 23)
                  ..lineTo(38.5, 29)
                  ..lineTo(33.5, 29)
                  ..close(),
                Paint()..color = gold,
              );
            }, turn: _tassel.at(phase));
          },
          move: Offset(0, _capDrop.at(phase)),
          turn: _capTurn.at(phase),
        );
        canvas.restore();
      }, turn: 14);
    });
  }

  // 2 May: the letters stand up with a wave; the line between white and red
  // in "GB" waves like the flag, and a little flag stands in the B.
  static const _p2Rise = Track([
    KF(0, 0.6),
    KF(0.16, 0.6),
    KF(0.28, -0.12),
    KF(0.36, 0),
    KF(0.82, 0, Css.leave),
    KF(0.92, -0.4),
    KF(1, -0.4),
  ], Css.pop);
  static const _p2Turn = Track([
    KF(0, -10),
    KF(0.16, -10),
    KF(0.28, 5),
    KF(0.36, 0),
    KF(1, 0),
  ], Css.pop);
  static const _p2Opacity = Track([
    KF(0, 0),
    KF(0.16, 0),
    KF(0.28, 1),
    KF(0.82, 1, Css.leave),
    KF(0.92, 0),
    KF(1, 0),
  ], Css.pop);
  static const _flagGrow = Track([
    KF(0, 0),
    KF(0.38, 0),
    KF(0.46, 1.08),
    KF(0.50, 1),
    KF(1, 1),
  ], Css.pop);
  static const _flagOpacity = Track([
    KF(0, 0),
    KF(0.38, 0),
    KF(0.39, 1),
    KF(0.84, 1, Css.leave),
    KF(0.92, 0),
    KF(1, 0),
  ], Css.pop);

  void _plFlag(Canvas canvas) {
    final (white, red) = WordmarkColours.gb(event, dark);
    final swing =
        1 -
        2 *
            alternating(
              phase,
              const Duration(milliseconds: 800),
              _cycle,
              curve: Css.easeInOut,
            );
    _framed(canvas, const EdgeInsets.fromLTRB(4, 40, 26, 10), () {
      for (var index = 0; index < 9; index++) {
        final local = delayed(
          phase,
          Duration(milliseconds: 60 * index),
          _cycle,
        );
        final box = layout.boxes[index];
        canvas.faded(_p2Opacity.at(local), () {
          canvas.moved(
            box.bottomCenter,
            () {
              if (index < 7) {
                layout.paintLetter(canvas, index, _ink);
                return;
              }
              // The wave along the middle of the letter, as eight segments.
              const offsets = [0.0, -0.07, 0, 0.07, 0, -0.07, 0, 0.07, 0];
              final wave = Path();
              for (var point = 0; point <= 8; point++) {
                final x = box.left + box.width * point / 8;
                final y = box.top + _height * (0.5 + offsets[point] * swing);
                point == 0 ? wave.moveTo(x, y) : wave.lineTo(x, y);
              }
              wave
                ..lineTo(box.right, box.bottom + _height)
                ..lineTo(box.left, box.bottom + _height)
                ..close();
              _twoTone(canvas, index, white, red, wave);
              if (index == 8 && accessories) _flag(canvas, box);
            },
            move: Offset(0, _p2Rise.at(local) * _height),
            turn: _p2Turn.at(local),
          );
        });
      }
    });
  }

  void _flag(Canvas canvas, Rect letter) {
    final k = _k;
    canvas.faded(_flagOpacity.at(phase), () {
      canvas.save();
      canvas.translate(letter.right + 19 * k - 30 * k, letter.top - 31 * k);
      canvas.scale(k);
      canvas.moved(const Offset(4.5, 36), () {
        canvas.drawLine(
          const Offset(3, 4),
          const Offset(3, 35),
          Paint()
            ..color = dark ? const Color(0xFF9FB3BE) : const Color(0xFF4A5D67)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          const Offset(3, 3),
          2,
          Paint()
            ..color = dark ? const Color(0xFFF2B544) : const Color(0xFFE59A2E),
        );
        final flutter = alternating(
          phase,
          const Duration(milliseconds: 1100),
          _cycle,
          curve: Css.easeInOut,
        );
        canvas.save();
        canvas.translate(4, 12);
        canvas.skew(0, math.tan((-8 + 14 * flutter) * math.pi / 180));
        canvas.scale(1 - 0.1 * flutter, 1);
        canvas.translate(-4, -12);
        canvas.drawRect(
          const Rect.fromLTWH(4, 5, 22, 7),
          Paint()..color = WordmarkColours.white(dark),
        );
        canvas.drawRect(
          const Rect.fromLTWH(4, 12, 22, 7),
          Paint()..color = WordmarkColours.red(dark),
        );
        canvas.restore();
      }, scaleY: _flagGrow.at(phase));
      canvas.restore();
    });
  }

  // 3 May: a quill writes the name, "GB" already in the flag's colours,
  // and lies down beside it.
  static const _p3Word = Track([
    KF(0, 0),
    KF(0.16, 0),
    KF(0.17, 1),
    KF(0.88, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ]);
  static const _p3Hidden = Track([
    KF(0, 1),
    KF(0.20, 1),
    KF(0.42, 0),
    KF(0.425, -0.1),
    KF(1, -0.1),
  ]);
  static const _p3Pen = Track([KF(0, 0), KF(0.20, 0), KF(0.42, 1), KF(1, 1)]);
  static const _quillX = Track([
    KF(0, 0),
    KF(0.42, 0),
    KF(0.48, 4),
    KF(1, 4),
  ], Css.easeInOut);
  static const _quillY = Track([
    KF(0, 0),
    KF(0.16, 0),
    KF(0.21, -3),
    KF(0.24, 2),
    KF(0.27, -2),
    KF(0.30, 2),
    KF(0.33, -2),
    KF(0.36, 1),
    KF(0.39, -1),
    KF(0.42, 0),
    KF(0.48, -4),
    KF(0.52, -2),
    KF(1, -2),
  ], Css.easeInOut);
  static const _quillTurn = Track([
    KF(0, 0),
    KF(0.16, 0),
    KF(0.21, -9),
    KF(0.24, 5),
    KF(0.27, -7),
    KF(0.30, 4),
    KF(0.33, -6),
    KF(0.36, 4),
    KF(0.39, -3),
    KF(0.42, 0),
    KF(0.48, 32),
    KF(0.52, 28),
    KF(1, 28),
  ], Css.easeInOut);
  static const _quillOpacity = Track([
    KF(0, 0),
    KF(0.16, 0),
    KF(0.18, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.easeInOut);

  void _plConstitution(Canvas canvas) {
    final (white, red) = WordmarkColours.gb(event, dark);
    final k = _k;
    canvas.faded(_p3Word.at(phase), () {
      final hidden = _p3Hidden.at(phase);
      canvas.clipped(
        Rect.fromLTRB(
          -0.1 * _width,
          -0.3 * _height,
          _width * (1 - hidden),
          1.3 * _height,
        ),
        () {
          for (var index = 0; index < 7; index++) {
            layout.paintLetter(canvas, index, _ink);
          }
          for (final index in [7, 8]) {
            _twoTone(canvas, index, white, red, _below(index, 0.5));
          }
        },
      );
      if (!accessories) return;
      canvas.faded(_quillOpacity.at(phase), () {
        canvas.save();
        canvas.translate(_width * _p3Pen.at(phase) - 5 * k, 2 * k);
        canvas.moved(
          Offset(5.2 * k, 38 * k),
          () {
            canvas.translate(0, 0.5 * k);
            canvas.scale(0.8125 * k);
            final vane = Path()
              ..moveTo(29, 2)
              ..cubicTo(17, 5, 9, 16, 9, 33)
              ..lineTo(13, 35)
              ..cubicTo(17, 21, 22, 11, 29, 2)
              ..close();
            canvas.drawPath(
              vane,
              Paint()
                ..color = dark
                    ? const Color(0xFFF7EDD3)
                    : const Color(0xFFFFFFFF),
            );
            canvas.drawPath(
              vane,
              Paint()
                ..color = dark
                    ? const Color(0xFFE3B04B)
                    : const Color(0xFF8E1B2C)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..strokeJoin = StrokeJoin.round,
            );
            canvas.drawPath(
              Path()
                ..moveTo(29, 2)
                ..cubicTo(21, 14, 15, 26, 8, 44),
              Paint()
                ..color = dark
                    ? const Color(0xFFE3B04B)
                    : const Color(0xFF6B4A2B)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6
                ..strokeCap = StrokeCap.round,
            );
            canvas.drawLine(
              const Offset(8, 44),
              const Offset(6.5, 47),
              Paint()
                ..color = dark
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF10222C)
                ..strokeWidth = 1.8
                ..strokeCap = StrokeCap.round,
            );
          },
          move: Offset(_quillX.at(phase) * k, _quillY.at(phase) * k),
          turn: _quillTurn.at(phase),
        );
        canvas.restore();
      });
    });
  }

  // 11 November: the letters rise one by one, red rises in "GB" to half
  // way, and a white and red ribbon unrolls under the name.
  static const _p11Rise = Track([
    KF(0, 1.1),
    KF(0.30, 1.1),
    KF(0.40, 0),
    KF(0.80, 0, Css.leave),
    KF(0.90, -0.6),
    KF(1, -0.6),
  ], Css.pop);
  static const _p11Opacity = Track([
    KF(0, 0),
    KF(0.30, 0),
    KF(0.40, 1),
    KF(0.80, 1, Css.leave),
    KF(0.90, 0),
    KF(1, 0),
  ], Css.pop);
  static const _p11Red = Track([
    KF(0, 1),
    KF(0.40, 1),
    KF(0.50, 0.5),
    KF(0.86, 0.5, Css.leave),
    KF(0.92, 1),
    KF(1, 1),
  ], Css.pop);
  static const _ribbonHidden = Track([
    KF(0, 0.5),
    KF(0.44, 0.5),
    KF(0.56, -0.02),
    KF(1, -0.02),
  ], Css.rise);
  static const _ribbonOpacity = Track([
    KF(0, 0),
    KF(0.44, 0),
    KF(0.45, 1),
    KF(0.78, 1, Css.leave),
    KF(0.86, 0),
    KF(1, 0),
  ], Css.rise);

  void _plIndependence(Canvas canvas) {
    final (white, red) = WordmarkColours.gb(event, dark);
    _framed(canvas, const EdgeInsets.symmetric(horizontal: 4, vertical: 8), () {
      for (var index = 0; index < 9; index++) {
        final local = delayed(
          phase,
          Duration(milliseconds: 50 * index),
          _cycle,
        );
        canvas.faded(_p11Opacity.at(local), () {
          canvas.moved(Offset.zero, () {
            if (index < 7) {
              layout.paintLetter(canvas, index, _ink);
            } else {
              _twoTone(
                canvas,
                index,
                white,
                red,
                _below(index, _p11Red.at(local)),
              );
            }
          }, move: Offset(0, _p11Rise.at(local) * _height));
        });
      }
    });
    if (!accessories) return;
    final k = _k;
    final ribbon = Rect.fromLTWH(
      -4 * k,
      _height + 6 * k,
      _width + 8 * k,
      16 * k,
    );
    final hidden = _ribbonHidden.at(phase);
    final sway = alternating(
      phase,
      const Duration(milliseconds: 2400),
      _cycle,
      curve: Css.easeInOut,
    );
    canvas.faded(_ribbonOpacity.at(phase), () {
      canvas.clipped(
        Rect.fromLTRB(
          ribbon.left + ribbon.width * hidden,
          ribbon.top - ribbon.height,
          ribbon.right - ribbon.width * hidden,
          ribbon.bottom + ribbon.height,
        ),
        () => canvas.moved(
          ribbon.center,
          () {
            canvas.save();
            canvas.translate(ribbon.left, ribbon.top);
            canvas.scale(ribbon.width / 300, k);
            canvas.drawPath(
              Path()
                ..moveTo(0, 1)
                ..lineTo(300, 1)
                ..lineTo(292, 8)
                ..lineTo(8, 8)
                ..close(),
              Paint()..color = white,
            );
            canvas.drawPath(
              Path()
                ..moveTo(8, 8)
                ..lineTo(292, 8)
                ..lineTo(300, 15)
                ..lineTo(0, 15)
                ..close(),
              Paint()..color = red,
            );
            canvas.restore();
          },
          move: Offset(0, (-1 + 2.5 * sway) * k),
          turn: -0.6 + 1.2 * sway,
        ),
      );
    });
  }

  // 23 August: the name comes up after the flag, and its colours come up
  // into "GB".
  static const _u23Word = Track([
    KF(0, 1.4),
    KF(0.30, 1.4),
    KF(0.44, 0),
    KF(0.84, 0, Css.leave),
    KF(0.94, 1.4),
    KF(1, 1.4),
  ], Css.pop);
  static const _u23Fill = Track([
    KF(0, 0),
    KF(0.40, 0, Css.fill),
    KF(0.54, 1),
    KF(0.88, 1, Css.leave),
    KF(0.96, 0),
    KF(1, 0),
  ], Css.rise);

  void _uaFlag(Canvas canvas) {
    final (blue, yellow) = WordmarkColours.gb(event, dark);
    _framed(canvas, const EdgeInsets.symmetric(horizontal: 4, vertical: 8), () {
      canvas.moved(Offset.zero, () {
        for (var index = 0; index < 7; index++) {
          layout.paintLetter(canvas, index, _ink);
        }
        final filled = _u23Fill.at(phase);
        if (filled <= 0) return;
        final gb = layout.gb;
        final blueTop = gb.top + _height * (1 - filled);
        final yellowTop = gb.top + _height * (1.5 - filled);
        for (final index in [7, 8]) {
          canvas.clipped(
            Rect.fromLTRB(
              gb.left - _height,
              blueTop,
              gb.right + _height,
              yellowTop,
            ),
            () => layout.paintLetter(canvas, index, blue),
          );
          canvas.clipped(
            Rect.fromLTRB(
              gb.left - _height,
              yellowTop,
              gb.right + _height,
              gb.bottom + _height,
            ),
            () => layout.paintLetter(canvas, index, yellow),
          );
        }
      }, move: Offset(0, _u23Word.at(phase) * _height));
    });
  }

  // 24 August: the letters come into focus, a gleam crosses "GB", and an
  // ear of wheat sways by the name.
  static const _u24Opacity = Track([
    KF(0, 0),
    KF(0.24, 0),
    KF(0.36, 1),
    KF(0.82, 1, Css.leave),
    KF(0.92, 0),
    KF(1, 0),
  ], Css.easeOut);
  static const _u24Blur = Track([
    KF(0, 10),
    KF(0.24, 10),
    KF(0.36, 0),
    KF(0.82, 0, Css.leave),
    KF(0.92, 10),
    KF(1, 10),
  ], Css.easeOut);
  static const _u24Shift = Track([
    KF(0, -14),
    KF(0.24, -14),
    KF(0.36, 0),
    KF(0.82, 0, Css.leave),
    KF(0.92, 10),
    KF(1, 10),
  ], Css.easeOut);
  static const _u24Gleam = Track([
    KF(0, 1),
    KF(0.42, 1),
    KF(0.58, 0),
    KF(1, 0),
  ]);
  static const _wheatGrow = Track([
    KF(0, 0),
    KF(0.34, 0),
    KF(0.41, 1.05),
    KF(0.47, 1),
    KF(1, 1),
  ], Css.easeInOut);
  static const _wheatTurn = Track([
    KF(0, -20),
    KF(0.34, -20),
    KF(0.41, 7),
    KF(0.47, -5),
    KF(0.54, 4),
    KF(0.61, -3),
    KF(0.68, 3),
    KF(0.75, -2),
    KF(0.82, 1),
    KF(0.92, 0),
    KF(1, 0),
  ], Css.easeInOut);
  static const _wheatOpacity = Track([
    KF(0, 0),
    KF(0.34, 0),
    KF(0.41, 1),
    KF(0.82, 1),
    KF(0.92, 0),
    KF(1, 0),
  ], Css.easeInOut);

  void _uaIndependence(Canvas canvas) {
    final (blue, yellow) = WordmarkColours.gb(event, dark);
    final k = _k;
    for (var index = 0; index < 9; index++) {
      final local = delayed(phase, Duration(milliseconds: 60 * index), _cycle);
      final box = layout.boxes[index];
      canvas.faded(_u24Opacity.at(local), () {
        canvas.blurred(_u24Blur.at(local) * k, () {
          canvas.moved(Offset.zero, () {
            if (index < 7) {
              layout.paintLetter(canvas, index, _ink);
              return;
            }
            canvas.saveLayer(box.inflate(_height), Paint());
            _twoTone(canvas, index, blue, yellow, _below(index, 0.5));
            // The gleam: a band three letters wide passing left to right.
            final centre =
                box.left + box.width * (1.5 - 2 * _u24Gleam.at(local));
            final half = 0.24 * box.width;
            const angle = 10 * math.pi / 180;
            final along = Offset(math.cos(angle), math.sin(angle)) * half;
            final middle = Offset(centre, box.center.dy);
            canvas.drawRect(
              box.inflate(_height),
              Paint()
                ..blendMode = BlendMode.srcATop
                ..shader = ui.Gradient.linear(
                  middle - along,
                  middle + along,
                  [
                    const Color(0x00FFFFFF),
                    Color.fromRGBO(255, 255, 255, dark ? 0.65 : 0.8),
                    const Color(0x00FFFFFF),
                  ],
                  const [0, 0.5, 1],
                ),
            );
            canvas.restore();
          }, move: Offset(_u24Shift.at(local) * k, 0));
        });
      });
    }
    if (!accessories) return;
    canvas.faded(_wheatOpacity.at(phase), () {
      canvas.save();
      canvas.translate(_width + 6 * k, layout.baseline + 6 * k - 58 * k);
      canvas.scale(k);
      canvas.moved(
        const Offset(12, 58),
        () {
          canvas.translate(0, 6);
          final stem = dark ? const Color(0xFFE3B04B) : const Color(0xFFB8860B);
          final grain = dark
              ? const Color(0xFFF2C94C)
              : const Color(0xFFD9A520);
          canvas.drawPath(
            Path()
              ..moveTo(12, 51)
              ..cubicTo(12, 40, 12.5, 26, 13.5, 8),
            Paint()
              ..color = stem
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round,
          );
          final paint = Paint()..color = grain;
          canvas.drawOval(
            Rect.fromCenter(
              center: const Offset(13.6, 7),
              width: 4.4,
              height: 8.8,
            ),
            paint,
          );
          for (final (x, y, turn) in const [
            (9.5, 14.0, -28.0),
            (16.5, 17.0, 28.0),
            (9.5, 21.0, -28.0),
            (16.5, 24.0, 28.0),
            (9.8, 28.0, -28.0),
            (16.2, 31.0, 28.0),
          ]) {
            canvas.moved(
              Offset(x, y),
              () => canvas.drawOval(
                Rect.fromCenter(center: Offset(x, y), width: 4.8, height: 9.2),
                paint,
              ),
              turn: turn,
            );
          }
          final awn = Paint()
            ..color = grain
            ..strokeWidth = 0.8
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(const Offset(13.6, 3), const Offset(13.4, -4), awn);
          canvas.drawLine(const Offset(8.2, 10), const Offset(4.5, 4), awn);
          canvas.drawLine(const Offset(17.8, 13), const Offset(21.5, 7), awn);
        },
        scale: _wheatGrow.at(phase),
        turn: _wheatTurn.at(phase),
      );
      canvas.restore();
    });
  }

  // Christmas: the name drops into place and a Santa hat lands on the S.
  static const _zcWord = Track([
    KF(0, -0.25),
    KF(0.20, -0.25),
    KF(0.34, 0),
    KF(0.84, 0, Css.leave),
    KF(0.94, 0.10),
    KF(1, 0.10),
  ], Css.pop);
  static const _zcOpacity = Track([
    KF(0, 0),
    KF(0.20, 0),
    KF(0.34, 1),
    KF(0.84, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.pop);
  static const _hatX = Track([
    KF(0, -30),
    KF(0.34, -30),
    KF(0.44, 0),
    KF(1, 0),
  ], Css.pop);
  static const _hatY = Track([
    KF(0, -60),
    KF(0.34, -60),
    KF(0.44, 3),
    KF(0.48, -3),
    KF(0.52, 0),
    KF(1, 0),
  ], Css.pop);
  static const _hatTurn = Track([
    KF(0, -70),
    KF(0.34, -70),
    KF(0.44, 8),
    KF(0.48, -3),
    KF(0.52, 0),
    KF(1, 0),
  ], Css.pop);
  static const _hatOpacity = Track([
    KF(0, 0),
    KF(0.34, 0),
    KF(0.36, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.pop);
  static const _pompom = Track([
    KF(0, 0),
    KF(0.48, 0),
    KF(0.52, 3),
    KF(0.56, -2),
    KF(0.60, 0),
    KF(0.72, 0),
    KF(0.75, 2.5),
    KF(0.78, -1.5),
    KF(0.81, 0),
    KF(1, 0),
  ], Css.easeOut);

  void _christmas(Canvas canvas) {
    final (green, _) = WordmarkColours.gb(event, dark);
    final k = _k;
    _framed(canvas, const EdgeInsets.fromLTRB(22, 34, 4, 8), () {
      canvas.faded(_zcOpacity.at(phase), () {
        canvas.moved(Offset.zero, () {
          for (var index = 0; index < 9; index++) {
            layout.paintLetter(canvas, index, index < 7 ? _ink : green);
          }
          if (!accessories) return;
          final box = Rect.fromLTWH(-3 * k, -24 * k, 46 * k, 38 * k);
          canvas.faded(_hatOpacity.at(phase), () {
            canvas.moved(box.center, () {
              canvas.save();
              canvas.translate(box.left, box.top);
              canvas.scale(k);
              canvas.moved(
                const Offset(13.8, 32.3),
                () {
                  final fur = dark
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFFE3E7EA);
                  canvas.drawPath(
                    Path()
                      ..moveTo(6, 26)
                      ..cubicTo(7, 15, 13, 6, 24, 4.5)
                      ..cubicTo(33, 3.3, 39, 8, 41, 17)
                      ..lineTo(36.5, 18.5)
                      ..cubicTo(35, 13.5, 31.5, 11.5, 28, 12.5)
                      ..cubicTo(29, 17, 29.5, 21.5, 29.5, 26)
                      ..close(),
                    Paint()
                      ..color = dark
                          ? const Color(0xFFE0314B)
                          : const Color(0xFFC8102E),
                  );
                  canvas.drawRRect(
                    RRect.fromRectAndRadius(
                      const Rect.fromLTWH(3, 23, 29, 8),
                      const Radius.circular(4),
                    ),
                    Paint()..color = fur,
                  );
                  canvas.drawCircle(
                    Offset(39.5, 19.5 + _pompom.at(phase)),
                    4.6,
                    Paint()..color = fur,
                  );
                },
                move: Offset(_hatX.at(phase), _hatY.at(phase)),
                turn: _hatTurn.at(phase),
              );
              canvas.restore();
            }, turn: -12);
          });
        }, move: Offset(0, _zcWord.at(phase) * _height));
      });
    });
  }

  // New Year: the name rises in, a gleam crosses the gold "GB", and
  // confetti falls on it.
  static const _znWord = Track([
    KF(0, 8),
    KF(0.14, 8),
    KF(0.26, 0),
    KF(1, 0),
  ], Css.pop);
  static const _znOpacity = Track([
    KF(0, 0),
    KF(0.14, 0),
    KF(0.26, 1),
    KF(0.86, 1, Css.leave),
    KF(0.94, 0),
    KF(1, 0),
  ], Css.pop);
  static const _znGleam = Track([KF(0, 1), KF(0.30, 1), KF(0.52, 0), KF(1, 0)]);
  static const _fallX = Track([
    KF(0, 0),
    KF(0.42, 0),
    KF(0.84, 8),
    KF(0.90, 9),
    KF(1, 9),
  ], Css.fall);
  static const _fallY = Track([
    KF(0, 0),
    KF(0.42, 0),
    KF(0.84, 104),
    KF(0.90, 112),
    KF(1, 112),
  ], Css.fall);
  static const _fallTurn = Track([
    KF(0, 0),
    KF(0.42, 0),
    KF(0.84, 420),
    KF(0.90, 460),
    KF(1, 460),
  ], Css.fall);
  static const _fallOpacity = Track([
    KF(0, 0),
    KF(0.42, 0),
    KF(0.46, 1),
    KF(0.84, 1),
    KF(0.90, 0),
    KF(1, 0),
  ], Css.fall);

  /// The confetti: where each piece starts, its size and colour, which way
  /// it turns, and how late it starts.
  static const _confetti = [
    (18.0, 8.0, 5.0, 9.0, 0, true, 0),
    (46.0, 0.0, 4.0, 8.0, 1, false, 120),
    (74.0, 14.0, 5.0, 9.0, 2, true, 300),
    (102.0, 4.0, 4.0, 8.0, 3, false, 50),
    (130.0, 18.0, 5.0, 9.0, 4, true, 220),
    (158.0, 2.0, 5.0, 9.0, 0, false, 380),
    (186.0, 12.0, 4.0, 8.0, 1, true, 150),
    (214.0, 6.0, 5.0, 9.0, 2, false, 280),
    (242.0, 16.0, 4.0, 8.0, 3, true, 80),
    (270.0, 0.0, 5.0, 9.0, 0, false, 330),
    (298.0, 10.0, 5.0, 9.0, 4, true, 180),
    (326.0, 4.0, 4.0, 8.0, 2, false, 420),
    (354.0, 14.0, 5.0, 9.0, 1, true, 250),
  ];

  void _newYear(Canvas canvas) {
    final (gold, _) = WordmarkColours.gb(event, dark);
    final k = _k;
    canvas.faded(_znOpacity.at(phase), () {
      canvas.moved(Offset.zero, () {
        for (var index = 0; index < 7; index++) {
          layout.paintLetter(canvas, index, _ink);
        }
        final gb = layout.gb;
        canvas.saveLayer(gb.inflate(_height), Paint());
        layout.paintLetter(canvas, 7, gold);
        layout.paintLetter(canvas, 8, gold);
        final centre = gb.left + gb.width * (1.5 - 2 * _znGleam.at(phase));
        final half = 0.3 * gb.width;
        final light = dark ? const Color(0xFFFFF6D8) : const Color(0xFFF7DC8A);
        canvas.drawRect(
          gb.inflate(_height),
          Paint()
            ..blendMode = BlendMode.srcATop
            ..shader = ui.Gradient.linear(
              Offset(centre - half, 0),
              Offset(centre + half, 0),
              [gold, light, gold],
              const [0, 0.5, 1],
            ),
        );
        canvas.restore();
        if (accessories) _confettiFall(canvas, k);
      }, move: Offset(0, _znWord.at(phase) * k));
    });
  }

  void _confettiFall(Canvas canvas, double k) {
    final colours = dark
        ? const [
            Color(0xFFF2C94C),
            Color(0xFFFFF4D6),
            Color(0xFFE3B93C),
            Color(0xFF9FCDE0),
            Color(0xFFC9A227),
          ]
        : const [
            Color(0xFFC9A227),
            Color(0xFF101C3D),
            Color(0xFFE3B93C),
            Color(0xFF7FA8D8),
            Color(0xFF9A6F00),
          ];
    canvas.save();
    canvas.translate(-18 * k, -62 * k);
    canvas.scale(k);
    for (final (x, y, w, h, colour, clockwise, delay) in _confetti) {
      final local = delayed(phase, Duration(milliseconds: delay), _cycle);
      final side = clockwise ? 1.0 : -1.0;
      final piece = Rect.fromLTWH(x, y, w, h);
      canvas.faded(_fallOpacity.at(local), () {
        canvas.moved(
          piece.center,
          () => canvas.drawRRect(
            RRect.fromRectAndRadius(piece, const Radius.circular(1)),
            Paint()..color = colours[colour],
          ),
          move: Offset(
            side * _fallX.at(local),
            _fallY.at(local) * (clockwise ? 1 : 100 / 104),
          ),
          turn: side * _fallTurn.at(local) * (clockwise ? 1 : 380 / 420),
        );
      });
    }
    for (final (x, top, colour, clockwise, delay) in const [
      (60.0, -6.0, 0, false, 100),
      (290.0, -8.0, 3, true, 300),
    ]) {
      final local = delayed(phase, Duration(milliseconds: delay), _cycle);
      final side = clockwise ? 1.0 : -1.0;
      final serpentine = Path()..moveTo(x, top);
      for (var step = 0; step < 3; step++) {
        final y = top + step * 10;
        serpentine.quadraticBezierTo(
          x + (step.isEven ? 5 : -5),
          y + 5,
          x,
          y + 10,
        );
      }
      final bounds = serpentine.getBounds();
      canvas.faded(_fallOpacity.at(local), () {
        canvas.moved(
          bounds.center,
          () => canvas.drawPath(
            serpentine,
            Paint()
              ..color = colours[colour]
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round,
          ),
          move: Offset(
            side * _fallX.at(local),
            _fallY.at(local) * (clockwise ? 1 : 100 / 104),
          ),
          turn: side * _fallTurn.at(local) * (clockwise ? 1 : 380 / 420),
        );
      });
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandWordmarkPainter oldDelegate) =>
      oldDelegate.event != event ||
      oldDelegate.phase != phase ||
      oldDelegate.dark != dark ||
      oldDelegate.layout != layout ||
      oldDelegate.accessories != accessories ||
      oldDelegate.clip != clip;
}

/// The wordmark of [event] at [phase], laid out at [fontSize].
class EventWordmark extends StatefulWidget {
  const EventWordmark({
    required this.event,
    required this.phase,
    this.fontSize = 56,
    this.accessories = false,
    this.clip = false,
    super.key,
  });

  final BrandEvent event;
  final double phase;
  final double fontSize;
  final bool accessories;
  final bool clip;

  @override
  State<EventWordmark> createState() => _EventWordmarkState();
}

class _EventWordmarkState extends State<EventWordmark> {
  WordmarkLayout? _layout;

  WordmarkLayout _laidOut() {
    final layout = _layout;
    if (layout != null && layout.fontSize == widget.fontSize) return layout;
    layout?.dispose();
    return _layout = WordmarkLayout(widget.fontSize);
  }

  @override
  void dispose() {
    _layout?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = _laidOut();
    return CustomPaint(
      size: layout.size,
      painter: BrandWordmarkPainter(
        event: widget.event,
        phase: widget.phase,
        dark: Theme.of(context).brightness == Brightness.dark,
        layout: layout,
        accessories: widget.accessories,
        clip: widget.clip,
      ),
    );
  }
}
