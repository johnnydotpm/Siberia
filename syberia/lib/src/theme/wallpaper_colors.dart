import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Material You: the colours Android picked from the wallpaper, for the
/// Expressive design.
///
/// Android 14 and newer give the colour of every role, the very ones the
/// system's own screens use. Android 12 and 13 only give tonal palettes, so
/// there the scheme is built from their key colour the way Material builds
/// every scheme. Older systems, and other platforms, have none.
@immutable
class WallpaperColors {
  const WallpaperColors({required this.seed, this.light, this.dark});

  /// The colour the system's palettes grew from.
  final Color seed;

  /// The system's colour of each role, by the name of the [ColorScheme]
  /// field, where the system names them.
  final Map<String, Color>? light;
  final Map<String, Color>? dark;

  static const _channel = MethodChannel('app.syberia.client/wallpaper_colors');

  /// What the phone says; tests answer for it.
  @visibleForTesting
  static Future<Object?> Function() ask = () =>
      _channel.invokeMethod<Object?>('colors');

  /// The wallpaper's colours, or null where the phone has none.
  static Future<WallpaperColors?> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      return fromPlatform(await ask());
    } on Object {
      // No channel in this engine (a widget's or the background's), or a
      // phone that cannot answer.
      return null;
    }
  }

  /// Reads the channel's answer: `seed` and, on Android 14 and newer, the
  /// `light` and `dark` roles, each colour as a 32-bit ARGB number.
  @visibleForTesting
  static WallpaperColors? fromPlatform(Object? data) {
    if (data is! Map) return null;
    final seed = data['seed'];
    if (seed is! int) return null;
    Map<String, Color>? roles(Object? value) {
      if (value is! Map) return null;
      final roles = {
        for (final MapEntry(:key, :value) in value.entries)
          if (key is String && value is int && _roles.contains(key))
            key: Color(value),
      };
      return roles.isEmpty ? null : roles;
    }

    return WallpaperColors(
      seed: Color(seed),
      light: roles(data['light']),
      dark: roles(data['dark']),
    );
  }

  /// The scheme for [brightness]: Material's tonal spot scheme from [seed],
  /// with the system's own colour in each role it names.
  ColorScheme scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final named = brightness == Brightness.light ? light : dark;
    if (named == null) return base;
    Color role(String name, Color fallback) => named[name] ?? fallback;
    return base.copyWith(
      primary: role('primary', base.primary),
      onPrimary: role('onPrimary', base.onPrimary),
      primaryContainer: role('primaryContainer', base.primaryContainer),
      onPrimaryContainer: role('onPrimaryContainer', base.onPrimaryContainer),
      secondary: role('secondary', base.secondary),
      onSecondary: role('onSecondary', base.onSecondary),
      secondaryContainer: role('secondaryContainer', base.secondaryContainer),
      onSecondaryContainer: role(
        'onSecondaryContainer',
        base.onSecondaryContainer,
      ),
      tertiary: role('tertiary', base.tertiary),
      onTertiary: role('onTertiary', base.onTertiary),
      tertiaryContainer: role('tertiaryContainer', base.tertiaryContainer),
      onTertiaryContainer: role(
        'onTertiaryContainer',
        base.onTertiaryContainer,
      ),
      error: role('error', base.error),
      onError: role('onError', base.onError),
      errorContainer: role('errorContainer', base.errorContainer),
      onErrorContainer: role('onErrorContainer', base.onErrorContainer),
      surface: role('surface', base.surface),
      onSurface: role('onSurface', base.onSurface),
      onSurfaceVariant: role('onSurfaceVariant', base.onSurfaceVariant),
      surfaceDim: role('surfaceDim', base.surfaceDim),
      surfaceBright: role('surfaceBright', base.surfaceBright),
      surfaceContainerLowest: role(
        'surfaceContainerLowest',
        base.surfaceContainerLowest,
      ),
      surfaceContainerLow: role(
        'surfaceContainerLow',
        base.surfaceContainerLow,
      ),
      surfaceContainer: role('surfaceContainer', base.surfaceContainer),
      surfaceContainerHigh: role(
        'surfaceContainerHigh',
        base.surfaceContainerHigh,
      ),
      surfaceContainerHighest: role(
        'surfaceContainerHighest',
        base.surfaceContainerHighest,
      ),
      outline: role('outline', base.outline),
      outlineVariant: role('outlineVariant', base.outlineVariant),
    );
  }

  /// The roles Android 14 names, as the [ColorScheme] fields are called.
  static const _roles = {
    'primary',
    'onPrimary',
    'primaryContainer',
    'onPrimaryContainer',
    'secondary',
    'onSecondary',
    'secondaryContainer',
    'onSecondaryContainer',
    'tertiary',
    'onTertiary',
    'tertiaryContainer',
    'onTertiaryContainer',
    'error',
    'onError',
    'errorContainer',
    'onErrorContainer',
    'surface',
    'onSurface',
    'onSurfaceVariant',
    'surfaceDim',
    'surfaceBright',
    'surfaceContainerLowest',
    'surfaceContainerLow',
    'surfaceContainer',
    'surfaceContainerHigh',
    'surfaceContainerHighest',
    'outline',
    'outlineVariant',
  };

  @override
  bool operator ==(Object other) =>
      other is WallpaperColors &&
      other.seed == seed &&
      mapEquals(other.light, light) &&
      mapEquals(other.dark, dark);

  @override
  int get hashCode => Object.hash(
    seed,
    Object.hashAllUnordered(light?.entries.map((e) => (e.key, e.value)) ?? []),
    Object.hashAllUnordered(dark?.entries.map((e) => (e.key, e.value)) ?? []),
  );
}
