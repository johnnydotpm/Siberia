import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF176B8F);

  /// The typeface closest to Apple's system font that may be shipped.
  static const _appleLikeFont = 'Inter';

  /// With [likeIos] the app looks and moves on any platform the way it does
  /// on an iPhone. The glass design that Flutter draws itself is a copy of
  /// the iPhone's, so it comes with the same conventions.
  static ThemeData light({bool likeIos = false}) =>
      _theme(Brightness.light, likeIos);
  static ThemeData dark({bool likeIos = false}) =>
      _theme(Brightness.dark, likeIos);
  static ThemeData amoled({bool likeIos = false}) =>
      _theme(Brightness.dark, likeIos, amoled: true);

  /// Loads the typeface of the iPhone-like theme. It is not declared as one
  /// of the app's fonts, so that only the devices that show it load it.
  static Future<void> loadAppleLikeFont() {
    final font = FontLoader(_appleLikeFont)
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    return font.load();
  }

  static ThemeData _theme(
    Brightness brightness,
    bool likeIos, {
    bool amoled = false,
  }) {
    var colors = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    if (amoled) {
      colors = colors.copyWith(
        surface: Colors.black,
        surfaceDim: Colors.black,
        surfaceBright: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: Colors.black,
        surfaceContainer: Colors.black,
        surfaceContainerHigh: Colors.black,
        surfaceContainerHighest: Colors.black,
        surfaceTint: Colors.transparent,
      );
    }
    final background = amoled
        ? Colors.black
        : brightness == Brightness.light
        ? const Color(0xFFF3F6F7)
        : const Color(0xFF101416);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      // Scrolling that bounces, pages that slide in from the side, iOS's
      // switches and progress rings, and no ink sparkle under the finger.
      platform: likeIos ? TargetPlatform.iOS : null,
      fontFamily: likeIos ? _appleLikeFont : null,
      splashFactory: likeIos ? InkRipple.splashFactory : null,
      scaffoldBackgroundColor: background,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.primary,
        scaffoldBackgroundColor: background,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // Flutter picks the status bar icons from the bar's colour. A
        // transparent bar reads as dark, which left white icons on the light
        // page, so the theme's brightness decides instead.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: brightness,
          statusBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: amoled
            ? Colors.black
            : brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1B2226),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      // Fields round their corners like the rest of the app. Search fields
      // set their own filled look.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: amoled
            ? Colors.black
            : brightness == Brightness.light
            ? const Color(0xFFF9FBFB)
            : const Color(0xFF172024),
        indicatorColor: colors.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
