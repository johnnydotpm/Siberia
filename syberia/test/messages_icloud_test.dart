import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_material.dart';
import 'package:syberia/src/ui/glass/glass_plate.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';
import 'package:syberia/src/ui/glass/glass_shell.dart';

/// Messages as Mail shows them: the folder as the title with its menu, a
/// status line with the filter, a dot while unread, and a message on a page
/// of its own.

class _Repository extends AppRepository {
  _Repository(this.data);
  AppSnapshot data;
  final deleted = <String>[];

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];

  @override
  Future<List<SchoolMessage>> fetchSentMessages({String? profileId}) async =>
      data.sentMessages;

  @override
  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage message, {
    String? profileId,
  }) async => SchoolMessageContent(
    id: message.id,
    sender: message.sender,
    subject: message.subject,
    body: 'Body of ${message.subject}',
    receivedAt: message.receivedAt,
    attachments: const [MessageAttachment(id: 'a', name: 'plan.pdf')],
  );

  @override
  Future<void> deleteMessage(SchoolMessage message, {String? profileId}) async {
    deleted.add(message.id);
  }
}

SchoolMessage _message(String id, {bool unread = false, int daysAgo = 0}) =>
    SchoolMessage(
      id: id,
      sender: 'Teacher $id',
      subject: 'Subject $id',
      preview: 'Preview of $id',
      receivedAt: DateTime.now().subtract(Duration(days: daysAgo, minutes: 5)),
      unread: unread,
    );

AppSnapshot _snapshot({int count = 3}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Test',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: const [],
  grades: const [],
  events: const [],
  messages: [
    for (var index = 0; index < count; index++)
      _message('m$index', unread: index < 2, daysAgo: index),
  ],
  sentMessages: [
    SchoolMessage(
      id: 's1',
      sender: 'Me',
      subject: 'Sent subject',
      preview: 'Sent preview',
      receivedAt: DateTime.now().subtract(const Duration(hours: 1)),
      sent: true,
      recipients: const ['Teacher m0'],
      recipientRead: true,
    ),
  ],
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: DateTime.now(),
);

