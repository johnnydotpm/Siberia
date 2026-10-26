import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/linked_text.dart';

import 'support/profile_fakes.dart';

/// The links of [text], as their text and where they lead.
List<(String, String)> _links(String text) => [
  for (final part in linkParts(text))
    if (part.link case final link?) (part.text, '$link'),
];

void main() {
  group('links in a text', () {
    test('a web address opens as written, in the middle of a sentence or at '
        'its end', () {
      expect(_links('Plan na https://example.pl/plan?a=1&b=2 jest gotowy.'), [
        ('https://example.pl/plan?a=1&b=2', 'https://example.pl/plan?a=1&b=2'),
      ]);
      expect(_links('Zobacz http://example.pl/a.'), [
        ('http://example.pl/a', 'http://example.pl/a'),
      ]);
      expect(_links('Czy byliście na https://example.pl/zajęcia?'), [
        ('https://example.pl/zajęcia', 'https://example.pl/zaj%C4%99cia'),
      ]);
    });

    test('"www." opens over https, and an e-mail address in the mail app', () {
      expect(
        _links(
          'Strona: www.example.pl, a pytania na adres '
          'sekretariat@example.pl.',
        ),
        [
          ('www.example.pl', 'https://www.example.pl'),
          ('sekretariat@example.pl', 'mailto:sekretariat@example.pl'),
        ],
      );
    });

    test('a bracket closing around an address is not part of it, one it '
        'opens itself is', () {
      expect(_links('(zob. https://example.pl/a)'), [
        ('https://example.pl/a', 'https://example.pl/a'),
      ]);
      expect(_links('plan (https://example.pl/a?x=1&y=2) i więcej'), [
        ('https://example.pl/a?x=1&y=2', 'https://example.pl/a?x=1&y=2'),
      ]);
      expect(_links('https://pl.example.org/wiki/Plan_(szkoła)'), [
        (
          'https://pl.example.org/wiki/Plan_(szkoła)',
          'https://pl.example.org/wiki/Plan_(szko%C5%82a)',
        ),
      ]);
    });

    test('the text around the links stays whole, and a text without links '
        'is one plain part', () {
      const text = 'Dzień dobry, (zob. https://example.pl/a). Dziękuję';
      expect(linkParts(text).map((part) => part.text).join(), text);
      expect(linkParts('Jutro sprawdzian o 8:00.'), [
        (text: 'Jutro sprawdzian o 8:00.', link: null),
      ]);
      // Cut of their full stops, these are no addresses.
      expect(_links('Wpisz „www.” albo „http://.”, nie więcej.'), isEmpty);
    });
  });

  group('the text of a message', () {
    testWidgets('a tap on a link opens it, a tap on the rest does not, and '
        'a link that cannot open says so', (tester) async {
      final original = LinkedText.open;
      addTearDown(() => LinkedText.open = original);
      final opened = <Uri>[];
      var answer = true;
      LinkedText.open = (link) async {
        opened.add(link);
        return answer;
      };
      var failures = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkedText(
              'Plan na www.example.pl jest gotowy.',
              onOpenFailed: () => failures++,
            ),
          ),
        ),
      );
      expect(find.byType(SelectionArea), findsOneWidget);
      await tester.tapOnText(find.textRange.ofSubstring('gotowy'));
      await tester.pump();
      expect(opened, isEmpty);

      await tester.tapOnText(find.textRange.ofSubstring('www.example.pl'));
      await tester.pump();
      expect(opened, [Uri.parse('https://www.example.pl')]);
      expect(failures, 0);

      answer = false;
      await tester.tapOnText(find.textRange.ofSubstring('www.example.pl'));
      await tester.pump();
      expect(failures, 1);
    });

    testWidgets('an opened message\'s links open with a tap; one that cannot '
        'says so in the sheet', (tester) async {
      final original = LinkedText.open;
      addTearDown(() => LinkedText.open = original);
      final opened = <Uri>[];
      var answer = true;
      LinkedText.open = (link) async {
        opened.add(link);
        return answer;
      };
      SharedPreferences.setMockInitialValues({
        'auto_sync_on_open_v1': false,
        'app_design_v1': 'classic',
        'app_locale_v1': 'en',
      });
      final world = FakeLibrusWorld()
        ..syncedAt = DateTime.now
        ..messageBody =
            'Plan: plan (https://example.pl/a?x=1&y=2), pytania: '
            'sekretariat@example.pl'
        ..changes['kid-regular'] = (data) => data.copyWith(
          messages: [
            SchoolMessage(
              id: 'm1',
              sender: 'Nauczyciel Testowy',
              subject: 'Plan lekcji',
              preview: 'Plan',
              receivedAt: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ],
        );
      final repository = world.repository();
      final found = await repository.signIn(
        username: familyEmail,
        password: 'x',
      );
      final added = await repository.addProfiles([found.students.first]);
      await repository.syncProfile(added.single.id);
      final controller = AppController(repository, updatesEnabled: false);
      await controller.bootstrap();
      controller.selectTab(5);
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan lekcji'));
      await tester.pumpAndSettle();

      await tester.tapOnText(
        find.textRange.ofSubstring('https://example.pl/a?x=1&y=2'),
      );
      await tester.pump();
      expect(opened, [Uri.parse('https://example.pl/a?x=1&y=2')]);
      expect(find.byKey(const ValueKey('link-open-failed')), findsNothing);

      answer = false;
      await tester.tapOnText(
        find.textRange.ofSubstring('sekretariat@example.pl'),
      );
      await tester.pumpAndSettle();
      expect(opened.last, Uri.parse('mailto:sekretariat@example.pl'));
      expect(find.text('Couldn\'t open the link'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
