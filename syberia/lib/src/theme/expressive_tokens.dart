import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// The values of Material 3 Expressive, as Google's own Compose library
/// keeps them (androidx compose/material3 tokens). Every screen of the
/// Expressive design takes its sizes from here rather than inventing them.

/// The corner sizes of the shape scale (ShapeTokens). [full] rounds a side
/// completely: use [StadiumBorder] or [BorderRadius.circular] with it.
abstract final class Corners {
  static const none = 0.0;
  static const extraSmall = 4.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const largeIncreased = 20.0;
  static const extraLarge = 28.0;
  static const extraLargeIncreased = 32.0;
  static const extraExtraLarge = 48.0;
  static const full = 999.0;
}

/// Spacing on Material's 4 dp grid.
abstract final class Space {
  /// Between the buttons of a connected group, and of a split button.
  static const connected = 2.0;
  static const extraSmall = 4.0;
  static const small = 8.0;
  static const medium = 12.0;

  /// The side margin of a phone screen, and the inside of cards.
  static const large = 16.0;
  static const extraLarge = 24.0;
  static const extraExtraLarge = 32.0;
}

/// The opacity of the colour laid over a component in each state
/// (StateTokens), and of disabled ones.
abstract final class StateLayer {
  static const hovered = 0.08;
  static const focused = 0.10;
  static const pressed = 0.10;
  static const dragged = 0.16;

  /// Disabled content: text and icons.
  static const disabledContent = 0.38;

  /// The container of a disabled button.
  static const disabledContainer = 0.10;
}

/// The springs of the Expressive motion scheme (ExpressiveMotionTokens).
/// Spatial ones move, scale and reshape things and may overshoot a little;
/// effects ones change colour and opacity and never overshoot.
abstract final class Springs {
  static final fastSpatial = _spring(0.6, 800);
  static final defaultSpatial = _spring(0.8, 380);
  static final slowSpatial = _spring(0.8, 200);
  static final fastEffects = _spring(1.0, 3800);
  static final defaultEffects = _spring(1.0, 1600);
  static final slowEffects = _spring(1.0, 800);

  static SpringDescription _spring(double damping, double stiffness) =>
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: stiffness,
        ratio: damping,
      );
}

/// A spring from 0 to 1 as a [Curve], for the implicit animations that take
/// a curve and a duration. [duration] is how long the spring takes to come to
/// rest, so the pair moves exactly as the spring does.
///
/// Material 3 Expressive moves with springs (see `Springs`); a spatial spring
/// overshoots its target a little, and so does this curve.
class SpringCurve extends Curve {
  SpringCurve(this.spring)
    : _simulation = SpringSimulation(spring, 0, 1, 0),
      duration = _settleTime(spring);

  final SpringDescription spring;

  /// How long the spring takes to settle within a thousandth of its target.
  final Duration duration;

  final SpringSimulation _simulation;

  double get _seconds =>
      duration.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  double transformInternal(double t) => _simulation.x(t * _seconds);

  /// The last moment the spring is still a thousandth or more away from its
  /// target, scanned back from two seconds.
  static Duration _settleTime(SpringDescription spring) {
    final simulation = SpringSimulation(spring, 0, 1, 0);
    const step = 0.001;
    for (var t = 2.0; t > 0; t -= step) {
      if ((simulation.x(t) - 1).abs() >= 0.001) {
        return Duration(microseconds: ((t + step) * 1e6).round());
      }
    }
    return Duration.zero;
  }
}

/// The type scale of Material 3 with its Emphasized variants
/// (TypeScaleTokens), in sizes, line heights, weights and tracking.
///
/// The baseline styles become the theme's [TextTheme]; the Emphasized ones,
/// for what should stand out, are under [ExpressiveType.of].
abstract final class TypeScale {
  /// The Expressive design's typeface. It has no Cyrillic, so in Russian
  /// and Ukrainian the system's own font draws the same scale.
  static const fontFamily = 'Google Sans Flex';