Future<(AppController, _Repository)> _open(
  WidgetTester tester, {
  String design = 'classic',
  int count = 3,
}) async {
  SharedPreferences.setMockInitialValues({'app_design_v1': design});
  final repository = _Repository(_snapshot(count: count));
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  controller.selectTab(5);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return (controller, repository);
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => GlassPlatform.debugSetBackend(GlassBackend.none));

  testWidgets('the title is the folder, and its menu changes it', (
    tester,
  ) async {
    await _open(tester);
    Finder title(String text) =>
        find.descendant(of: _key('messages-folder'), matching: find.text(text));
    expect(title('Inbox'), findsOneWidget);
    await tester.tap(_key('messages-folder'));
    await tester.pumpAndSettle();
    // The folder open is the one checked.
    expect(
      tester.widget<CheckedPopupMenuItem<Object>>(
        _key('messages-folder-inbox'),
      ),
      isA<CheckedPopupMenuItem<Object>>().having(
        (item) => item.checked,
        'checked',
        isTrue,
      ),
    );
    await tester.tap(_key('messages-folder-sent'));
    await tester.pumpAndSettle();
    expect(title('Sent'), findsOneWidget);
    expect(find.text('Sent subject'), findsOneWidget);
    // A sent message says whether it was read.
    expect(_key('sent-read-s1'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the status line counts the unread, and the filter narrows to '
      'them', (tester) async {
    await _open(tester);
    Finder status(String text) =>
        find.descendant(of: _key('messages-status'), matching: find.text(text));
    expect(status('2 unread'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('messages-status'),
        matching: find.textContaining('updated '),
      ),
      findsOneWidget,
    );
    expect(find.text('Subject m2'), findsOneWidget);
    await tester.tap(_key('messages-filter'));
    await tester.pumpAndSettle();
    expect(status('Filter: unread'), findsOneWidget);
    expect(find.text('Subject m2'), findsNothing);
    expect(find.text('Subject m0'), findsOneWidget);
  });

  testWidgets('unread rows have a dot; picking puts a check in its place '
      'and keeps the dot beside the sender', (tester) async {
    await _open(tester);
    expect(_key('message-unread-m0'), findsOneWidget);
    expect(_key('message-unread-m2'), findsNothing);
    final dot = tester.getRect(_key('message-unread-m0'));
    final sender = tester.getRect(find.text('Teacher m0'));
    // Level with the sender's line, before it.
    expect(dot.center.dy, closeTo(sender.center.dy, 2));
    expect(dot.right, lessThan(sender.left));

    await tester.tap(_key('message-select-m0'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(_key('message-unread-m0'), findsOneWidget);
    expect(_key('messages-select'), findsNothing);
  });

  testWidgets('a message opens on a page of its own; back returns to the '
      'list where it was', (tester) async {
    final (controller, _) = await _open(tester, count: 14);
    final list = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
    final scrolled = tester.state<ScrollableState>(list).position.pixels;
    expect(scrolled, greaterThan(0));
    final row = find.textContaining('Subject m').hitTestable().first;
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const ValueKey('message-body')), findsOneWidget);
    expect(find.text('plan.pdf'), findsOneWidget);
    // The way back says where it leads.
    expect(find.text('Inbox'), findsOneWidget);
    await tester.tap(_key('message-page-back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-body')), findsNothing);
    expect(tester.state<ScrollableState>(list).position.pixels, scrolled);
    controller.dispose();
  });

  testWidgets('a message can be deleted from its page, after asking', (
    tester,
  ) async {
    final (controller, repository) = await _open(tester);
    await tester.tap(find.text('Subject m1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('message-page-delete'));
    await tester.pumpAndSettle();
    await tester.tap(_key('messages-confirm-delete'));
    await tester.pumpAndSettle();
    expect(repository.deleted, ['m1']);
    expect(find.byKey(const ValueKey('message-body')), findsNothing);
    expect(find.text('Subject m1'), findsNothing);
    expect(controller.snapshot.messages.map((item) => item.id), ['m0', 'm2']);
  });

  testWidgets('Expressive writes from a floating button that gives way to '
      'picking', (tester) async {
    await _open(tester, design: 'expressive');
    expect(
      tester.widget(_key('messages-compose')),
      isA<FloatingActionButton>(),
    );
    await tester.tap(_key('messages-select'));
    await tester.pumpAndSettle();
    expect(_key('messages-compose'), findsNothing);
  });

  testWidgets('in glass on iOS 26 the message page has UIKit\'s bars', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final created = <String>[];
    GlassPlatform.debugSetBackend(GlassBackend.uikit);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        created.add((call.arguments as Map)['viewType'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    await _open(tester, design: 'glass');
    created.clear();
    await tester.tap(find.text('Subject m0'));
    await tester.pumpAndSettle();
    // Its own top bar with the way back, and the toolbar with deleting and
    // writing.
    expect(created, contains('siberia/glass_bar_buttons'));
    expect(created, contains('siberia/glass_toolbar'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('where Flutter draws the glass, the page\'s toolbar shows '
      'symbols and its back button returns', (tester) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    await _open(tester, design: 'glass');
    // As in Gmail: the sender's picture at the page's margin and the dot
    // after the date; then, as in Mail, the way in at the end and the
    // subject on one line.
    final avatar = find.descendant(
      of: _key('message-tile-m0'),
      matching: find.text('TM'),
    );
    expect(avatar, findsOneWidget);
    final sender = tester.getRect(find.text('Teacher m0'));
    final picture = tester.getRect(
      find.descendant(
        of: _key('message-select-m0'),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(picture.left, closeTo(16, 0.5));
    expect(picture.width, 44);
    expect(picture.right, lessThan(sender.left));
    final dot = tester.getRect(_key('message-unread-m0'));
    final date = tester.getRect(
      find.descendant(
        of: _key('message-tile-m0'),
        matching: find.textContaining(':'),
      ),
    );
    final chevron = tester.getRect(_key('message-open-m0'));
    expect(dot.left, greaterThan(date.right));
    expect(chevron.left, greaterThan(dot.right));
    expect(dot.center.dy, closeTo(date.center.dy, 1.5));
    expect(_key('message-unread-m2'), findsNothing);
    expect(_key('message-open-m2'), findsOneWidget);
    final subject = find.text('Subject m0');
    expect(
      tester.widget<Text>(subject),
      isA<Text>().having((text) => text.maxLines, 'maxLines', 1),
    );
    // The picture stands in the middle of the row, and every row is as tall.
    final row = tester.getRect(_key('message-tile-m0'));
    expect(picture.center.dy, closeTo(row.center.dy, 1));
    expect(row.height, greaterThanOrEqualTo(72));
    expect(tester.getSize(_key('message-tile-m1')).height, row.height);
    // Picking turns the picture into the check, in its place.
    await tester.tap(_key('message-select-m0'));
    await tester.pumpAndSettle();
    expect(avatar, findsNothing);
    expect(
      tester
          .getRect(
            find.descendant(
              of: _key('message-select-m0'),
              matching: find.byIcon(Icons.check_rounded),
            ),
          )
          .center,
      offsetMoreOrLessEquals(picture.center, epsilon: 0.5),
    );
    // The page's title asks to pick and fits its line whole.
    await tester.tap(_key('message-select-m0'));
    await tester.pumpAndSettle();
    final ask = find.text('Select messages');
    expect(ask, findsWidgets);
    expect(
      tester.renderObject<RenderParagraph>(ask.first).didExceedMaxLines,
      isFalse,
    );
    await tester.tap(_key('glass-bar-button-selection-close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subject m0'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _key('message-page-delete'),
        matching: find.byType(Icon),
      ),
      findsOneWidget,
    );
    expect(_key('message-page-compose'), findsOneWidget);
    await tester.tap(_key('glass-bar-button-message-page-back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-body')), findsNothing);
    expect(find.text('Subject m0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a long large title gets smaller to fit its line, whole and '
      'as tall as before', (tester) async {
    Future<(Rect, double)> title(String text) async {
      await tester.pumpWidget(
        MaterialApp(
          // A page's own text style, as the app's font, counts as well.
          home: DefaultTextStyle(
            style: const TextStyle(wordSpacing: 40),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 320, child: GlassLargeTitle(text)),
            ),
          ),
        ),
      );
      return (
        tester.getRect(find.text(text)),
        tester.getSize(find.byType(GlassLargeTitle)).height,
      );
    }

    final (short, height) = await title('Inbox');
    expect(short.height, closeTo(41, 0.5));
    // Too long at full size, even far too long: smaller, and all of it.
    for (final text in [
      'Wybierz coś',
      'Wybierz wiadomości do usunięcia teraz',
    ]) {
      final (long, longHeight) = await title(text);
      expect(long.height, lessThan(41));
      expect(long.left, greaterThanOrEqualTo(0));
      expect(long.right, lessThanOrEqualTo(320.5));
      expect(
        tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines,
        isFalse,
      );
      expect(longHeight, height);
    }
  });

  testWidgets('where Flutter draws the glass, the folder menu grows out on '
      'clear glass that reads the page all the way', (tester) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    await _open(tester, design: 'glass');
    await tester.tap(_key('messages-folder'));
    // Halfway open: nothing over the glass is faded, or the glass would have
    // no page to read and come up flat.
    await tester.pump(const Duration(milliseconds: 120));
    final plate = find.ancestor(
      of: _key('messages-folder-sent'),
      matching: find.byType(GlassPlate),
    );
    expect(plate, findsOneWidget);
    for (final fade in tester.widgetList<FadeTransition>(
      find.ancestor(of: plate, matching: find.byType(FadeTransition)),
    )) {
      expect(fade.opacity.value, 1);
    }
    expect(
      find.ancestor(of: plate, matching: find.byType(Opacity)),
      findsNothing,
    );
    await tester.pumpAndSettle();
    // The bars' clearer glass, not a panel's.
    expect(
      tester.widget<GlassPlate>(plate).look,
      same(GlassMaterial.menu(Brightness.light)),
    );
    await tester.tap(_key('messages-folder-sent'));
    await tester.pumpAndSettle();
    expect(find.text('Sent subject'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('where Flutter draws the glass, the menu pours out of the '
      'title on springs and folds back into it', (tester) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    await _open(tester, design: 'glass');
    final title = tester.getRect(_key('messages-folder'));
    await tester.tap(_key('messages-folder'));
    final plate = find.ancestor(
      of: _key('messages-folder-sent'),
      matching: find.byType(GlassPlate),
    );
    final heights = <double>[];
    final tops = <double>[];
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (plate.evaluate().isEmpty) continue;
      final rect = tester.getRect(plate);
      heights.add(rect.height);
      tops.add(rect.top);
    }
    await tester.pumpAndSettle();
    final open = tester.getRect(plate);
    // It comes from the title, above where it ends.
    expect(tops.first, lessThan(open.top - 10));
    expect(tops.first, lessThan(title.bottom));
    expect(open.top, closeTo(title.bottom + 6, 0.5));
    // A spring: it stretches past its size and settles back.
    expect(heights.reduce(math.max), greaterThan(open.height + 1));
    // Closing, it heads back up into the title, smaller.
    await tester.tapAt(const Offset(390, 590));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 130));
    final closing = tester.getRect(plate);
    expect(closing.top, lessThan(open.top));
    expect(closing.height, lessThan(open.height));
    await tester.pumpAndSettle();
    expect(plate, findsNothing);
    expect(find.text('Subject m0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('on iOS 26 the title opens UIKit\'s own menu, whose choice '
      'opens the folder', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final views = <String, int>{};
    GlassPlatform.debugSetBackend(GlassBackend.uikit);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map;
        views[arguments['viewType'] as String] = arguments['id'] as int;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    await _open(tester, design: 'glass');
    final id = views['siberia/glass_menu_button'];
    expect(id, isNotNull);
    // The button lies over the title.
    expect(
      tester
          .getRect(_key('messages-folder-native'))
          .overlaps(tester.getRect(_key('messages-folder'))),
      isTrue,
    );
    // UIKit says the second folder was picked.
    await messenger.handlePlatformMessage(
      'siberia/glass_menu_button/$id',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('pick', '1'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Sent subject'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
