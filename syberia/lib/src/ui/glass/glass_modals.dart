import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'glass_material.dart';
import 'glass_plate.dart';
import 'glass_platform.dart';
import 'glass_shell.dart';

/// The barrier behind a glass sheet or dialog. It is lighter than Material's,
/// so the material still has something to refract.
Color get glassBarrierColor => Colors.black.withValues(alpha: 0.2);

/// Shows a modal bottom sheet.
///
/// A [compact] sheet holds a few lines of detail. In the glass design it
/// floats above the bottom edge as a glass panel, the way a system sheet does
/// on iOS 26 at a small height. Tall sheets and every sheet of the classic
/// design keep the regular opaque Material surface, which reads better under
/// forms and long text.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool compact = false,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool showDragHandle = false,
  BoxConstraints? constraints,
}) {
  if (!compact || !GlassStyle.of(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      constraints: constraints,
      builder: builder,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    constraints: constraints,
    barrierColor: glassBarrierColor,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // The glass rounds its own corners. A rounded Material shape would clip
    // the platform view and flatten the material.
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.none,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: GlassPanel(
        radius: 38,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDragHandle) const _Grabber(),
            Flexible(child: builder(context)),
          ],
        ),
      ),
    ),
  );
}

/// Shows a dialog whose frame is an [AppDialog].
///
/// Where Flutter draws the glass, the dialog comes up the way an iOS 26
/// alert does: the glass appears out of the page while it settles from a
/// little too large. Material's fade would not do there, because glass
/// inside a fading layer has no page behind it to show. The panel fades
/// itself instead; see [AppDialog].
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (!GlassStyle.of(context)) {
    return showDialog<T>(context: context, builder: builder);
  }
  if (GlassPlatform.backend != GlassBackend.rendered) {
    return showDialog<T>(
      context: context,
      barrierColor: glassBarrierColor,
      builder: builder,
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: glassBarrierColor,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, _, _) => SafeArea(child: Builder(builder: builder)),
    transitionBuilder: (context, animation, _, child) => ScaleTransition(
      scale: Tween<double>(
        begin: 1.1,
        end: 1,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// The frame of a dialog: Material's, or a glass panel in the glass design.
class AppDialog extends StatelessWidget {
  const AppDialog({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!GlassStyle.of(context)) return Dialog(child: child);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.none,
      // The route does not fade the dialog in, so the panel does it.
      child: GlassPanel(
        radius: 34,
        reveal: ModalRoute.of(context)?.animation,
        child: child,
      ),
    );
  }
}

/// The handle at the top of a sheet that can be dragged away.
class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

/// One choice of [showGlassMenu].
@immutable
class GlassMenuItem<T> {
  const GlassMenuItem({
    required this.value,
    required this.label,
    this.selected = false,
    this.key,
  });

  final T value;
  final String label;

  /// Marked with a check, as the choice in force.
  final bool selected;
  final Key? key;
}

/// A pull-down menu on glass that comes out of [anchor], as the menu of a
/// title does in iOS 26. Gives the value picked, or null.
///
/// Where Flutter draws the glass, the glass pours out of the title like a
/// drop: it starts as a capsule over the title, flows down into the menu on
/// springs, a little stiffer across than down, so it stretches and settles
/// with a wobble, and its labels come up once it is nearly there. Closing,
/// it folds back into the title. On iOS 26 the title opens UIKit's own menu
/// instead (see `NativeGlassMenuButton`).
Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required Rect anchor,
  required List<GlassMenuItem<T>> items,
}) => Navigator.of(context).push<T>(
  _GlassMenuRoute<T>(
    anchor: anchor,
    items: items,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    liquid: GlassPlatform.backend == GlassBackend.rendered,
  ),
);

class _GlassMenuRoute<T> extends PopupRoute<T> {
  _GlassMenuRoute({
    required this.anchor,
    required this.items,
    required this.barrierLabel,
    required this.liquid,
  });

  final Rect anchor;
  final List<GlassMenuItem<T>> items;

  /// Whether the glass pours out of the title, where Flutter draws it.
  final bool liquid;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.06);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration =>
      liquid ? _GlassMenu.pour : const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _GlassMenu<T>(
    anchor: anchor,
    items: items,
    animation: animation,
    liquid: liquid,
  );

  // No fade of the drawn glass: inside a faded layer it has no page to read,
  // and would come up flat. UIKit's glass follows the route's fade.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => liquid ? child : FadeTransition(opacity: animation, child: child);
}

/// A spring's way from 0 to 1, as SwiftUI describes one: [response] is how
/// long one swing takes, [damping] how much of the swing dies away, 1 for
/// none past the end. It runs over [time] seconds of the curve.
class _SpringCurve extends Curve {
  const _SpringCurve({
    required this.response,
    required this.damping,
    required this.time,
  });

  final double response;
  final double damping;
  final double time;

