part of '../app_shell.dart';

/// Signing in on the account step. While Librus works, the form gives way to
/// the parts of signing in as they really happen, each ticked off and shown
/// for half a second at least however fast it went; then, for a moment, the
/// students added. A failed sign-in brings the form back with its error.
class _SignInFlow extends StatefulWidget {
  const _SignInFlow({
    required this.controller,
    required this.onFlowing,
    required this.onDone,
  });

  final AppController controller;

  /// Whether the form has given way, so the step keeps it until the end.
  final ValueChanged<bool> onFlowing;

  /// Called once the students added have been shown.
  final VoidCallback onDone;

  @override
  State<_SignInFlow> createState() => _SignInFlowState();
}

class _SignInFlowState extends State<_SignInFlow>
    with TickerProviderStateMixin {
  /// The parts of signing in begun so far, in order.
  final _begun = <SignInStage>[];

  /// The part shown as under way; those before it are ticked off.
  var _shown = 0;
  bool _flowing = false;
  bool _succeeded = false;
  Set<String> _before = const {};
  List<SchoolProfile> _added = const [];

  /// The least time each part is shown under way.
  late final AnimationController _least =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advance();
      });

  /// The students added, shown before the step goes on.
  late final AnimationController _end =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
        )
        // The students stay on screen as the step slides away.
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onDone();
        });

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_watch);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_watch);
    _least.dispose();
    _end.dispose();
    super.dispose();
  }

  void _started() {
    _before = {for (final profile in widget.controller.profiles) profile.id};
    setState(() {
      _flowing = true;
      _succeeded = false;
      _begun.clear();
      _shown = 0;
    });
    widget.onFlowing(true);
  }

  void _watch() {
    final stage = widget.controller.signInStage;
    if (!_flowing || stage == null) return;
    if (_begun.isNotEmpty && _begun.last == stage) return;
    setState(() => _begun.add(stage));
    if (_begun.length == 1) _hold();
    _advance();
  }

  void _finished(bool ok) {
    if (!ok) {
      // Back to the form, which shows what went wrong.
      _least.stop();
      setState(() {
        _flowing = false;
        _begun.clear();
      });
      widget.onFlowing(false);
      return;
    }
    final profiles = widget.controller.profiles;
    final fresh = [
      for (final profile in profiles)
        if (!_before.contains(profile.id)) profile,
    ];
    setState(() {
      _succeeded = true;
      // Signing in again to students already here opens the first of them.
      _added = fresh.isNotEmpty ? fresh : [?widget.controller.activeProfile];
    });
    _advance();
  }

  /// Gives the part under way its least time.
  void _hold() {
    if (_reduceMotion(context)) return;
    unawaited(_least.forward(from: 0));
  }

  /// Ticks off the part under way once it has had its time and really is
  /// over, and ends with the students added once all are.
  void _advance() {
    if (!mounted || _least.isAnimating) return;
    final over = _succeeded ? _begun.length : _begun.length - 1;
    if (_shown < over) {
      setState(() => _shown++);
      if (_shown < _begun.length) {
        _hold();
        if (_reduceMotion(context)) _advance();
      } else {
        _advance();
      }
      return;
    }
    if (_succeeded &&
        _shown >= _begun.length &&
        _end.status == AnimationStatus.dismissed) {
      HapticFeedback.mediumImpact();
      setState(() {});
      unawaited(_end.forward());
    }
  }

  String _label(SignInStage stage) => context.tr(switch (stage) {
    SignInStage.checking => 'signInChecking',
    SignInStage.choosing => 'signInChoosing',
    SignInStage.loading => 'signInLoading',
  });

  @override
  Widget build(BuildContext context) {
    final ending = _end.status != AnimationStatus.dismissed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kept while hidden: it asks which students to add, and finishes.
        Offstage(
          offstage: _flowing,
          child: _Login(
            widget.controller,
            onStarted: _started,
            onFinished: _finished,
          ),
        ),
        if (_flowing)
          AnimatedSwitcher(
            duration: _motion(context, const Duration(milliseconds: 300)),
            child: ending
                ? _SignInDone(
                    key: const ValueKey('sign-in-done'),
                    added: _added,
                    progress: _end,
                  )
                : Card(
                    key: const ValueKey('sign-in-progress'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: AnimatedSize(
                        duration: _motion(context, _Motion.list),
                        curve: _Motion.curve,
                        alignment: Alignment.topCenter,
                        child: Column(
                          children: [
                            for (final (index, stage) in _begun.indexed)
                              if (index <= _shown)
                                _StageRow(
                                  key: ValueKey('sign-in-stage-${stage.name}'),
                                  label: _label(stage),
                                  done: index < _shown,
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}

/// One part of signing in: a spinner while under way, a tick drawing itself
/// once over.
class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.done, super.key});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      // Each row fades in as its turn comes.
      tween: Tween(begin: 0, end: 1),
      duration: _motion(context, const Duration(milliseconds: 250)),
      builder: (context, shown, child) =>
          _LightOpacity(opacity: shown, child: child),
      child: ListTile(
        leading: SizedBox.square(
          dimension: 28,
          child: done
              ? TweenAnimationBuilder<double>(
                  key: const ValueKey('tick'),
                  tween: Tween(begin: 0, end: 1),
                  duration: _motion(context, const Duration(milliseconds: 350)),
                  builder: (context, drawn, _) => _DrawnCheck(
                    progress: drawn,
                    color: colors.primary,
                    size: 28,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(4),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.primary,
                  ),
                ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: done ? FontWeight.w500 : FontWeight.w700,
            color: done ? colors.onSurfaceVariant : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The end of signing in: a tick drawing itself, and the students added
/// coming in one after another.
class _SignInDone extends StatelessWidget {
  const _SignInDone({required this.added, required this.progress, super.key});

  final List<SchoolProfile> added;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        final pop = t < 0.25
            ? 0.6 + 0.4 * Curves.easeOutBack.transform(t / 0.25)
            : 1.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Transform.scale(
                scale: pop,
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: _DrawnCheck(
                    progress: const Interval(
                      0.15,
                      0.45,
                      curve: Curves.easeInOutCubic,
                    ).transform(t),
                    color: colors.onPrimaryContainer,
                    size: 34,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('signInDone'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final (index, profile) in added.indexed)
              _LightOpacity(
                opacity: Interval(
                  math.min(0.3 + index * 0.08, 0.6),
                  math.min(0.55 + index * 0.08, 0.85),
                  curve: Curves.easeOut,
                ).transform(t),
                child: _ProfileRow(
                  key: ValueKey('sign-in-added-${profile.id}'),
                  name: profile.displayName,
                  school: profile.school,
                  color: profile.color,
                  active: false,
                ),
              ),
          ],
        );
      },
    );
  }
}
