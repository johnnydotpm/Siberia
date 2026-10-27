import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_items.dart';

import 'support/profile_fakes.dart';

/// One profile of the family login, synced when [syncedAt] says, with
/// what [change] makes of its data; the app on it, in English.
Future<(AppController, FakeLibrusWorld)> _app({
  AppSnapshot Function(AppSnapshot data)? change,
  DateTime Function()? syncedAt,
}) async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  final world = FakeLibrusWorld()..syncedAt = syncedAt ?? DateTime.now;
  if (change != null) world.changes['kid-regular'] = change;
  final repository = world.repository();
  final found = await repository.signIn(username: familyEmail, password: 'x');
  final added = await repository.addProfiles([found.students.first]);
  await repository.syncProfile(added.single.id);
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  return (controller, world);
}

SchoolMessage _message(String id, String subject, DateTime receivedAt) =>
    SchoolMessage(
      id: id,
      sender: 'Nauczyciel Testowy',
      subject: subject,
      preview: 'Treść',
      receivedAt: receivedAt,
    );

Future<void> _pump(WidgetTester tester, AppController controller) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('numbers and time', () {
    testWidgets('an opened message says its day in words and keeps its '
        'short date', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 0, 5);
      // By the calendar: 20 × 24 hours may cross a change of the clocks.
      final old = DateTime(now.year, now.month, now.day - 20, 0, 5);
      final (controller, _) = await _app(
        change: (data) => data.copyWith(
          messages: [
            _message('m1', 'Plan dnia', today),
            _message('m2', 'Stara wiadomość', old),
          ],
        ),
      );
      controller.selectTab(5);
      await _pump(tester, controller);

      await tester.tap(find.text('Plan dnia'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('message-stamp'))).data,
        'Today, ${DateFormat('dd.MM').format(today)}, 00:05',
      );
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      // Older than a week: no day in words, the year only for another year.
      await tester.tap(find.text('Stara wiadomość'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('message-stamp'))).data,
        '${DateFormat(old.year == now.year ? 'dd.MM' : 'dd.MM.yyyy').format(old)}, 00:05',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a month of this year is headed without its year', (
      tester,
    ) async {
      final now = DateTime.now();
      // The 1st of the month before last: this year from March on.
      final month = DateTime(now.year, now.month - 2, 1, 9);
      final (controller, _) = await _app(
        change: (data) =>
            data.copyWith(messages: [_message('m1', 'Dawno', month)]),
      );
      controller.selectTab(5);
      await _pump(tester, controller);
      final name = DateFormat.LLLL('en').format(month);
      final withYear = DateFormat.yMMMM('en').format(month);
      if (month.year == now.year) {
        expect(find.text(name), findsOneWidget);
        expect(find.text(withYear), findsNothing);
      } else {
        expect(find.text(withYear), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('"synced just now" in the settings turns into minutes on its '
        'own', (tester) async {
      final syncedAt = DateTime.now().subtract(const Duration(seconds: 57));
      final (controller, _) = await _app(syncedAt: () => syncedAt);
      controller.selectTab(9);
      await _pump(tester, controller);
      Text line() =>
          tester.widget(find.byKey(const ValueKey('settings-synced-ago')));
      expect(line().data, 'Synced just now');
      // Real time passes the minute; the clock's next tick redraws it.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await tester.pump(const Duration(minutes: 1));
      expect(line().data, 'Synced 1 min ago');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('a badge past 99 says "99+"', () {
      expect(badgeText(7), '7');
      expect(badgeText(99), '99');
      expect(badgeText(120), '99+');
    });

    testWidgets('averages of the subjects form an even column', (tester) async {
      final (controller, _) = await _app(
        change: (data) => AppSnapshot(
          profile: data.profile,
          lessons: const [],
          grades: [
            for (final (id, subject, value) in [
              ('g1', 'Fizyka', '4'),
              ('g2', 'Fizyka', '5'),
              ('g3', 'Chemia', '3'),
              ('g4', 'Chemia', '4'),
              ('g5', 'Chemia', '4'),
            ])
              Grade(
                id: id,
                subject: subject,
                value: value,
                description: '',
                date: DateTime.now().subtract(const Duration(days: 30)),
                weight: 1,
                semester: DateTime.now().month >= 2 && DateTime.now().month <= 8
                    ? 2
                    : 1,
              ),
          ],
          events: const [],
          messages: const [],
          attendance: const [],
          announcements: const [],
          notices: const [],
          lastSync: data.lastSync,
        ),
      );
      controller.selectTab(2);
      await _pump(tester, controller);
      final pills = find.byKey(const ValueKey('average-pill'));
      // "4,5" and "3,67" in two rows, the overview's large one apart.
      final widths = {
        for (final element in pills.evaluate())
          if ((element.renderObject! as RenderBox).size case final size
              when size.height < 40)
            size.width,
      };
      expect(widths, hasLength(1), reason: 'one width for both: $widths');
      final style = tester
          .widget<Text>(
            find.descendant(of: pills.last, matching: find.byType(Text)),
          )
          .style!;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
