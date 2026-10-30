import 'package:flutter/material.dart';

import 'brand/brand_events.dart';
import 'brand/brand_mark.dart';
import 'brand/brand_motion.dart';
import 'brand/brand_wordmark.dart';

export 'brand/brand_events.dart';
export 'brand/brand_motion.dart';

/// The book mark, drawn from the supplied SVG; on the days the logo dresses
/// up, that day's, resting. The PNGs it was drawn from stay for the native
/// launch screens.
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 84, this.event, super.key});
  final double size;

  /// The event to show; the nearest [BrandEventScope]'s when null.
  final BrandEvent? event;

  @override
  Widget build(BuildContext context) {
    final shown = event ?? BrandEventScope.of(context);
    return Semantics(
      label: 'SiberiaGB',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: BrandMarkPainter(
          event: shown,
          phase: LogoMotion.of(shown).rest,
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }
}

/// The supplied Unbounded wordmark, shared by startup and app branding.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    this.fontSize = 56,
    this.event,
    this.accessories = false,
    super.key,
  });
  final double fontSize;

  /// The event to show; the nearest [BrandEventScope]'s when null.
  final BrandEvent? event;

  /// Whether the event's detail by the name is drawn, as on the large
  /// wordmarks; a small one in a menu has the colours only.
  final bool accessories;

  @override
  Widget build(BuildContext context) {
    final shown = event ?? BrandEventScope.of(context);
    if (shown != BrandEvent.ordinary) {
      return EventWordmark(
        event: shown,
        phase: LogoMotion.of(shown).rest,
        fontSize: fontSize,
        accessories: accessories,
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Siberia',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: 'GB',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: dark ? const Color(0xFF6CC3E6) : const Color(0xFF176B8F),
            ),
          ),
        ],
      ),
      textScaler: TextScaler.noScaling,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: TextStyle(
        fontFamily: 'Unbounded',
        fontSize: fontSize,
        letterSpacing: -0.03 * fontSize,
        height: 1,
        color: dark ? Colors.white : const Color(0xFF10222C),
      ),
    );
  }
}

/// The background behind the startup animation, also where the setup carries
/// it on.
Color startupBackground(Brightness brightness, {bool amoled = false}) =>
    brightness == Brightness.light
    ? Colors.white
    : amoled
    ? Colors.black
    : const Color(0xFF0B1A22);

/// One frame of the supplied five-second animation, [phase] running from 0
/// to 1 over it: the mark pops in, the wordmark slides out from behind it,
/// both rest, and they leave again.
class BrandLogoFrame extends StatelessWidget {
  const BrandLogoFrame({
    required this.phase,
    this.event,
    this.iconKey,
    this.wordKey,
    super.key,
  });

  final double phase;

  /// The event whose animation this is a frame of; the nearest
  /// [BrandEventScope]'s when null. The ordinary one is the supplied
  /// animation, as it always was.
  final BrandEvent? event;

  /// On the mark and the wordmark, to find where they are drawn.
  final GlobalKey? iconKey;
  final GlobalKey? wordKey;

  /// The animation's length.
  static const cycle = Duration(seconds: 5);

  /// From here to [wholeEnd] the whole logo rests on screen.
  static const wholeStart = 0.38;
  static const wholeEnd = 0.80;

  /// From here to [iconEnd] the mark is fully there, at its size.
  static const iconStart = 0.13;
  static const iconEnd = 0.88;

  static double iconOpacity(double phase) => _sample(const [
    (0, 0),
    (0.08, 1),
    (0.88, 1),
    (0.97, 0),
    (1, 0),
  ], phase).clamp(0.0, 1.0);

  static double iconScale(double phase) => _sample(const [
    (0, 0.6),
    (0.08, 1.06),
    (0.13, 1),
    (0.88, 1),
    (0.97, 0.6),
    (1, 0.6),
  ], phase);

