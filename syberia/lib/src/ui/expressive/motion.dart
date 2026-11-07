import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// A spring from 0 to 1 as a [Curve], for the implicit animations that take
/// a curve and a duration. [duration] is how long the spring takes to come to
/// rest, so the pair moves exactly as the spring does.
///
/// Material 3 Expressive moves with springs (see `Springs`); a spatial spring
/// overshoots its target a little, and so does this curve.
class SpringCurve extends Curve {
  SpringCurve(this.spring)
    : _simulation = SpringSimulation(spring, 0, 1, 0),
      duration = _settleTime(spring);

  final SpringDescription spring;

  /// How long the spring takes to settle within a thousandth of its target.
  final Duration duration;

  final SpringSimulation _simulation;

  double get _seconds =>
      duration.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  double transformInternal(double t) => _simulation.x(t * _seconds);

  /// The last moment the spring is still a thousandth or more away from its
  /// target, scanned back from two seconds.
  static Duration _settleTime(SpringDescription spring) {
    final simulation = SpringSimulation(spring, 0, 1, 0);
    const step = 0.001;
    for (var t = 2.0; t > 0; t -= step) {
      if ((simulation.x(t) - 1).abs() >= 0.001) {
        return Duration(microseconds: ((t + step) * 1e6).round());
      }
    }
    return Duration.zero;
  }
}
