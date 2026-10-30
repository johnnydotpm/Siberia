import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/demo_data.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/snapshot_store.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/homework_done.dart';
import 'package:syberia/src/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  test(
    'demo fixtures cover the requested screens and stay relative to today',
    () {
      final demo = DemoData(now: DateTime(2026, 10, 22, 10));
      final data = demo.snapshot;
      expect(data.profile.provider, 'Demo');
      expect(data.grades.map((grade) => grade.semester).toSet(), {1, 2});
      expect(data.grades.map((grade) => grade.subject).toSet().length, 6);
      expect(data.messages.any((message) => message.unread), isTrue);
      expect(data.messages.any((message) => !message.unread), isTrue);
      expect(data.sentMessages, isNotEmpty);
      expect(
        data.notices.map((notice) => notice.tone).toSet(),
        NoticeTone.values.toSet(),
      );
      expect(
        data.attendance.map((record) => record.kind).toSet(),
        containsAll([
          AttendanceKind.present,
          AttendanceKind.absent,
          AttendanceKind.absentExcused,
          AttendanceKind.late,
        ]),
      );
      expect(
        data.lessons.any((lesson) => lesson.start.isAfter(data.lastSync)),
        isTrue,
      );
      expect(
        data.events.every((event) => event.date.isAfter(data.lastSync)),
        isTrue,
      );
      expect(
        demo.timetableWeek(DateTime(2027, 1, 4)).first.start,
        DateTime(2027, 1, 4, 8),
      );
    },
  );

  test(
    'demo operations stay local and preserve saved snapshots and homework',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SnapshotStore.preferencesKey,
        'preserved account snapshot',
      );
      await prefs.setStringList(HomeworkDoneStore.key, [
        '2026-10-22|real-homework',
      ]);
      final saved = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      var networkRequests = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              networkRequests++;
              handler.reject(
                DioException(
                  requestOptions: request,
                  error: 'Demo must stay local',
                ),
              );
            },
          ),
        );
      final repository = AppRepository(
        librusClient: LibrusClient(dio: dio),
        githubClient: dio,
      );
      final controller = AppController(repository, updatesEnabled: false);
      await controller.bootstrap();
      controller.startDemo();
      expect(controller.isDemo, isTrue);
      final unread = controller.snapshot.messages.firstWhere(
        (message) => message.unread,
      );
      final content = await controller.fetchMessageContent(unread);
      expect(content.body, contains('fictional demo message'));
      expect(
        controller.snapshot.messages
            .firstWhere((message) => message.id == unread.id)
            .unread,
        isFalse,
      );
      final recipients = await controller.fetchMessageRecipients();
      await controller.sendMessage(
        recipients: recipients.take(2).toList(),
        subject: 'Demo reply',
        body: 'Only a local message',
      );
      await controller.refreshSentMessages(force: true);
      expect(controller.snapshot.sentMessages.first.subject, 'Demo reply');
      expect(
        (await controller.fetchMessageContent(
          controller.snapshot.sentMessages.first,
        )).recipients,
        hasLength(2),
      );
      final homework = controller.snapshot.events.firstWhere(
        (event) => event.kind == EventKind.homework,
      );
      await controller.setHomeworkDone(homework, true);
      expect(controller.isHomeworkDone(homework), isTrue);
      await controller.fetchTimetableWeek(DateTime(2027, 1, 4));
      await controller.sync();
      expect(controller.error, isNull);
      expect(
        controller.snapshot.messages
            .firstWhere((message) => message.id == unread.id)
            .unread,
        isFalse,
      );
      expect(controller.snapshot.sentMessages.first.subject, 'Demo reply');
      expect(await repository.fetchBackgroundSnapshot(), isNull);
      expect(await repository.fetchLatestReleaseVersion(), isNull);
      expect(await repository.availableStudents(), isEmpty);
      await expectLater(
        repository.loginLibrus(username: 'unused', password: 'unused'),
        throwsStateError,
      );
      await expectLater(
        repository.addProfiles(const [
          LinkedSynergiaAccount(
            login: 'real-account',
            name: 'Uczeń',
            selected: false,
          ),
        ]),
        throwsStateError,
      );
      await expectLater(
        repository.fetchMessageAttachmentUrl(
          messageId: unread.id,
          attachmentId: 'none',
        ),
        throwsUnsupportedError,
      );
      // A fresh process/repository has no persistent demo session.
      expect((await AppRepository().load()).profile.provider, 'Signed out');
      await controller.logout();
      expect(controller.isDemo, isFalse);
      expect(controller.snapshot.profile.provider, 'Signed out');
      expect(controller.snapshot.grades, isEmpty);
      expect(networkRequests, 0);
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, saved);
      controller.dispose();
    },
  );

  test('demo activation cannot replace a signed-in school account', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'active_profile_v1',
      jsonEncode(
        const StudentProfile(
          id: 'real-student',
          name: 'Student',
          school: 'School',
          provider: 'Librus Synergia',
        ).toJson(),
      ),
    );
    final controller = AppController(AppRepository(), updatesEnabled: false);
    await controller.bootstrap();
    controller.startDemo();
    expect(controller.isDemo, isFalse);
    expect(controller.snapshot.profile.id, 'real-student');
    controller.dispose();
  });

  Future<AppController> pumpLogin(WidgetTester tester) async {
    final controller = AppController(AppRepository(), updatesEnabled: false);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);
    return controller;
  }

  testWidgets(
    'a continuous five-second logo hold opens populated demo screens',
    (tester) async {
      final controller = await pumpLogin(tester);
      final logo = find.byKey(const ValueKey('login-demo-logo'));
      expect(find.text('Demo mode'), findsNothing);
      final hold = await tester.startGesture(tester.getCenter(logo));
      await tester.pump(const Duration(milliseconds: 4999));
      expect(controller.isDemo, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(controller.isDemo, isTrue);
      await hold.up();
      await tester.pumpAndSettle();
      expect(logo, findsNothing);
      for (final (tab, key) in [
        (2, 'grades-overview'),
        (6, 'attendance-by-subject'),
      ]) {
        controller.selectTab(tab);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      controller.selectTab(5);
      await tester.pumpAndSettle();
      expect(find.text('Class trip information'), findsWidgets);
      controller.selectTab(8);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Praise'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data ==
                  'Helped classmates prepare for the school science fair.',
        ),
        findsOneWidget,
      );
      await tester.tap(_profileButton().first);
      await tester.pumpAndSettle();
      expect(find.text('Demo mode'), findsOneWidget);
      expect(find.byKey(const ValueKey('profiles-add')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('account-logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-logout-confirm')));
      await tester.pumpAndSettle();
      expect(logo, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('releasing early or scrolling cancels the hidden hold', (
    tester,
  ) async {
    final controller = await pumpLogin(tester);
    final logo = find.byKey(const ValueKey('login-demo-logo'));
    for (var i = 0; i < 2; i++) {
      final hold = await tester.startGesture(tester.getCenter(logo));
      await tester.pump(const Duration(seconds: 3));
      await hold.up();
      await tester.pump();
    }
    expect(controller.isDemo, isFalse);
    final drag = await tester.startGesture(tester.getCenter(logo));
    await drag.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(seconds: 6));
    await drag.up();
    expect(controller.isDemo, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disposing the login screen cancels a pending hold', (
    tester,
  ) async {
    final controller = await pumpLogin(tester);
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('login-demo-logo'))),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
    await hold.up();
    expect(controller.isDemo, isFalse);
    expect(tester.takeException(), isNull);
  });
}

/// The profile button of the top bar, in either design.
Finder _profileButton() => find.byWidgetPredicate(
  (widget) =>
      widget.key == const ValueKey('profile-button') ||
      widget.key == const ValueKey('glass-bar-button-account'),
);
