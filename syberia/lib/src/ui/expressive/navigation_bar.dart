import 'package:flutter/material.dart';

import '../../theme/app_symbols.dart';
import '../../theme/expressive_tokens.dart';
import 'motion.dart';

/// One page of an [ExpressiveNavigationBar].
typedef ExpressiveDestination = ({
  IconData icon,
  String label,
  int badge,
  String badgeText,
});

final _indicatorSpring = SpringCurve(Springs.defaultSpatial);

/// Material 3 Expressive's short navigation bar (NavigationBarTokens,
/// NavigationBarVerticalItemTokens).
///
/// 64 points tall on the surface container. Each item has its icon in a
/// 56 by 32 pill, 6 from the top, and its label 4 below. The chosen item's
/// pill grows from its middle on the default spatial spring, its icon fills
/// and its label takes the secondary colour. Icons are Material Symbols:
/// pass the Material icon and its symbol is drawn.
class ExpressiveNavigationBar extends StatelessWidget {
  const ExpressiveNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<ExpressiveDestination> destinations;

  /// Negative when the page on screen is none of these.
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final (index, destination) in destinations.indexed)
                Expanded(
                  child: _NavigationItem(
                    destination: destination,
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ExpressiveDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _indicator = Size(56, 32);
  static const _top = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final symbol = AppSymbols.of(destination.icon) ?? destination.icon;
    final iconColor = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    Widget icon = Icon(
      symbol,
      size: 24,
      color: iconColor,
      fill: selected ? 1 : 0,
    );
    if (destination.badge > 0) {
      icon = Badge(label: Text(destination.badgeText), child: icon);
    }
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: _IndicatorInkWell(
        onTap: onTap,
        child: Column(
          children: [
            const SizedBox(height: _top),
            SizedBox.fromSize(
              size: _indicator,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: selected ? 1 : 0),
                    duration: _indicatorSpring.duration,
                    curve: _indicatorSpring,
                    builder: (context, progress, _) => Container(
                      width: _indicator.width * progress.clamp(0, 2),
                      height: _indicator.height,
                      decoration: ShapeDecoration(
                        color: colors.secondaryContainer,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  icon,
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium!.copyWith(
                color: selected ? colors.secondary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The whole item takes the tap, but its ripple stays in the pill.
class _IndicatorInkWell extends InkResponse {
  const _IndicatorInkWell({super.child, super.onTap})
    : super(
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        customBorder: const StadiumBorder(),
      );

  @override
  RectCallback getRectCallback(RenderBox referenceBox) =>
      () => Rect.fromCenter(
        center: Offset(
          referenceBox.size.width / 2,
          _NavigationItem._top + _NavigationItem._indicator.height / 2,
        ),
        width: _NavigationItem._indicator.width,
        height: _NavigationItem._indicator.height,
      );
}