  /// How far the wordmark is out: 0 hidden behind the mark, 1 fully out.
  static double word(double phase) => _sample(const [
    (0, 0),
    (0.14, 0),
    (0.38, 1),
    (0.80, 1),
    (0.92, 0),
    (1, 0),
  ], phase);

  static double _sample(List<(double, double)> frames, double phase) {
    for (var index = 1; index < frames.length; index++) {
      final (end, target) = frames[index];
      if (phase <= end) {
        final (start, previous) = frames[index - 1];
        final fraction = ((phase - start) / (end - start)).clamp(0.0, 1.0);
        final curved = const Cubic(0.2, 0.8, 0.2, 1).transform(fraction);
        return previous + (target - previous) * curved;
      }
    }
    return frames.last.$2;
  }

  @override
  Widget build(BuildContext context) {
    final shown = event ?? BrandEventScope.of(context);
    if (shown != BrandEvent.ordinary) return _eventFrame(context, shown);
    final word = BrandLogoFrame.word(phase);
    return Semantics(
      label: 'SiberiaGB',
      image: true,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                key: const ValueKey('startup-icon-opacity'),
                opacity: iconOpacity(phase),
                child: Transform.scale(
                  scale: iconScale(phase),
                  child: AppLogo(
                    key: iconKey,
                    size: 128,
                    event: BrandEvent.ordinary,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              ClipRect(
                child: SizedBox(
                  height: 80,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: FractionalTranslation(
                      translation: Offset(-1.1 * (1 - word), 0),
                      child: Opacity(
                        key: const ValueKey('startup-word-opacity'),
                        opacity: word.clamp(0.0, 1.0),
                        child: BrandWordmark(
                          key: wordKey,
                          event: BrandEvent.ordinary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A frame of an event's animation: the mark and the wordmark painted as
  /// in the event's mockup, at the startup animation's size.
  Widget _eventFrame(BuildContext context, BrandEvent shown) => Semantics(
    label: 'SiberiaGB',
    image: true,
    child: ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              key: iconKey,
              dimension: 128,
              child: CustomPaint(
                key: const ValueKey('brand-event-mark'),
                painter: BrandMarkPainter(
                  event: shown,
                  phase: phase,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
            const SizedBox(width: 28),
            EventWordmark(
              key: wordKey,
              event: shown,
              phase: phase,
              accessories: true,
              clip: true,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Tells how long an [AnimatedBrandLogo] has been going, so the setup can
/// carry the animation on from there.
class BrandLogoTime {
  Duration Function()? _read;

  Duration get elapsed => _read?.call() ?? Duration.zero;
}

/// Flutter rendering of the supplied five-second HTML animation, going round
/// for as long as the app loads. No web view, network fonts or external
/// scripts are needed at launch.
class AnimatedBrandLogo extends StatefulWidget {
  const AnimatedBrandLogo({this.time, this.event, super.key});

  final BrandLogoTime? time;

  /// The event to animate; the nearest [BrandEventScope]'s when null.
  final BrandEvent? event;

  @override
  State<AnimatedBrandLogo> createState() => _AnimatedBrandLogoState();
}

class _AnimatedBrandLogoState extends State<AnimatedBrandLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: BrandLogoFrame.cycle,
  );
  bool? _reduceMotion;
  BrandEvent? _event;

  Duration _elapsed() => _animation.lastElapsedDuration ?? Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.time?._read = _elapsed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(AnimatedBrandLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  /// Plays the shown event's animation, or holds its resting frame with
  /// less motion.
  void _follow() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final event = widget.event ?? BrandEventScope.of(context);
    if (_reduceMotion == reduce && _event == event) return;
    _reduceMotion = reduce;
    _event = event;
    final motion = LogoMotion.of(event);
    _animation.duration = motion.cycle;
    if (reduce) {
      _animation.stop();
      _animation.value = motion.rest;
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    if (widget.time?._read == _elapsed) widget.time?._read = null;
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, _) =>
        BrandLogoFrame(phase: _animation.value, event: _event),
  );
}
