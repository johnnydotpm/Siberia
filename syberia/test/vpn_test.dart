import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/network_vpn.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

const _signInHint =
    'A VPN is on. Librus sometimes blocks VPNs, so if signing in fails, '
    'turn it off.';
final _todayHint = find.byKey(const ValueKey('today-vpn'));
final _hintCard = find.byKey(const ValueKey('vpn-hint'));

/// Fails each sync with [failure], as Librus would.
class _Repository extends AppRepository {
  _Repository(this.failure);

  final Object failure;

  @override
  Future<AppSnapshot> load() async => AppSnapshot(
    profile: const StudentProfile(
      id: 'test',
      name: 'Uczeń Testowy',
      school: 'Szkoła Testowa',
      provider: 'Librus Synergia',
    ),
    lessons: const [],
    grades: const [],
    events: const [],
    messages: const [],
    attendance: const [],
    announcements: const [],
    notices: const [],
    lastSync: DateTime(2026, 10, 20, 8),
  );

  @override
  Future<AppSnapshot> sync(AppSnapshot current) async => throw failure;
}

/// The first setup, on its sign-in step.
Future<AppController> _onSignIn(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(
    FakeLibrusWorld().repository(),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  for (final step in ['welcome', 'appearance']) {
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('onboarding-$step')),
        matching: find.byKey(const ValueKey('onboarding-next')),
      ),
    );
    await tester.pumpAndSettle();
  }
  return controller;
}

/// The Today screen after a sync that failed with [failure].
Future<void> _failedSync(WidgetTester tester, Object failure) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
    'onboarding_done_v1': true,
  });
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(_Repository(failure), updatesEnabled: false);
  await controller.bootstrap();
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  await controller.sync();
  await tester.pumpAndSettle();
}

void main() {
  group('signing in', () {
    for (final (phone, shown) in [
      (true, true),
      (false, false),
      (null, false),
    ]) {
      testWidgets(
        'with the phone saying ${switch (phone) {
          true => 'a VPN is on',
          false => 'no VPN',
          null => 'nothing',
        }}, the hint is ${shown ? '' : 'not '}there',
        (tester) async {
          Vpn.check = () async => phone;
          await _onSignIn(tester);
          expect(find.text(_signInHint), shown ? findsOneWidget : findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets('asks again after a failed sign-in', (tester) async {
      var asked = 0;
      var phone = false;
      Vpn.check = () async {
        asked++;
        return phone;
      };
      final controller = await _onSignIn(tester);
      expect(asked, 1);
      expect(find.text(_signInHint), findsNothing);

      phone = true;
      await tester.enterText(
        find.byType(TextFormField).first,
        'nobody@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'secret');
      await tester.tap(find.text('Sign in and sync'));
      await tester.pumpAndSettle();
      expect(controller.error, isNotNull);
      expect(asked, 2, reason: 'once more, not all the time');
      expect(find.text(_signInHint), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('a failed sync', () {
    testWidgets('that Librus did not answer says a VPN may be why, with one '
        'on', (tester) async {
      Vpn.check = () async => true;
      await _failedSync(
        tester,
        const LibrusException(LibrusErrorCode.networkTimeout),
      );
      expect(_todayHint, findsOneWidget);
      expect(
        find.descendant(of: _todayHint, matching: _hintCard),
        findsOneWidget,
      );
      expect(
        find.text(
          'A VPN is on, and Librus sometimes blocks VPNs. Try turning it off.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('says nothing of a VPN without one on', (tester) async {
      Vpn.check = () async => false;
      await _failedSync(
        tester,
        const LibrusException(LibrusErrorCode.networkTimeout),
      );
      expect(_hintCard, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('says nothing of a VPN when the password was wrong', (
      tester,
    ) async {
      Vpn.check = () async => true;
      await _failedSync(
        tester,
        const LibrusException(LibrusErrorCode.invalidCredentials),
      );
      expect(find.byKey(const ValueKey('today-error')), findsOneWidget);
      expect(_todayHint, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  test('a VPN may be behind Librus not answering or turning a request '
      'away, never behind a wrong password or a missing account', () {
    for (final code in LibrusErrorCode.values) {
      final expected = switch (code) {
        LibrusErrorCode.networkTimeout ||
        LibrusErrorCode.networkUnavailable ||
        LibrusErrorCode.networkOther ||
        LibrusErrorCode.networkUnknown ||
        LibrusErrorCode.serverReply ||
        LibrusErrorCode.captchaRequired ||
        LibrusErrorCode.sessionRenewFailed ||
        LibrusErrorCode.loginFailed ||
        LibrusErrorCode.portalRejected ||
        LibrusErrorCode.apiRejected => true,
        _ => false,
      };
      expect(
        Vpn.mayCause(AppError(errorCode: code)),
        expected,
        reason: '$code',
      );
    }
    expect(Vpn.mayCause(const AppError(raw: 'Bad state')), isFalse);
  });

  test('the debug menu can say a VPN is on whatever the phone says', () async {
    Vpn.check = () async => false;
    expect(await Vpn.isActive(), isFalse);
    Vpn.simulated = true;
    expect(await Vpn.isActive(), isTrue);
    expect(await Vpn.phone(), isFalse, reason: 'the phone still says no');
  });
}
