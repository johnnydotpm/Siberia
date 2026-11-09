import 'package:flutter/material.dart';

import '../../theme/app_symbols.dart';
import '../../theme/expressive_tokens.dart';

/// Tells the widgets below whether the app is drawn in its Expressive design.
///
/// Screens keep their logic in every design and only change how they look
/// where this is on. Without this widget above them, widgets draw the other
/// designs.
class ExpressiveStyle extends InheritedWidget {
  const ExpressiveStyle({
    required this.enabled,
    required super.child,
    super.key,
  });

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ExpressiveStyle>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(ExpressiveStyle oldWidget) =>
      oldWidget.enabled != enabled;
}

/// An icon that is drawn from Material Symbols Rounded in the Expressive
/// design and as the given Material icon everywhere else. Screens use it in
/// place of [Icon], with the same arguments.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    this.size,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.color,
    this.shadows,
    this.semanticLabel,
    this.textDirection,
    this.applyTextScaling,
    this.blendMode,
    super.key,
  });

  final IconData? icon;
  final double? size;
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;
  final Color? color;
  final List<Shadow>? shadows;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final bool? applyTextScaling;
  final BlendMode? blendMode;

  @override
  Widget build(BuildContext context) {
    final material = icon;
    final symbol = material != null && ExpressiveStyle.of(context)
        ? AppSymbols.of(material)
        : null;
    return Icon(
      symbol ?? material,
      size: size,
      fill: fill,
      weight: weight,
      grade: grade,
      opticalSize: opticalSize,
      color: color,
      shadows: shadows,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
      applyTextScaling: applyTextScaling,
      blendMode: blendMode,
    );
  }
}

/// Marks a page of the Expressive design that opens with [largeTitle]: the
/// page shows the title itself and lets it scroll away, and the top bar then
/// takes it.
class ExpressivePageScope extends InheritedWidget {
  const ExpressivePageScope({
    required this.largeTitle,
    required super.child,
    super.key,
  });

  final String? largeTitle;

  static ExpressivePageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ExpressivePageScope>();

  @override
  bool updateShouldNotify(ExpressivePageScope oldWidget) =>
      oldWidget.largeTitle != largeTitle;
}

/// The title that opens a page of the Expressive design: Display Small,
/// Emphasized, its letters rounded.
class ExpressiveLargeTitle extends StatelessWidget {
  const ExpressiveLargeTitle(this.text, {super.key});

  final String text;

  /// How far a page scrolls before the title is gone and the bar shows it.
  static const double extent = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emphasized =
        theme.extension<ExpressiveType>()?.emphasized ?? theme.textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: emphasized.displaySmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
