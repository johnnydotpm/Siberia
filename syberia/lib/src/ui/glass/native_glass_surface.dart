import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_view_link.dart';

/// Apple's glass material behind [child], hosted as a platform view.
///
/// The surface takes the size of [child] and rounds its own corners. It must
/// not sit under a rounded Flutter clip: the material would lose its
/// refraction (flutter/flutter#191771), so the content is clipped instead.
class NativeGlassSurface extends StatefulWidget {
  const NativeGlassSurface({
    required this.radius,
    required this.child,
    this.tint,
    super.key,
  });

  final double radius;

  /// A colour mixed into the glass, to keep text on it readable.
  final Color? tint;

  final Widget child;

  @override
  State<NativeGlassSurface> createState() => _NativeGlassSurfaceState();
}

class _NativeGlassSurfaceState extends State<NativeGlassSurface> {
  final _link = NativeViewLink('siberia/glass_surface');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _link.update(_params());
  }

  @override
  void didUpdateWidget(NativeGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _link.update(_params());
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Map<String, Object?> _params() => {
    'radius': widget.radius,
    'tint': widget.tint?.toARGB32(),
    'style': 'regular',
    'dark': Theme.of(context).brightness == Brightness.dark,
  };

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        // Flutter keeps every gesture; the material is only a background.
        child: IgnorePointer(
          child: UiKitView(
            viewType: _link.viewType,
            creationParams: _link.params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _link.attach,
          ),
        ),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: widget.child,
      ),
    ],
  );
}
