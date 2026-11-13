import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';

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
    // As in Mail on iOS 26, each row has its sender's picture, between the
    // unread dot and the text.
    final avatar = find.descendant(
      of: _key('message-tile-m0'),
      matching: find.text('TM'),
    );
    expect(avatar, findsOneWidget);
    expect(
      tester.getCenter(_key('message-unread-m0')).dx,
      lessThan(tester.getRect(avatar).left),
    );
    expect(
      tester.getRect(avatar).right,
      lessThan(tester.getRect(find.text('Teacher m0')).left),
    );
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
}
