import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/excuse.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

DateTime _day(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo);
}

AttendanceRecord _absence(String id, int daysAgo, int lesson, String subject) =>
    AttendanceRecord(
      id: id,
      date: _day(daysAgo),
      lessonNumber: lesson,
      subject: subject,
      type: 'Nieobecność',
      symbol: 'nb',
      kind: AttendanceKind.absent,
    );

AppSnapshot _withAbsences(AppSnapshot data) => AppSnapshot(
  profile: data.profile,
  lessons: data.lessons,
  grades: data.grades,
  events: const [],
  messages: data.messages,
  attendance: [
    _absence('a1', 2, 1, 'Matematyka'),
    _absence('a2', 2, 2, 'Fizyka'),
  ],
  announcements: const [],
  notices: const [],
  lastSync: data.lastSync,
);

/// The parent's login, the parent's account open when [parent].
Future<(AppController, FakeLibrusWorld)> _app({
  bool parent = true,
  List<MessageRecipient> recipients = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  final world = FakeLibrusWorld()
    ..syncedAt = DateTime.now
    ..recipients = recipients;
  world.changes['child-parent'] = _withAbsences;
  world.changes['child-u'] = _withAbsences;
  final repository = world.repository();
  final found = await repository.signIn(username: parentEmail, password: 'x');
  final added = await repository.addProfiles(found.students);
  for (final profile in added) {
    await repository.syncProfile(profile.id);
  }
  await repository.switchProfile(
    added.firstWhere((profile) => profile.parent == parent).id,
  );
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  return (controller, world);
}

Future<void> _pump(WidgetTester tester, AppController controller) async {
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the note to the class teacher', () {
    test('lists each day\'s lessons and subjects, the reason and the '
        'signature, in Polish', () {
      final message = excuseMessage(
        child: 'Uczeń Testowy',
        lessons: [
          (date: DateTime(2026, 10, 27), lesson: 2, subject: 'Fizyka'),
          (date: DateTime(2026, 10, 27), lesson: 1, subject: 'Matematyka'),
          (date: DateTime(2026, 10, 28), lesson: 3, subject: 'Historia'),
        ],
        reason: ExcuseReason.illness,
        note: 'Zaświadczenie dostarczę.',
        signature: 'Rodzic Testowy',
      );
      expect(message.subject, 'Usprawiedliwienie nieobecności – Uczeń Testowy');
      expect(
        message.body,
        'Dzień dobry,\n'
        '\n'
        'proszę o usprawiedliwienie nieobecności mojego dziecka, '
        'Uczeń Testowy:\n'
        '– wtorek 27.10.2026: lekcje 1, 2 (Matematyka, Fizyka)\n'
        '– środa 28.10.2026: lekcja 3 (Historia)\n'
        '\n'
        'Powód: choroba.\n'
        'Zaświadczenie dostarczę.\n'
        '\n'
        'Z poważaniem\n'
        'Rodzic Testowy',
      );
    });

    test('tells of days to come, with the reason written out', () {
      final message = excuseMessage(
        child: 'Uczeń Testowy',
        from: DateTime(2026, 11, 3),
        to: DateTime(2026, 11, 5),
        reason: ExcuseReason.other,
        note: 'wyjazd rodzinny',
      );
      expect(message.subject, 'Planowana nieobecność – Uczeń Testowy');
      expect(
        message.body,
        contains(
          'moje dziecko, Uczeń Testowy, nie będzie obecne w szkole w dniach '
          '03.11–05.11.2026.',
        ),
      );
      expect(message.body, contains('Powód: wyjazd rodzinny.'));
      expect(message.body, endsWith('Z poważaniem'));
    });
  });

  testWidgets('from Today, the note opens as a message to the class '
      'teacher; once sent, the absences wait for the teacher', (tester) async {
    final (controller, world) = await _app(
      recipients: const [
        MessageRecipient(
          id: 7,
          name: 'Wychowawca Testowy',
          group: 'Wychowawcy',
        ),
      ],
    );
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('today-excuse-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('excuse-absence-a1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('excuse-preview'))).data,
      contains('lekcje 1, 2 (Matematyka, Fizyka)'),
    );
    await tester.tap(find.byKey(const ValueKey('excuse-reason-doctor')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('excuse-prepare')));
    await tester.tap(find.byKey(const ValueKey('excuse-prepare')));
    await tester.pumpAndSettle();

    expect(_field(tester, 'compose-subject'), startsWith('Usprawiedliwienie'));
    expect(_field(tester, 'compose-body'), contains('wizyta u lekarza'));
    expect(
      find.widgetWithText(InputChip, 'Wychowawca Testowy'),
      findsOneWidget,
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.sentMessages, hasLength(1));
    expect(find.byKey(const ValueKey('excuse-prepare')), findsNothing);

    // The block counts nothing more to excuse, and says what waits.
    expect(find.byKey(const ValueKey('today-excuse-button')), findsNothing);
    expect(find.byKey(const ValueKey('today-excuse-sent')), findsOneWidget);
    final again = AppController(world.repository(), updatesEnabled: false);
    await again.bootstrap();
    expect(
      again.excuseSentAt(controller.snapshot.attendance.first),
      isNotNull,
      reason: 'kept',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the class teacher is found by the code of the group too', (
    tester,
  ) async {
    final (controller, _) = await _app(
      recipients: const [
        MessageRecipient(
          id: 8,
          name: 'Wychowawca Testowy',
          group: 'Klasa 2a',
          groupId: 'tutors',
        ),
      ],
    );
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('today-excuse-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('excuse-prepare')));
    await tester.tap(find.byKey(const ValueKey('excuse-prepare')));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(InputChip, 'Wychowawca Testowy'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('without a class teacher among the recipients, the message '
      'waits for one to be picked; the signature signs it', (tester) async {
    final (controller, _) = await _app();
    await controller.setExcuseSignature('Rodzic Testowy');
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('today-excuse-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('excuse-prepare')));
    await tester.tap(find.byKey(const ValueKey('excuse-prepare')));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
    expect(_field(tester, 'compose-body'), endsWith('Rodzic Testowy'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('attendance offers to excuse to a parent, not to a student', (
    tester,
  ) async {
    for (final parent in [true, false]) {
      final (controller, _) = await _app(parent: parent);
      controller.selectTab(6);
      await _pump(tester, controller);
      expect(
        find.byKey(const ValueKey('attendance-excuse')),
        parent ? findsOneWidget : findsNothing,
        reason: 'parent: $parent',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
