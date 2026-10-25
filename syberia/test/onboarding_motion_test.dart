import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/startup.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/test_reminders.dart';
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

class _Presenter implements SchoolNotificationPresenter {
  _Presenter({this.allow = true});
  final bool allow;
  var asked = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allow;
  }

  @override
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
    int? id,
    NotificationTarget? target,
    String? channelName,
  }) async {}

  @override
  Future<NotificationTarget?> launchTarget() async => null;

  @override
  void onTap(void Function(NotificationTarget) callback) {}

  @override
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  }) async {}
}

class _SignedIn extends AppRepository {
  @override
  Future<AppSnapshot> load() async => AppSnapshot(
    profile: const StudentProfile(
      id: 'test',
      name: 'Uczeń Testowy',
      school: 'Liceum nr 1',
      provider: 'Librus Synergia',
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
}

/// The setup run again on a signed-in phone, opening without the animation.
Future<(AppController, _Presenter)> _repeat(
  WidgetTester tester, {
  bool allow = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final presenter = _Presenter(allow: allow);
  final controller = AppController(
    _SignedIn(),
    updatesEnabled: false,
    notifications: SchoolNotificationService(presenter),
  );
  await controller.bootstrap();
  controller.restartOnboarding();
  controller.takeIntro();
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return (controller, presenter);
}

/// The Next button of the step with [key].
Finder _nextOn(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byKey(const ValueKey('onboarding-next')),
);

/// How far [finder]'s part of a step has come in.
double _shown(WidgetTester tester, Finder finder) =>
    (tester.widget(
          find
              .ancestor(
                of: finder,
                matching: find.byWidgetPredicate(
                  (widget) => '${widget.runtimeType}' == '_LightOpacity',
                ),
              )
              .first,
        ) as dynamic).opacity
        as double;

/// The largest turn of anything in the badge of [motion], in radians.
double _turn(WidgetTester tester, String motion) => tester
    .widgetList<Transform>(
      find.descendant(
        of: find.byKey(ValueKey('setup-badge-$motion')),
        matching: find.byType(Transform),
      ),
    )
    .map((widget) {
      final m = widget.transform.storage;
      return math.atan2(m[1], m[0]).abs();
    })
    .fold(0.0, math.max);

/// How far anything in the badge of [motion] is lifted.
double _lift(WidgetTester tester, String motion) => tester
    .widgetList<Transform>(
      find.descendant(
        of: find.byKey(ValueKey('setup-badge-$motion')),
        matching: find.byType(Transform),
      ),
    )
    .map((widget) => -widget.transform.storage[13])
    .fold(0.0, math.max);

/// How far the tick of the last step has drawn itself.
double _tick(WidgetTester tester) =>
    (tester
                    .widget<CustomPaint>(
                      find
                          .descendant(
                            of: find.byKey(const ValueKey('setup-badge-check')),
                            matching: find.byType(CustomPaint),
                          )
                          .last,
                    )
                    .painter!
                as dynamic)
            .progress
        as double;

List<String> _haptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}');
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
  return calls;
}

/// A new install on the account step, signing in to the fake Librus.
Future<AppController> _onAccount(
  WidgetTester tester,
  FakeLibrusWorld world,
) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(
    world.repository(),
    updatesEnabled: false,
    notifications: SchoolNotificationService(_Presenter()),
  );
  await controller.bootstrap();
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  await tester.tap(_nextOn('onboarding-welcome'));
  await tester.pumpAndSettle();
  await tester.tap(_nextOn('onboarding-appearance'));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _submit(
  WidgetTester tester,
  String email, {
  bool fromKeyboard = false,
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, 'secret');
  if (fromKeyboard) {
    await tester.testTextInput.receiveAction(TextInputAction.done);
  } else {
    await tester.tap(find.text('Sign in and sync'));
  }
  await tester.pump();
}

/// Whether the part of signing in [stage] is shown, and still under way.
bool _underWay(String stage) => find
    .descendant(
      of: find.byKey(ValueKey('sign-in-stage-$stage')),
      matching: find.byType(CircularProgressIndicator),
    )
    .evaluate()
    .isNotEmpty;

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
      expect(find.text('Hello'), findsNothing, reason: 'greetings wait too');

