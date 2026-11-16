import 'dart:async';
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

/// One choice of a [GlassSegmentedControl].
@immutable
class GlassSegment<T> {
  const GlassSegment(this.value, this.label);

  final T value;
  final String label;
}

/// A segmented control as iOS 26 draws it: UIKit's own on iOS 26, whose
/// selection is a piece of Liquid Glass, and drawn alike elsewhere.
///
/// Drawn, the selection rests as a plain platter; under a finger and while
/// it travels it turns into a lens of glass, moves on a spring and squashes
/// with its speed, as the tab bar's selection does. It can be dragged from
/// one choice to another.
///
/// It takes the whole width where it is made to, and its own otherwise.
class GlassSegmentedControl<T> extends StatefulWidget {
  const GlassSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.emptyAllowed = false,
    super.key,
  });

  final List<GlassSegment<T>> segments;

  /// The choice in force, or none.
  final T? selected;

  /// Told the choice made, or null where [emptyAllowed] and the choice in
  /// force is tapped again. Null leaves the control disabled.
  final ValueChanged<T?>? onChanged;

  final bool emptyAllowed;

  /// The drawn control's height before the text is scaled.
  static const double height = 36;

  /// Room on each side of a label.
  static const double _padding = 16;

  /// How far the selection sits inside the track.
  static const double _inset = 2;

  @override
  State<GlassSegmentedControl<T>> createState() =>
      _GlassSegmentedControlState<T>();
}

class _GlassSegmentedControlState<T> extends State<GlassSegmentedControl<T>> {
  /// The height UIKit wants for its control, once it has said.
  double? _nativeHeight;

  int? get _index {
    final selected = widget.selected;
    if (selected == null) return null;
    final index = widget.segments.indexWhere(
      (segment) => segment.value == selected,
    );
    return index < 0 ? null : index;
  }

  void _pick(int? index) {
    final change = widget.onChanged;
    if (change == null) return;
    change(index == null ? null : widget.segments[index].value);
  }

