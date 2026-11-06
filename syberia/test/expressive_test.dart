import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/theme/app_symbols.dart';
import 'package:syberia/src/theme/app_theme.dart';
import 'package:syberia/src/theme/expressive_tokens.dart';
import 'package:syberia/src/theme/wallpaper_colors.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';

import 'support/profile_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final onAndroid = TargetPlatformVariant.only(TargetPlatform.android);

  final green = {
    'seed': 0xFF4A7C45,
    'light': {'primary': 0xFF3B6939, 'surface': 0xFFF7FBF1},
    'dark': {'primary': 0xFFA2D399},
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WallpaperColors.ask = () async => null;
  });

  tearDown(() {
    WallpaperColors.ask = () async => null;
    GlassPlatform.debugSetBackend(GlassBackend.none);
  });

  group('type scale', () {
    test('has the sizes, weights and tracking of the Material tokens', () {
      final base = TypeScale.baseline(family: TypeScale.fontFamily);
      final titleMedium = base.titleMedium!;
      expect(titleMedium.fontSize, 16);
      expect(titleMedium.height, 24 / 16);
      expect(titleMedium.fontWeight, FontWeight.w500);
      expect(titleMedium.letterSpacing, 0.2);
      expect(titleMedium.fontFamily, 'Google Sans Flex');
      expect(base.displayLarge!.letterSpacing, -0.2);
      expect(base.bodyMedium!.fontWeight, FontWeight.w400);
      expect(base.labelSmall!.fontSize, 11);
      expect(base.headlineMedium!.fontVariations, [
        const FontVariation.opticalSize(28),
      ]);
    });

    test('emphasized styles are heavier and display ones rounded', () {
      final emphasized = TypeScale.emphasized();
      expect(emphasized.titleMedium!.fontWeight, FontWeight.w700);
      expect(emphasized.titleMedium!.letterSpacing, 0.15);
      expect(emphasized.bodyLarge!.fontWeight, FontWeight.w500);
      expect(emphasized.headlineMedium!.fontWeight, FontWeight.w500);
      expect(emphasized.displaySmall!.fontVariations, [
        const FontVariation.opticalSize(36),
        const FontVariation('ROND', 100),
      ]);
      expect(emphasized.displaySmall!.fontFamily, isNull);
    });

    testWidgets('a heavier weight draws heavier Google Sans Flex', (
      tester,
    ) async {
      await tester.runAsync(AppTheme.loadExpressiveFont);
      final key = GlobalKey();
      final base = TypeScale.baseline(family: TypeScale.fontFamily);
      Future<int> ink(TextStyle style) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: Colors.white,
                  child: Text(
                    'Matematyka',
                    style: style.copyWith(color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
        );
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData();
          var dark = 0;
          for (var i = 0; i < bytes!.lengthInBytes; i += 4) {
            if (bytes.getUint8(i) < 128) dark++;
          }
          return dark;
        }))!;
      }

      final regular = await ink(
        base.titleMedium!.copyWith(fontWeight: FontWeight.w400),
      );
      final bold = await ink(
        TypeScale.emphasized(family: TypeScale.fontFamily).titleMedium!,
      );
      expect(regular, greaterThan(0));
      expect(bold, greaterThan(regular * 1.2));
    });
  });

  group('expressive theme', () {
    test('takes Material colours from the brand colour', () {
      final light = AppTheme.expressive(Brightness.light);
      expect(light.colorScheme.primary, const Color(0xFF1D6586));
      expect(light.colorScheme.primaryContainer, const Color(0xFFC4E7FF));
      expect(light.scaffoldBackgroundColor, light.colorScheme.surface);
      expect(light.textTheme.titleMedium!.fontFamily, 'Google Sans Flex');
      expect(light.extension<ExpressiveType>(), isNotNull);
      expect(light.navigationBarTheme.height, 64);
      expect(
        light.navigationBarTheme.indicatorColor,
        light.colorScheme.secondaryContainer,
      );
      expect(
        light.navigationBarTheme.backgroundColor,
        light.colorScheme.surfaceContainer,
      );
      final card = light.cardTheme.shape! as RoundedRectangleBorder;
      expect(card.borderRadius, BorderRadius.circular(Corners.largeIncreased));
    });

    test('draws Russian and Ukrainian in the system font', () {
      expect(AppTheme.expressiveFontDraws(const Locale('pl')), isTrue);
      expect(AppTheme.expressiveFontDraws(const Locale('ru')), isFalse);
      expect(AppTheme.expressiveFontDraws(const Locale('uk')), isFalse);
      final theme = AppTheme.expressive(Brightness.light, latinFont: false);
      expect(theme.textTheme.bodyMedium!.fontFamily, isNot('Google Sans Flex'));
      expect(theme.textTheme.bodyMedium!.fontSize, 14);
    });

    test('in black mode the surfaces are black', () {
      final theme = AppTheme.expressive(Brightness.dark, amoled: true);
      expect(theme.colorScheme.surface, Colors.black);
      expect(theme.colorScheme.surfaceContainer, Colors.black);
      expect(theme.colorScheme.primary, isNot(Colors.black));
    });

    test('takes the wallpaper colours when given', () {
      final wallpaper = WallpaperColors.fromPlatform(green)!;
      final theme = AppTheme.expressive(Brightness.light, wallpaper: wallpaper);
      expect(theme.colorScheme.primary, const Color(0xFF3B6939));
      expect(
        identical(
          AppTheme.expressive(Brightness.light, wallpaper: wallpaper),
          theme,
        ),
        isTrue,
      );
    });
  });

  group('wallpaper colours', () {
    test('read the colour of each role Android names', () {
      final colors = WallpaperColors.fromPlatform({
        ...green,
        'light': {
          'primary': 0xFF3B6939,
          'unknown': 0xFF000000,
          'surface': 'not a colour',
        },
      })!;
      expect(colors.seed, const Color(0xFF4A7C45));
      expect(colors.light, {'primary': const Color(0xFF3B6939)});
      final light = colors.scheme(Brightness.light);
      expect(light.primary, const Color(0xFF3B6939));
      final fromSeed = ColorScheme.fromSeed(seedColor: const Color(0xFF4A7C45));
      // A role Android did not name comes from the seed.
      expect(light.secondaryContainer, fromSeed.secondaryContainer);
    });

    test('Android 12 and 13 give only the seed', () {
      final colors = WallpaperColors.fromPlatform({'seed': 0xFF4A7C45})!;
      expect(colors.light, isNull);
      expect(
        colors.scheme(Brightness.dark),
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A7C45),
          brightness: Brightness.dark,
        ),
      );
    });

    test('Java colours arrive as signed numbers', () {
      final colors = WallpaperColors.fromPlatform({'seed': -16711936})!;
      expect(colors.seed, const Color(0xFF00FF00));
    });

    test('nothing usable gives no colours', () {
      expect(WallpaperColors.fromPlatform(null), isNull);
      expect(WallpaperColors.fromPlatform({'light': {}}), isNull);
      expect(WallpaperColors.fromPlatform('seed'), isNull);
    });

    testWidgets('are asked for on Android only', (tester) async {
      var asked = 0;
      WallpaperColors.ask = () async {
        asked++;
        return green;
      };
      expect(await WallpaperColors.load(), isNull);
      expect(asked, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android answers with its colours', (tester) async {
      WallpaperColors.ask = () async => green;
      final colors = await WallpaperColors.load();
      expect(colors?.seed, const Color(0xFF4A7C45));
      expect(colors?.dark, {'primary': const Color(0xFFA2D399)});
    }, variant: onAndroid);

    testWidgets('a phone that cannot answer has none', (tester) async {
      WallpaperColors.ask = () async =>
          throw PlatformException(code: 'unavailable');
      expect(await WallpaperColors.load(), isNull);
      WallpaperColors.ask = () async => throw MissingPluginException();
      expect(await WallpaperColors.load(), isNull);
    }, variant: onAndroid);
  });

  group('symbols', () {
    test('every Material icon of the app has its symbol', () {
      final pattern = RegExp(r'(?<![A-Za-z_])Icons\.([a-z0-9_]+)');
      final names = {
        for (final file in Directory('lib').listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              !file.path.endsWith('app_symbols.dart'))
            ...pattern
                .allMatches(file.readAsStringSync())
                .map((match) => match[1]!),
      };
      final symbols = File('lib/src/theme/app_symbols.dart').readAsStringSync();
      final missing = [
        for (final name in names)
          if (!symbols.contains('Icons.$name:')) name,
      ];
      expect(
        missing,
        isEmpty,
        reason: 'Run tool/subset_fonts.py --symbols to add them.',
      );
    });

    test('are drawn from Material Symbols Rounded', () {
      expect(AppSymbols.of(Icons.home_rounded), AppSymbols.home);
      expect(AppSymbols.of(Icons.copy_rounded), AppSymbols.contentCopy);
      expect(AppSymbols.home.fontFamily, 'MaterialSymbolsRounded');
    });

    testWidgets('the icon font is bundled', (tester) async {
      final font = await tester.runAsync(
        () => rootBundle.load('assets/fonts/MaterialSymbolsRounded.ttf'),
      );
      expect(font!.lengthInBytes, greaterThan(10000));
    });
  });

  group('settings', () {
    Future<AppController> pumpApp(
      WidgetTester tester, {
      AppDesign design = AppDesign.glass,
    }) async {
      final repository = _Repository();
      await repository.saveDesign(design);
      final controller = AppController(repository, updatesEnabled: false);
      await controller.bootstrap();
      // As main() does before the first frame.
      await controller.refreshWallpaperColors();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      controller.selectTab(9);
      await tester.pumpAndSettle();
      return controller;
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Off the bottom bar, which would take the tap.
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('offers Expressive next to the classic design', (tester) async {
      final controller = await pumpApp(tester);
      final expressive = find.byKey(
        const ValueKey('settings-design-expressive'),
      );
      await scrollTo(tester, expressive);
      // Without glass on this platform, glass is not offered and the classic
      // design shows as chosen.
      expect(find.byKey(const ValueKey('settings-design-glass')), findsNothing);
      expect(find.text('Expressive'), findsOneWidget);

      await tester.tap(expressive);
      await tester.pumpAndSettle();
      expect(controller.design, AppDesign.expressive);
      expect(await _Repository().loadDesign(), AppDesign.expressive);
      final theme = Theme.of(tester.element(find.byType(NavigationBar)));
      expect(theme.extension<ExpressiveType>(), isNotNull);
      expect(theme.colorScheme.primary, const Color(0xFF1D6586));
    }, variant: onAndroid);

    testWidgets('the wallpaper colours can be turned off', (tester) async {
      WallpaperColors.ask = () async => green;
      final controller = await pumpApp(tester, design: AppDesign.expressive);
      final toggle = find.byKey(const ValueKey('settings-wallpaper-colors'));
      await scrollTo(tester, toggle);
      expect(controller.useWallpaperColors, isTrue);
      Color primary() =>
          Theme.of(tester.element(find.byType(NavigationBar)))
              .colorScheme
              .primary;
      expect(primary(), const Color(0xFF3B6939));

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(controller.useWallpaperColors, isFalse);
      expect(controller.themeWallpaperColors, isNull);
      expect(await _Repository().loadUseWallpaperColors(), isFalse);
      expect(primary(), const Color(0xFF1D6586));
    }, variant: onAndroid);

    testWidgets('without wallpaper colours there is no switch', (tester) async {
      await pumpApp(tester, design: AppDesign.expressive);
      await scrollTo(
        tester,
        find.byKey(const ValueKey('settings-design-expressive')),
      );
      expect(
        find.byKey(const ValueKey('settings-wallpaper-colors')),
        findsNothing,
      );
    }, variant: onAndroid);

    testWidgets('a new wallpaper is picked up when the app comes back', (
      tester,
    ) async {
      final controller = await pumpApp(tester, design: AppDesign.expressive);
      expect(controller.wallpaperColors, isNull);
      WallpaperColors.ask = () async => green;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(controller.wallpaperColors?.seed, const Color(0xFF4A7C45));
    }, variant: onAndroid);
  });
}

class _Repository extends AppRepository {
  @override
  Future<AppSnapshot> load() async => studentSnapshot('s1', 'a');

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}
