import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/startup.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/brand_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Unbounded')
      ..addFont(rootBundle.load('assets/fonts/Unbounded.ttf'));
    await font.load();
  });
  // Past the first setup, which has tests of its own.
  setUp(
    () => SharedPreferences.setMockInitialValues({'onboarding_done_v1': true}),
  );

  Future<void> capture(WidgetTester tester, String name) async {
    final context = tester.element(find.byType(AppLogo));
    await tester.runAsync(
      () => precacheImage(
        AssetImage(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/branding/logo-dark.png'
              : 'assets/branding/logo-light.png',
        ),
        context,
      ),
    );
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    if (!const bool.fromEnvironment('CAPTURE_STARTUP')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('/workspace/artifacts/branding/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'shows the animation while initialization is pending and leaves as soon as it completes',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final loading = Completer<AppController>();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('preview'),
          child: StartupApp(
            initialize: () => loading.future,
            preferences: AppRepository(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
      expect(find.byType(AnimatedBrandLogo), findsOneWidget);
      expect(find.byType(SyberiaApp), findsNothing);
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('startup-word-opacity')))
            .opacity,
        1,
      );
      await capture(tester, 'startup-light');
      final controller = AppController(_Repository(), updatesEnabled: false);
      await controller.bootstrap();
      loading.complete(controller);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedBrandLogo), findsNothing);
      expect(find.byType(SyberiaApp), findsOneWidget);
      expect(find.text('Connect to Librus'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'saved dark and AMOLED appearance apply during loading, and system follows the phone',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      for (final (mode, background, variant) in [
        ('dark', const Color(0xFF0B1A22), 'dark'),
        ('amoled', Colors.black, 'dark'),
        ('light', Colors.white, 'light'),
        ('system', const Color(0xFF0B1A22), 'dark'),
      ]) {
        SharedPreferences.setMockInitialValues({'app_color_mode_v1': mode});
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('preview'),
            child: StartupApp(
              key: ValueKey(mode),
              initialize: () => Completer<AppController>().future,
              preferences: AppRepository(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2100));
        expect(
          Theme.of(tester.element(find.byType(Scaffold)))
              .scaffoldBackgroundColor,
          background,
        );
        expect(
          tester.widget<Image>(find.byType(Image)).image,
          AssetImage('assets/branding/logo-$variant.png'),
        );
        if (mode == 'dark') await capture(tester, 'startup-dark');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Reduce Motion keeps the complete logo static', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      StartupApp(
        initialize: () => Completer<AppController>().future,
        preferences: AppRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('startup-word-opacity')))
          .opacity,
      1,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('startup-icon-opacity')))
          .opacity,
      1,
    );
    await tester.pump(const Duration(seconds: 6));
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('startup-word-opacity')))
          .opacity,
      1,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'startup errors allow retry and fit a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var attempts = 0;
      final retry = Completer<AppController>();
      await tester.pumpWidget(
        StartupApp(
          initialize: () {
            attempts++;
            return attempts == 1
                ? Future.error(StateError('fixture'))
                : retry.future;
          },
          preferences: AppRepository(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('The app could not start. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(attempts, 2);
      expect(
        find.text('The app could not start. Please try again.'),
        findsNothing,
      );
      final controller = AppController(_Repository(), updatesEnabled: false);
      await controller.bootstrap();
      retry.complete(controller);
      await tester.pumpAndSettle();
      expect(find.byType(SyberiaApp), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Repository extends AppRepository {
  @override
  Future<AppSnapshot> load() async => AppSnapshot(
    profile: const StudentProfile(
      id: 'signed-out',
      name: 'SiberiaGB',
      school: '',
      provider: 'Signed out',
    ),
    lessons: const [],
    grades: const [],
    events: const [],
    messages: const [],
    attendance: const [],
    announcements: const [],
    notices: const [],
    lastSync: DateTime.now(),
  );

  // The real one would reach Librus; the Today look-ahead asks for weeks.
  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}
