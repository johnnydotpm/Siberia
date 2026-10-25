import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/startup.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/brand_logo.dart';

import 'support/profile_fakes.dart';

final _intro = find.byKey(const ValueKey('setup-intro'));
final _flight = find.byKey(const ValueKey('setup-intro-flight'));

double _iconOpacity(WidgetTester tester) => tester
    .widget<Opacity>(find.byKey(const ValueKey('startup-icon-opacity')))
    .opacity;

double _wordOpacity(WidgetTester tester) => tester
    .widget<Opacity>(find.byKey(const ValueKey('startup-word-opacity')))
    .opacity;

/// How visible the first step's logo is.
double _welcomeLogo(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .descendant(
            of: find.byKey(const ValueKey('login-demo-logo')),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

/// Lets [time] pass frame by frame, as on a screen: an animation that starts
/// when another ends starts on the next frame.
Future<void> _advance(WidgetTester tester, Duration time) async {
  const frame = Duration(milliseconds: 16);
  for (var passed = Duration.zero; passed < time; passed += frame) {
    await tester.pump(frame);
  }
}

/// A first launch: the startup screen, and the app ready after [loading].
Future<AppController> _launch(
  WidgetTester tester, {
  required Duration loading,
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
    ...saved,
  });
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(
    FakeLibrusWorld().repository(),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  final ready = Completer<AppController>();
  await tester.pumpWidget(
    StartupApp(initialize: () => ready.future, preferences: AppRepository()),
  );
  await tester.pump(loading);
  ready.complete(controller);
  await tester.pump();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the startup animation on a first launch', () {
    testWidgets('carries on from where it got to and plays to the whole '
        'logo, however fast the app loaded', (tester) async {
      SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = AppController(
        FakeLibrusWorld().repository(),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      final ready = Completer<AppController>();
      await tester.pumpWidget(
        StartupApp(
          initialize: () => ready.future,
          preferences: AppRepository(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final before = _iconOpacity(tester);
      ready.complete(controller);
      await tester.pump();
      expect(find.byType(SyberiaApp), findsOneWidget);
      expect(_intro, findsOneWidget);
      // The same frame as on the startup screen, give or take one.
      expect(_iconOpacity(tester), closeTo(before, 0.1));

      // 3.9 s from the start: the whole logo rests, the flight waits.
      await tester.pump(const Duration(milliseconds: 3600));
      expect(_wordOpacity(tester), 1);
      expect(_flight, findsNothing);
      expect(_welcomeLogo(tester), 0, reason: 'hidden until the mark lands');

      // At 4 s the rest is over and the mark flies.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_flight, findsOneWidget);
      await tester.pumpAndSettle();
      expect(_intro, findsNothing);
      expect(_welcomeLogo(tester), 1);
      expect(find.byKey(const ValueKey('onboarding-welcome')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a tap starts the flight at once', (tester) async {
      await _launch(tester, loading: const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(_intro);
      await tester.pump();
      expect(_flight, findsOneWidget);
      await tester.pumpAndSettle();
      expect(_intro, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('after a slow start that showed the whole logo, the mark '
        'flies as soon as it is whole', (tester) async {
      // 4.2 s: the wordmark is leaving, the mark still whole.
      await _launch(tester, loading: const Duration(milliseconds: 4200));
      await tester.pump();
      expect(_flight, findsOneWidget);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());

      // 4.7 s: the mark is fading; it waits for it to be whole again, at
      // 5.65 s.
      await _launch(tester, loading: const Duration(milliseconds: 4700));
      await _advance(tester, const Duration(milliseconds: 850));
      expect(_flight, findsNothing);
      await _advance(tester, const Duration(milliseconds: 200));
      expect(_flight, findsOneWidget);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('is not carried on once the setup is done, nor with less '
        'motion', (tester) async {
      await _launch(
        tester,
        loading: const Duration(milliseconds: 300),
        saved: {'onboarding_done_v1': true},
      );
      expect(_intro, findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Connect to Librus'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _launch(tester, loading: const Duration(milliseconds: 300));
      await tester.pump();
      expect(_intro, findsNothing);
      expect(find.byKey(const ValueKey('onboarding-welcome')), findsOneWidget);
      expect(_welcomeLogo(tester), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('plays from the start when the setup is run again', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'app_design_v1': 'classic',
        'app_locale_v1': 'en',
        'onboarding_done_v1': true,
      });
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = AppController(
        FakeLibrusWorld().repository(),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      controller.restartOnboarding();
      await tester.pump();
      expect(_intro, findsOneWidget);
      expect(_iconOpacity(tester), 0, reason: 'from the very start');
      await tester.pump(const Duration(milliseconds: 3900));
      expect(_flight, findsNothing);
      await tester.pumpAndSettle();
      expect(_intro, findsNothing);
      expect(find.byKey(const ValueKey('onboarding-welcome')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  test('the frame of the animation is whole between its marks', () {
    for (final phase in [0.38, 0.5, 0.8]) {
      expect(BrandLogoFrame.word(phase), 1);
      expect(BrandLogoFrame.iconOpacity(phase), 1);
      expect(BrandLogoFrame.iconScale(phase), 1);
    }
    expect(BrandLogoFrame.iconOpacity(0), 0);
    expect(BrandLogoFrame.word(0.1), 0);
  });
}
