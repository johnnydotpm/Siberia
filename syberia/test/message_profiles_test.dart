import 'dart:async';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SharedPreferences.setMockInitialValues({});
  });

  AppSnapshot withMail(AppSnapshot data) => data.copyWith(
    messages: [
      for (final id in ['1', '2'])
        SchoolMessage(
          id: id,
          sender: 'Teacher',
          subject: 'Subject $id',
          preview: '',
          receivedAt: DateTime.now(),
          unread: true,
          hasAttachments: false,
        ),
    ],
  );

  test('combined selection routes colliding message IDs to their own profiles and retains failed deletions', () async {
    final world = FakeLibrusWorld()..syncedAt = DateTime.now;
    world.changes['kid-regular'] = withMail;
    world.changes['kid-music'] = withMail;
    final repo = world.repository();
    final login = await repo.signIn(username: familyEmail, password: 'x');
    final profiles = await repo.addProfiles(login.students);
    for (final p in profiles) {
      await repo.syncProfile(p.id);
    }
    final controller = AppController(repo, updatesEnabled: false);
    await controller.bootstrap();
    await controller.openTogether();
    final selected = controller.snapshot.messages
        .where((m) => m.subject == 'Subject 1')
        .toList();
    expect(selected, hasLength(2));
    await controller.markMessagesRead([selected.first]);
    expect(world.opened, hasLength(1));
    expect(controller.snapshot.messages.where((m) => m.unread), hasLength(3));
    world.deleteFailures.add('kid-music');
    await expectLater(controller.deleteMessages(selected), throwsA(anything));
    expect(world.deleted.toSet(), {'kid-regular:1', 'kid-music:1'});
    expect(
      (await repo.loadProfileSnapshot(profiles[0].id)).messages
          .map((m) => m.id),
      ['2'],
    );
    expect(
      (await repo.loadProfileSnapshot(profiles[1].id)).messages
          .map((m) => m.id),
      ['1', '2'],
    );
    expect(controller.snapshot.messages, hasLength(3));
    controller.dispose();
  });

  test('switching profiles during deletion finishes only the in-flight message in its original cache', () async {
    final world = FakeLibrusWorld()..syncedAt = DateTime.now;
    world.changes['kid-regular'] = withMail;
    world.changes['kid-music'] = withMail;
    final repo = world.repository();
    final login = await repo.signIn(username: familyEmail, password: 'x');
    final profiles = await repo.addProfiles(login.students);
    for (final p in profiles) {
      await repo.syncProfile(p.id);
    }
    final controller = AppController(repo, updatesEnabled: false);
    await controller.bootstrap();
    final gate = Completer<void>();
    world.deleting = gate.future;
    final deleting = controller.deleteMessages(controller.snapshot.messages);
    // Wait for the first request to cross the repository boundary.
    while (world.deleted.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await controller.switchProfile(profiles[1].id);
    gate.complete();
    await deleting;
    expect(world.deleted, ['kid-regular:1']);
    expect(controller.snapshot.messages.map((m) => m.id), ['1', '2']);
    expect(
      (await repo.loadProfileSnapshot(profiles[0].id)).messages
          .map((m) => m.id),
      ['2'],
    );
    controller.dispose();
  });
}
