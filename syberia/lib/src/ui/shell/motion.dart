part of '../app_shell.dart';

/// How long things on screen take to move, and how, close to iOS.
abstract final class _Motion {
  /// Rows coming and going.
  static const list = Duration(milliseconds: 250);

  /// A day or a week sliding in.
  static const page = Duration(milliseconds: 300);

  static const curve = Curves.easeInOutCubic;
}

/// Whether the system asks for less motion.
bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A column whose children come and go smoothly: a new one unfolds and
/// fades in, one taken out fades and folds away, and the rest slide into
/// place. Children are told apart by their keys, which must be unique.
///
/// The first build shows everything as it is; only later changes move.
class _AnimatedColumn extends StatefulWidget {
  const _AnimatedColumn({required this.children, this.spacing = 0, super.key});

  final List<Widget> children;

  /// The room above each child but the first.
  final double spacing;

  @override
  State<_AnimatedColumn> createState() => _AnimatedColumnState();
}

class _ColumnEntry {
  _ColumnEntry(this.widget, this.controller)
    : size = CurvedAnimation(parent: controller, curve: _Motion.curve);

  Widget widget;
  final AnimationController controller;
  final CurvedAnimation size;

  /// Taken out, and folding away.
  bool leaving = false;

  /// The room above it, kept while it leaves.
  double gap = 0;

  void dispose() {
    size.dispose();
    controller.dispose();
  }
}

class _AnimatedColumnState extends State<_AnimatedColumn>
    with TickerProviderStateMixin {
  var _entries = <_ColumnEntry>[];

  _ColumnEntry _entry(Widget child, {required bool shown}) {
    assert(child.key != null, 'Each child needs a key.');
    final entry = _ColumnEntry(
      child,
      AnimationController(
        vsync: this,
        duration: _Motion.list,
        value: shown ? 1 : 0,
      ),
    );
    entry.controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && entry.leaving) {
        _drop(entry);
      }
    });
    return entry;
  }

  /// Done folding away: out of the column.
  void _drop(_ColumnEntry entry) {
    if (!mounted) return;
    setState(() => _entries.remove(entry));
    // Not from within its own listener.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  @override
  void initState() {
    super.initState();
    _entries = [
      for (final child in widget.children) _entry(child, shown: true),
    ];
  }

  @override
  void didUpdateWidget(_AnimatedColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final animate = !_reduceMotion(context);
    final keys = {for (final child in widget.children) child.key};
    assert(keys.length == widget.children.length, 'Keys must be unique.');
    final byKey = {for (final entry in _entries) entry.widget.key: entry};
    // One taken out stays where it was: after the child it followed.
    final after = <Key?, List<_ColumnEntry>>{};
    final gone = <_ColumnEntry>[];
    Key? last;
    for (final entry in _entries) {
      final key = entry.widget.key;
      if (keys.contains(key)) {
        last = key;
        continue;
      }
      if (!animate) {
        gone.add(entry);
        continue;
      }
      after.putIfAbsent(last, () => []).add(entry);
      if (!entry.leaving) {
        entry.leaving = true;
        entry.controller.reverse();
      }
    }
    final next = <_ColumnEntry>[...?after[null]];
    for (final child in widget.children) {
      var entry = byKey[child.key];
      if (entry == null) {
        entry = _entry(child, shown: !animate);
        if (animate) entry.controller.forward();
      } else {
        entry.widget = child;
        if (entry.leaving) {
          // Back before it was gone.
          entry.leaving = false;
          entry.controller.forward();
        }
      }
      next.add(entry);
      next.addAll(after[child.key] ?? const []);
    }
    _entries = next;
    if (gone.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final entry in gone) {
          entry.dispose();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var shown = 0;
    for (final entry in _entries) {
      if (!entry.leaving) entry.gap = shown++ == 0 ? 0.0 : widget.spacing;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in _entries)
          KeyedSubtree(
            key: ValueKey(('slot', entry.widget.key)),
            child: IgnorePointer(
              // On its way out, it takes no taps.
              ignoring: entry.leaving,
              child: SizeTransition(
                sizeFactor: entry.size,
                alignment: AlignmentDirectional.topStart,
                child: FadeTransition(
                  opacity: entry.controller,
                  child: AnimatedPadding(
                    duration: _Motion.list,
                    curve: _Motion.curve,
                    padding: EdgeInsets.only(top: entry.gap),
                    child: entry.widget,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Grey shapes where content is about to be, breathing gently, as in iOS,
/// instead of a spinner. Still when the system asks for less motion.
class _Skeleton extends StatefulWidget {
  const _Skeleton({required this.child, super.key});

  /// Made of [_Bone]s.
  final Widget child;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FadeTransition(opacity: _pulse, child: widget.child),
  );
}

/// One grey shape of a [_Skeleton]: a line of text, a circle, a card.
class _Bone extends StatelessWidget {
  const _Bone({this.width, this.height = 12, this.radius = 6});

  /// The whole width when null.
  final double? width;
  final double height;
  final double radius;

  const _Bone.circle(double size)
    : width = size,
      height = size,
      radius = size / 2;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Rows of messages about to load: an avatar and two lines each.
class _MessageRowsSkeleton extends StatelessWidget {
  const _MessageRowsSkeleton();
  static const rows = 4;

  @override
  Widget build(BuildContext context) => _Skeleton(
    child: Column(
      children: [
        for (var index = 0; index < rows; index++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Bone.circle(40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 3),
                      FractionallySizedBox(
                        widthFactor: const [0.5, 0.65, 0.4, 0.55][index % 4],
                        child: const _Bone(height: 13),
                      ),
                      const SizedBox(height: 8),
                      FractionallySizedBox(
                        widthFactor: const [0.85, 0.7, 0.9, 0.75][index % 4],
                        child: const _Bone(height: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Lines of text about to load, as in a paragraph.
class _TextSkeleton extends StatelessWidget {
  const _TextSkeleton();
  static const lines = 6;

  @override
  Widget build(BuildContext context) => _Skeleton(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          FractionallySizedBox(
            // The last line of a paragraph stops short.
            widthFactor: index == lines - 1
                ? 0.45
                : const [1.0, 0.94, 0.97, 0.9][index % 4],
            child: const _Bone(height: 14),
          ),
        ],
      ],
    ),
  );
}

/// Lessons of a day about to load: a time rail and a card each.
class _LessonsSkeleton extends StatelessWidget {
  const _LessonsSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _Skeleton(
    child: Column(
      children: [
        for (var index = 0; index < 5; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: _TimetableTimeline._axisWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      _Bone(width: 36),
                      SizedBox(height: 6),
                      _Bone(width: 28, height: 10),
                    ],
                  ),
                ),
                const Expanded(child: _Bone(height: 72, radius: 14)),
              ],
            ),
          ),
      ],
    ),
  );
}
