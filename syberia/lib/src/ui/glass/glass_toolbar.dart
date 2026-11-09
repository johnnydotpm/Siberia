import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'glass_material.dart';
import 'glass_motion.dart';
import 'glass_plate.dart';
import 'glass_platform.dart';
import 'native_view_link.dart';
import 'rendered_tab_bar.dart';

/// One action of a [GlassToolbar].
@immutable
class GlassAction {
  const GlassAction({
    required this.id,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  /// Identifies the action in messages from UIKit, and in tests.
  final String id;
  final String label;

  /// Null while the action cannot be taken.
  final VoidCallback? onPressed;

  /// Drawn in the system's red, as deleting is.
  final bool destructive;
}

/// The toolbar system apps show in place of the tab bar while something is
/// picked, as Mail and Files do: each action on glass of its own, the first
/// at the leading edge and the last at the trailing one, a lone one at the
/// trailing edge.
///
/// On iOS 26 it is UIKit's own toolbar. Elsewhere Flutter draws it to the
/// same sizes, of the same glass as the bar buttons.
class GlassToolbar extends StatelessWidget {
  const GlassToolbar({required this.actions, super.key});

  final List<GlassAction> actions;

  /// The red iOS gives a destructive action, light and dark.
  static Color destructive(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFFF453A)
      : const Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) =>
      GlassPlatform.backend == GlassBackend.rendered
      ? _RenderedGlassToolbar(actions)
      : _NativeGlassToolbar(actions);
}

/// UIKit's toolbar, hosted as a platform view at the bottom of the screen
/// with the page extending behind it.
class _NativeGlassToolbar extends StatefulWidget {
  const _NativeGlassToolbar(this.actions);

  final List<GlassAction> actions;

  @override
  State<_NativeGlassToolbar> createState() => _NativeGlassToolbarState();
}

class _NativeGlassToolbarState extends State<_NativeGlassToolbar> {
  static final _gestures = <Factory<OneSequenceGestureRecognizer>>{
    // UIKit must see every touch at once, as a pressed item swells.
    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
  };

  late final _link = NativeViewLink('siberia/glass_toolbar', onCall: _onCall);

  /// UIKit's toolbar height and the room above it, until the toolbar has
  /// measured itself on screen.
  double _height = 50;
  double _room = 16;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _link.update(_params());
  }

  @override
  void didUpdateWidget(_NativeGlassToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _link.update(_params());
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Map<String, Object?> _params() {
    final theme = Theme.of(context);
    return {
      'items': [
        for (final action in widget.actions)
          {
            'id': action.id,
            'label': action.label,
            'enabled': action.onPressed != null,
            'destructive': action.destructive,
          },
      ],
      'tint': theme.colorScheme.primary.toARGB32(),
      'dark': theme.brightness == Brightness.dark,
    };
  }

  Future<void> _onCall(MethodCall call) async {
    final arguments = call.arguments;
    switch (call.method) {
      case 'tap':
        for (final action in widget.actions) {
          if (action.id == arguments) {
            action.onPressed?.call();
            return;
          }
        }
      case 'metrics':
        if (arguments is! Map || !mounted) return;
        final height = arguments['height'];
        final room = arguments['room'];
        if (height is! num || height <= 0 || room is! num) return;
        setState(() {
          _height = height.toDouble();
          _room = room.toDouble();
        });
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _room + _height + MediaQuery.viewPaddingOf(context).bottom,
    // The room above only lets the glass cast its shadow; touches there
    // belong to the page behind the toolbar.
    child: _TopPassThrough(
      extent: _room,
      child: UiKitView(
        viewType: _link.viewType,
        creationParams: _link.params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _link.attach,
        gestureRecognizers: _gestures,
      ),
    ),
  );
}

/// The toolbar drawn by Flutter: what iOS 26 shows, a capsule of glass for
/// each action with its label in the accent colour, or red.
class _RenderedGlassToolbar extends StatelessWidget {
  const _RenderedGlassToolbar(this.actions);

  final List<GlassAction> actions;

  /// The height iOS 26 gives an item of a bottom toolbar.
  static const double itemHeight = 48;

  /// What iOS 26 keeps between the toolbar's items and the screen's edges.
  static const double edgeGap = 16;

  @override
  Widget build(BuildContext context) {
    final gap = RenderedGlassTabBar.bottomGap(
      MediaQuery.viewPaddingOf(context).bottom,
    );
    // Like UIKit's, the labels grow only a little with the text size: the
    // bar has a fixed height.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          edgeGap,
          RenderedGlassTabBar.headroom,
          edgeGap,
          gap,
        ),
        child: SizedBox(
          height: itemHeight,
          // Together the capsules read the page behind them once.
          child: BackdropGroup(
            child: Row(
              children: [
                for (final (index, action) in actions.indexed) ...[
                  if (index > 0 || actions.length == 1) const Spacer(),
                  _ToolbarItem(action),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One action on its own capsule of glass, which swells and lights up under
/// the finger as the bar buttons do.
class _ToolbarItem extends StatefulWidget {
  const _ToolbarItem(this.action);

  final GlassAction action;

  @override
  State<_ToolbarItem> createState() => _ToolbarItemState();
}

class _ToolbarItemState extends State<_ToolbarItem> {
  /// How much longer the glass gets under a finger.
  static const double _growth = 14;

  bool _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final enabled = action.onPressed != null;
    final tint = action.destructive
        ? GlassToolbar.destructive(theme.brightness)
        : theme.colorScheme.primary;
    // UIKit greys a disabled item out instead of fading its colour.
    final color = enabled
        ? tint
        : GlassMaterial.label(theme.brightness).withValues(alpha: 0.3);
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: action.label,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey(action.id),
        behavior: HitTestBehavior.opaque,
        onTap: action.onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                action.onPressed!();
              },
        child: Listener(
          onPointerDown: enabled ? (_) => _press(true) : null,
          onPointerUp: (_) => _press(false),
          onPointerCancel: (_) => _press(false),
          child: GlassSpring(
            target: _down ? 1 : 0,
            spring: GlassSprings.press,
            builder: (context, press, _, child) => Transform.scale(
              scale: 1 + _growth * press / 120,
              child: GlassPlate(
                look: GlassMaterial.button(theme.brightness),
                shape: const StadiumBorder(),
                child: ColoredBox(
                  // The light a pressed piece of glass takes on.
                  color: Colors.white.withValues(
                    alpha: (dark ? 0.14 : 0.3) * press.clamp(0.0, 1.0),
                  ),
                  child: child,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                widthFactor: 1,
                child: Text(
                  action.label,
                  maxLines: 1,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.41,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Leaves the top [extent] of its child out of hit testing, so touches there
/// reach whatever is painted underneath.
class _TopPassThrough extends SingleChildRenderObjectWidget {
  const _TopPassThrough({required this.extent, super.child});

  final double extent;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTopPassThrough(extent);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTopPassThrough renderObject,
  ) {
    renderObject.extent = extent;
  }
}

class _RenderTopPassThrough extends RenderProxyBox {
  _RenderTopPassThrough(this.extent);

  double extent;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      position.dy >= extent && super.hitTest(result, position: position);
}