      // At 4 s the rest is over and the mark flies; the page comes in as
      // it arrives, not under it.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_flight, findsOneWidget);
      await _advance(tester, const Duration(milliseconds: 150));
      expect(_shown(tester, find.text('Cześć')), 0);
      await tester.pumpAndSettle();
      expect(_shown(tester, find.text('Cześć')), 1);
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

  group('the steps', () {
    testWidgets("a step's parts come in one after another", (tester) async {
      await _repeat(tester);
      await tester.tap(_nextOn('onboarding-welcome'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final title = find.text('Appearance');
      final next = _nextOn('onboarding-appearance');
      final early = _shown(tester, title);
      expect(early, lessThan(0.6));
      expect(_shown(tester, next), lessThan(early), reason: 'buttons last');
      await tester.pumpAndSettle();
      expect(_shown(tester, title), 1);
      expect(_shown(tester, next), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the greeting changes smoothly', (tester) async {
      await _repeat(tester);
      expect(find.text('Cześć'), findsOneWidget);
      for (var waited = 0; waited < 3000; waited += 50) {
        if (find.text('Hello').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 50));
      }
      // One word goes as the next comes.
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Cześć'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Cześć'), findsNothing);
      expect(find.text('Hello'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets("each step's badge comes alive as it opens, and the bell "
        'rings again when notifications are allowed', (tester) async {
      final (_, presenter) = await _repeat(tester);
      await tester.tap(_nextOn('onboarding-welcome'));
      await tester.pump();
      await _advance(tester, const Duration(milliseconds: 300));
      expect(_turn(tester, 'palette'), greaterThan(0.01));
      await tester.pumpAndSettle();
      expect(_turn(tester, 'palette'), lessThan(1e-6));

      await tester.tap(_nextOn('onboarding-appearance'));
      await tester.pump();
      await _advance(tester, const Duration(milliseconds: 350));
      expect(_lift(tester, 'cap'), greaterThan(2), reason: 'the cap jumps');
      await tester.pumpAndSettle();
      expect(_lift(tester, 'cap'), lessThan(1e-6));
      await tester.tap(_nextOn('onboarding-account'));
      await tester.pump();
      await _advance(tester, const Duration(milliseconds: 200));
      expect(_turn(tester, 'bell'), greaterThan(0.01));
      await tester.pumpAndSettle();
      expect(_turn(tester, 'bell'), lessThan(1e-6));

      await tester.tap(_nextOn('onboarding-notifications'));
      await tester.pump();
      await _advance(tester, const Duration(milliseconds: 150));
      expect(presenter.asked, 1);
      expect(_turn(tester, 'bell'), greaterThan(0.01));
      expect(
        find.byKey(const ValueKey('onboarding-done')),
        findsNothing,
        reason: 'the step waits for the bell',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('onboarding-done')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the tick of the last step draws itself', (tester) async {
      await _repeat(tester);
      await tester.tap(_nextOn('onboarding-welcome'));
      await tester.pumpAndSettle();
      await tester.tap(_nextOn('onboarding-appearance'));
      await tester.pumpAndSettle();
      await tester.tap(_nextOn('onboarding-account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pump();
      await _advance(tester, const Duration(milliseconds: 650));
      expect(_tick(tester), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_tick(tester), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('with less motion nothing moves', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _repeat(tester);
      await tester.tap(_nextOn('onboarding-welcome'));
      await tester.pump();
      await tester.pump();
      expect(_shown(tester, find.text('Appearance')), 1);
      expect(_turn(tester, 'palette'), lessThan(1e-6));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Hello'), findsNothing, reason: 'the greeting stays');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('choices and steps are felt', (tester) async {
      final haptics = _haptics(tester);
      await _repeat(tester);
      await tester.tap(find.byKey(const ValueKey('onboarding-language-pl')));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      await tester.tap(_nextOn('onboarding-welcome'));
      await tester.pumpAndSettle();
      expect(haptics.last, 'HapticFeedbackType.lightImpact');
      await tester.tap(find.byKey(const ValueKey('onboarding-theme-dark')));
      await tester.pumpAndSettle();
      expect(haptics.last, 'HapticFeedbackType.selectionClick');
      await tester.tap(find.byKey(const ValueKey('onboarding-back')));
      await tester.pumpAndSettle();
      expect(haptics.last, 'HapticFeedbackType.lightImpact');
      for (final step in ['welcome', 'appearance', 'account']) {
        await tester.tap(_nextOn('onboarding-$step'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(haptics.last, 'HapticFeedbackType.mediumImpact');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('signing in', () {
    testWidgets('shows its real parts in turn, each for half a second at '
        'least, then the students added', (tester) async {
      final world = FakeLibrusWorld();
      final controller = await _onAccount(tester, world);
      final stages = <SignInStage>[];
      controller.addListener(() {
        final stage = controller.signInStage;
        if (stage != null && (stages.isEmpty || stages.last != stage)) {
          stages.add(stage);
        }
      });
      final regular = world.holds['kid-regular'] = Completer<void>();
      final music = world.holds['kid-music'] = Completer<void>();

      await _submit(tester, familyEmail, fromKeyboard: true);
      // The form gives way at once, and the keyboard goes with it.
      expect(find.byKey(const ValueKey('sign-in-progress')), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>(),
        isNull,
        reason: 'no text field keeps the focus',
      );
      expect(_underWay('checking'), isTrue);
      await _advance(tester, const Duration(milliseconds: 200));
      // Librus answered and asks which students, but the first part is
      // still shown under way.
      expect(controller.signInStage, SignInStage.choosing);
      expect(_underWay('checking'), isTrue);
      expect(
        find.byKey(const ValueKey('sign-in-stage-choosing')),
        findsNothing,
      );
      await _advance(tester, const Duration(milliseconds: 400));
      expect(_underWay('checking'), isFalse, reason: 'ticked off');
      expect(_underWay('choosing'), isTrue);

      await tester.tap(find.byKey(const ValueKey('choose-students-add')));
      // Long after its half second, loading shows under way for as long as
      // Librus really loads.
      await _advance(tester, const Duration(milliseconds: 1600));
      expect(controller.signInStage, SignInStage.loading);
      expect(_underWay('choosing'), isFalse);
      expect(_underWay('loading'), isTrue, reason: 'Librus still loading');

      regular.complete();
      music.complete();
      await _advance(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('sign-in-done')), findsOneWidget);
      for (final profile in controller.profiles) {
        expect(
          find.byKey(ValueKey('sign-in-added-${profile.id}')),
          findsOneWidget,
        );
      }
      expect(controller.profiles, hasLength(2));
      expect(
        find.byKey(const ValueKey('onboarding-notifications')),
        findsNothing,
        reason: 'the students are shown for a moment first',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('onboarding-notifications')),
        findsOneWidget,
      );
      expect(stages, [
        SignInStage.checking,
        SignInStage.choosing,
        SignInStage.loading,
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a failed sign-in brings the form back with its error', (
      tester,
    ) async {
      final controller = await _onAccount(tester, FakeLibrusWorld());
      await _submit(tester, 'nobody@example.com');
      await tester.pumpAndSettle();
      expect(controller.error, isNotNull);
      expect(find.byKey(const ValueKey('sign-in-progress')), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('nobody@example.com'), findsOneWidget, reason: 'kept');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('with less motion the parts are not held back', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _onAccount(tester, FakeLibrusWorld());
      await _submit(tester, familyEmail);
      await tester.pump();
      expect(_underWay('checking'), isFalse);
      expect(_underWay('choosing'), isTrue);
      // The sheet asking which students comes up.
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('choose-students-add')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('onboarding-notifications')),
        findsOneWidget,
      );
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
