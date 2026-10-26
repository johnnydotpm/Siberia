import 'brand_events.dart';

/// The timing of an event's logo animation, as fractions of its [cycle].
class LogoMotion {
  const LogoMotion({
    required this.cycle,
    required this.wholeStart,
    required this.wholeEnd,
    required this.iconStart,
    required this.iconEnd,
    required this.rest,
  });

  final Duration cycle;

  /// From here to [wholeEnd] the whole logo rests on screen, the details by
  /// the name included.
  final double wholeStart;
  final double wholeEnd;

  /// From here to [iconEnd] the mark is fully there, at its size.
  final double iconStart;
  final double iconEnd;

  /// The moment a logo that does not move shows.
  final double rest;

  static LogoMotion of(BrandEvent event) => switch (event) {
    // The supplied five-second animation, unchanged.
    BrandEvent.ordinary => const LogoMotion(
      cycle: Duration(seconds: 5),
      wholeStart: 0.38,
      wholeEnd: 0.80,
      iconStart: 0.13,
      iconEnd: 0.88,
      rest: 0.5,
    ),
    BrandEvent.schoolStart => const LogoMotion(
      cycle: _six,
      wholeStart: 0.68,
      wholeEnd: 0.76,
      iconStart: 0.40,
      iconEnd: 0.84,
      rest: 0.72,
    ),
    BrandEvent.plFlag => const LogoMotion(
      cycle: _six,
      wholeStart: 0.50,
      wholeEnd: 0.82,
      iconStart: 0.13,
      iconEnd: 0.88,
      rest: 0.66,
    ),
    BrandEvent.plConstitution => const LogoMotion(
      cycle: _six,
      wholeStart: 0.59,
      wholeEnd: 0.86,
      iconStart: 0.59,
      iconEnd: 0.86,
      rest: 0.72,
    ),
    BrandEvent.plIndependence => const LogoMotion(
      cycle: _six,
      wholeStart: 0.57,
      wholeEnd: 0.78,
      iconStart: 0.54,
      iconEnd: 0.84,
      rest: 0.68,
    ),
    BrandEvent.uaFlag => const LogoMotion(
      cycle: _six,
      wholeStart: 0.54,
      wholeEnd: 0.84,
      iconStart: 0.45,
      iconEnd: 0.86,
      rest: 0.70,
    ),
    BrandEvent.uaIndependence => const LogoMotion(
      cycle: _six,
      wholeStart: 0.68,
      wholeEnd: 0.82,
      iconStart: 0.36,
      iconEnd: 0.86,
      rest: 0.76,
    ),
    BrandEvent.christmas => const LogoMotion(
      cycle: _six,
      wholeStart: 0.60,
      wholeEnd: 0.72,
      iconStart: 0.30,
      iconEnd: 0.86,
      rest: 0.66,
    ),
    BrandEvent.newYear => const LogoMotion(
      cycle: _six,
      wholeStart: 0.58,
      wholeEnd: 0.84,
      iconStart: 0.58,
      iconEnd: 0.86,
      // The confetti still above the name, as on the approved still; later
      // they would stay frozen across the letters.
      rest: 0.50,
    ),
  };

  static const _six = Duration(seconds: 6);
}
