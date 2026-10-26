part of '../app_shell.dart';

/// The startup animation carried on in the setup until the whole logo has
/// been shown, however fast the app loaded. Then the wordmark leaves, the
/// mark flies to its place on the first step, and the page comes in from
/// beneath. A tap starts the flight at once. On a holiday it is that day's
/// animation.
class _SetupIntro extends StatefulWidget {
  const _SetupIntro({
    required this.event,
    required this.from,
    required this.target,
    required this.background,
    required this.onFlight,
    required this.onDone,
    super.key,
  });

  /// Whose animation it is: the day's, as on the startup screen.
  final BrandEvent event;

  /// How far the animation had got on the startup screen.
  final Duration from;

  /// The logo of the first step, where the mark lands.
  final GlobalKey target;

  /// The startup screen's background, which fades as the mark flies.
  final Color background;

  /// Called on the way, for the page beneath to come in.
  final VoidCallback onFlight;

  /// Called once the mark has landed.
  final VoidCallback onDone;

  @override
  State<_SetupIntro> createState() => _SetupIntroState();
}

/// Where the flight goes, measured as it starts.
typedef _FlightPath = ({
  Rect icon,
  double iconOpacity,
  Rect? wordHome,
  double word,
  Rect target,
  Rect? wordRect,
  double phase,
});

