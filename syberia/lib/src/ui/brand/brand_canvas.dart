import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// The few ways the logo painters draw their parts, as CSS would.
extension BrandCanvas on Canvas {
  /// Draws [draw] faded to [opacity], all of it as one layer.
  void faded(double opacity, VoidCallback draw) {
    if (opacity <= 0) return;
    if (opacity >= 1) {
      draw();
      return;
    }
    saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    draw();
    restore();
  }

  /// Draws [draw] blurred by [sigma], as CSS's blur().
  void blurred(double sigma, VoidCallback draw) {
    if (sigma <= 0.01) {
      draw();
      return;
    }
    saveLayer(
      null,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    draw();
    restore();
  }

  /// Draws [draw] moved by [move], then scaled and turned [turn] degrees
  /// about [origin], as CSS applies translate, scale and rotate in turn.
  void moved(
    Offset origin,
    VoidCallback draw, {
    Offset move = Offset.zero,
    double scale = 1,
    double scaleX = 1,
    double scaleY = 1,
    double turn = 0,
  }) {
    if (scale * scaleX * scaleY == 0) return;
    save();
    translate(origin.dx + move.dx, origin.dy + move.dy);
    this.scale(scale * scaleX, scale * scaleY);
    if (turn != 0) rotate(turn * math.pi / 180);
    translate(-origin.dx, -origin.dy);
    draw();
    restore();
  }

  /// Draws [draw] inside [area] only.
  void clipped(Rect area, VoidCallback draw) {
    save();
    clipRect(area);
    draw();
    restore();
  }

  /// Draws the first [fraction] of [path], as a stroke drawing itself.
  void drawPart(Path path, double fraction, Paint paint) {
    if (fraction <= 0) return;
    for (final metric in path.computeMetrics()) {
      drawPath(
        metric.extractPath(0, metric.length * fraction.clamp(0.0, 1.0)),
        paint,
      );
    }
  }
}
