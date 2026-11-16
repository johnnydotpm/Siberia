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

  /// UIKit's switch measures this on iOS 26, and the drawn one keeps it.
  static const Size size = Size(63, 28);

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

/// The switch drawn by Flutter, to the measure of UIKit's on iOS 26: a
/// track of 63 by 28 points with a knob of 37 by 24, two points in.
class _RenderedSwitch extends StatefulWidget {
  const _RenderedSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<_RenderedSwitch> createState() => _RenderedSwitchState();
}

class _RenderedSwitchState extends State<_RenderedSwitch> {
  static const double _inset = 2;
  static const Size _knob = Size(37, 24);

  /// How much the knob grows as a lens under the finger, across and up and
  /// down: to 58 by 38 points, past the track on every side, around its own
  /// middle.
  static const double _swellWide = 21;
  static const double _swellHigh = 14;

  /// How far the lens is grown while the knob travels after a tap: a
  /// frosted piece of glass a little taller than the track.
  static const double _travelSwell = 0.4;

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
    final brightness = theme.brightness;
    final dark = brightness == Brightness.dark;
    // UIKit's colours, as iOS 26 draws them on a grouped row: green for on,
    // a grey for off.
    final on = dark ? const Color(0xFF30D158) : const Color(0xFF34C759);
    final off = dark ? const Color(0xFF5A5A5E) : const Color(0xFFC5C5C7);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const size = GlassSwitch.size;
    final travel = size.width - _knob.width - 2 * _inset;
    final target = _drag ?? (widget.value ? 1.0 : 0.0);
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
          target: target,
          spring: _drag != null ? GlassSprings.follow : GlassSprings.settle,
          builder: (context, position, _, _) {
            // On its way after a tap the knob is glass too, smaller and
            // frosted, as on iOS 26.
            final moving = (target - position).abs() > 0.02;
            return GlassSpring(
              target: still
                  ? 0
                  : _held
                  ? 1
                  : moving
                  ? _travelSwell
                  : 0,
              spring: GlassSprings.press,
              builder: (context, lens, _, _) => _paint(
                position: position.clamp(0.0, 1.0),
                swell: lens.clamp(0.0, 1.0),
                travel: travel,
                on: on,
                off: off,
                brightness: brightness,
              ),
            );
          },
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
    // UIKit draws a disabled switch at half its strength, knob and all.
    return IgnorePointer(child: Opacity(opacity: 0.5, child: control));
  }

  Widget _paint({
    required double position,
    required double swell,
    required double travel,
    required Color on,
    required Color off,
    required Brightness brightness,
  }) {
    const size = GlassSwitch.size;
    final width = _knob.width + _swellWide * swell;
    final height = _knob.height + _swellHigh * swell;
    final middle = _inset + travel * position + _knob.width / 2;
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: Color.lerp(off, on, position),
              ),
            ),
          ),
          PositionedDirectional(
            start: middle - width / 2,
            top: (size.height - height) / 2,
            width: width,
            height: height,
            child: Stack(
              key: const ValueKey('glass-switch-knob'),
              fit: StackFit.expand,
              children: [
                // Glass only while it shows: at rest a clear lens would read
                // the page behind every switch for nothing.
                if (swell > 0.01)
                  GlassPlate(
                    look: GlassMaterial.clearLens(brightness).faded(swell),
                    shape: const StadiumBorder(),
                  ),
                // The white knob, frosting the lens on its way and gone once
                // the lens is held.
                Opacity(
                  opacity: (1 - swell * swell).clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(),
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
