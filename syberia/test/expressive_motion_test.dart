import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/theme/app_theme.dart';
import 'package:syberia/src/theme/expressive_tokens.dart';
import 'package:syberia/src/theme/wallpaper_colors.dart';
import 'package:syberia/src/ui/expressive/expressive.dart';

import 'support/profile_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('theme', () {
    final theme = AppTheme.expressive(Brightness.light);

    test('buttons are round and take the small corner when pressed', () {
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
        theme.iconButtonTheme.style!,
      ]) {
        expect(style.shape!.resolve({}), isA<StadiumBorder>());
        final pressed =
            style.shape!.resolve({WidgetState.pressed})!
                as RoundedRectangleBorder;
        expect(pressed.borderRadius, BorderRadius.circular(Corners.small));
        expect(
          style.animationDuration,
          SpringCurve(Springs.fastSpatial).duration,
        );
      }
    });

    test('pages follow the predictive back gesture on Android', () {
      final builders = theme.pageTransitionsTheme.builders;
      expect(
        builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    });

    test('Android is told the app handles the back gesture itself', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
    });
  });

  group('less motion', () {
    Widget app(Widget child) => MaterialApp(
      theme: AppTheme.expressive(Brightness.light, latinFont: false),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: child)),
      ),
    );

    testWidgets('a group changes its shape at once', (tester) async {
      var selected = 'a';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => app(
            SizedBox(
              width: 300,
              child: ConnectedButtonGroup<String>(
                selected: selected,
                onSelected: (value) => setState(() => selected = value),
                options: const [
                  (value: 'a', label: 'A', icon: null, key: null),
                  (value: 'b', label: 'B', icon: null, key: null),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('B'));
      await tester.pump();
      // Only the ink of the tap is still moving; the shape is already final.
      await tester.pump(const Duration(milliseconds: 16));
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text('B'), matching: find.byType(Material))
            .first,
      );
      expect(
        (material.shape! as RoundedRectangleBorder).borderRadius,
        const BorderRadiusDirectional.horizontal(
          start: Radius.circular(20),
          end: Radius.circular(20),
        ),
      );
    });

    testWidgets('the navigation pill is there at once', (tester) async {
      await tester.pumpWidget(
        app(
          ExpressiveNavigationBar(
            selectedIndex: 0,
            onSelected: (_) {},
            destinations: const [
              (icon: Icons.home_outlined, label: 'A', badge: 0, badgeText: ''),
              (
                icon: Icons.school_outlined,
                label: 'B',
                badge: 0,
                badgeText: '',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('switches', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      WallpaperColors.ask = () async => null;
    });

    Future<List<String>> flipAutoSync(
      WidgetTester tester,
      AppDesign design,
    ) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repository = _Repository();
      await repository.saveDesign(design);
      final controller = AppController(repository, updatesEnabled: false);
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      controller.selectTab(9);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final tile = find.widgetWithText(SwitchListTile, 'Sync automatically');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(tile);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      haptics.clear();
      final before = controller.autoSyncOnOpen;
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(Switch)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.autoSyncOnOpen, !before);
      return haptics;
    }

    testWidgets('a flip is felt in the Expressive design', (tester) async {
      final haptics = await flipAutoSync(tester, AppDesign.expressive);
      expect(haptics, contains('HapticFeedbackType.selectionClick'));
    });

    testWidgets('and on an iPhone the switch is Material too', (tester) async {
      await flipAutoSync(tester, AppDesign.expressive);
      expect(find.byType(CupertinoSwitch), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
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
