import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

/// Shapes of Material's shape library (androidx graphics-shapes, in a Dart
/// port), as borders any widget can be drawn and clipped in.
///
/// Between two of them a border lerps by morphing one shape into the other,
/// so an animated border changes shape smoothly.
abstract final class ExpressiveShapes {
  static final circle = MaterialShapeBorder(MaterialShapes.circle);
  static final oval = MaterialShapeBorder(MaterialShapes.oval);
  static final pill = MaterialShapeBorder(MaterialShapes.pill);
  static final pentagon = MaterialShapeBorder(MaterialShapes.pentagon);
  static final sunny = MaterialShapeBorder(MaterialShapes.sunny);
  static final cookie4 = MaterialShapeBorder(MaterialShapes.cookie4Sided);
  static final cookie9 = MaterialShapeBorder(MaterialShapes.cookie9Sided);
  static final softBurst = MaterialShapeBorder(MaterialShapes.softBurst);
  static final clover4 = MaterialShapeBorder(MaterialShapes.clover4Leaf);
  static final flower = MaterialShapeBorder(MaterialShapes.flower);
}

/// A [RoundedPolygon] of Material's library drawn to fill the rectangle it
/// is given.
class MaterialShapeBorder extends ShapeBorder {
  /// Takes [polygon] fitted to the unit square, as Material normalizes them.
  MaterialShapeBorder(RoundedPolygon polygon) : polygon = polygon.normalized();

  final RoundedPolygon polygon;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _fit(polygon.toPath(), rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b is MaterialShapeBorder
      ? _MorphBorder(_morph(polygon, b.polygon), t)
      : super.lerpTo(b, t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is MaterialShapeBorder
      ? _MorphBorder(_morph(a.polygon, polygon), t)
      : super.lerpFrom(a, t);
}

/// Part of the way from one Material shape to another.
class _MorphBorder extends ShapeBorder {
  const _MorphBorder(this.morph, this.progress);

  final Morph morph;
  final double progress;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _fit(morph.toPath(progress: progress), rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// Morphs take some work to build, so each pair of shapes builds one.
final _morphs = Expando<Map<RoundedPolygon, Morph>>();

Morph _morph(RoundedPolygon from, RoundedPolygon to) =>
    (_morphs[from] ??= Map.identity())[to] ??= Morph(from, to);

/// [unit], drawn in the unit square, scaled into [rect].
Path _fit(Path unit, Rect rect) => unit.transform(
  (Matrix4.identity()
        ..translateByDouble(rect.left, rect.top, 0, 1)
        ..scaleByDouble(rect.width, rect.height, 1, 1))
      .storage,
);

/// How much of their box [polygons] may fill and still fit it while they
/// turn: Compose's own factor for its loading indicator.
double rotationSafeScale(Iterable<RoundedPolygon> polygons) {
  var scale = 1.0;
  for (final polygon in polygons) {
    final bounds = polygon.calculateBounds();
    final max = polygon.calculateMaxBounds();
    final scaleX = (bounds[2] - bounds[0]) / (max[2] - max[0]);
    final scaleY = (bounds[3] - bounds[1]) / (max[3] - max[1]);
    // The larger of the two, so a long shape like a pill does not shrink
    // the rest.
    scale = math.min(scale, math.max(scaleX, scaleY));
  }
  return scale;
}

/// A shape of Material's library with [child] in its middle: a lesson's
/// number, an average, a grade.
class ShapeBadge extends StatelessWidget {
  const ShapeBadge({
    required this.shape,
    required this.size,
    required this.color,
    this.child,
    super.key,
  });

  final ShapeBorder shape;
  final double size;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: shape),
      child: Center(child: child),
    ),
  );
}
