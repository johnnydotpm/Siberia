import 'package:flutter/widgets.dart';

/// The days the logo dresses up for; every other day it is [ordinary].
enum BrandEvent {
  ordinary,

  /// 2 May, the Polish Flag Day.
  plFlag,

  /// 3 May, the Constitution of 3 May.
  plConstitution,

  /// 23 August, the Day of the National Flag of Ukraine.
  uaFlag,

  /// 24 August, the Independence Day of Ukraine.
  uaIndependence,

  /// 1 September, the start of the school year.
  schoolStart,

  /// 11 November, the Polish National Independence Day.
  plIndependence,

  /// 24 to 26 December.
  christmas,

  /// 31 December and 1 January.
  newYear;

  /// The event of the calendar day [day] is in, as the phone counts days.
  static BrandEvent on(DateTime day) => switch ((day.month, day.day)) {
    (5, 2) => plFlag,
    (5, 3) => plConstitution,
    (8, 23) => uaFlag,
    (8, 24) => uaIndependence,
    (9, 1) => schoolStart,
    (11, 11) => plIndependence,
    (12, 24 || 25 || 26) => christmas,
    (12, 31) || (1, 1) => newYear,
    _ => ordinary,
  };
}

/// Which event the logo shows now.
abstract final class BrandEvents {
  /// The phone's clock; tests set a fixed day.
  static DateTime Function() clock = DateTime.now;

  /// The event chosen in the debug menu for every launch, if any.
  static BrandEvent? override;

  static BrandEvent today() => override ?? BrandEvent.on(clock());
}

/// The event the logos below show.
class BrandEventScope extends InheritedWidget {
  const BrandEventScope({required this.event, required super.child, super.key});

  final BrandEvent event;

  /// The nearest scope's event, or the ordinary logo without one.
  static BrandEvent of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrandEventScope>()?.event ??
      BrandEvent.ordinary;

  @override
  bool updateShouldNotify(BrandEventScope oldWidget) =>
      event != oldWidget.event;
}
