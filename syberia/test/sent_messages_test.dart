import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/domain/calendar_days.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

const _profile = StudentProfile(
  id: 'librus-1',
  name: 'Demo Student',
  school: 'School',
  provider: 'Librus Synergia',
);

SchoolMessage _received(String id) => SchoolMessage(
  id: id,
  sender: 'Teacher Alpha',
  subject: 'Received $id',
  preview: '',
  receivedAt: DateTime.now().subtract(const Duration(hours: 1)),
  unread: id == 'r1',
);

SchoolMessage _sent(
  String id, {
  List<String> recipients = const ['Teacher Alpha'],
  bool? read,
  Duration ago = const Duration(hours: 2),
}) => SchoolMessage(
  id: id,
  sender: '',
  subject: 'Sent $id',
  preview: '',
  receivedAt: DateTime.now().subtract(ago),
  sent: true,
  recipients: recipients,
  recipientRead: read,
);

AppSnapshot _snapshot({
  StudentProfile profile = _profile,
  List<SchoolMessage> messages = const [],
  List<SchoolMessage> sent = const [],
}) => AppSnapshot(
  profile: profile,
  lessons: const [],
  grades: const [],
  events: const [],
  messages: messages,
  sentMessages: sent,
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: DateTime.now(),
);

/// [snapshot] saved as the signed-in account's. The background check only
/// runs with [autoSync] on.
void _saved(AppSnapshot snapshot, {bool autoSync = false}) =>
    SharedPreferences.setMockInitialValues({
      'active_profile_v1': jsonEncode(snapshot.profile.toJson()),
      'last_librus_snapshot_v1': SnapshotCache.encode(snapshot),
      'auto_sync_on_open_v1': autoSync,
      'app_design_v1': 'classic',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('cache', () {
    test('keeps sent messages with their recipients', () {
      final decoded = SnapshotCache.decode(
        SnapshotCache.encode(
          _snapshot(
            messages: [_received('r1')],
            sent: [
              _sent('s1', recipients: ['Teacher Alpha', 'Teacher Beta']),
              _sent('s2', read: true),
            ],
          ),
        ),
      )!;
      expect(decoded.messages.single.sent, isFalse);
      expect(decoded.sentMessages.map((item) => item.id), ['s1', 's2']);
      expect(decoded.sentMessages.first.sent, isTrue);
      expect(decoded.sentMessages.first.recipients, [
        'Teacher Alpha',
        'Teacher Beta',
      ]);
      expect(decoded.sentMessages.first.recipientRead, isNull);
      expect(decoded.sentMessages.last.recipientRead, isTrue);
    });

    test('a cache from before the Sent folder still opens', () {
      final old = jsonDecode(
        SnapshotCache.encode(_snapshot(messages: [_received('r1')])),
      ) as Map<String, Object?>..remove('sentMessages');
      final decoded = SnapshotCache.decode(jsonEncode(old));
      expect(decoded, isNotNull);
      expect(decoded!.messages.single.id, 'r1');
      expect(decoded.sentMessages, isEmpty);
    });
  });

  group('sync', () {
    test('keeps the Sent folder of the same account', () async {
      _saved(_snapshot());
      final client = _Client(_snapshot(messages: [_received('r2')]));
      final result = await AppRepository(librusClient: client)
          .sync(_snapshot(sent: [_sent('s1')]));
      expect(result.messages.single.id, 'r2');
      expect(result.sentMessages.single.id, 's1');
      expect((await AppRepository().load()).sentMessages.single.id, 's1');
    });

    test('another account starts without one', () async {
      _saved(_snapshot());
      final client = _Client(_snapshot());
      final result = await AppRepository(librusClient: client).sync(
        _snapshot(
          profile: const StudentProfile(
            id: 'librus-2',
            name: 'Other',
            school: 'School',
            provider: 'Librus Synergia',
          ),
          sent: [_sent('s1')],
        ),
      );
      expect(result.sentMessages, isEmpty);
    });

    test('the background check keeps it too', () async {
      // Synced long enough ago for the background check to run.
      _saved(
        _snapshot(
          sent: [_sent('s1')],
        ).copyWith(lastSync: DateTime.now().subtract(const Duration(hours: 1))),
        autoSync: true,
      );
      final live = await AppRepository(
        librusClient: _Client(_snapshot(messages: [_received('r2')])),
      ).fetchBackgroundSnapshot(parts: {LibrusPart.messages});
      expect(live!.messages.single.id, 'r2');
      expect(live.sentMessages.single.id, 's1');
    });
  });

  group('controller', () {
    Future<(AppController, _Client)> load(AppSnapshot data) async {
      _saved(data);
      final client = _Client(data);
      final controller = AppController(
        AppRepository(librusClient: client),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      return (controller, client);
    }

    test('loads the Sent folder once in a while, or when asked', () async {
      final (controller, client) = await load(_snapshot());
      client.sent = [_sent('s1'), _sent('s2')];
      await controller.refreshSentMessages();
      expect(controller.snapshot.sentMessages.map((m) => m.id), ['s1', 's2']);
      expect((await AppRepository().load()).sentMessages, hasLength(2));
      await controller.refreshSentMessages();
      expect(client.sentLoads, 1);
      await controller.refreshSentMessages(force: true);
      expect(client.sentLoads, 2);
      controller.dispose();
    });

    test('a Sent folder loaded during a sync stays after it', () async {
      final (controller, client) = await load(_snapshot());
      client.gate = Completer<void>();
      final syncing = controller.sync();
      client.sent = [_sent('s1')];
      await controller.refreshSentMessages();
      await controller.sendMessage(
        recipients: const [
          MessageRecipient(id: 20, name: 'Teacher Alpha', group: 'Teachers'),
        ],
        subject: 'Question',
        body: 'Body',
      );
      client.gate!.complete();
      await syncing;
      expect(controller.snapshot.sentMessages.map((m) => m.id), ['99', 's1']);
      controller.dispose();
    });

    test('a failure is shown and the saved folder stays', () async {
      final (controller, client) = await load(_snapshot(sent: [_sent('s1')]));
      client.sentError = const LibrusException(LibrusErrorCode.serverReply);
      await controller.refreshSentMessages();
      expect(controller.sentMessagesError, isNotNull);
      expect(controller.loadingSentMessages, isFalse);
      expect(controller.snapshot.sentMessages.single.id, 's1');
      client.sentError = null;
      await controller.refreshSentMessages();
      expect(controller.sentMessagesError, isNull);
      controller.dispose();
    });

    test('a message just sent is in the Sent folder at once', () async {
      final (controller, client) = await load(_snapshot(sent: [_sent('s1')]));
      await controller.sendMessage(
        recipients: const [
          MessageRecipient(id: 20, name: 'Teacher Alpha', group: 'Teachers'),
          MessageRecipient(id: 21, name: 'Teacher Beta', group: 'Teachers'),
          // The same person picked in another group.
          MessageRecipient(id: 20, name: 'Teacher Alpha', group: 'Class'),
        ],
        subject: ' Question ',
        body: 'When is the test?',
      );
      expect(client.sentTo, [20, 21]);
      final first = controller.snapshot.sentMessages.first;
      expect(first.id, '99');
      expect(first.sent, isTrue);
      expect(first.subject, 'Question');
      expect(first.preview, 'When is the test?');
      expect(first.recipients, ['Teacher Alpha', 'Teacher Beta']);
      expect(first.recipientRead, isFalse);
      expect(controller.snapshot.sentMessages, hasLength(2));
      final saved = await AppRepository().load();
      expect(saved.sentMessages.map((m) => m.id), ['99', 's1']);
      controller.dispose();
    });

    test('opening a sent message learns who read it', () async {
      final (controller, _) = await load(_snapshot(sent: [_sent('s1')]));
      await controller.fetchMessageContent(
        controller.snapshot.sentMessages.single,
      );
      final opened = controller.snapshot.sentMessages.single;
      expect(opened.recipients, ['Teacher Alpha', 'Teacher Beta']);
      // One of the two has not read it yet.
      expect(opened.recipientRead, isFalse);
      final saved = (await AppRepository().load()).sentMessages.single;
      expect(saved.recipients, hasLength(2));
      controller.dispose();
    });
  });

  group('screen', () {
    Future<(AppController, _Client)> show(
      WidgetTester tester,
      AppSnapshot data, {
      List<SchoolMessage> server = const [],
    }) async {
      _saved(data);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = _Client(data)..sent = server;
      final controller = AppController(
        AppRepository(librusClient: client),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      controller.selectTab(5);
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      return (controller, client);
    }

    Future<void> openSent(WidgetTester tester) async {
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the Sent folder shows who a message went to and if it was read',
      (tester) async {
        final (_, client) = await show(
          tester,
          _snapshot(messages: [_received('r1')]),
          server: [
            _sent(
              's1',
              recipients: ['Teacher Alpha', 'Teacher Beta'],
              read: true,
            ),
            _sent('s2', read: false, ago: const Duration(days: 1)),
          ],
        );
        expect(find.text('Received r1'), findsOneWidget);
        await openSent(tester);
        expect(client.sentLoads, 1);
        expect(find.text('Received r1'), findsNothing);
        expect(find.text('Sent s1'), findsOneWidget);
        expect(find.textContaining('To: '), findsNWidgets(2));
        expect(find.text('+1'), findsOneWidget);
        final read = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('sent-read-s1')),
            matching: find.byType(Icon),
          ),
        );
        expect(read.icon, Icons.done_all_rounded);
        final unread = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('sent-read-s2')),
            matching: find.byType(Icon),
          ),
        );
        expect(unread.icon, Icons.done_rounded);
        // No unread dot or swipe for messages that went out.
        expect(find.byType(Dismissible), findsNothing);
        // Coming back within a short while does not load it again.
        await tester.tap(find.text('Inbox'));
        await tester.pumpAndSettle();
        await openSent(tester);
        expect(client.sentLoads, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('an opened sent message lists its recipients', (tester) async {
      final message = _sent('s1');
      final now = DateTime.now();
      final readAt = DateTime(now.year, now.month, now.day, 7, 40);
      // The day in words, in a sentence, with its short date and the time.
      String stamp(DateTime value) => [
        calendarDaysBetween(value, now) == 0 ? 'today' : 'yesterday',
        DateFormat('dd.MM').format(value),
        DateFormat('HH:mm').format(value),
      ].join(', ');
      final (controller, client) = await show(
        tester,
        _snapshot(sent: [message]),
        server: [message],
      );
      client.receivers = [
        for (var index = 1; index <= 6; index++)
          MessageReceiver(
            name: 'Teacher $index',
            read: index == 1,
            readAt: index == 1 ? readAt : null,
          ),
      ];
      await openSent(tester);
      await tester.tap(find.text('Sent s1'));
      await tester.pumpAndSettle();
      expect(find.text('Sent message'), findsOneWidget);
      expect(find.text('To:'), findsOneWidget);
      expect(find.text('Read · ${stamp(readAt)}'), findsOneWidget);
      expect(find.text('Not read yet'), findsNWidgets(3));
      expect(find.text('Teacher 5'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('sent-recipients-all')));
      await tester.pumpAndSettle();
      expect(find.text('Teacher 6'), findsOneWidget);
      expect(find.text('Not read yet'), findsNWidgets(5));
      expect(find.text('Sent ${stamp(message.receivedAt)}'), findsOneWidget);
      // The list row now knows all six.
      expect(controller.snapshot.sentMessages.single.recipients, hasLength(6));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an empty Sent folder, and one that failed to load', (
      tester,
    ) async {
      final (_, client) = await show(tester, _snapshot());
      client.sentError = const LibrusException(LibrusErrorCode.serverReply);
      await openSent(tester);
      expect(find.byKey(const ValueKey('messages-error-sent')), findsOneWidget);
      expect(find.text('No sent messages yet.'), findsNothing);
      client.sentError = null;
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('messages-error-sent')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(client.sentLoads, 2);
      expect(find.byKey(const ValueKey('messages-error-sent')), findsNothing);
      expect(find.text('No sent messages yet.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the unread chip still filters the inbox', (tester) async {
      await show(
        tester,
        _snapshot(messages: [_received('r1'), _received('r2')]),
      );
      expect(find.text('Received r2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('messages-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Received r1'), findsOneWidget);
      expect(find.text('Received r2'), findsNothing);
      expect(find.text('Unread (1)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

class _Client extends LibrusClient {
  _Client(this.response);
  final AppSnapshot response;
  List<SchoolMessage> sent = const [];
  Object? sentError;
  int sentLoads = 0;
  List<int>? sentTo;

  /// Holds a sync until completed.
  Completer<void>? gate;
  List<MessageReceiver> receivers = const [
    MessageReceiver(name: 'Teacher Alpha', read: true),
    MessageReceiver(name: 'Teacher Beta', read: false),
  ];

  @override
  Future<AppSnapshot?> restoreAndFetch({Set<LibrusPart>? parts}) async {
    await gate?.future;
    return response;
  }

  @override
  Future<List<SchoolMessage>> fetchSentMessages() async {
    sentLoads++;
    if (sentError != null) throw sentError!;
    return sent;
  }

  @override
  Future<String> sendMessage({
    required List<int> recipientIds,
    required String subject,
    required String body,
  }) async {
    sentTo = recipientIds;
    return '99';
  }

  @override
  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage summary,
  ) async => SchoolMessageContent(
    id: summary.id,
    sender: summary.sender,
    subject: summary.subject,
    body: 'Body',
    receivedAt: summary.receivedAt,
    recipients: summary.sent ? receivers : const [],
  );
}
