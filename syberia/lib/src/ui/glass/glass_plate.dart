import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'glass_lens.dart';
import 'glass_material.dart';

/// A piece of glass in the given [shape], with [child] on it.
///
/// It is made of what Flutter has on every renderer: a filter over the page
/// behind it, a hairline along its edge and a shadow around it. Where the
/// renderer can also bend the page, the rim of the glass is a lens. Several
/// plates under one [BackdropGroup] that do not overlap read the page in a
/// single pass.
class GlassPlate extends StatelessWidget {
  const GlassPlate({
    required this.look,
    required this.shape,
    this.child,
    super.key,
  });

  final GlassLook look;
  final ShapeBorder shape;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.maybeOf(context);
    final content = child ?? const SizedBox.expand();
    final veil = look.veil;
    final lens = look.bend > 0 && GlassLens.available
        ? Positioned.fill(
            child: GlassEdgeLens(
              radius: _cornerRadius(shape, direction),
              band: look.bend,
              fold: look.fold * look.visibility,
            ),
          )
        : null;
    final Widget glass;
    if (veil != null) {
      // Glass that is plain paint has nothing below it to bend, so its lens
      // goes over what lies on it.
      final filled = ColoredBox(color: veil, child: content);
      glass = lens == null
          ? filled
          : Stack(fit: StackFit.passthrough, children: [filled, lens]);
    } else if (lens != null) {
      // The lens bends the glass below it and nothing that lies on it.
      glass = Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: BackdropFilter.grouped(
              filter: look.filter,
              child: const SizedBox.expand(),
            ),
          ),
          lens,
          content,
        ],
      );
    } else {
      glass = BackdropFilter.grouped(filter: look.filter, child: content);
    }
    return CustomPaint(
      painter: look.shadows.isEmpty
          ? null
          : _ShadowPainter(shape, look.shadows, direction),
      foregroundPainter: look.rim.color.a == 0
          ? null
          : _RimPainter(shape, look.rim, direction),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape, textDirection: direction),
        child: glass,
      ),
    );
  }
}

/// The radius of [shape]'s corners. A stadium, like any shape that does not
/// say, is as round as its size allows.
double _cornerRadius(ShapeBorder shape, TextDirection? direction) {
  final corners = switch (shape) {
    RoundedRectangleBorder(:final borderRadius) => borderRadius,
    RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
    _ => null,
  };
  return corners?.resolve(direction).topLeft.x ?? double.infinity;
}

/// The hairline iOS 26 draws at the edge of its glass: strongest at the very
/// edge and gone a point further in.
class _RimPainter extends CustomPainter {
  const _RimPainter(this.shape, this.rim, this.direction);

  final ShapeBorder shape;
  final GlassRim rim;
  final TextDirection? direction;

  /// What an edge gets of the light when it faces it at half a right angle,
  /// as every straight edge does.
  static const double _aslant = math.sqrt1_2;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final outline = shape.getOuterPath(bounds, textDirection: direction);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..blendMode = rim.blendMode
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rim.softness);
    canvas
      ..save()
      // Only the inner half of the stroke is part of the glass.
      ..clipPath(outline);
    if (rim.lit) {
      _paintLit(canvas, bounds, outline, stroke);
    } else {
      canvas.drawPath(outline, stroke..color = rim.color);
    }
    canvas.restore();
  }

  /// The light comes down the diagonal from the upper left. How much of it
  /// an edge throws back depends on the way the edge faces, which at a
  /// corner is the way from the corner's centre: so across each corner the
  /// strength runs evenly from full, through nothing where the edge lies
  /// along the diagonal, to full again.
  void _paintLit(Canvas canvas, Rect bounds, Path outline, Paint stroke) {
    final radius = math.min(
      _cornerRadius(shape, direction),
      bounds.shortestSide / 2,
    );
    final full = rim.color;
    final none = full.withValues(alpha: 0);
    final corners = [
      for (final bottom in [false, true])
        for (final right in [false, true])
          Rect.fromLTWH(
            right ? bounds.right - radius : bounds.left,
            bottom ? bounds.bottom - radius : bounds.top,
            radius,
            radius,
          ),
    ];
    final centers = [
      corners[0].bottomRight,
      corners[1].bottomLeft,
      corners[2].topRight,
      corners[3].topLeft,
    ];
    canvas.save();
    for (final corner in corners) {
      canvas.clipRect(corner, clipOp: ui.ClipOp.difference);
    }
    canvas
      ..drawPath(
        outline,
        stroke..color = full.withValues(alpha: full.a * _aslant),
      )
      ..restore();
    final reach = Offset(radius, radius) * _aslant;
    stroke.color = const Color(0xFF000000);
    for (final (index, corner) in corners.indexed) {
      canvas
        ..save()
        ..clipRect(corner)
        ..drawPath(
          outline,
          stroke
            ..shader = ui.Gradient.linear(
              centers[index] - reach,
              centers[index] + reach,
              [full, none, full],
              const [0, 0.5, 1],
            ),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.rim != rim ||
      oldDelegate.direction != direction;
}

/// Shadows around the glass and none under it, where they would show
/// through.
class _ShadowPainter extends CustomPainter {
  const _ShadowPainter(this.shape, this.shadows, this.direction);

  final ShapeBorder shape;
  final List<BoxShadow> shadows;
  final TextDirection? direction;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final outline = shape.getOuterPath(bounds, textDirection: direction);
    var reach = 0.0;
    for (final shadow in shadows) {
      final extent =
          shadow.blurRadius * 2 + shadow.spreadRadius + shadow.offset.distance;
      if (extent > reach) reach = extent;
    }
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(bounds.inflate(reach))
          ..addPath(outline, Offset.zero),
      );
    for (final shadow in shadows) {
      canvas.drawPath(
        shape.getOuterPath(
          bounds.inflate(shadow.spreadRadius).shift(shadow.offset),
          textDirection: direction,
        ),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.direction != direction ||
      !_same(oldDelegate.shadows, shadows);

  static bool _same(List<BoxShadow> a, List<BoxShadow> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
