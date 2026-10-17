import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// The springs the drawn glass moves on, close to those of UIKit's bars.
abstract final class GlassSprings {
  /// Settles on a tab that was chosen, with a small overshoot.
  static final settle = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 350),
    bounce: 0.15,
  );

  /// Keeps up with a finger that drags the selection.
  static final follow = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 150),
    bounce: 0.14,
  );

  /// Swells and lets go under a touch.
  static final press = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 300),
    bounce: 0.15,
  );
}

/// Builds with a spring's current [value] and [velocity], and with [child].
typedef GlassSpringBuilder = Widget Function(
  BuildContext context,
  double value,
  double velocity,
  Widget? child,
);

/// Moves a value towards [target] on a spring.
///
/// When the target changes on the way, the value turns towards the new one
/// without losing its speed, the way a dragged thing does when it is let go.
class GlassSpring extends StatefulWidget {
  const GlassSpring({
    required this.target,
    required this.spring,
    required this.builder,
    this.jump = 0,
    this.child,
    super.key,
  });

  final double target;
  final SpringDescription spring;

  /// A new number here puts the value on [target] at once: the thing has to
  /// appear there, not travel there.
  final int jump;

  final GlassSpringBuilder builder;
  final Widget? child;

  @override
  State<GlassSpring> createState() => _GlassSpringState();
}

class _GlassSpringState extends State<GlassSpring>
    with SingleTickerProviderStateMixin {
  /// Close enough to count as arrived, for values that run from 0 to 1.
  static const _rest = Tolerance(distance: 0.0005, velocity: 0.005);

  late final _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.target,
  );

  @override
  void didUpdateWidget(GlassSpring oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jump != widget.jump) {
      _controller.value = widget.target;
      return;
    }
    final moved = oldWidget.target != widget.target;
    final swapped = oldWidget.spring != widget.spring;
    if (!moved && !(swapped && _controller.isAnimating)) return;
    final target = widget.target;
    _controller
        .animateWith(
          SpringSimulation(
            widget.spring,
            _controller.value,
            target,
            _controller.velocity,
            tolerance: _rest,
          ),
        )
        // The spring stops a hair short. A run that was not cut off by a new
        // target ends exactly where it was going.
        .then((_) {
          if (mounted && widget.target == target) _controller.value = target;
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) =>
        widget.builder(context, _controller.value, _controller.velocity, child),
  );
}
