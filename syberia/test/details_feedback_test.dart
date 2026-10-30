import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/domain/together.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/linked_text.dart';
import 'package:syberia/src/ui/profile_avatar.dart';

import 'support/profile_fakes.dart';

/// What the app hands the phone: the kinds of haptic feedback, in turn, and
/// the text it puts on the clipboard.
class _Phone {
  final haptics = <String>[];
  String? clipboard;
}

_Phone _phone(WidgetTester tester) {
  final phone = _Phone();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'HapticFeedback.vibrate':
          phone.haptics.add('${call.arguments}');
        case 'Clipboard.setData':
          phone.clipboard = (call.arguments as Map)['text'] as String?;
        case 'Clipboard.getData':
          return {'text': phone.clipboard};
        case 'Clipboard.hasStrings':
          return {'value': phone.clipboard != null};
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
  return phone;
}

/// The family login's profiles (both when [both]), the regular school open,
/// synced just now with what [changes] makes of each login's data; the app
/// in English in its classic look.
Future<(AppController, FakeLibrusWorld, SchoolProfile, SchoolProfile)> _family({
  Map<String, AppSnapshot Function(AppSnapshot)> changes = const {},
  bool both = true,
  bool together = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  world.changes.addAll(changes);
  final repository = world.repository();
  final found = await repository.signIn(username: familyEmail, password: 'x');
  final added = await repository.addProfiles(
    both ? found.students : [found.students.first],
  );
  for (final profile in added) {
    await repository.syncProfile(profile.id);
  }
  await repository.switchProfile(added[0].id);
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  if (together) await controller.openTogether();
  return (controller, world, added[0], added.length > 1 ? added[1] : added[0]);
}

Future<void> _pump(WidgetTester tester, AppController controller) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
}

SchoolMessage _message(String id, String subject, {bool unread = false}) =>
    SchoolMessage(
      id: id,
      sender: 'Nauczyciel Testowy',
      subject: subject,
      preview: 'Treść',
      receivedAt: DateTime.now().subtract(const Duration(hours: 1)),
      unread: unread,
    );

const _hapticSelection = 'HapticFeedbackType.selectionClick';

Future<void> _openCompose(WidgetTester tester) async {
  await tester.tap(find.text('New message').first);
  await tester.pumpAndSettle();
}