class _SetupIntroState extends State<_SetupIntro>
    with TickerProviderStateMixin {
  final _icon = GlobalKey();
  final _word = GlobalKey();
  // Kept from the start, so a new day at midnight cannot change the
  // animation halfway.
  late final BrandEvent _event = widget.event;
  late final LogoMotion _motion = LogoMotion.of(_event);
  late final AnimationController _logo = AnimationController(
    vsync: this,
    duration: _motion.cycle,
  );
  late final AnimationController _flight =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )
        ..addListener(() {
          // The page comes in as the mark arrives, not under it.
          if (!_pageCalled && _flight.value >= 0.6) {
            _pageCalled = true;
            widget.onFlight();
          }
        })
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onDone();
        });
  _FlightPath? _path;
  bool _pageCalled = false;

  @override
  void initState() {
    super.initState();
    final cycle = _motion.cycle.inMicroseconds;
    final elapsed = widget.from.inMicroseconds;
    final phase = (elapsed % cycle) / cycle;
    _logo.value = phase;
    if (elapsed < cycle * _motion.wholeEnd) {
      // On to the end of the rest, so the whole logo is seen in full.
      unawaited(_playTo(_motion.wholeEnd));
    } else if (phase >= _motion.iconStart && phase <= _motion.iconEnd) {
      // A slow start showed it already, and the mark is still whole.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fly());
    } else {
      // Round to where the mark is whole again.
      unawaited(_playTo(_motion.iconStart, round: phase > _motion.iconStart));
    }
  }

  Future<void> _playTo(double target, {bool round = false}) async {
    try {
      if (round) {
        await _logo.animateTo(1).orCancel;
        _logo.value = 0;
      }
      await _logo.animateTo(target).orCancel;
    } on TickerCanceled {
      return;
    }
    _fly();
  }

  void _fly() {
    if (_path != null || !mounted) return;
    _logo.stop();
    final overlay = context.findRenderObject();
    Rect? rectOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || overlay is! RenderBox) {
        return null;
      }
      return MatrixUtils.transformRect(
        box.getTransformTo(overlay),
        Offset.zero & box.size,
      );
    }

    final icon = rectOf(_icon);
    final word = rectOf(_word);
    final target = rectOf(widget.target);
    if (icon == null || target == null) {
      widget.onFlight();
      widget.onDone();
      return;
    }
    final phase = _logo.value;
    if (_event != BrandEvent.ordinary) {
      // The frame the flight starts from stays as it was: the name fades
      // away, the mark settles into its resting look as it lands.
      setState(
        () => _path = (
          icon: icon,
          iconOpacity: 1,
          wordHome: null,
          word: 1,
          target: target,
          wordRect: word,
          phase: phase,
        ),
      );
      unawaited(_flight.forward());
      return;
    }
    final out = BrandLogoFrame.word(phase);
    setState(
      () => _path = (
        icon: icon,
        iconOpacity: BrandLogoFrame.iconOpacity(phase),
        // Where the wordmark rests when fully out: it is drawn shifted
        // towards the mark until then.
        wordHome: word?.shift(Offset(1.1 * (1 - out) * word.width, 0)),
        word: out,
        target: target,
        wordRect: null,
        phase: phase,
      ),
    );
    unawaited(_flight.forward());
  }

  @override
  void dispose() {
    _logo.dispose();
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path == null) {
      return Semantics(
        button: true,
        label: 'SiberiaGB',
        hint: context.tr('introSkip'),
        onTap: _fly,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _fly,
          // Laid out as the startup screen is, so carrying on shows no seam.
          child: ColoredBox(
            color: widget.background,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _logo,
                        builder: (context, _) => BrandLogoFrame(
                          phase: _logo.value,
                          event: _event,
                          iconKey: _icon,
                          wordKey: _word,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_event != BrandEvent.ordinary) return _eventFlight(path);
    return IgnorePointer(
      child: AnimatedBuilder(
        key: const ValueKey('setup-intro-flight'),
        animation: _flight,
        builder: (context, _) {
          final t = _flight.value;
          final fade = const Interval(
            0.3,
            0.9,
            curve: Curves.easeOut,
          ).transform(t);
          final leave = const Interval(
            0,
            0.45,
            curve: Curves.easeInCubic,
          ).transform(t);
          final move = const Interval(
            0.1,
            1,
            curve: Curves.easeInOutCubic,
          ).transform(t);
          final word = path.word * (1 - leave);
          final iconOpacity =
              path.iconOpacity +
              (1 - path.iconOpacity) * const Interval(0, 0.3).transform(t);
          final home = path.wordHome;
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: widget.background.withValues(alpha: 1 - fade),
                ),
              ),
              if (home != null)
                Positioned.fromRect(
                  rect: home,
                  child: ClipRect(
                    child: FractionalTranslation(
                      translation: Offset(-1.1 * (1 - word), 0),
                      child: Opacity(
                        opacity: word.clamp(0.0, 1.0),
                        child: const FittedBox(child: BrandWordmark()),
                      ),
                    ),
                  ),
                ),
              Positioned.fromRect(
                rect: Rect.lerp(path.icon, path.target, move)!,
                child: Opacity(
                  opacity: iconOpacity.clamp(0.0, 1.0),
                  child: const FittedBox(child: AppLogo()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The flight of an event's logo: the name, as it was when the flight
  /// began, fades away to the left; the mark flies, turning into its
  /// resting look as it lands, so it lands as the first step shows it.
  Widget _eventFlight(_FlightPath path) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rest = _motion.rest;
    return IgnorePointer(
      child: AnimatedBuilder(
        key: const ValueKey('setup-intro-flight'),
        animation: _flight,
        builder: (context, _) {
          final t = _flight.value;
          final fade = const Interval(
            0.3,
            0.9,
            curve: Curves.easeOut,
          ).transform(t);
          final leave = const Interval(
            0,
            0.45,
            curve: Curves.easeInCubic,
          ).transform(t);
          final move = const Interval(
            0.1,
            1,
            curve: Curves.easeInOutCubic,
          ).transform(t);
          final land = const Interval(0.7, 1).transform(t);
          final word = path.wordRect;
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: widget.background.withValues(alpha: 1 - fade),
                ),
              ),
              if (word != null)
                Positioned.fromRect(
                  rect: word,
                  child: FractionalTranslation(
                    translation: Offset(-0.3 * leave, 0),
                    child: Opacity(
                      opacity: 1 - leave,
                      child: FittedBox(
                        child: EventWordmark(
                          event: _event,
                          phase: path.phase,
                          accessories: true,
                          clip: true,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fromRect(
                rect: Rect.lerp(path.icon, path.target, move)!,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 1 - land,
                      child: CustomPaint(
                        painter: BrandMarkPainter(
                          event: _event,
                          phase: path.phase,
                          dark: dark,
                        ),
                      ),
                    ),
                    if (land > 0)
                      Opacity(
                        opacity: land,
                        child: CustomPaint(
                          painter: BrandMarkPainter(
                            event: _event,
                            phase: rest,
                            dark: dark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
