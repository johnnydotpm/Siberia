import 'package:flutter/animation.dart';

/// A value at a point of an animation's cycle, as a CSS keyframe: at [at],
/// from 0 to 1, the value is [value]. The way on to the next keyframe
/// follows [curve], or the track's own curve when there is none.
class KF {
  const KF(this.at, this.value, [this.curve]);

  final double at;
  final double value;
  final Curve? curve;
}

/// One animated value over a cycle, given by keyframes in order.
class Track {
  const Track(this.keys, [this.curve = Curves.linear]);

  final List<KF> keys;

  /// The animation's timing, used between keyframes without their own.
  final Curve curve;

  /// The value at [t], from 0 to 1 of the cycle.
  double at(double t) {
    if (t <= keys.first.at) return keys.first.value;
    for (var index = 1; index < keys.length; index++) {
      final end = keys[index];
      if (t <= end.at) {
        final start = keys[index - 1];
        final span = end.at - start.at;
        if (span <= 0) return end.value;
        final fraction = ((t - start.at) / span).clamp(0.0, 1.0);
        final eased = (start.curve ?? curve).transform(fraction);
        return start.value + (end.value - start.value) * eased;
      }
    }
    return keys.last.value;
  }
}

/// Where a part started [delay] after the others is in its own cycle of
/// [cycle] when the cycle as a whole is at [phase].
double delayed(double phase, Duration delay, Duration cycle) {
  final length = cycle.inMicroseconds;
  final time = phase * length - delay.inMicroseconds;
  return (time % length) / length;
}

/// Where a looping part with its own [period] is when the cycle of [cycle]
/// is at [phase], [delay] after the others; negative delays start it partway.
double looping(
  double phase,
  Duration period,
  Duration cycle, {
  Duration delay = Duration.zero,
}) {
  final time = phase * cycle.inMicroseconds - delay.inMicroseconds;
  final length = period.inMicroseconds;
  return (time % length) / length;
}

/// Back and forth over [period] each way, easing at both ends, as a CSS
/// animation that alternates: 0 at the start, 1 after one period.
double alternating(
  double phase,
  Duration period,
  Duration cycle, {
  Curve curve = Curves.easeInOut,
}) {
  final run = looping(phase, period * 2, cycle) * 2;
  return curve.transform(run <= 1 ? run : 2 - run);
}

/// The CSS curves the supplied animations use.
abstract final class Css {
  static const pop = Cubic(0.2, 0.8, 0.2, 1);
  static const settle = Cubic(0.3, 0.7, 0.2, 1);
  static const rise = Cubic(0.3, 0.8, 0.2, 1);
  static const leave = Cubic(0.4, 0, 1, 1);
  static const ease = Cubic(0.25, 0.1, 0.25, 1);
  static const easeOut = Cubic(0, 0, 0.58, 1);
  static const easeInOut = Cubic(0.42, 0, 0.58, 1);
  static const reveal = Cubic(0.4, 0, 0.2, 1);
  static const hoist = Cubic(0.25, 0.75, 0.3, 1);
  static const fill = Cubic(0.45, 0, 0.25, 1);
  static const fall = Cubic(0.3, 0.6, 0.4, 1);
}
