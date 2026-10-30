import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import 'glass_items.dart';
import 'glass_material.dart';
import 'glass_motion.dart';
import 'glass_plate.dart';

/// The buttons of the top bar, drawn by Flutter to the sizes iOS 26 gives
/// them. Neighbours share one capsule, as in system apps, and the bar has no
/// background of its own.
class RenderedGlassBarButtons extends StatelessWidget {
  const RenderedGlassBarButtons({
    required this.leading,
    required this.trailing,
    super.key,
  });

  /// Buttons on the leading and trailing side, in reading order.
  final List<GlassBarButton> leading;
  final List<GlassBarButton> trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: GlassBarButton.edgeGap),
    // Together the capsules read the page behind them once, not once each.
    child: BackdropGroup(
      child: Row(
        children: [
          ..._capsules(leading),
          const Spacer(),
          ..._capsules(trailing),
        ],
      ),
    ),
  );

  static List<Widget> _capsules(List<GlassBarButton> buttons) => [
    for (final (index, group) in GlassBarButton.groups(buttons).indexed) ...[
      if (index > 0) const SizedBox(width: GlassBarButton.groupGap),
      _Capsule(group),
    ],
  ];
}

/// One piece of glass with the buttons that share it.
class _Capsule extends StatefulWidget {
  const _Capsule(this.buttons);

  final List<GlassBarButton> buttons;

  @override
  State<_Capsule> createState() => _CapsuleState();
}

class _CapsuleState extends State<_Capsule> {
  /// How much longer the glass gets under a finger. On iOS 26 a button
  /// swells by about as much whatever its size.
  static const double _growth = 14;

  bool _down = false;

  /// What iOS 26 draws a symbol with on glass filled with [accent]: the fill
  /// itself, far lighter where it is dark and far darker where it is light.
  static Color _onAccent(Color accent) {
    final shift = accent.computeLuminance() > 0.4 ? -175 / 255 : 158 / 255;
    return Color.from(
      alpha: 1,
      red: (accent.r + shift).clamp(0.0, 1.0),
      green: (accent.g + shift).clamp(0.0, 1.0),
      blue: (accent.b + shift).clamp(0.0, 1.0),
    );
  }

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final buttons = widget.buttons;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    // Only a button with a capsule of its own can be filled.
    final prominent = buttons.length == 1 && buttons.single.prominent;
    final color = prominent
        ? _onAccent(accent)
        : GlassMaterial.label(theme.brightness);
    final width = GlassBarButton.groupWidth(buttons.length);
    final last = buttons.length - 1;
    return Listener(
      // Every button answers its own taps. The glass only shows the touch:
      // it swells and lights up under the finger as one piece.
      onPointerDown: (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: GlassSpring(
        target: _down ? 1 : 0,
        spring: GlassSprings.press,
        builder: (context, press, _, child) => Transform.scale(
          scale: 1 + _growth * press / width,
          child: SizedBox(
            width: width,
            height: GlassBarButton.size,
            child: GlassPlate(
              look: prominent
                  ? GlassMaterial.prominent(theme.brightness, accent)
                  : GlassMaterial.button(theme.brightness),
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
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (index, button) in buttons.indexed)
              _Slot(
                button,
                color: color,
                // In a shared capsule the buttons sit 12 apart and 2 from
                // its ends. Each one also answers taps in its half of the
                // gap.
                padding: buttons.length == 1
                    ? EdgeInsets.zero
                    : EdgeInsetsDirectional.only(
                        start: index == 0 ? 2 : 6,
                        end: index == last ? 2 : 6,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One button's symbol and the area that answers its taps.
class _Slot extends StatelessWidget {
  const _Slot(this.button, {required this.color, required this.padding});

  final GlassBarButton button;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final enabled = button.onPressed != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: button.label,
      child: GestureDetector(
        key: ValueKey('glass-bar-button-${button.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: button.onPressed,
        child: Padding(
          padding: padding,
          child: SizedBox.square(
            dimension: GlassBarButton.size,
            child: Center(
              child: button.loading
                  ? CupertinoActivityIndicator(color: color)
                  : button.avatar != null
                  ? Opacity(
                      opacity: enabled ? 1 : 0.3,
                      // A round sign is 32 high; signs side by side may
                      // take the button's width.
                      child: SizedBox(
                        width: GlassBarButton.size,
                        height: 32,
                        child: FittedBox(child: button.avatar),
                      ),
                    )
                  : Icon(
                      button.symbol.icon,
                      size: 26,
                      color: enabled ? color : color.withValues(alpha: 0.3),
                      shadows: enabled ? GlassSymbol.heavier(color) : null,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
