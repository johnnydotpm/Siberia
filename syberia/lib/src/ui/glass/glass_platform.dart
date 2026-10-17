import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import 'glass_lens.dart';

/// Sizes of the system bars, as UIKit reports them.
@immutable
class GlassMetrics {
  const GlassMetrics({
    this.tabBarHeight = 49,
    this.tabBarHeadroom = 16,
    this.navigationBarHeight = 44,
    this.navigationBarRoom = 36,
    this._navigationBarCenter,
  });

  /// What UIKit reports on iOS 26. Where Flutter draws the glass itself, it
  /// lays the bars out to these sizes.
  static const ios26 = GlassMetrics(navigationBarHeight: 54);

  /// The height of a glass bar button. A taller bar keeps its buttons at its
  /// top edge and leaves the rest as spacing below them.
  static const double _buttonHeight = 44;

  /// Height of the tab bar's content, without the bottom safe area.
  final double tabBarHeight;

  /// Room the tab bar's view keeps above the bar for the selection lens.
  final double tabBarHeadroom;

  /// Height of the navigation bar: its buttons and the spacing UIKit keeps
  /// below them.
  final double navigationBarHeight;

  /// Room the buttons' view keeps above and below the bar for their shadows.
  final double navigationBarRoom;

  final double? _navigationBarCenter;

  /// The middle of the buttons, measured from the top of the bar. Until
  /// UIKit reports it, the buttons are taken to sit at the bar's top edge.
  double get navigationBarCenter =>
      _navigationBarCenter ??
      (navigationBarHeight < _buttonHeight
              ? navigationBarHeight
              : _buttonHeight) /
          2;

  GlassMetrics copyWith({
    double? tabBarHeight,
    double? tabBarHeadroom,
    double? navigationBarHeight,
    double? navigationBarRoom,
    double? navigationBarCenter,
  }) => GlassMetrics(
    tabBarHeight: tabBarHeight ?? this.tabBarHeight,
    tabBarHeadroom: tabBarHeadroom ?? this.tabBarHeadroom,
    navigationBarHeight: navigationBarHeight ?? this.navigationBarHeight,
    navigationBarRoom: navigationBarRoom ?? this.navigationBarRoom,
    navigationBarCenter: navigationBarCenter ?? _navigationBarCenter,
  );

  @override
  bool operator ==(Object other) =>
      other is GlassMetrics &&
      other.tabBarHeight == tabBarHeight &&
      other.tabBarHeadroom == tabBarHeadroom &&
      other.navigationBarHeight == navigationBarHeight &&
      other.navigationBarRoom == navigationBarRoom &&
      other._navigationBarCenter == _navigationBarCenter;

  @override
  int get hashCode => Object.hash(
    tabBarHeight,
    tabBarHeadroom,
    navigationBarHeight,
    navigationBarRoom,
    _navigationBarCenter,
  );
}

/// Who draws the glass design on this device.
enum GlassBackend {
  /// Nobody: the classic Material chrome is the only design.
  none,

  /// UIKit, with Apple's own Liquid Glass views. iOS 26 and newer.
  uikit,

  /// Flutter, which blurs and tints the page behind the glass the way
  /// Apple's material does. Android, wherever the Impeller renderer runs.
  rendered,
}

/// What the platform can do for the glass design.
///
/// Only iOS 26 and newer has Apple's Liquid Glass, which the app shows with
/// real UIKit views. Android has no such material, so there Flutter draws a
/// copy of it. Everywhere else the classic Material chrome is the only design.
abstract final class GlassPlatform {
  static const _channel = MethodChannel('siberia/glass');

  static GlassBackend _backend = GlassBackend.none;

  static GlassBackend get backend => _backend;

  /// True when the bars, compact sheets and menus can be shown as glass.
  static bool get supported => _backend != GlassBackend.none;

  /// Starts from UIKit's own defaults and is corrected by each bar once it is
  /// on screen.
  static final ValueNotifier<GlassMetrics> metrics = ValueNotifier(
    const GlassMetrics(),
  );

  /// Asks the platform once, before the first frame, so the right chrome is
  /// built from the start.
  static Future<void> ensureInitialized() async {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        await _askUIKit();
      case TargetPlatform.android:
        // Flutter draws with Impeller on Android 10 and newer, and that is
        // where the drawn glass has been checked. Older systems fall back
        // to Skia, on phones for which a screen of backdrop blurs is a lot,
        // and keep the classic design.
        if (ImageFilter.isShaderFilterSupported) {
          _backend = GlassBackend.rendered;
          metrics.value = GlassMetrics.ios26;
          await Future.wait([AppTheme.loadAppleLikeFont(), GlassLens.load()]);
        }
      default:
    }
  }

  static Future<void> _askUIKit() async {
    try {
      final info = await _channel.invokeMapMethod<String, Object?>(
        'capabilities',
      );
      if (info == null) return;
      if (info['liquidGlass'] == true) _backend = GlassBackend.uikit;
      final current = metrics.value;
      metrics.value = GlassMetrics(
        tabBarHeight: _positive(info['tabBarHeight'], current.tabBarHeight),
        tabBarHeadroom: _positive(
          info['tabBarHeadroom'],
          current.tabBarHeadroom,
        ),
        navigationBarHeight: _positive(
          info['navigationBarHeight'],
          current.navigationBarHeight,
        ),
        navigationBarRoom: _positive(
          info['navigationBarRoom'],
          current.navigationBarRoom,
        ),
      );
    } on PlatformException {
      // The runner has no glass channel: the classic design is all there is.
    } on MissingPluginException {
      // Same as above.
    }
  }

  static double _positive(Object? value, double fallback) =>
      value is num && value > 0 ? value.toDouble() : fallback;

  @visibleForTesting
  static void debugSetBackend(GlassBackend value) {
    _backend = value;
    metrics.value = value == GlassBackend.rendered
        ? GlassMetrics.ios26
        : const GlassMetrics();
  }
}

/// Tells the widgets below whether the app is drawn in its glass design.
///
/// It is on when the user chose that design and the platform supports it.
/// Without this widget above them, widgets draw the classic design.
class GlassStyle extends InheritedWidget {
  const GlassStyle({required this.enabled, required super.child, super.key});

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassStyle>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(GlassStyle oldWidget) => oldWidget.enabled != enabled;
}