Future<void> _pickTeacher(WidgetTester tester, String name) async {
  await tester.enterText(find.widgetWithText(TextField, 'Recipient'), 'Naucz');
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

/// Presses long on [text], as a finger selects a word.
Future<void> _longPressOn(WidgetTester tester, String text) async {
  final range = find.textRange.ofSubstring(text).evaluate().single;
  final boxes = range.renderObject.getBoxesForSelection(
    TextSelection(
      baseOffset: range.textRange.start,
      extentOffset: range.textRange.end,
    ),
  );
  await tester.longPressAt(
    range.renderObject.localToGlobal(boxes.first.toRect().center),
  );
  await tester.pumpAndSettle();
}

SchoolProfile _profile(String id, String name, String school) => SchoolProfile(
  id: id,
  account: 'a',
  synergiaLogin: id,
  name: name,
  school: school,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('haptics', () {
    testWidgets('the classic bottom bar clicks, as the glass one does', (
      tester,
    ) async {
      final (controller, _, _, _) = await _family(both: false);
      await _pump(tester, controller);
      final phone = _phone(tester);
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      expect(phone.haptics, [_hapticSelection]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a message swiped read is felt, as homework done is', (
      tester,
    ) async {
      final (controller, _, _, _) = await _family(
        both: false,
        changes: {
          'kid-regular': (data) => data.copyWith(
            messages: [_message('m1', 'Wycieczka', unread: true)],
          ),
        },
      );
      controller.selectTab(5);
      await _pump(tester, controller);
      final phone = _phone(tester);
      await tester.drag(
        find.byKey(const ValueKey('message-m1')),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();
      expect(phone.haptics, contains('HapticFeedbackType.lightImpact'));
      expect(controller.snapshot.messages.single.unread, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('picking a profile, or all of them together, clicks', (
      tester,
    ) async {
      final (controller, _, _, music) = await _family();
      await _pump(tester, controller);
      final phone = _phone(tester);
      await tester.tap(find.byKey(const ValueKey('profile-button')));
      await tester.pumpAndSettle();
      phone.haptics.clear();
      await tester.tap(find.byKey(ValueKey('profile-${music.id}')));
      await tester.pumpAndSettle();
      expect(phone.haptics, [_hapticSelection]);
      expect(controller.activeProfile?.id, music.id);

      await tester.tap(find.byKey(const ValueKey('profile-button')));
      await tester.pumpAndSettle();
      phone.haptics.clear();
      await tester.tap(find.byKey(const ValueKey('profiles-together')));
      await tester.pumpAndSettle();
      expect(phone.haptics, [_hapticSelection]);
      expect(controller.together, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a message sent is felt, and leaves no draft behind', (
      tester,
    ) async {
      final (controller, _, _, _) = await _family(both: false);
      controller.selectTab(5);
      await _pump(tester, controller);
      final phone = _phone(tester);
      await _openCompose(tester);
      await _pickTeacher(tester, 'Nauczyciel kid-regular');
      await tester.enterText(
        find.byKey(const ValueKey('compose-subject')),
        'Próba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('compose-body')),
        'Treść',
      );
      phone.haptics.clear();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(phone.haptics, ['HapticFeedbackType.mediumImpact']);
      expect(controller.snapshot.sentMessages, hasLength(1));
      expect(find.byKey(const ValueKey('draft-saved')), findsNothing);

      await _openCompose(tester);
      expect(_field(tester, 'compose-subject'), isEmpty);
      expect(find.byType(InputChip), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('the classic top bar shows one sign of a sync: its button '
      'turns into the spinner', (tester) async {
    final (controller, world, _, _) = await _family(both: false);
    await _pump(tester, controller);
    final button = find.byKey(const ValueKey('sync-button'));
    final spinners = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(CircularProgressIndicator),
    );
    expect(spinners, findsNothing);

    final hold = world.holds['kid-regular'] = Completer<void>();
    unawaited(controller.sync());
    await tester.pump();
    expect(spinners, findsOneWidget);
    expect(
      find.descendant(
        of: button,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(button).onPressed, isNull);

    hold.complete();
    await tester.pumpAndSettle();
    expect(spinners, findsNothing);
    expect(
      find.descendant(of: button, matching: find.byIcon(Icons.sync_rounded)),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('a new message', () {
    testWidgets('the subject counts only near its limit, and its next key '
        'goes on to the message', (tester) async {
      final (controller, _, _, _) = await _family(both: false);
      controller.selectTab(5);
      await _pump(tester, controller);
      await _openCompose(tester);
      final subject = find.byKey(const ValueKey('compose-subject'));
      expect(find.text('0/100'), findsNothing);
      await tester.enterText(subject, 'a' * 79);
      await tester.pump();
      expect(find.text('79/100'), findsNothing);
      await tester.enterText(subject, 'a' * 80);
      await tester.pump();
      expect(find.text('80/100'), findsOneWidget);

      expect(
        tester.widget<TextField>(subject).textInputAction,
        TextInputAction.next,
      );
      await tester.showKeyboard(subject);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      final body = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('compose-body')),
          matching: find.byType(EditableText),
        ),
      );
      expect(body.focusNode.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('closed unsent, by its button or a swipe down, it comes back '
        'as it was left, until thrown away', (tester) async {
      final (controller, _, _, _) = await _family(both: false);
      controller.selectTab(5);
      await _pump(tester, controller);
      await _openCompose(tester);
      await _pickTeacher(tester, 'Nauczyciel kid-regular');
      await tester.enterText(
        find.byKey(const ValueKey('compose-subject')),
        'Wycieczka',
      );
      await tester.enterText(
        find.byKey(const ValueKey('compose-body')),
        'Dzień dobry',
      );
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('draft-saved')), findsOneWidget);
      expect(find.text('Draft saved'), findsOneWidget);

      Future<void> expectKept() async {
        await _openCompose(tester);
        expect(_field(tester, 'compose-subject'), 'Wycieczka');
        expect(_field(tester, 'compose-body'), 'Dzień dobry');
        expect(
          find.widgetWithText(InputChip, 'Nauczyciel kid-regular'),
          findsOneWidget,
        );
      }

      await expectKept();
      // A swipe down closes the sheet past any question; the text stays.
      await tester.drag(find.text('New message').last, const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('compose-subject')), findsNothing);
      await expectKept();

      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      // Closed three times in a row, it is told of once: the word that
      // still shows throws away the draft kept now.
      expect(find.text('Draft saved'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Draft saved'), findsNothing, reason: 'none queued');
      await _openCompose(tester);
      expect(_field(tester, 'compose-subject'), isEmpty);
      expect(_field(tester, 'compose-body'), isEmpty);
      expect(find.byType(InputChip), findsNothing);

      // Nothing written, nothing kept.
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Draft saved'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a draft stays with the profile it was written in', (
      tester,
    ) async {
      final (controller, _, regular, music) = await _family();
      controller.selectTab(5);
      await _pump(tester, controller);
      await _openCompose(tester);
      await tester.enterText(
        find.byKey(const ValueKey('compose-subject')),
        'Wycieczka',
      );
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      await controller.switchProfile(music.id);
      await tester.pumpAndSettle();
      await _openCompose(tester);
      expect(_field(tester, 'compose-subject'), isEmpty);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      await controller.switchProfile(regular.id);
      await tester.pumpAndSettle();
      await _openCompose(tester);
      expect(_field(tester, 'compose-subject'), 'Wycieczka');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('links', () {
    Future<(AppController, List<Uri>, void Function(bool))> openMessage(
      WidgetTester tester,
    ) async {
      final original = LinkedText.open;
      addTearDown(() => LinkedText.open = original);
      final opened = <Uri>[];
      var answer = true;
      LinkedText.open = (link) async {
        opened.add(link);
        return answer;
      };
      final (controller, world, _, _) = await _family(
        both: false,
        changes: {
          'kid-regular': (data) =>
              data.copyWith(messages: [_message('m1', 'Plan lekcji')]),
        },
      );
      world.messageBody =
          'plan zajęć: www.example.pl/plan, pytania: sekretariat@example.pl';
      controller.selectTab(5);
      await _pump(tester, controller);
      await tester.tap(find.text('Plan lekcji'));
      await tester.pumpAndSettle();
      return (controller, opened, (bool value) => answer = value);
    }

    testWidgets('text selected in a link offers to open it or copy it; a '
        'word of the rest does not, even one the link holds too', (
      tester,
    ) async {
      final phone = _phone(tester);
      final (_, opened, _) = await openMessage(tester);

      await _longPressOn(tester, 'zajęć');
      expect(find.text('Copy'), findsOneWidget, reason: 'the menu is open');
      expect(find.text('Open link'), findsNothing);
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      // "plan" is a word of the text and the end of the link.
      await _longPressOn(tester, 'plan zaj');
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Copy link'), findsNothing);
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      await _longPressOn(tester, 'sekretariat');
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(phone.clipboard, 'sekretariat@example.pl');
      expect(find.text('Copy link'), findsNothing, reason: 'the menu closed');
      expect(opened, isEmpty);

      await _longPressOn(tester, 'example.pl/plan');
      await tester.tap(find.text('Open link'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://www.example.pl/plan')]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a link that opens takes back the word on one that did not', (
      tester,
    ) async {
      final (_, opened, answer) = await openMessage(tester);
      answer(false);
      await tester.tapOnText(find.textRange.ofSubstring('sekretariat'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('link-open-failed')), findsOneWidget);

      answer(true);
      await tester.tapOnText(find.textRange.ofSubstring('www.example.pl'));
      await tester.pumpAndSettle();
      expect(opened, hasLength(2));
      expect(find.byKey(const ValueKey('link-open-failed')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('one child at two schools, all together', () {
    final regular = _profile(
      'p1',
      'Uczeń Testowy',
      'Szkoła Podstawowa nr 12 im. Testową',
    );
    final music = _profile('p2', 'Uczeń Testowy', 'Szkoła Muzyczna I stopnia');
    final other = _profile('p3', 'Inny Uczeń', 'Szkoła Podstawowa nr 12');

    test('each goes by what tells its school from the other', () {
      final both = [regular, music, other];
      expect(togetherName(regular, both), 'Podstawowa nr 12 im. Testową');
      expect(togetherName(music, both), 'Muzyczna I stopnia');
      expect(togetherName(other, both), 'Inny Uczeń', reason: 'its own name');

      // Marks between the shared words and the rest go; the rest begins
      // with a capital.
      final lyceum = _profile('a', 'Uczeń', 'Zespół Szkół nr 1 · liceum');
      final college = _profile('b', 'Uczeń', 'Zespół Szkół nr 1 – Technikum');
      expect(togetherName(lyceum, [lyceum, college]), 'Liceum');
      expect(togetherName(college, [lyceum, college]), 'Technikum');

      // Nothing to tell them apart by: the whole school.
      final same = _profile('c', 'Uczeń', 'Szkoła Podstawowa nr 12');
      final longer = _profile('d', 'Uczeń', 'Szkoła Podstawowa nr 12 filia');
      expect(togetherName(same, [same, longer]), 'Szkoła Podstawowa nr 12');
      expect(togetherName(longer, [same, longer]), 'Filia');
    });

    test('their signs are the initials of their schools, not two of the '
        'same', () {
      final both = [regular, music, other];
      expect(profileInitials(togetherSign(regular, both)), 'SP');
      expect(profileInitials(togetherSign(music, both)), 'SM');
      expect(togetherSign(other, both), 'Inny Uczeń');
    });

    testWidgets('the bar shows the schools\' initials', (tester) async {
      final (controller, _, regular, music) = await _family(together: true);
      await _pump(tester, controller);
      Finder sign(String initials) => find.descendant(
        of: find.byKey(const ValueKey('profile-button')),
        matching: find.text(initials),
      );
      expect(sign('SP'), findsOneWidget);
      expect(sign('SM'), findsOneWidget);
      Finder inside(String key, String initials) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.text(initials),
      );
      expect(inside('summary-profile-${regular.id}', 'SP'), findsOneWidget);
      expect(inside('summary-profile-${music.id}', 'SM'), findsOneWidget);

      controller.selectTab(5);
      await tester.pumpAndSettle();
      await _openCompose(tester);
      expect(inside('compose-from-${regular.id}', 'SP'), findsOneWidget);
      expect(inside('compose-from-${music.id}', 'SM'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
