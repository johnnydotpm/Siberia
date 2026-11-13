import 'package:flutter/material.dart';

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

/// A pull-down menu on glass that grows out of [anchor], as the menu of a
/// title in iOS 26: UIKit's glass on iOS, Flutter's elsewhere, as all the
/// app's glass. Gives the value picked, or null.
Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required Rect anchor,
  required List<GlassMenuItem<T>> items,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black.withValues(alpha: 0.06),
  transitionDuration: const Duration(milliseconds: 280),
  pageBuilder: (context, animation, _) =>
      _GlassMenu(anchor: anchor, items: items, animation: animation),
);

class _GlassMenu<T> extends StatelessWidget {
  const _GlassMenu({
    required this.anchor,
    required this.items,
    required this.animation,
  });

  final Rect anchor;
  final List<GlassMenuItem<T>> items;
  final Animation<double> animation;

  static const double _width = 250;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final left = anchor.left.clamp(8.0, screen.width - _width - 8);
    final grow = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    final divider = theme.colorScheme.onSurface.withValues(alpha: 0.12);
    return Stack(
      children: [
        Positioned(
          left: left,
          top: anchor.bottom + 6,
          width: _width,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              alignment: Alignment.topLeft,
              scale: Tween<double>(begin: 0.6, end: 1).animate(grow),
              child: GlassPanel(
                radius: 24,
                reveal: animation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (index, item) in items.indexed) ...[
                      if (index > 0)
                        Divider(height: 0.5, thickness: 0.5, color: divider),
                      InkWell(
                        key: item.key,
                        onTap: () => Navigator.of(context).pop(item.value),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
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
            ),
          ),
        ),
      ],
    );
  }
}
