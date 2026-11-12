import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Leaves the top [extent] of its child out of hit testing, so touches there
/// reach whatever is painted underneath: the room a native glass bar keeps
/// above itself for its shadow belongs to the page behind it.
class TopPassThrough extends SingleChildRenderObjectWidget {
  const TopPassThrough({required this.extent, super.child, super.key});

  final double extent;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTopPassThrough(extent);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTopPassThrough).extent = extent;
  }
}

class _RenderTopPassThrough extends RenderProxyBox {
  _RenderTopPassThrough(this.extent);

  double extent;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      position.dy >= extent && super.hitTest(result, position: position);
}
