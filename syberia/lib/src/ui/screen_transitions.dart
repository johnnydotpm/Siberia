import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How the whole screen goes over to its new look.
enum ScreenChange {
  /// The new look spreads in a circle from a point, as a theme does in
  /// Telegram.
  reveal,

  /// The old look dissolves into the new one, as for another language.
  dissolve,

  /// The old screen moves back and fades while the new one comes forward, as
  /// on entering or leaving the setup.
  zoom,
}

/// Changes of the whole screen drawn as one movement: the last frame is kept
/// as a picture, the change happens beneath it, and the picture goes away the
/// way [ScreenChange] says.
///
/// Where no picture can be taken the change happens at once: when the system
/// asks for less motion, or when [enabled] is false, as under the native glass
/// views of iOS 26, which a picture of Flutter's layers would miss.
class ScreenTransitions extends StatefulWidget {
  const ScreenTransitions({
    required this.child,
    this.enabled = true,
    this.revealing,
    super.key,
  });

  final Widget child;
  final bool enabled;

  /// True while a circle spreads, so the theme does not fade on its own under
  /// it.
  final ValueNotifier<bool>? revealing;

  /// Runs [change] behind a [kind] of transition, or at once where none can be
  /// drawn. [origin], in global coordinates, is where a circle starts.
  static void run(
    BuildContext context,
    ScreenChange kind,
    VoidCallback change, {
    Offset? origin,
  }) {
    final state = context.findAncestorStateOfType<_ScreenTransitionsState>();
    if (state == null) {
      change();
    } else {
      state._run(kind, change, origin);
    }
  }

  @override
  State<ScreenTransitions> createState() => _ScreenTransitionsState();
}

class _ScreenTransitionsState extends State<ScreenTransitions>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final AnimationController _progress = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  final _queued = <VoidCallback>[];
  ScreenChange _kind = ScreenChange.dissolve;
  Offset? _origin;
  ui.Image? _picture;

  static const _durations = {
    ScreenChange.reveal: Duration(milliseconds: 480),
    ScreenChange.dissolve: Duration(milliseconds: 260),
    ScreenChange.zoom: Duration(milliseconds: 520),
  };

  void _run(ScreenChange kind, VoidCallback change, Offset? origin) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.enabled || still) {
      change();
      return;
    }
    _queued.add(change);
    if (_queued.length > 1) return;
    _kind = kind;
    _origin = origin;
    // The picture is taken once the frame on screen is painted.
    SchedulerBinding.instance.addPostFrameCallback((_) => _start());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _start() {
    final changes = [..._queued];
    _queued.clear();
    ui.Image? picture;
    if (mounted) {
      final boundary = _boundary.currentContext?.findRenderObject();
      if (boundary is RenderRepaintBoundary && boundary.hasSize) {
        try {
          picture = boundary.toImageSync(
            pixelRatio: View.of(context).devicePixelRatio,
          );
        } on Object {
          // Something asked to be painted again first: change at once.
          picture = null;
        }
      }
    }
    _finish();
    if (picture != null) {
      setState(() => _picture = picture);
      if (_kind == ScreenChange.reveal) widget.revealing?.value = true;
      _progress.duration = _durations[_kind];
      _progress.forward(from: 0);
    }
    for (final change in changes) {
      change();
    }
  }

  void _finish() {
    if (_progress.isAnimating) _progress.stop();
    widget.revealing?.value = false;
    final picture = _picture;
    if (picture == null) return;
    picture.dispose();
    if (mounted) setState(() => _picture = null);
  }

  @override
  void dispose() {
    _progress.dispose();
    _picture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = _picture;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          key: _boundary,
          child: AnimatedBuilder(
            animation: _progress,
            child: widget.child,
            // The new screen settles into place as the old one moves back.
            builder: (context, child) => Transform.scale(
              scale: picture != null && _kind == ScreenChange.zoom
                  ? 1.06 - 0.06 * Curves.easeOutCubic.transform(_progress.value)
                  : 1,
              child: child,
            ),
          ),
        ),
        if (picture != null)
          Positioned.fill(
            key: const ValueKey('screen-transition'),
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PicturePainter(
                  picture: picture,
                  kind: _kind,
                  origin: _origin,
                  progress: _progress,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The old frame, going away: a circle opening in it, fading, or moving back.
class _PicturePainter extends CustomPainter {
  _PicturePainter({
    required this.picture,
    required this.kind,
    required this.origin,
    required this.progress,
  }) : super(repaint: progress);

  final ui.Image picture;
  final ScreenChange kind;
  final Offset? origin;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final source = Rect.fromLTWH(
      0,
      0,
      picture.width.toDouble(),
      picture.height.toDouble(),
    );
    final screen = Offset.zero & size;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    switch (kind) {
      case ScreenChange.reveal:
        final t = Curves.easeInOutCubic.transform(progress.value);
        final center = origin ?? size.center(Offset.zero);
        // Far enough to clear the farthest corner.
        final reach = [
          screen.topLeft,
          screen.topRight,
          screen.bottomLeft,
          screen.bottomRight,
        ].map((corner) => (corner - center).distance).reduce(math.max);
        canvas.save();
        canvas.clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(screen)
            ..addOval(Rect.fromCircle(center: center, radius: reach * t)),
        );
        canvas.drawImageRect(picture, source, screen, paint);
        canvas.restore();
      case ScreenChange.dissolve:
        final t = Curves.easeOut.transform(progress.value);
        paint.color = Color.fromRGBO(0, 0, 0, 1 - t);
        canvas.drawImageRect(picture, source, screen, paint);
      case ScreenChange.zoom:
        final t = Curves.easeOutCubic.transform(progress.value);
        final scale = 1 - 0.08 * t;
        final center = size.center(Offset.zero);
        paint.color = Color.fromRGBO(0, 0, 0, 1 - t);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.scale(scale);
        canvas.translate(-center.dx, -center.dy);
        canvas.drawImageRect(picture, source, screen, paint);
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PicturePainter old) =>
      old.picture != picture || old.kind != kind || old.origin != origin;
}