  @override
  double transformInternal(double t) {
    final omega = 2 * math.pi / response;
    final spring = SpringDescription(
      mass: 1,
      stiffness: omega * omega,
      damping: 2 * damping * omega,
    );
    return SpringSimulation(spring, 0, 1, 0).x(t * time);
  }
}

class _GlassMenu<T> extends StatelessWidget {
  const _GlassMenu({
    required this.anchor,
    required this.items,
    required this.animation,
    required this.liquid,
  });

  final Rect anchor;
  final List<GlassMenuItem<T>> items;
  final Animation<double> animation;
  final bool liquid;

  static const double _width = 250;
  static const double _radius = 24;

  /// How long the glass takes to pour out and settle.
  static const pour = Duration(milliseconds: 600);
  static final _seconds = pour.inMicroseconds / Duration.microsecondsPerSecond;

  /// Across, the glass is a little stiffer and calmer than down, so it
  /// stretches as it flows and settles with a wobble.
  static final _across = _SpringCurve(
    response: 0.42,
    damping: 0.72,
    time: _seconds,
  );
  static final _down = _SpringCurve(
    response: 0.5,
    damping: 0.62,
    time: _seconds,
  );

  static double _phase(double t, double start, double length) =>
      ((t - start) / length).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final row = math.max(48.0, scaler.scale(17) * 1.3 + 12);
    final height = items.length * row + (items.length - 1) * 0.5;
    final left = anchor.left.clamp(8.0, screen.width - _width - 8);
    final target = Rect.fromLTWH(left, anchor.bottom + 6, _width, height);
    final divider = theme.colorScheme.onSurface.withValues(alpha: 0.12);
    final content = SizedBox(
      width: _width,
      height: height,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (index, item) in items.indexed) ...[
              if (index > 0)
                Divider(height: 0.5, thickness: 0.5, color: divider),
              InkWell(
                key: item.key,
                onTap: () => Navigator.of(context).pop(item.value),
                child: SizedBox(
                  height: row,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: item.selected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurface,
                                )
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 17,
                              letterSpacing: -0.41,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (!liquid) {
      final grow = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return Stack(
        children: [
          Positioned(
            left: target.left,
            top: target.top,
            child: ScaleTransition(
              alignment: Alignment.topLeft,
              scale: Tween<double>(begin: 0.6, end: 1).animate(grow),
              child: GlassPanel(
                radius: _radius,
                reveal: animation,
                clear: true,
                child: content,
              ),
            ),
          ),
        ],
      );
    }
    // The glass starts as a capsule over the title it comes out of.
    final source = Rect.fromLTWH(
      left,
      anchor.top,
      math.min(anchor.width, _width),
      anchor.height,
    );
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final look = GlassMaterial.menu(theme.brightness);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final opening = animation.status != AnimationStatus.reverse;
        final double across, top, bottom, glass, labels;
        if (still) {
          across = top = bottom = 1;
          glass = labels = t;
        } else if (opening) {
          across = _across.transform(t);
          top = _down.transform(t);
          // The bottom trails the rest: the glass pours down.
          bottom = _down.transform(_phase(t, 0.05, 0.95));
          glass = Curves.easeOut.transform(_phase(t, 0, 0.3));
          labels = Curves.easeOut.transform(_phase(t, 0.3, 0.4));
        } else {
          // Back into the title without a bounce: the labels go first, the
          // bottom comes up ahead of the rest, the glass goes last.
          across = Curves.easeInOutCubic.transform(t);
          top = across;
          bottom = Curves.easeInOutCubic.transform(_phase(t, 0.12, 0.88));
          glass = Curves.easeOut.transform(_phase(t, 0, 0.35));
          labels = _phase(t, 0.55, 0.35);
        }
        double lerp(double a, double b, double f) => a + (b - a) * f;
        final l = lerp(source.left, target.left, across);
        final r = lerp(source.right, target.right, across);
        final y = lerp(source.top, target.top, top);
        final rect = Rect.fromLTRB(
          l,
          y,
          math.max(r, l + 1),
          math.max(lerp(source.bottom, target.bottom, bottom), y + 1),
        );
        final radius = math.min(
          lerp(source.height / 2, _radius, across.clamp(0.0, 1.0)),
          math.min(rect.width, rect.height) / 2,
        );
        // Kept just short of whole while it moves, so its rim is not baked
        // into an image for every size it passes through.
        final shown = opening && t >= 1 ? 1.0 : math.min(glass, 0.999);
        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: GlassPlate(
                look: look.faded(shown),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Transform.translate(
                  // The labels stay where the menu will be; the glass
                  // uncovers them as it flows.
                  offset: target.topLeft - rect.topLeft,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: _width,
                    maxWidth: _width,
                    minHeight: height,
                    maxHeight: height,
                    child: Opacity(
                      opacity: labels,
                      child: Transform.scale(
                        alignment: Alignment.topLeft,
                        scale: lerp(0.94, 1, labels),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
