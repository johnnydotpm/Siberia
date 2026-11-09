import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syberia/src/theme/app_theme.dart';
import 'package:syberia/src/theme/wallpaper_colors.dart';
import 'package:syberia/src/ui/subject_colors.dart';

/// The text of the Expressive design against what it stands on, by WCAG's
/// contrast ratio: 4.5:1 for normal text, 3:1 for large text (24 points, or
/// 18.7 bold), in the brand colours and the colours of several wallpapers,
/// light, dark and black.
void main() {
  /// WCAG 2.x relative luminance contrast.
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final (hi, lo) = la > lb ? (la, lb) : (lb, la);
    return (hi + 0.05) / (lo + 0.05);
  }

  final wallpapers = {
    'brand': null,
    'green': const Color(0xFF4A7C45),
    'red': const Color(0xFFB3261E),
    'yellow': const Color(0xFFE6C229),
    'purple': const Color(0xFF6750A4),
    'grey': const Color(0xFF8A8A8A),
  };

  for (final MapEntry(key: name, value: seed) in wallpapers.entries) {
    for (final (mode, brightness, amoled) in const [
      ('light', Brightness.light, false),
      ('dark', Brightness.dark, false),
      ('black', Brightness.dark, true),
    ]) {
      test('$name wallpaper, $mode', () {
        final colors = AppTheme.expressive(
          brightness,
          amoled: amoled,
          wallpaper: seed == null ? null : WallpaperColors(seed: seed),
        ).colorScheme;
        final failures = <String>[];
        void check(String what, Color text, Color on, {bool large = false}) {
          final ratio = contrast(text, on);
          if (ratio < (large ? 3 : 4.5)) {
            failures.add('$what: ${ratio.toStringAsFixed(2)}');
          }
        }

        // Pages, cards and bars.
        check('text on page', colors.onSurface, colors.surface);
        check('muted text on page', colors.onSurfaceVariant, colors.surface);
        check('text on card', colors.onSurface, colors.surfaceContainerLow);
        check(
          'muted text on card',
          colors.onSurfaceVariant,
          colors.surfaceContainerLow,
        );
        check('section label', colors.primary, colors.surface);
        check('chosen tab label', colors.secondary, colors.surfaceContainer);
        check(
          'tab label, group button',
          colors.onSurfaceVariant,
          colors.surfaceContainer,
        );
        // The lesson on now, the tiles and the average.
        check(
          'lesson card',
          colors.onPrimaryContainer,
          colors.primaryContainer,
        );
        check('chosen button', colors.onPrimary, colors.primary);
        check(
          'lesson number on its shape',
          colors.onPrimary,
          colors.primary,
          large: true,
        );
        check(
          'average tile',
          colors.onTertiaryContainer,
          colors.tertiaryContainer,
        );
        check(
          'average on its burst',
          colors.onTertiary,
          colors.tertiary,
          large: true,
        );
        check(
          'attendance tile',
          colors.onSecondaryContainer,
          colors.secondaryContainer,
        );
        check(
          'chosen tab icon',
          colors.onSecondaryContainer,
          colors.secondaryContainer,
          large: true,
        );
        check('error', colors.onErrorContainer, colors.errorContainer);
        expect(failures, isEmpty);
      });
    }
  }

  for (final brightness in Brightness.values) {
    test('subject colours, ${brightness.name}', () {
      final failures = <String>[];
      for (var hue = 0; hue < SubjectColors.hueCount; hue++) {
        final palette = SubjectColors.colors(hue, brightness);
        final ratio = contrast(palette.foreground, palette.background);
        if (ratio < 4.5) failures.add('hue $hue: ${ratio.toStringAsFixed(2)}');
        // The "Now" badge: the card's colour on its accent.
        final badge = contrast(palette.background, palette.accent);
        if (badge < 3) failures.add('badge $hue: ${badge.toStringAsFixed(2)}');
      }
      expect(failures, isEmpty);
    });

    test('grade colours, ${brightness.name}', () {
      final failures = <String>[];
      for (final value in [null, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]) {
        final palette = SubjectColors.grade(value, brightness);
        final ratio = contrast(palette.foreground, palette.background);
        if (ratio < 4.5) {
          failures.add('grade $value: ${ratio.toStringAsFixed(2)}');
        }
      }
      expect(failures, isEmpty);
    });
  }
}
