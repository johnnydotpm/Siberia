import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Material 3 Expressive's linear wavy progress indicator, drawn as
/// Compose's `LinearWavyProgressIndicator` draws it.
///
/// The done part is a wave (thickness 4, amplitude 3, wavelength 40) that
/// travels one wavelength a second; the rest is a straight track 4 points
/// after it, with a 4 point dot at its end. Below 10 % and from 95 % the wave
/// flattens to a line (500 ms), and grows back between them.
///
/// With animations turned off on the phone the wave stands still.
class WavyProgressIndicator extends StatefulWidget {
  const WavyProgressIndicator({
    required this.value,
    this.color,
    this.trackColor,
    this.semanticsLabel,
    this.semanticsValue,
    super.key,
  });

  /// From 0 to 1.
  final double value;

  /// The done part and the dot: primary.
  final Color? color;

  /// The rest: the secondary container, or what shows on the colour below.
  final Color? trackColor;

  final String? semanticsLabel;

  /// What a screen reader says for the value; "62%" by default.
  final String? semanticsValue;

  static const height = 10.0;
  static const thickness = 4.0;
  static const wavelength = 40.0;
  static const gap = 4.0;
  static const stopSize = 4.0;

  /// Compose's amplitude for a progress: none near the ends, full between.
  static double amplitudeFor(double value) =>
      value <= 0.1 || value >= 0.95 ? 0 : 1;

  @override
  State<WavyProgressIndicator> createState() => _WavyProgressIndicatorState();
}

class _WavyProgressIndicatorState extends State<WavyProgressIndicator>
    with TickerProviderStateMixin {
  late final _amplitude = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: WavyProgressIndicator.amplitudeFor(_value),
  )..addListener(_moveOrRest);
  late final Ticker _wave = createTicker(
    (elapsed) => _offset.value = elapsed.inMicroseconds % 1000000 / 1000000,
  );
  final _offset = ValueNotifier(0.0);
  bool _still = false;

  double get _value => widget.value.isFinite ? widget.value.clamp(0, 1) : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _moveOrRest();
  }

  @override
  void didUpdateWidget(WavyProgressIndicator old) {
    super.didUpdateWidget(old);
    final target = WavyProgressIndicator.amplitudeFor(_value);
    if (target == _amplitude.value && !_amplitude.isAnimating) return;
    if (_still) {
      _amplitude.value = target;
    } else if (target > _amplitude.value) {
      _amplitude.animateTo(target, curve: Easing.standard);
    } else if (target < _amplitude.value) {
      _amplitude.animateTo(target, curve: Easing.emphasizedAccelerate);
    }
  }

  /// The wave travels only while there is a wave to see.
  void _moveOrRest() {
    final moving = !_still && _amplitude.value > 0;
    if (moving && !_wave.isActive) {
      _wave.start();
    } else if (!moving && _wave.isActive) {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _amplitude.dispose();
    _wave.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = _value;
    return Semantics(
      label: widget.semanticsLabel,
      value: widget.semanticsValue ?? '${(value * 100).round()}%',
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(double.infinity, WavyProgressIndicator.height),
          painter: WavyProgressPainter(
            value: value,
            amplitude: _amplitude,
            offset: _offset,
            color: widget.color ?? colors.primary,
            trackColor: widget.trackColor ?? colors.secondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Paints the indicator; public for tests and for a still picture.
class WavyProgressPainter extends CustomPainter {
  WavyProgressPainter({
    required this.value,
    required this.amplitude,
    required this.offset,
    required this.color,
    required this.trackColor,
  }) : super(repaint: Listenable.merge([amplitude, offset]));

  final double value;
  final ValueListenable<double> amplitude;
  final ValueListenable<double> offset;
  final Color color;
  final Color trackColor;

  static const _cap = WavyProgressIndicator.thickness / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final halfHeight = size.height / 2;
    final amp = amplitude.value.clamp(0.0, 1.0);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = WavyProgressIndicator.thickness
      ..strokeCap = StrokeCap.round;

    final head = value * width;
    final adjustedHead = head.clamp(_cap, width - _cap);
    const adjustedTail = _cap;
    final activeVisible = head >= _cap;
    final gap = head < _cap
        ? 0.0
        : math.min(head - _cap, WavyProgressIndicator.gap);

    if (head > 0) {
      canvas.drawPath(
        _activePath(width, size.height, adjustedTail, adjustedHead, amp),
        stroke..color = color,
      );
    }

    final spacing = activeVisible ? gap + _cap * 2 : gap;
    final trackStart = math.max(_cap, adjustedHead + spacing);
    final trackEnd = width - _cap;
    if (trackEnd > trackStart) {
      canvas.drawLine(
        Offset(trackStart, halfHeight),
        Offset(trackEnd, halfHeight),
        stroke..color = trackColor,
      );
    }

    // The dot at the end, which the progress eats into as it arrives.
    var stopSize = WavyProgressIndicator.stopSize;
    var stopX = width - stopSize;
    final progressX = width * value + _cap;
    if (stopX <= progressX) {
      stopSize = math.max(0, stopSize - (progressX - stopX));
      stopX = progressX;
    }
    if (stopSize > 0) {
      canvas.drawCircle(
        Offset(stopX + stopSize / 2, halfHeight),
        stopSize / 2,
        Paint()..color = color,
      );
    }
  }

  /// A wave as long as the bar and two wavelengths more, from which the
  /// done part is cut further along as the wave travels, then moved back.
  Path _activePath(
    double width,
    double height,
    double tail,
    double head,
    double amp,
  ) {
    const wavelength = WavyProgressIndicator.wavelength;
    final full = Path()..moveTo(0, 0);
    if (amp == 0) {
      full.lineTo(width, 0);
    } else {
      const half = wavelength / 2;
      var anchorX = half;
      var controlX = half / 2;
      var controlY = height - WavyProgressIndicator.thickness;
      while (anchorX <= width + wavelength * 2) {
        full.quadraticBezierTo(controlX, controlY, anchorX, 0);
        anchorX += half;
        controlX += half;
        controlY = -controlY;
      }
    }
    final metric = full.computeMetrics().first;
    final scale = metric.length / (full.getBounds().width + 1e-8);
    final shift = amp == 0 ? 0.0 : offset.value * wavelength;
    final segment = metric.extractPath(
      (tail + shift) * scale,
      (head + shift) * scale,
    );
    // Back to where it belongs, centred, its height scaled by the amplitude.
    return segment.transform(
      (Matrix4.identity()
            ..translateByDouble(-shift, height / 2, 0, 1)
            ..scaleByDouble(1, amp == 0 ? 1 : amp, 1, 1))
          .storage,
    );
  }

  @override
  bool shouldRepaint(WavyProgressPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.amplitude != amplitude ||
      old.offset != offset;
}