  /// The width the labels take, with their room.
  double _natural(BuildContext context, TextStyle style) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var width = 2 * GlassSegmentedControl._inset;
    for (final segment in widget.segments) {
      final painter = TextPainter(
        text: TextSpan(text: segment.label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      width += painter.width + 2 * GlassSegmentedControl._padding;
      painter.dispose();
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final native = GlassPlatform.backend == GlassBackend.uikit;
    final style = DefaultTextStyle.of(context).style
        .merge(_RenderedSegmented.labelStyle(context, selected: true));
    final scaler = MediaQuery.textScalerOf(context);
    final height = native
        ? _nativeHeight ?? GlassSegmentedControl.height
        : math.max(GlassSegmentedControl.height, scaler.scale(14) * 1.3 + 14);
    return LayoutBuilder(
      builder: (context, constraints) {
        final natural = _natural(context, style);
        final width = constraints.hasTightWidth
            ? constraints.maxWidth
            : constraints.hasBoundedWidth
            ? math.min(natural, constraints.maxWidth)
            : natural;
        return SizedBox(
          width: width,
          height: height,
          child: native
              ? _NativeSegmented<T>(
                  segments: widget.segments,
                  index: _index,
                  emptyAllowed: widget.emptyAllowed,
                  enabled: widget.onChanged != null,
                  onPicked: _pick,
                  onHeight: (value) {
                    if (value != _nativeHeight) {
                      setState(() => _nativeHeight = value);
                    }
                  },
                )
              : _RenderedSegmented<T>(
                  segments: widget.segments,
                  index: _index,
                  emptyAllowed: widget.emptyAllowed,
                  enabled: widget.onChanged != null,
                  onPicked: _pick,
                ),
        );
      },
    );
  }
}

/// UIKit's segmented control, hosted as a platform view. A drag across it
/// stays with it; one up or down still scrolls the page.
class _NativeSegmented<T> extends StatefulWidget {
  const _NativeSegmented({
    required this.segments,
    required this.index,
    required this.emptyAllowed,
    required this.enabled,
    required this.onPicked,
    required this.onHeight,
  });

  final List<GlassSegment<T>> segments;
  final int? index;
  final bool emptyAllowed;
  final bool enabled;
  final ValueChanged<int?> onPicked;
  final ValueChanged<double> onHeight;

  @override
  State<_NativeSegmented<T>> createState() => _NativeSegmentedState<T>();
}

class _NativeSegmentedState<T> extends State<_NativeSegmented<T>> {
  static final _gestures = <Factory<OneSequenceGestureRecognizer>>{
    const Factory<HorizontalDragGestureRecognizer>(
      HorizontalDragGestureRecognizer.new,
    ),
  };

  late final _link = NativeViewLink('siberia/glass_segmented', onCall: _onCall);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _link.update(_params());
  }

  @override
  void didUpdateWidget(_NativeSegmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _link.update(_params());
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Map<String, Object?> _params() => {
    'labels': [for (final segment in widget.segments) segment.label],
    'selected': widget.index ?? -1,
    'enabled': widget.enabled,
    'emptyAllowed': widget.emptyAllowed,
    'dark': Theme.of(context).brightness == Brightness.dark,
  };

  Future<void> _onCall(MethodCall call) async {
    final arguments = call.arguments;
    switch (call.method) {
      case 'select':
        if (arguments is! int) return;
        if (arguments >= widget.segments.length) return;
        HapticFeedback.selectionClick();
        widget.onPicked(arguments < 0 ? null : arguments);
      case 'metrics':
        if (arguments is! Map) return;
        final height = arguments['height'];
        if (height is num && height > 0) widget.onHeight(height.toDouble());
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

/// The segmented control drawn by Flutter.
class _RenderedSegmented<T> extends StatefulWidget {
  const _RenderedSegmented({
    required this.segments,
    required this.index,
    required this.emptyAllowed,
    required this.enabled,
    required this.onPicked,
  });

  final List<GlassSegment<T>> segments;
  final int? index;
  final bool emptyAllowed;
  final bool enabled;
  final ValueChanged<int?> onPicked;

  static TextStyle labelStyle(BuildContext context, {required bool selected}) =>
      TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: -0.15,
      );

  @override
  State<_RenderedSegmented<T>> createState() => _RenderedSegmentedState<T>();
}

class _RenderedSegmentedState<T> extends State<_RenderedSegmented<T>> {
  /// How much larger the selection grows as a lens.
  static const double _growth = 0.1;

  /// Where a dragged selection is, in choices from the first.
  double? _drag;

  /// Whether a finger is on the selection.
  bool _held = false;

  /// Whether the selection is on its way to a new choice.
  bool _travelling = false;
  Timer? _travel;

  /// Puts the selection on its choice at once, as when it first appears.
  int _jump = 0;

  @override
  void didUpdateWidget(_RenderedSegmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (oldWidget.index == null) {
      _jump++;
      return;
    }
    // The selection is a lens while it travels, and a platter again once
    // it has settled.
    _travelling = true;
    _travel?.cancel();
    _travel = Timer(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _travelling = false);
    });
  }

  @override
  void dispose() {
    _travel?.cancel();
    super.dispose();
  }

  int get _count => widget.segments.length;

  int _slotAt(double dx, double width) =>
      (dx / (width / _count)).floor().clamp(0, _count - 1);

  void _tap(int slot) {
    if (slot == widget.index) {
      if (widget.emptyAllowed) {
        HapticFeedback.selectionClick();
        widget.onPicked(null);
      }
      return;
    }
    HapticFeedback.selectionClick();
    widget.onPicked(slot);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // iOS's fill for a control's track, and its platter: white in the light
    // appearance, a lifted grey in the dark.
    final track = dark ? const Color(0x3D767680) : const Color(0x1F767680);
    final platter = dark ? const Color(0xFF636366) : Colors.white;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final control = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final slot = width / _count;
        final index = widget.index;
        final gestures = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (_slotAt(details.localPosition.dx, width) == index) {
              setState(() => _held = true);
            }
          },
          onTapUp: (details) {
            setState(() => _held = false);
            _tap(_slotAt(details.localPosition.dx, width));
          },
          onTapCancel: () => setState(() => _held = false),
          onHorizontalDragStart: (details) {
            if (index == null) return;
            if (_slotAt(details.localPosition.dx, width) != index) return;
            setState(() {
              _held = true;
              _drag = index.toDouble();
            });
          },
          onHorizontalDragUpdate: (details) {
            final drag = _drag;
            if (drag == null) return;
            setState(() {
              _drag = (drag + details.delta.dx / slot).clamp(
                0.0,
                (_count - 1).toDouble(),
              );
            });
          },
          onHorizontalDragEnd: (_) => _release(),
          onHorizontalDragCancel: _release,
          child: GlassSpring(
            target: _drag ?? (index ?? 0).toDouble(),
            jump: _jump,
            spring: _drag != null ? GlassSprings.follow : GlassSprings.settle,
            builder: (context, position, velocity, _) => GlassSpring(
              target: !still && (_held || _travelling || _drag != null) ? 1 : 0,
              spring: GlassSprings.press,
              builder: (context, lens, _, _) => _paint(
                context,
                width: width,
                position: position,
                velocity: still ? 0 : velocity,
                lens: lens.clamp(0.0, 1.0),
                track: track,
                platter: platter,
              ),
            ),
          ),
        );
        return Semantics(
          container: true,
          child: Stack(
            children: [
              ExcludeSemantics(child: gestures),
              // Each choice for assistive technologies, over the drawing.
              Row(
                children: [
                  for (var i = 0; i < _count; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        enabled: widget.enabled,
                        label: widget.segments[i].label,
                        onTap: widget.enabled ? () => _tap(i) : null,
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (widget.enabled) return control;
    return IgnorePointer(child: Opacity(opacity: 0.45, child: control));
  }

  void _release() {
    final drag = _drag;
    setState(() {
      _held = false;
      _drag = null;
    });
    if (drag == null) return;
    final slot = drag.round();
    if (slot != widget.index) {
      HapticFeedback.selectionClick();
      widget.onPicked(slot);
    }
  }

  Widget _paint(
    BuildContext context, {
    required double width,
    required double position,
    required double velocity,
    required double lens,
    required Color track,
    required Color platter,
  }) {
    const inset = GlassSegmentedControl._inset;
    final brightness = Theme.of(context).brightness;
    final slot = width / _count;
    final shown = widget.index != null || _drag != null;
    final nearest = position.round();
    // Narrower along its way and a little taller while it moves fast, as
    // the tab bar's lens.
    final squash = (velocity.abs() / 10).clamp(0.0, 1.0) * 0.35;
    final grow = 1 + _growth * lens;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: track,
          ),
        ),
        if (shown)
          Positioned(
            left: inset + position * slot,
            top: inset,
            bottom: inset,
            width: slot - 2 * inset,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                grow * (1 - squash * 0.5),
                grow * (1 + squash * 0.3),
                1,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The platter at rest, gone soon after the glass shows.
                  Opacity(
                    opacity: (1 - lens / 0.3).clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: platter,
                        shadows: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GlassPlate(
                    look: GlassMaterial.lens(brightness).faded(lens),
                    shape: const StadiumBorder(),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            for (var i = 0; i < _count; i++)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      widget.segments[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _RenderedSegmented.labelStyle(
                        context,
                        selected: shown && i == nearest,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
