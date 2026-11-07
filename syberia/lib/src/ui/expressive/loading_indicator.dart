import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import 'shapes.dart';

/// Material 3 Expressive's loading indicator: a shape that keeps turning and
/// morphing into the next of seven, as Compose's `LoadingIndicator` does.
///
/// Every 650 ms a spring (damping 0.6, stiffness 200) morphs the shape into
/// the next one and turns it a quarter more, while the whole indicator turns
/// once every 4.666 s. The shape fills 38 of the indicator's 48 points.
/// [contained] puts it on a circle of the primary container.
///
/// With animations turned off on the phone it stands still.
class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({
    this.contained = false,
    this.color,
    this.containerColor,
    this.semanticsLabel,
    super.key,
  });

  final bool contained;

  /// The shape's colour: primary, or on the primary container when
  /// contained.
  final Color? color;

  /// The circle's colour when [contained]: the primary container.
  final Color? containerColor;

  final String? semanticsLabel;

  /// The shapes it goes through (LoadingIndicatorDefaults).
  static final List<RoundedPolygon> polygons = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
  ];

  static const size = 48.0;
  static const _activeSize = 38.0;
  static const morphInterval = Duration(milliseconds: 650);
  static const rotationPeriod = Duration(milliseconds: 4666);

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (elapsed) => _elapsed.value = elapsed,
  );
  final _elapsed = ValueNotifier(Duration.zero);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _ticker.isActive) {
      _ticker.stop();
      _elapsed.value = Duration.zero;
    } else if (!still && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color =
        widget.color ??
        (widget.contained ? colors.onPrimaryContainer : colors.primary);
    Widget indicator = CustomPaint(
      size: const Size.square(LoadingIndicator.size),
      painter: _LoadingPainter(_elapsed, color),
    );
    if (widget.contained) {
      indicator = DecoratedBox(
        decoration: ShapeDecoration(
          color: widget.containerColor ?? colors.primaryContainer,
          shape: const CircleBorder(),
        ),
        child: indicator,
      );
    }
    return Semantics(
      label: widget.semanticsLabel,
      // Like an indeterminate progress bar.
      value: '',
      child: RepaintBoundary(child: indicator),
    );
  }
}

/// Where the indicator is at a moment: which morph, how far along, how far
/// turned. Kept apart from painting so tests can check it.
@visibleForTesting
({int morph, double progress, double degrees}) loadingIndicatorFrame(
  Duration elapsed,
) {
  final ms = elapsed.inMicroseconds / 1000;
  final interval = LoadingIndicator.morphInterval.inMilliseconds;
  final cycle = ms ~/ interval;
  final seconds = (ms - cycle * interval) / 1000;
  final count = LoadingIndicator.polygons.length;
  // A morph ends once its spring is near enough to rest; the next shape
  // then waits, a quarter further turned, for the next interval.
  final settled = seconds >= _morphSettle;
  final progress = settled ? 0.0 : _morphSpring.x(seconds);
  final quarters = settled ? cycle + 2 : cycle + 1;
  final morph = (settled ? cycle + 1 : cycle) % count;
  final turn =
      ms %
      LoadingIndicator.rotationPeriod.inMilliseconds /
      LoadingIndicator.rotationPeriod.inMilliseconds *
      360;
  return (
    morph: morph,
    progress: progress,
    degrees: (progress * 90 + quarters * 90 + turn) % 360,
  );
}

final _morphSpring = SpringSimulation(
  SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.6),
  0,
  1,
  0,
);

/// When the morph spring stays within 0.1 of its end, Compose's raised
/// visibility threshold, from then on.
final double _morphSettle = () {
  for (var t = 1.0; t > 0; t -= 0.001) {
    if ((_morphSpring.x(t) - 1).abs() >= 0.1) return t + 0.001;
  }
  return 0.0;
}();

final _morphs = [
  for (var i = 0; i < LoadingIndicator.polygons.length; i++)
    Morph(
      LoadingIndicator.polygons[i].normalized(),
      LoadingIndicator.polygons[(i + 1) % LoadingIndicator.polygons.length]
          .normalized(),
    ),
];

final _scale =
    rotationSafeScale(LoadingIndicator.polygons) *
    LoadingIndicator._activeSize /
    LoadingIndicator.size;

class _LoadingPainter extends CustomPainter {
  _LoadingPainter(this.elapsed, this.color) : super(repaint: elapsed);

  final ValueListenable<Duration> elapsed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = loadingIndicatorFrame(elapsed.value);
    final unit = _morphs[frame.morph].toPath(progress: frame.progress);
    final scaled = unit.transform(
      (Matrix4.identity()
            ..scaleByDouble(size.width * _scale, size.height * _scale, 1, 1))
          .storage,
    );
    final center = size.center(Offset.zero);
    final path = scaled.shift(center - scaled.getBounds().center);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(frame.degrees * math.pi / 180)
      ..translate(-center.dx, -center.dy)
      ..drawPath(path, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_LoadingPainter old) =>
      old.color != color || old.elapsed != elapsed;
}