  static const _regular = FontWeight.w400;
  static const _medium = FontWeight.w500;
  static const _bold = FontWeight.w700;

  /// The baseline scale in [family], or the platform's font when null.
  static TextTheme baseline({String? family}) => TextTheme(
    displayLarge: _style(family, 57, 64, _regular, -0.2),
    displayMedium: _style(family, 45, 52, _regular, 0),
    displaySmall: _style(family, 36, 44, _regular, 0),
    headlineLarge: _style(family, 32, 40, _regular, 0),
    headlineMedium: _style(family, 28, 36, _regular, 0),
    headlineSmall: _style(family, 24, 32, _regular, 0),
    titleLarge: _style(family, 22, 28, _regular, 0),
    titleMedium: _style(family, 16, 24, _medium, 0.2),
    titleSmall: _style(family, 14, 20, _medium, 0.1),
    bodyLarge: _style(family, 16, 24, _regular, 0.5),
    bodyMedium: _style(family, 14, 20, _regular, 0.2),
    bodySmall: _style(family, 12, 16, _regular, 0.4),
    labelLarge: _style(family, 14, 20, _medium, 0.1),
    labelMedium: _style(family, 12, 16, _medium, 0.5),
    labelSmall: _style(family, 11, 16, _medium, 0.5),
  );

  /// The Emphasized scale: heavier, and display sizes fully rounded.
  static TextTheme emphasized({String? family}) => TextTheme(
    displayLarge: _style(family, 57, 64, _medium, 0, round: true),
    displayMedium: _style(family, 45, 52, _medium, 0, round: true),
    displaySmall: _style(family, 36, 44, _medium, 0, round: true),
    headlineLarge: _style(family, 32, 40, _medium, 0),
    headlineMedium: _style(family, 28, 36, _medium, 0),
    headlineSmall: _style(family, 24, 32, _medium, 0),
    titleLarge: _style(family, 22, 28, _medium, 0),
    titleMedium: _style(family, 16, 24, _bold, 0.15),
    titleSmall: _style(family, 14, 20, _bold, 0.1),
    bodyLarge: _style(family, 16, 24, _medium, 0.15),
    bodyMedium: _style(family, 14, 20, _medium, 0.25),
    bodySmall: _style(family, 12, 16, _medium, 0.4),
    labelLarge: _style(family, 14, 20, _bold, 0.1),
    labelMedium: _style(family, 12, 16, _bold, 0.5),
    labelSmall: _style(family, 11, 16, _bold, 0.5),
  );

  /// Google Sans Flex draws each size with its own optical size, as the web
  /// does on its own, and rounds the letters of display text with its
  /// roundness axis. Fonts without those axes ignore them.
  static TextStyle _style(
    String? family,
    double size,
    double lineHeight,
    FontWeight weight,
    double tracking, {
    bool round = false,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: tracking,
    leadingDistribution: TextLeadingDistribution.even,
    fontVariations: [
      FontVariation.opticalSize(size),
      if (round) const FontVariation('ROND', 100),
    ],
  );
}

/// The Emphasized type scale of the Expressive theme.
@immutable
class ExpressiveType extends ThemeExtension<ExpressiveType> {
  const ExpressiveType({required this.emphasized});

  /// In the same roles as the theme's [TextTheme].
  final TextTheme emphasized;

  /// The Emphasized styles, or the theme's own ones outside the Expressive
  /// design, so a widget can use them in any design.
  static TextTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ExpressiveType>()?.emphasized ?? theme.textTheme;
  }

  @override
  ExpressiveType copyWith({TextTheme? emphasized}) =>
      ExpressiveType(emphasized: emphasized ?? this.emphasized);

  @override
  ExpressiveType lerp(ExpressiveType? other, double t) => other == null
      ? this
      : ExpressiveType(
          emphasized: TextTheme.lerp(emphasized, other.emphasized, t),
        );
}
