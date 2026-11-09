import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_symbols.dart';
import 'expressive_tokens.dart';
import 'wallpaper_colors.dart';

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

  static Future<void>? _expressiveFont;

  /// Loads Google Sans Flex, the Expressive design's typeface, once. Like
  /// Inter it is not declared as one of the app's fonts, so only the devices
  /// that show the design load it.
  static Future<void> loadExpressiveFont() => _expressiveFont ??= (FontLoader(
    TypeScale.fontFamily,
  )..addFont(rootBundle.load('assets/fonts/GoogleSansFlex.ttf'))).load();

  /// The Expressive scheme from the brand colour, as previews show it.
  static ColorScheme brandScheme(Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

  /// Languages whose letters Google Sans Flex does not have.
  static const _withoutExpressiveFont = {'ru', 'uk'};

  /// Whether Google Sans Flex can draw the app in [locale]'s language. In
  /// the others the system's font draws the same type scale.
  static bool expressiveFontDraws(Locale locale) =>
      !_withoutExpressiveFont.contains(locale.languageCode);

  /// Material 3 Expressive: Material's colours from the brand colour, or
  /// from the wallpaper when [wallpaper] is given, its type scale in Google
  /// Sans Flex (unless [latinFont] is false) and its shapes.
  static ThemeData expressive(
    Brightness brightness, {
    WallpaperColors? wallpaper,
    bool amoled = false,
    bool latinFont = true,
  }) {
    // Built again on each change of the app's state otherwise, and a scheme
    // from a seed takes some arithmetic.
    final key = (brightness, wallpaper, amoled, latinFont);
    final cached = _expressiveThemes[key];
    if (cached != null) return cached;
    if (_expressiveThemes.length >= 4) _expressiveThemes.clear();
    return _expressiveThemes[key] = _expressive(
      brightness,
      wallpaper,
      amoled: amoled,
      latinFont: latinFont,
    );
  }

  static final _expressiveThemes =
      <(Brightness, WallpaperColors?, bool, bool), ThemeData>{};

  static ThemeData _expressive(
    Brightness brightness,
    WallpaperColors? wallpaper, {
    required bool amoled,
    required bool latinFont,
  }) {
    var colors =
        wallpaper?.scheme(brightness) ??
        ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    if (amoled) colors = _black(colors);
    final family = latinFont ? TypeScale.fontFamily : null;
    final text = TypeScale.baseline(family: family);
    TextStyle label(Color color) => text.labelMedium!.copyWith(color: color);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      fontFamily: family,
      textTheme: text,
      scaffoldBackgroundColor: colors.surface,
      extensions: [
        ExpressiveType(emphasized: TypeScale.emphasized(family: family)),
      ],
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.primary,
        scaffoldBackgroundColor: colors.surface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: _statusBar(brightness),
        titleTextStyle: text.titleLarge!.copyWith(color: colors.onSurface),
      ),
      // Flat cards on the low container, rounded as the mockup's lists.
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.largeIncreased),
        ),
      ),
      // Pages open with Material's fade forwards and follow Android's
      // predictive back gesture; iOS keeps its own slide.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // Buttons and icon buttons are round and, pressed, take the small
      // corner (ButtonSmallTokens, SmallIconButtonTokens).
      filledButtonTheme: FilledButtonThemeData(style: _pressMorph),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _pressMorph),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _pressMorph),
      textButtonTheme: TextButtonThemeData(style: _pressMorph),
      iconButtonTheme: IconButtonThemeData(style: _pressMorph),
      // The bar's menu, back and close buttons in Material Symbols too.
      actionIconTheme: ActionIconThemeData(
        drawerButtonIconBuilder: (context) => const Icon(AppSymbols.menu),
        backButtonIconBuilder: (context) => const Icon(AppSymbols.arrowBack),
        closeButtonIconBuilder: (context) => const Icon(AppSymbols.close),
      ),
      // A check on the handle of a switch that is on.
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(AppSymbols.check)
              : null,
        ),
      ),
      // The short navigation bar (NavigationBarTokens).
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => label(
            states.contains(WidgetState.selected)
                ? colors.secondary
                : colors.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Round at rest, the small corner while pressed; Material moves from one
  /// to the other.
  static final _pressMorph = ButtonStyle(
    shape: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.pressed)
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Corners.small),
            )
          : const StadiumBorder(),
    ),
    animationDuration: SpringCurve(Springs.fastSpatial).duration,
  );

  /// The surfaces of [colors] made black, for screens that save power.
  static ColorScheme _black(ColorScheme colors) => colors.copyWith(
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

  // Flutter picks the status bar icons from the bar's colour. A transparent
  // bar reads as dark, which left white icons on the light page, so the
  // theme's brightness decides instead.
  static SystemUiOverlayStyle _statusBar(Brightness brightness) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: brightness,
        statusBarIconBrightness: brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      );

  static ThemeData _theme(
    Brightness brightness,
    bool likeIos, {
    bool amoled = false,
  }) {
    var colors = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    if (amoled) colors = _black(colors);
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
        systemOverlayStyle: _statusBar(brightness),
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
