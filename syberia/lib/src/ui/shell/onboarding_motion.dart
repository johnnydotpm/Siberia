part of '../app_shell.dart';

/// [child] rising 16 into place and fading in as [animation] runs, after the
/// [index] items before it: a step's parts come in one after another.
class _Rise extends StatelessWidget {
  const _Rise({
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = math.min(index * 0.09, 0.55);
    final curve = Interval(start, start + 0.45, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      // The same widgets at rest as on the way, so nothing inside, as a text
      // field being typed in, is built anew.
      builder: (context, child) {
        final t = curve.transform(animation.value);
        return _LightOpacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Hello in each language of the app, one after another: the word goes up
/// and away, a little blurred, as the next comes up from below.
class _GreetingSwitcher extends StatelessWidget {
  const _GreetingSwitcher({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 650),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) =>
        Stack(alignment: Alignment.center, children: [...previous, ?current]),
    transitionBuilder: (child, animation) {
      final coming = child.key == ValueKey(text);
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = animation.value;
          final away = 1 - t;
          // In from below; out upwards.
          final shift = (coming ? 0.4 : -0.4) * away;
          final blur = 6 * away;
          final moved = FractionalTranslation(
            translation: Offset(0, shift),
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          );
          return blur < 0.05
              ? moved
              : ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: moved,
                );
        },
      );
    },
    child: _WholeWords(
      text,
      key: ValueKey(text),
      textAlign: TextAlign.center,
      style: style,
    ),
  );
}

/// What a step's badge does when the step opens.
enum _BadgeMotion {
  /// The palette sways and its circle passes through the theme's colours.
  palette,

  /// The cap jumps up and lands.
  cap,

  /// The bell rings.
  bell,

  /// The circle pops up and a tick draws itself.
  check,
}

/// The round badge above a step's heading, alive for a moment as the step
/// opens, and again each time [replay] changes. Still with less motion.
class _StepBadge extends StatefulWidget {
  const _StepBadge({
    required this.icon,
    required this.motion,
    required this.active,
    this.replay = 0,
  });

  final IconData icon;
  final _BadgeMotion motion;

  /// Whether its step is the one open.
  final bool active;
  final int replay;

  @override
  State<_StepBadge> createState() => _StepBadgeState();
}

class _StepBadgeState extends State<_StepBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _play.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  @override
  void didUpdateWidget(_StepBadge old) {
    super.didUpdateWidget(old);
    if (widget.active && (!old.active || widget.replay != old.replay)) {
      _start();
    }
  }

  void _start() {
    if (_reduceMotion(context)) {
      _play.value = 1;
    } else {
      unawaited(_play.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  /// Through [colors] in turn as [t] runs from 0 to 1.
  static Color _through(List<Color> colors, double t) {
    final span = t * (colors.length - 1);
    final index = span.floor().clamp(0, colors.length - 2);
    return Color.lerp(colors[index], colors[index + 1], span - index)!;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      key: ValueKey('setup-badge-${widget.motion.name}'),
      animation: _play,
      builder: (context, _) {
        final t = _play.value;
        var background = colors.primaryContainer;
        var scale = 1.0;
        Widget glyph = Icon(
          widget.icon,
          size: 36,
          color: colors.onPrimaryContainer,
        );
        switch (widget.motion) {
          case _BadgeMotion.palette:
            glyph = Transform.rotate(
              angle: math.sin(t * math.pi * 3) * 0.35 * (1 - t),
              child: glyph,
            );
            background = _through([
              colors.primaryContainer,
              colors.tertiaryContainer,
              colors.secondaryContainer,
              colors.primaryContainer,
            ], t);
          case _BadgeMotion.cap:
            final up = t < 0.6 ? math.sin(math.pi * t / 0.6) : 0.0;
            final squash = t >= 0.6 && t < 0.85
                ? math.sin(math.pi * (t - 0.6) / 0.25)
                : 0.0;
            glyph = Transform.translate(
              offset: Offset(0, -12 * up),
              child: Transform.rotate(
                angle: -0.2 * up,
                child: Transform.scale(
                  alignment: Alignment.bottomCenter,
                  scaleX: 1 + 0.1 * squash,
                  scaleY: 1 - 0.14 * squash,
                  child: glyph,
                ),
              ),
            );
          case _BadgeMotion.bell:
            glyph = Transform.rotate(
              alignment: Alignment.topCenter,
              angle:
                  math.sin(t * math.pi * 6) *
                  0.42 *
                  math.pow(1 - t, 1.5).toDouble(),
              child: glyph,
            );
          case _BadgeMotion.check:
            scale = t < 0.35
                ? 0.6 + 0.4 * Curves.easeOutBack.transform(t / 0.35)
                : 1.0;
            glyph = _DrawnCheck(
              progress: const Interval(
                0.3,
                0.85,
                curve: Curves.easeInOutCubic,
              ).transform(t),
              color: colors.onPrimaryContainer,
              size: 38,
            );
        }
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: glyph,
          ),
        );
      },
    );
  }
}

/// A tick drawn as far as [progress], from its short stroke to the end of
/// its long one.
class _DrawnCheck extends StatelessWidget {
  const _DrawnCheck({
    required this.progress,
    required this.color,
    required this.size,
  });

  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CheckPainter(progress: progress, color: color),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.53)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.8, size.height * 0.3);
    final metrics = path.computeMetrics().toList();
    var left =
        progress.clamp(0.0, 1.0) *
        metrics.fold(0.0, (length, metric) => length + metric.length);
    final drawn = Path();
    for (final metric in metrics) {
      final take = math.min(left, metric.length);
      drawn.addPath(metric.extractPath(0, take), Offset.zero);
      left -= take;
      if (left <= 0) break;
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
