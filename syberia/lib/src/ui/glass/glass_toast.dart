import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'glass_motion.dart';
import 'glass_platform.dart';
import 'glass_shell.dart';

/// A short word on glass over the tab bar: the glass design's snack bar.
///
/// It comes up out of the bottom on a spring while its glass appears out of
/// the page, stays a few seconds, and sinks away; a swipe down sends it off
/// at once. One shows at a time: a new one takes the place of the last.
/// UIKit's glass on iOS 26, Flutter's elsewhere, as all the app's glass.
///
/// [overlay] is taken before any wait, as a snack bar's messenger is. The
/// future completes once the word has gone.
Future<void> showGlassToast(
  OverlayState overlay, {
  required String text,
  Key? key,
  String? actionLabel,
  VoidCallback? onAction,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 4),
}) {
  _GlassToasts.dismissCurrent();
  final gone = Completer<void>();
  late final OverlayEntry entry;
  void remove() {
    if (entry.mounted) entry.remove();
    if (!gone.isCompleted) gone.complete();
    if (identical(_GlassToasts.current, entry)) {
      _GlassToasts.current = null;
      _GlassToasts.removeCurrent = null;
    }
  }

  entry = OverlayEntry(
    builder: (context) => _GlassToast(
      key: key,
      text: text,
      actionLabel: actionLabel,
      onAction: onAction,
      onTap: onTap,
      duration: duration,
      onGone: remove,
    ),
  );
  _GlassToasts.current = entry;
  _GlassToasts.removeCurrent = remove;
  overlay.insert(entry);
  return gone.future;
}

abstract final class _GlassToasts {
  static OverlayEntry? current;
  static VoidCallback? removeCurrent;

  /// The word on screen goes at once, for the next one.
  static void dismissCurrent() {
    final remove = removeCurrent;
    removeCurrent = null;
    remove?.call();
  }
}

class _GlassToast extends StatefulWidget {
  const _GlassToast({
    required this.text,
    required this.duration,
    required this.onGone,
    this.actionLabel,
    this.onAction,
    this.onTap,
    super.key,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final Duration duration;
  final VoidCallback onGone;

  @override
  State<_GlassToast> createState() => _GlassToastState();
}

class _GlassToastState extends State<_GlassToast>
    with TickerProviderStateMixin {
  /// How far below its place it starts, and sinks to.
  static const double _travel = 36;

  /// Past this, in points or points a second, a swipe down sends it off.
  static const double _throwDistance = 24;
  static const double _throwSpeed = 300;

  /// Runs from 0, gone, to 1, in place, on a spring that may pass 1.
  late final _shown = AnimationController.unbounded(vsync: this);

  /// Brings a swipe that did not send it off back to its place.
  late final _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  double _drag = 0;
  double _dragAtRelease = 0;
  bool _leaving = false;
  Timer? _timer;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _back.addListener(() {
      setState(() => _drag = _dragAtRelease * (1 - _back.value));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_still) {
        _shown.animateTo(1, duration: const Duration(milliseconds: 150));
      } else {
        _shown.animateWith(SpringSimulation(GlassSprings.settle, 0, 1, 0));
      }
      _wait();
    });
  }

  void _wait() {
    _timer?.cancel();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    await _shown.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInCubic,
    );
    if (mounted) widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shown.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final glass = GlassPlatform.backend == GlassBackend.rendered;
    final bottom =
        MediaQuery.paddingOf(context).bottom +
        GlassPlatform.metrics.value.tabBarHeight +
        14;
    final action = widget.actionLabel;
    final content = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        20,
        6,
        action == null ? 20 : 6,
        6,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  widget.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.24,
                  ),
                ),
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: () {
                  widget.onAction?.call();
                  _dismiss();
                },
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  shape: const StadiumBorder(),
                  // In the app's typeface, as the word beside it.
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(action),
              ),
          ],
        ),
      ),
    );
    final panel = GlassPanel(
      radius: 26,
      clear: true,
      // Where Flutter draws the glass, it appears out of the page; a fade of
      // the whole would leave it nothing to read.
      reveal: glass ? _shown : null,
      child: widget.onTap == null
          ? content
          : InkWell(onTap: widget.onTap, child: content),
    );
    return Stack(
      children: [
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: Semantics(
            container: true,
            liveRegion: true,
            child: GestureDetector(
              onVerticalDragStart: (_) {
                _timer?.cancel();
                _back.stop();
              },
              onVerticalDragUpdate: (details) {
                // Down it follows the finger; up it stays.
                setState(() => _drag = math.max(0, _drag + details.delta.dy));
              },
              onVerticalDragEnd: (details) {
                final speed = details.primaryVelocity ?? 0;
                if (_drag > _throwDistance || speed > _throwSpeed) {
                  _dismiss();
                  return;
                }
                _dragAtRelease = _drag;
                _back.forward(from: 0);
                _wait();
              },
              child: AnimatedBuilder(
                animation: _shown,
                child: panel,
                builder: (context, child) {
                  final t = _shown.value;
                  final shown = t.clamp(0.0, 1.0);
                  Widget result = child!;
                  if (!glass) {
                    // UIKit's glass fades with its view.
                    result = Opacity(opacity: shown, child: result);
                  }
                  if (_still) return result;
                  return Transform.translate(
                    offset: Offset(0, (1 - t) * _travel + _drag),
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * t,
                      alignment: Alignment.bottomCenter,
                      child: result,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
