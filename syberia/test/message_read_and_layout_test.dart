import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => GlassPlatform.debugSetBackend(GlassBackend.none));

  Future<AppController> load(_ReadClient client, AppSnapshot data) async {
    SharedPreferences.setMockInitialValues({
      'active_profile_v1': jsonEncode(data.profile.toJson()),
      'last_librus_snapshot_v1': SnapshotCache.encode(data),
      'auto_sync_on_open_v1': false,
    });
    final controller = AppController(
      AppRepository(librusClient: client),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    return controller;
  }

  test('bulk read contacts Librus only for unread messages, retains failures and persists successes', () async {
    final client = _ReadClient()..failures.add('b');
    final controller = await load(client, _data());
    await expectLater(
      controller.markAllMessagesRead(),
      throwsA(isA<LibrusException>()),
    );
    expect(client.opened, ['a', 'b', 'c']);
    expect(controller.markingMessagesRead, isFalse);
    expect(controller.error, isNotNull);
    expect(
      controller.snapshot.messages.where((m) => m.unread).map((m) => m.id),
      ['b'],
    );
    final restored = await AppRepository().load();
    expect(restored.messages.where((m) => m.unread).map((m) => m.id), ['b']);
    client.failures.clear();
    await controller.markAllMessagesRead();
    expect(client.opened, ['a', 'b', 'c', 'b']);
    expect(controller.snapshot.unreadMessages, 0);
    expect(controller.error, isNull);
    await controller.markAllMessagesRead();
    expect(client.opened, hasLength(4));
    controller.dispose();
  });

  testWidgets(
    'unread labels and bulk action update after opening and reading messages',
    (tester) async {
      final client = _ReadClient()..failures.add('b');
      final controller = await load(client, _data());
      controller.selectTab(5);
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      expect(_unreadDots(), findsNWidgets(3));
      await tester.tap(find.text('Subject a'));
      await tester.pumpAndSettle();
      expect(client.opened, ['a']);
      expect(controller.snapshot.unreadMessages, 2);
      expect((await AppRepository().load()).unreadMessages, 2);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      expect(_unreadDots(), findsNWidgets(2));
      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();
      expect(controller.snapshot.unreadMessages, 1);
      expect(_unreadDots(), findsOneWidget);
      expect(
        find.text(
          'Some messages could not be marked as read. Please try again.',
        ),
        findsOneWidget,
      );
      client.failures.clear();
      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();
      expect(_unreadDots(), findsNothing);
      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('messages-mark-all-read')),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('an attachment that fails to open says so inside the sheet', (
    tester,
  ) async {
    final controller = await load(_ReadClient(), _data());
    controller.selectTab(5);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subject a'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attachment-open-failed')), findsNothing);
    await tester.ensureVisible(find.text('plan.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('plan.pdf'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('attachment-open-failed')),
      findsOneWidget,
    );
    expect(find.text('The attachment could not be opened.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('swiping one message read that fails shows why', (tester) async {
    final client = _ReadClient()..failures.add('b');
    final controller = await load(client, _data());
    controller.selectTab(5);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('message-b')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();
    expect(client.opened, ['b']);
    expect(find.text('The message could not be loaded.'), findsOneWidget);
    expect(
      find.text('Some messages could not be marked as read. Please try again.'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('Today uses wall clock progress with Reduce Motion enabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 9));
    final controller = await load(
      _ReadClient(),
      _data().copyWith(
        lessons: [
          Lesson(
            id: 'current',
            subject: 'Current lesson',
            teacher: '',
            room: '',
            start: start,
            end: start.add(const Duration(minutes: 45)),
          ),
        ],
      ),
    );
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('today-now-card'));
    LinearProgressIndicator progress() => tester.widget(
      find.descendant(of: card, matching: find.byType(LinearProgressIndicator)),
    );
    expect(find.text('Ends in 36 min'), findsOneWidget);
    expect(progress().value, closeTo(0.2, 0.01));
    // Animation ticks and rebuilds must not make the real lesson end early.
    await tester.pump(const Duration(seconds: 30));
    await controller.setColorMode(AppColorMode.amoled);
    await tester.pumpAndSettle();
    expect(find.text('Ends in 36 min'), findsOneWidget);
    expect(progress().value, closeTo(0.2, 0.01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'calendar keeps every day inside the grid with glass insets and large text',
    (tester) async {
      GlassPlatform.debugSetBackend(GlassBackend.rendered);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = await load(_ReadClient(), _data());
      controller.selectTab(3);
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      final picker = find.byType(CalendarDatePicker);
      final grid = find
          .descendant(of: picker, matching: find.byType(GridView))
          .first;
      final now = DateTime.now();
      final last = DateTime(now.year, now.month + 1, 0);
      final lastDay = find
          .descendant(of: picker, matching: find.text('${last.day}'))
          .first;
      final viewport = tester.getRect(grid);
      final day = tester.getRect(lastDay);
      expect(day.top, greaterThanOrEqualTo(viewport.top));
      expect(day.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(MediaQuery.paddingOf(tester.element(grid)), EdgeInsets.zero);
      await tester.ensureVisible(lastDay);
      await tester.tap(lastDay);
      await tester.pumpAndSettle();
      controller.selectTab(0);
      await tester.pumpAndSettle();
      controller.selectTab(3);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(lastDay).bottom,
        lessThanOrEqualTo(tester.getRect(grid).bottom),
      );

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}

AppSnapshot _data() => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Test',
    school: '',
    provider: 'Librus Synergia',
  ),
  lessons: const [],
  grades: const [],
  events: const [],
  messages: [
    for (final id in ['a', 'b', 'c', 'd'])
      SchoolMessage(
        id: id,
        sender: 'Teacher',
        subject: 'Subject $id',
        preview: '',
        receivedAt: DateTime(2026, 10, 16),
        unread: id != 'd',
        hasAttachments: true,
      ),
  ],
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: DateTime.now(),
);

class _ReadClient extends LibrusClient {
  final opened = <String>[];
  final failures = <String>{};

  @override
  Future<Uri> fetchMessageAttachmentUrl({
    required String messageId,
    required String attachmentId,
  }) async =>
      throw const LibrusException(LibrusErrorCode.attachmentFetchFailed);

  @override
  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage message,
  ) async {
    opened.add(message.id);
    if (failures.contains(message.id)) {
      throw const LibrusException(LibrusErrorCode.messageContentFailed);
    }
    return SchoolMessageContent(
      id: message.id,
      sender: message.sender,
      subject: message.subject,
      body: 'Content',
      receivedAt: message.receivedAt,
      attachments: [MessageAttachment(id: 'f-${message.id}', name: 'plan.pdf')],
    );
  }
}

/// The dots that mark unread messages in the list.
Finder _unreadDots() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('message-unread-'),
);
