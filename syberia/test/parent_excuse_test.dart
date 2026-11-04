import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/librus/librus_client.dart'
    show parseJustifications, probeMask, probeMessages, probeShape, probeWords;
import 'package:syberia/src/domain/excuse.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/parent.dart';
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

AppSnapshot _withAbsences(
  AppSnapshot data, {
  bool excused = false,
  SchoolMessage? reply,
}) => AppSnapshot(
  profile: data.profile,
  lessons: data.lessons,
  grades: data.grades,
  events: const [],
  messages: [...data.messages, ?reply],
  attendance: [
    for (final record in [
      _absence('a1', 2, 1, 'Matematyka'),
      _absence('a2', 2, 2, 'Fizyka'),
    ])
      excused
          ? AttendanceRecord(
              id: record.id,
              date: record.date,
              lessonNumber: record.lessonNumber,
              subject: record.subject,
              type: 'Nieobecność usprawiedliwiona',
              symbol: 'u',
              kind: AttendanceKind.absentExcused,
            )
          : record,
  ],
  announcements: const [],
  notices: const [],
  lastSync: data.lastSync,
);

const _teacher = MessageRecipient(
  id: 7,
  name: 'Anna Testowa',
  group: 'Wychowawca',
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
    test('says each day and its reason, as the design shows', () {
      expect(
        excuseSentence([
          (
            date: DateTime(2026, 10, 27),
            reason: ExcuseReason.unwell,
            other: '',
          ),
          (
            date: DateTime(2026, 10, 29),
            reason: ExcuseReason.family,
            other: '',
          ),
        ], word: ExcuseChild.son),
        'Proszę o usprawiedliwienie nieobecności mojego syna w dniu 27 '
        'października z powodu złego samopoczucia oraz 29 z powodu spraw '
        'rodzinnych.',
      );
    });

    test('puts days of one reason together, a month once, in date order', () {
      expect(
        excuseSentence([
          (
            date: DateTime(2026, 11, 3),
            reason: ExcuseReason.illness,
            other: '',
          ),
          (
            date: DateTime(2026, 10, 30),
            reason: ExcuseReason.illness,
            other: '',
          ),
          (
            date: DateTime(2026, 10, 31),
            reason: ExcuseReason.illness,
            other: '',
          ),
          (date: DateTime(2026, 11, 4), reason: ExcuseReason.doctor, other: ''),
        ], word: ExcuseChild.daughter),
        'Proszę o usprawiedliwienie nieobecności mojej córki w dniach 30 i 31 '
        'października i 3 listopada z powodu choroby oraz 4 z powodu wizyty '
        'u lekarza.',
      );
    });

    test('a reason in the parent\'s words goes after "z powodu"; none, and '
        'the sentence goes without it', () {
      final day = DateTime(2026, 10, 2);
      expect(
        excuseSentence([
          (date: day, reason: ExcuseReason.other, other: ' wizyty w urzędzie '),
        ], word: ExcuseChild.child),
        'Proszę o usprawiedliwienie nieobecności mojego dziecka w dniu 2 '
        'października z powodu wizyty w urzędzie.',
      );
      expect(
        excuseSentence([
          (date: day, reason: ExcuseReason.other, other: ''),
        ], word: ExcuseChild.child),
        'Proszę o usprawiedliwienie nieobecności mojego dziecka w dniu 2 '
        'października.',
      );
    });

    test('tells of days to come', () {
      expect(
        plannedSentence(
          from: DateTime(2026, 11, 3),
          to: DateTime(2026, 11, 5),
          word: ExcuseChild.daughter,
          reason: ExcuseReason.familyTrip,
        ),
        'Uprzejmie informuję, że moja córka nie będzie obecna w szkole w '
        'dniach 3–5 listopada z powodu wyjazdu rodzinnego.',
      );
      expect(
        plannedSentence(
          from: DateTime(2026, 10, 30),
          to: DateTime(2026, 11, 2),
          word: ExcuseChild.son,
          reason: ExcuseReason.sport,
        ),
        'Uprzejmie informuję, że mój syn nie będzie obecny w szkole w dniach '
        '30 października – 2 listopada z powodu udziału w zawodach '
        'sportowych.',
      );
      expect(
        plannedSentence(
          from: DateTime(2026, 11, 3),
          to: DateTime(2026, 11, 3),
          word: ExcuseChild.child,
          reason: ExcuseReason.dentist,
        ),
        'Uprzejmie informuję, że moje dziecko nie będzie obecne w szkole w '
        'dniu 3 listopada z powodu wizyty u dentysty.',
      );
    });

    test('greets, closes and signs; empty greeting or closing falls back', () {
      expect(
        excuseBody(
          sentence: 'Zdanie.',
          greeting: 'Dzień dobry Pani Anno,',
          signature: ' Rodzic Testowy ',
        ),
        'Dzień dobry Pani Anno,\nZdanie.\n\nDziękuję za zrozumienie.\n'
        'Rodzic Testowy',
      );
      expect(
        excuseBody(sentence: 'Zdanie.', greeting: ' ', closing: ''),
        'Dzień dobry,\nZdanie.\n\nDziękuję za zrozumienie.',
      );
      expect(
        excuseSubject('Uczeń Testowy'),
        'Usprawiedliwienie nieobecności – Uczeń Testowy',
      );
      expect(
        excuseSubject('Uczeń Testowy', planned: true),
        'Planowana nieobecność – Uczeń Testowy',
      );
    });

    test('suggests "Pani" with a woman\'s first name, whichever way round, '
        'and only the plain greeting for a man', () {
      for (final name in ['Anna Kowalska', 'Kowalska Anna', 'Anna Testowa']) {
        expect(excuseGreetings(name), [
          'Dzień dobry Pani Anno,',
          'Dzień dobry,',
        ], reason: name);
      }
      expect(excuseGreetings('Maja Nowak').first, 'Dzień dobry Pani Maju,');
      expect(
        excuseGreetings('Wioleta Zielińska').first,
        'Dzień dobry Pani Wioleto,',
      );
      expect(
        excuseGreetings('Maria Wiśniewska').first,
        'Dzień dobry Pani Mario,',
      );
      expect(excuseGreetings('Jan Nowak'), ['Dzień dobry,']);
      expect(excuseGreetings(''), ['Dzień dobry,']);
    });
  });

  testWidgets('from Today: the day, its reason and the child\'s word make the '
      'note; it goes to the class teacher after a confirmation, and waits', (
    tester,
  ) async {
    final (controller, world) = await _app(recipients: const [_teacher]);
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('today-excuse-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Anna Testowa'), findsWidgets);
    final day = _day(2);
    String text() => _field(tester, 'excuse-preview');
    expect(text(), startsWith('Dzień dobry Pani Anno,\n'));
    expect(text(), contains('mojego dziecka w dniu ${day.day} '));
    expect(text(), contains('z powodu złego samopoczucia.'));

    await tester.tap(
      find.byKey(ValueKey('excuse-reason-${day.month}-${day.day}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('excuse-reason-doctor')).last);
    await tester.pumpAndSettle();
    expect(text(), contains('z powodu wizyty u lekarza.'));

    await tester.tap(find.byKey(const ValueKey('excuse-word')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('excuse-word-daughter')).last);
    await tester.pumpAndSettle();
    expect(text(), contains('mojej córki'));
    expect(
      controller.activeProfile!.parentPreferences.excuseChild,
      'daughter',
      reason: 'kept for the child',
    );

    await tester.ensureVisible(find.byKey(const ValueKey('excuse-send')));
    await tester.tap(find.byKey(const ValueKey('excuse-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('excuse-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('excuse-confirm-send')));
    await tester.pumpAndSettle();
    expect(controller.snapshot.sentMessages, hasLength(1));
    expect(
      controller.snapshot.sentMessages.single.subject,
      startsWith('Usprawiedliwienie nieobecności'),
    );
    expect(find.byKey(const ValueKey('excuse-send')), findsNothing);
    expect(find.byKey(const ValueKey('today-excuse-button')), findsNothing);
    expect(find.byKey(const ValueKey('today-excuse-sent')), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);

    final again = AppController(world.repository(), updatesEnabled: false);
    await again.bootstrap();
    final history = await again.absenceRequests(controller.activeProfile!.id);
    expect(history, hasLength(1));
    expect(history.single.state, AbsenceRequestState.sent);
    expect(history.single.recipient, 'Anna Testowa');
    expect(history.single.reasons, ['doctor']);
    expect(history.single.days.single, day);
    expect(history.single.recordIds, unorderedEquals(['a1', 'a2']));
    expect(history.single.body, contains('mojej córki'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a note in the parent\'s own words goes as written', (
    tester,
  ) async {
    final (controller, _) = await _app(recipients: const [_teacher]);
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('today-excuse-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('excuse-own')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const ValueKey('excuse-send')))
          .onPressed,
      isNull,
      reason: 'nothing written yet',
    );
    await tester.enterText(
      find.byKey(const ValueKey('excuse-own-text')),
      'Dzień dobry, syn był chory. Pozdrawiam',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('excuse-send')));
    await tester.tap(find.byKey(const ValueKey('excuse-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('excuse-confirm-send')));
    await tester.pumpAndSettle();
    final history = await controller.absenceRequests(
      controller.activeProfile!.id,
    );
    expect(history.single.body, 'Dzień dobry, syn był chory. Pozdrawiam');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the history says waiting, then accepted once the school '
      'excused the days, with the class teacher\'s answer', (tester) async {
    final (controller, world) = await _app(recipients: const [_teacher]);
    final id = controller.activeProfile!.id;
    final record = controller.snapshot.attendance.first;
    await controller.sendAbsenceRequest(
      profileId: id,
      recordIds: {'a1', 'a2'},
      recipient: _teacher,
      subject: 'Usprawiedliwienie nieobecności',
      body: 'Treść',
      days: [_day(2)],
      reasons: const ['illness'],
    );
    expect(controller.excuseSentAt(record), isNotNull);
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('today-excuse-history')));
    await tester.pumpAndSettle();
    final request = (await controller.absenceRequests(id)).single;
    Text status() => tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('absence-status-${request.id}')),
        matching: find.byType(Text),
      ),
    );
    expect(status().data, 'Waiting');
    expect(find.text('Illness'), findsOneWidget);
    expect(find.byKey(ValueKey('absence-reply-${request.id}')), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    world.changes['child-parent'] = (data) => _withAbsences(
      data,
      excused: true,
      reply: SchoolMessage(
        id: 'reply-1',
        sender: 'Anna Testowa',
        subject: 'Re: Usprawiedliwienie',
        preview: 'Dziękuję, usprawiedliwione.',
        receivedAt: DateTime.now().add(const Duration(minutes: 5)),
        unread: true,
        hasAttachments: false,
      ),
    );
    await controller.sync();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-excuse-history')), findsOneWidget);
    expect(find.text('Accepted'), findsOneWidget, reason: 'on Today');
    await tester.tap(find.byKey(const ValueKey('today-excuse-history')));
    await tester.pumpAndSettle();
    expect(status().data, 'Accepted');
    expect(find.byKey(ValueKey('absence-reply-${request.id}')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('absence-reply-${request.id}')),
        matching: find.text('Dziękuję, usprawiedliwione.'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('a planned note needs no absences; one not sure until it went '
      'counts as sent, so it is not sent twice', () async {
    final (controller, _) = await _app(recipients: const [_teacher]);
    final id = controller.activeProfile!.id;
    await controller.sendAbsenceRequest(
      profileId: id,
      recordIds: const {},
      recipient: _teacher,
      subject: 'Planowana nieobecność',
      body: 'Treść',
      days: [DateTime(2026, 11, 3), DateTime(2026, 11, 4)],
      reasons: const ['familyTrip'],
      planned: true,
    );
    expect((await controller.absenceRequests(id)).single.planned, isTrue);
    await expectLater(
      controller.sendAbsenceRequest(
        profileId: id,
        recordIds: const {},
        recipient: _teacher,
        subject: 'Usprawiedliwienie',
        body: 'Treść',
      ),
      throwsArgumentError,
      reason: 'excusing days gone needs absences',
    );

    final record = controller.snapshot.attendance.first;
    await controller.recordExcuse(
      'r1',
      [record],
      subject: 'Usprawiedliwienie',
      body: 'Treść',
      recipient: 'Wychowawca Testowy',
      sent: false,
    );
    expect(controller.excuseSentAt(record), isNotNull);
    await controller.recordExcuse(
      'r1',
      [record],
      subject: 'Usprawiedliwienie',
      body: 'Treść',
      recipient: 'Wychowawca Testowy',
      sent: true,
    );
    final history = await controller.absenceRequests(id);
    expect(
      history.where((request) => request.id.endsWith('-r1')),
      hasLength(1),
      reason: 'the same note, now sent',
    );
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('excuse-teacher')),
        matching: find.textContaining('Wychowawca Testowy'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('without a class teacher among the recipients, the note opens '
      'as a message to pick one; the signature signs it', (tester) async {
    final (controller, _) = await _app();
    await controller.setExcuseSignature('Rodzic Testowy');
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('today-excuse-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('excuse-send')));
    await tester.tap(find.byKey(const ValueKey('excuse-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('excuse-confirm')), findsNothing);
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

  testWidgets('the attendance calendar marks a day whose absences went in a '
      'note and wait', (tester) async {
    final (controller, world) = await _app(recipients: const [_teacher]);
    final now = DateTime.now();
    world.changes['child-parent'] = (data) => AppSnapshot(
      profile: data.profile,
      lessons: data.lessons,
      grades: data.grades,
      events: const [],
      messages: data.messages,
      attendance: [
        AttendanceRecord(
          id: 'c1',
          date: DateTime(now.year, now.month, now.day),
          lessonNumber: 1,
          subject: 'Matematyka',
          type: 'Nieobecność',
          symbol: 'nb',
          kind: AttendanceKind.absent,
        ),
      ],
      announcements: const [],
      notices: const [],
      lastSync: data.lastSync,
    );
    await controller.sync();
    controller.selectTab(6);
    await _pump(tester, controller);
    expect(find.text('sent, waiting'), findsNothing);
    await controller.recordExcuse(
      'r1',
      [controller.snapshot.attendance.single],
      subject: 'Usprawiedliwienie',
      body: 'Treść',
      recipient: 'Anna Testowa',
      sent: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('sent, waiting'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings keep how the notes of each child read', (tester) async {
    final (controller, _) = await _app();
    controller.selectTab(9);
    await _pump(tester, controller);
    final word = find.byKey(const ValueKey('settings-excuse-child'));
    await tester.scrollUntilVisible(
      word,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(word);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: word, matching: find.text('córka')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('settings-excuse-closing')),
      'Pozdrawiam serdecznie',
    );
    await tester.pumpAndSettle();
    final preferences = controller.activeProfile!.parentPreferences;
    expect(preferences.excuseChild, 'daughter');
    expect(preferences.excuseClosing, 'Pozdrawiam serdecznie');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the Librus check reports the shape of an answer, never a value', () {
    final shape = probeShape({
      'Justifications': [
        {'Id': 7, 'Note': 'Anna Testowa', 'Accepted': true},
      ],
      'Resources': {'Url': 'https://example.invalid'},
    });
    expect(
      shape,
      '{Justifications: [1 × {Id: number, Note: text, Accepted: bool}], '
      'Resources: {Url: text}}',
    );
    expect(shape, isNot(contains('Anna')));
    expect(probeShape(null), 'null');
  });

  group('the school\'s own e-Usprawiedliwienia module', () {
    test('reads the notes Librus keeps, newest first, with the teachers', () {
      final notes = parseJustifications({
        'status': 'ok',
        'message': '',
        'data': [
          {
            'id': 11,
            'messageFromParent': 'Proszę o usprawiedliwienie.',
            'postDate': '2026-10-20 07:12:00',
            'justificationStatus': 'accepted',
            'lessons': [],
            'attachment': false,
            'dateFrom': '2026-10-15',
            'dateTo': '2026-10-15',
            'justifiedAbsences': 3,
            'notifiedTeachers': [
              {'firstName': 'Anna', 'lastName': 'Testowa'},
            ],
          },
          {
            'id': 12,
            'messageFromParent': 'Wyjazd.',
            'postDate': '2026-11-01 18:40:00',
            'justificationStatus': 'Oczekuje',
            'lessons': [
              {'id': 1},
            ],
            'dateFrom': '2026-11-03',
            'dateTo': '2026-11-05',
            'justifiedAbsences': '0',
            'notifiedTeachers': [
              {'name': 'Nauczyciel Testowy'},
              {'id': 5},
            ],
          },
          {'messageFromParent': 'bez id'},
          'nie mapa',
        ],
      });
      expect(notes.map((note) => note.id), ['12', '11']);
      final [later, earlier] = notes;
      expect(later.state, JustificationState.pending);
      expect(later.from, DateTime(2026, 11, 3));
      expect(later.to, DateTime(2026, 11, 5));
      expect(later.lessons, 1);
      expect(later.teachers, ['Nauczyciel Testowy', '']);
      expect(earlier.state, JustificationState.accepted);
      expect(earlier.justified, 3);
      expect(earlier.teachers, ['Anna Testowa']);
      expect(earlier.postedAt, DateTime(2026, 10, 20, 7, 12));
      expect(parseJustifications(null), isEmpty);
      expect(parseJustifications({'data': 'nic'}), isEmpty);
    });

    test('knows the status words in English and Polish; others stay as '
        'they are', () {
      for (final (word, state) in [
        ('accepted', JustificationState.accepted),
        ('Zaakceptowane', JustificationState.accepted),
        ('rejected', JustificationState.rejected),
        ('Odrzucone', JustificationState.rejected),
        ('pending', JustificationState.pending),
        ('Oczekuje', JustificationState.pending),
        ('', JustificationState.unknown),
        ('cośinnego', JustificationState.unknown),
      ]) {
        expect(justificationState(word), state, reason: word);
      }
    });

    test('the check shows status codes and the shape of dates, never a '
        'long text or a date itself; an error answer says its messages', () {
      expect(
        probeWords(['accepted', 'pending', 'accepted', null]),
        'accepted | pending | null',
      );
      expect(
        probeWords(['Proszę o usprawiedliwienie nieobecności syna']),
        '<String 44>',
      );
      expect(probeMask('2026-10-20 07:12:00'), 'dddd-dd-dd dd:dd:dd');
      expect(probeMask(7), isNull);
      expect(
        probeMessages({
          'status': 'error',
          'message': 'Validation failed',
          'errors': [
            {'field': 'dateFrom', 'message': 'required'},
          ],
        }),
        [
          'status: error',
          'message: Validation failed',
          'field: dateFrom',
          'message: required',
        ],
      );
      expect(probeMessages('Bad Request'), ['Bad Request']);
    });

    testWidgets('the history shows the notes Librus keeps, with the school\'s '
        'answer', (tester) async {
      final (controller, world) = await _app(recipients: const [_teacher]);
      world.justifications = [
        SchoolJustification(
          id: 'j1',
          message: 'Proszę o usprawiedliwienie.',
          status: 'rejected',
          postedAt: DateTime(2026, 10, 20, 7, 12),
          from: DateTime(2026, 10, 15),
          to: DateTime(2026, 10, 16),
          justified: 0,
          teachers: const ['Anna Testowa'],
        ),
        const SchoolJustification(id: 'j2', message: '', status: 'nowyKod'),
      ];
      await controller.sendAbsenceRequest(
        profileId: controller.activeProfile!.id,
        recordIds: {'a1', 'a2'},
        recipient: _teacher,
        subject: 'Usprawiedliwienie nieobecności',
        body: 'Treść',
        days: [_day(2)],
        reasons: const ['illness'],
      );
      await _pump(tester, controller);
      await tester.tap(find.byKey(const ValueKey('today-excuse-history')));
      await tester.pumpAndSettle();
      expect(find.text('In Librus'), findsOneWidget);
      Text status(String id) => tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('absence-diary-status-$id')),
          matching: find.byType(Text),
        ),
      );
      expect(status('j1').data, 'Rejected');
      expect(status('j2').data, 'nowyKod');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('absence-diary-j1')),
          matching: find.textContaining('Anna Testowa'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
