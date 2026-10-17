import 'package:flutter/material.dart';

import 'glass_material.dart';
import 'glass_plate.dart';

/// A glass material behind [child], drawn by Flutter.
///
/// Like Apple's, the surface takes the size of [child] and rounds its own
/// corners, and the content is clipped to them.
class RenderedGlassSurface extends StatelessWidget {
  const RenderedGlassSurface({
    required this.radius,
    required this.child,
    this.reveal,
    super.key,
  });

  final double radius;
  final Widget child;

  /// Runs from 0 to 1 while the surface appears. The glass itself comes up
  /// out of the page then, its content fading in on it. A fade of the whole
  /// surface would not do: a filter over the page has no page to read
  /// inside a layer that is being faded.
  final Animation<double>? reveal;

  @override
  Widget build(BuildContext context) {
    final look = GlassMaterial.panel(Theme.of(context).brightness);
    // The continuous corners iOS gives its sheets and alerts.
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final reveal = this.reveal;
    if (reveal == null) {
      return GlassPlate(look: look, shape: shape, child: child);
    }
    return AnimatedBuilder(
      animation: reveal,
      child: child,
      builder: (context, child) {
        final shown = reveal.value.clamp(0.0, 1.0);
        return GlassPlate(
          look: look.faded(shown),
          shape: shape,
          child: Opacity(opacity: shown, child: child),
        );
      },
    );
  }
}
