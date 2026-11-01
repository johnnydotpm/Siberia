import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/diary_plugins.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/data/plugin_text.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/domain/together.dart';
import 'package:syberia/src/state/app_controller.dart';

PluginManifest manifest() => PluginManifest.fromJson({
  'id': 'fryderyk',
  'name': 'Fryderyk',
  'version': '0.1.0',
  'apiVersion': 1,
  'runtime': 'dart_eval-0.8.5',
  'artifact': 'fryderyk/0.1.0/plugin.evc',
  'bytes': 1,
  'sha256': List.filled(64, '0').join(),
  'origins': <String>[],
  'operations': ['authenticate', 'accounts', 'sync'],
  'loginFields': [
    {'id': 'username', 'label': 'username', 'type': 'text', 'required': true},
    {
      'id': 'password',
      'label': 'password',
      'type': 'password',
      'required': true,
    },
  ],
});

class SchoolPlugins extends DiaryPlugins {
  final removed = <String>[];
  final sentFrom = <String>[];
  final synced = <String>[];
  @override
  Future<List<PluginManifest>> catalog() async => [manifest()];
  @override
  Future<PluginSignIn> connect(
    PluginManifest m,
    Map<String, Object?> fields,
  ) async => PluginSignIn('plugin-fryderyk-owner', m, const [
    PluginStudent('1', 'Anna', 'Music', true),
    PluginStudent('2', 'Jan', 'Music', true),
  ]);
  @override
  Future<void> forget(String owner) async {
    removed.add(owner);
  }

  @override
  Future<AppSnapshot> sync(
    SchoolProfile p,
    AppSnapshot previous, {
    Set<LibrusPart>? parts,
  }) async {
    synced.add(p.id);
    return AppSnapshot(
      profile: DiaryPlugins.student(p),
      lessons: const [],
      events: const [],
      grades: [
        Grade(
          id: '${p.id}:mark',
          subject: 'Piano',
          value: '5',
          description: 'Synthetic',
          date: DateTime(2026, 10, 31),
          weight: 2,
          semester: 1,
        ),
      ],
      messages: previous.messages,
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: DateTime.now(),
      moduleErrors: const {'notices': 'module_unavailable'},
      providerData: const {
        'grades': {'period': '2026/27'},
      },
      attendanceComplete: false,
    );
  }

  @override
  Future<List<MessageRecipient>> recipients(SchoolProfile p) async => const [
    MessageRecipient(id: 'teacher:0007', name: 'Teacher', group: 'teacher'),
  ];
  @override
  Future<String> send(
    SchoolProfile p,
    List<MessageRecipient> recipients,
    String subject,
    String body,
  ) async {
    expect(recipients.single.id, 'teacher:0007');
    sentFrom.add(p.id);
    return '${p.id}:sent';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
  });
  test('rich diary text keeps paragraphs, entities and safe link targets', () {
    expect(
      pluginText(
        '<p>Hello &amp; Anna</p><p><a href="https://school.example/info">Details</a><br>Next</p><script>hidden()</script>',
      ),
      'Hello & Anna\nDetails (https://school.example/info)\nNext',
    );
    expect(pluginText('<a href="javascript:ignored()">Visible</a>'), 'Visible');
  });
  test('plugin child profiles survive reload, are isolated, and keep owner until the last child leaves', () async {
    final service = SchoolPlugins();
    final repository = AppRepository(plugins: service);
    final found = await repository.signInPlugin(manifest(), {
      'username': 'synthetic',
      'password': 'synthetic',
    });
    final profiles = await repository.addPluginProfiles(found, found.students);
    expect(profiles, hasLength(2));
    expect(profiles.map((p) => p.id).toSet(), hasLength(2));
    expect(
      await repository.availableStudents(),
      isEmpty,
    ); // Never call Librus for plugin owners.
    await repository.switchProfile(profiles.first.id);
    final first = await repository.syncProfile(profiles.first.id);
    expect(first.profile.connected, true);
    expect(first.profile.pluginId, 'fryderyk');
    expect(first.moduleErrors, containsPair('notices', 'module_unavailable'));
    final restored = AppRepository(plugins: service);
    final cached = await restored.load();
    expect(restored.activeProfile?.providerId, 'fryderyk');
    expect(restored.activeProfile?.pluginStudent, '1');
    expect(cached.grades.single.value, '5');
    expect(cached.attendanceComplete, false);
    expect(cached.providerData, first.providerData);
    await restored.switchProfile(profiles.last.id);
    expect((await restored.load()).grades, isEmpty);
    final recipients = await restored.fetchMessageRecipients(
      profileId: profiles.first.id,
    );
    await restored.sendMessage(
      recipients: recipients,
      subject: 'Hello',
      body: 'Synthetic',
      profileId: profiles.first.id,
    );
    expect(service.sentFrom, [profiles.first.id]);
    expect(
      (await restored.loadProfileSnapshot(profiles.first.id)).sentMessages,
      hasLength(1),
    );
    expect(
      (await restored.loadProfileSnapshot(profiles.last.id)).sentMessages,
      isEmpty,
    );
    await restored.removeProfile(profiles.first.id);
    expect(service.removed, isEmpty);
    await restored.removeProfile(profiles.last.id);
    expect(service.removed, ['plugin-fryderyk-owner']);
  });
  test('plugin status survives cache and All together; excluded grades never enter averages', () async {
    final service = SchoolPlugins();
    final repository = AppRepository(plugins: service);
    final found = await repository.signInPlugin(manifest(), {});
    final profiles = await repository.addPluginProfiles(found, found.students);
    final first = await repository.syncProfile(profiles.first.id);
    final second = await repository.syncProfile(profiles.last.id);
    final together = mergeSnapshots([
      (profiles.first, first),
      (profiles.last, second),
    ]);
    expect(together.profile.connected, true);
    expect(together.attendanceComplete, false);
    expect(together.moduleErrors, hasLength(2));
    final cached = SnapshotCache.decode(SnapshotCache.encode(first))!;
    expect(cached.moduleErrors, first.moduleErrors);
    final raw = jsonDecode(SnapshotCache.encode(first)) as Map<String, dynamic>;
    (raw['grades'] as List).first['countsToAverage'] = false;
    final excluded = SnapshotCache.decode(jsonEncode(raw))!.grades.single;
    expect(const GradeAverageSettings().average([excluded]), isNull);
    expect(excluded.withSource('other', id: 'other').countsToAverage, false);
  });
  testWidgets(
    'login offers downloadable diaries and renders their credential fields',
    (tester) async {
      final controller = AppController(
        AppRepository(plugins: SchoolPlugins()),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      // Open the account form, keeping the existing Librus default intact.
      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-diary')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fryderyk'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plugin-field-username')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plugin-field-password')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('plugin-field-password')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
