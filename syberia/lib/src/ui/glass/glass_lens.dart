import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The lens at the edge of drawn glass: the rim of Apple's Liquid Glass does
/// not show what lies under it but a squeezed mirror image of what lies
/// further in.
///
/// That takes a shader which reads the picture behind it, and only the
/// Impeller renderer runs those. Everywhere else, and wherever the shader
/// fails to load, the glass keeps a flat edge and is otherwise the same.
abstract final class GlassLens {
  static ui.FragmentProgram? _program;

  /// Whether the edge of the glass can bend what shows through it.
  static bool get available => _program != null;

  /// Loads the shader. Call once, before the first frame.
  static Future<void> load() async {
    if (_program != null || !ui.ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/glass_lens.frag');
    } on Object {
      // The glass stays flat.
    }
  }
}

/// Bends what shows through the rim of a rounded piece of glass as large as
/// this widget. It goes over whatever it is to bend.
class GlassEdgeLens extends SingleChildRenderObjectWidget {
  const GlassEdgeLens({
    required this.radius,
    required this.band,
    this.fold = 1,
    super.child,
    super.key,
  });

  /// The radius of the glass's corners. Anything larger than its size allows
  /// makes a capsule.
  final double radius;

  /// How far from the edge the bending starts.
  final double band;

  /// How far towards the middle of the glass its very edge reaches for what
  /// it shows: all the way at 1, which is what Apple's bars and panels do
  /// and mirrors the picture in the rim, and not at all at 0. A small share
  /// only stretches what is near the edge.
  final double fold;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassEdgeLens(radius, band, fold);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderGlassEdgeLens)
      ..radius = radius
      ..band = band
      ..fold = fold;
  }
}

class _RenderGlassEdgeLens extends RenderProxyBox {
  _RenderGlassEdgeLens(this._radius, this._band, this._fold);

  double get radius => _radius;
  double _radius;
  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsPaint();
  }

  double get band => _band;
  double _band;
  set band(double value) {
    if (_band == value) return;
    final bent = _bends;
    _band = value;
    if (bent != _bends) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  double get fold => _fold;
  double _fold;
  set fold(double value) {
    if (_fold == value) return;
    final bent = _bends;
    _fold = value;
    if (bent != _bends) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// Whether this lens could ever push a layer. It has to keep saying so
  /// even if the shader gives out later.
  final bool _layered = GlassLens.available;

  /// Whether it bends anything now. A lens that does not, as the tab bar's
  /// selection at rest, needs no layer of its own.
  bool get _bends => band > 0 && fold >= 0.002;

  @override
  bool get alwaysNeedsCompositing => _layered && _bends;

  @override
  void paint(PaintingContext context, Offset offset) {
    final program = GlassLens._program;
    if (program == null || size.isEmpty || band <= 0 || fold < 0.002) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final lens = (layer as _LensLayer?) ?? _LensLayer(program.fragmentShader())
      ..glass = offset & size
      ..radius = math.min(radius, size.shortestSide / 2)
      ..band = band
      ..fold = fold.clamp(0.0, 1.0);
    context.pushLayer(lens, super.paint, offset);
    layer = lens;
  }
}

/// A backdrop filter whose shader is told where on the screen the glass is.
///
/// A filter shader sees the whole picture behind it, in that picture's own
/// pixels, so the glass has to be placed in them. Its place can change
/// without a repaint, when something above it moves it as a whole. So the
/// place is worked out each time a frame is put together.
class _LensLayer extends ContainerLayer {
  _LensLayer(this._shader);

  final ui.FragmentShader _shader;

  /// The glass, in the coordinates this layer is painted in.
  Rect glass = Rect.zero;
  double radius = 0;
  double band = 0;
  double fold = 1;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    ui.ImageFilter? filter;
    if (GlassLens.available) {
      try {
        filter = _filter();
      } on Object {
        // A renderer that will not take the shader after all gets flat glass
        // from here on, not a frame that fails to come together.
        GlassLens._program = null;
      }
    }
    if (filter == null) {
      engineLayer = null;
      addChildrenToScene(builder);
      return;
    }
    engineLayer = builder.pushBackdropFilter(
      filter,
      oldLayer: engineLayer as ui.BackdropFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  /// The filter for where the glass is now, or null where it is turned or
  /// seen in perspective, which the lens is not made for.
  ui.ImageFilter? _filter() {
    final ancestors = <ContainerLayer>[];
    for (var layer = parent; layer != null; layer = layer.parent) {
      ancestors.add(layer);
    }
    final toScreen = Matrix4.identity();
    for (var index = ancestors.length - 1; index >= 0; index--) {
      ancestors[index].applyTransform(
        index == 0 ? this : ancestors[index - 1],
        toScreen,
      );
    }
    final m = toScreen.storage;
    const tiny = 1e-6;
    if (m[1].abs() > tiny ||
        m[4].abs() > tiny ||
        m[3].abs() > tiny ||
        m[7].abs() > tiny ||
        m[0] <= 0 ||
        m[5] <= 0) {
      return null;
    }
    final onScreen = MatrixUtils.transformRect(toScreen, glass);
    final scale = (m[0] + m[5]) / 2;
    _shader
      ..setFloat(2, onScreen.center.dx)
      ..setFloat(3, onScreen.center.dy)
      ..setFloat(4, onScreen.width / 2)
      ..setFloat(5, onScreen.height / 2)
      ..setFloat(6, radius * scale)
      ..setFloat(7, band * scale)
      ..setFloat(8, fold);
    return ui.ImageFilter.shader(_shader);
  }

  @override
  void dispose() {
    _shader.dispose();
    super.dispose();
  }
}
