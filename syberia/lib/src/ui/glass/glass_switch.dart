import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_material.dart';
import 'glass_motion.dart';
import 'glass_plate.dart';
import 'glass_platform.dart';
import 'native_view_link.dart';

/// A switch as iOS 26 draws it: UIKit's own on iOS 26, whose knob turns
/// into Liquid Glass under the finger, and drawn alike elsewhere.
///
/// Drawn, its knob swells into a lens of glass while it is held, slides on
/// a spring, and can be dragged across; the track takes the colour of on as
/// the knob goes over.
class GlassSwitch extends StatefulWidget {
  const GlassSwitch({required this.value, required this.onChanged, super.key});

  final bool value;

  /// Null leaves the switch disabled.
  final ValueChanged<bool>? onChanged;

  /// UIKit's switch before iOS 26 measured this, and the drawn one keeps it.
  static const Size size = Size(51, 31);

  @override
  State<GlassSwitch> createState() => _GlassSwitchState();
}

class _GlassSwitchState extends State<GlassSwitch> {
  /// The size UIKit wants for its switch, once it has said.
  Size? _nativeSize;

  @override
  Widget build(BuildContext context) {
    if (GlassPlatform.backend == GlassBackend.uikit) {
      final size = _nativeSize ?? GlassSwitch.size;
      return SizedBox.fromSize(
        size: size,
        child: _NativeSwitch(
          value: widget.value,
          onChanged: widget.onChanged,
          onSize: (value) {
            if (value != _nativeSize) setState(() => _nativeSize = value);
          },
        ),
      );
    }
    return _RenderedSwitch(value: widget.value, onChanged: widget.onChanged);
  }
}

/// UIKit's switch, hosted as a platform view. A drag across it stays with
/// it; one up or down still scrolls the page.
class _NativeSwitch extends StatefulWidget {
  const _NativeSwitch({
    required this.value,
    required this.onChanged,
    required this.onSize,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final ValueChanged<Size> onSize;

  @override
  State<_NativeSwitch> createState() => _NativeSwitchState();
}

class _NativeSwitchState extends State<_NativeSwitch> {
  static final _gestures = <Factory<OneSequenceGestureRecognizer>>{
    const Factory<HorizontalDragGestureRecognizer>(
      HorizontalDragGestureRecognizer.new,
    ),
  };

  late final _link = NativeViewLink('siberia/glass_switch', onCall: _onCall);

  /// Sends the value again where UIKit was flipped and the app kept it.
  int _again = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _link.update(_params());
  }

  @override
  void didUpdateWidget(_NativeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    _link.update(_params());
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Map<String, Object?> _params() => {
    'value': widget.value,
    'enabled': widget.onChanged != null,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'again': _again,
  };

  Future<void> _onCall(MethodCall call) async {
    final arguments = call.arguments;
    switch (call.method) {
      case 'changed':
        if (arguments is! bool) return;
        widget.onChanged?.call(arguments);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // The app may keep the value: UIKit's switch goes back to it.
          if (!mounted || widget.value == arguments) return;
          _again++;
          _link.update(_params());
        });
      case 'metrics':
        if (arguments is! Map) return;
        final width = arguments['width'];
        final height = arguments['height'];
        if (width is num && height is num && width > 0 && height > 0) {
          widget.onSize(Size(width.toDouble(), height.toDouble()));
        }
    }
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: _link.viewType,
    creationParams: _link.params,
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: _link.attach,
    gestureRecognizers: _gestures,
  );
}

/// The switch drawn by Flutter.
class _RenderedSwitch extends StatefulWidget {
  const _RenderedSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<_RenderedSwitch> createState() => _RenderedSwitchState();
}

class _RenderedSwitchState extends State<_RenderedSwitch> {
  static const double _inset = 2;

  /// How much the knob swells as a lens, across and up and down.
  static const double _swellWide = 12;
  static const double _swellHigh = 6;

  /// Where a dragged knob is, from 0 for off to 1 for on.
  double? _drag;

  bool _held = false;

  bool get _enabled => widget.onChanged != null;

  void _set(bool value) {
    if (value == widget.value) return;
    HapticFeedback.selectionClick();
    widget.onChanged?.call(value);
  }

  void _release() {
    final drag = _drag;
    setState(() {
      _held = false;
      _drag = null;
    });
    if (drag != null) _set(drag >= 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // iOS's colours for a switch: green for on, a light fill for off.
    final on = dark ? const Color(0xFF30D158) : const Color(0xFF34C759);
    final off = dark ? const Color(0xFF39393D) : const Color(0xFFE9E9EA);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const size = GlassSwitch.size;
    final knob = size.height - 2 * _inset;
    final travel = size.width - knob - 2 * _inset;
    // The knob swells the moment a finger is on it, as UIKit's does, not
    // once a tap has been told apart from a drag.
    final drawn = Listener(
      onPointerDown: (_) => setState(() => _held = true),
      onPointerUp: (_) {
        if (_drag == null) setState(() => _held = false);
      },
      onPointerCancel: (_) {
        if (_drag == null) setState(() => _held = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _set(!widget.value),
        onHorizontalDragStart: (_) => setState(() {
          _held = true;
          _drag = widget.value ? 1 : 0;
        }),
        onHorizontalDragUpdate: (details) {
          final drag = _drag;
          if (drag == null) return;
          final direction = Directionality.of(context) == TextDirection.rtl
              ? -1
              : 1;
          setState(() {
            _drag = (drag + direction * details.delta.dx / travel).clamp(
              0.0,
              1.0,
            );
          });
        },
        onHorizontalDragEnd: (_) => _release(),
        onHorizontalDragCancel: _release,
        child: GlassSpring(
          target: _drag ?? (widget.value ? 1 : 0),
          spring: _drag != null ? GlassSprings.follow : GlassSprings.settle,
          builder: (context, position, _, _) => GlassSpring(
            target: !still && _held ? 1 : 0,
            spring: GlassSprings.press,
            builder: (context, lens, _, _) {
              final swell = lens.clamp(0.0, 1.0);
              final at = position.clamp(0.0, 1.0);
              final width = knob + _swellWide * swell;
              final height = knob + _swellHigh * swell;
              // The knob grows from its own side, as UIKit's does.
              final left = _inset + travel * at - _swellWide * swell * at;
              return SizedBox.fromSize(
                size: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: const StadiumBorder(),
                          color: Color.lerp(off, on, at),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: left,
                      top: (size.height - height) / 2,
                      width: width,
                      height: height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // The white knob at rest, gone soon after the glass
                          // shows.
                          Opacity(
                            opacity: (1 - swell / 0.4).clamp(0.0, 1.0),
                            child: const DecoratedBox(
                              decoration: ShapeDecoration(
                                shape: StadiumBorder(),
                                color: Colors.white,
                                shadows: [
                                  BoxShadow(
                                    color: Color(0x26000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                  BoxShadow(
                                    color: Color(0x0F000000),
                                    blurRadius: 1,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GlassPlate(
                            look: GlassMaterial.lens(theme.brightness)
                                .faded(math.min(swell, 1)),
                            shape: const StadiumBorder(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    final control = Semantics(
      toggled: widget.value,
      enabled: _enabled,
      onTap: _enabled ? () => _set(!widget.value) : null,
      child: ExcludeSemantics(child: drawn),
    );
    if (_enabled) return control;
    return IgnorePointer(child: Opacity(opacity: 0.45, child: control));
  }
}
