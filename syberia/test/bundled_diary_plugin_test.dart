import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siberia_plugins/siberia_plugins.dart'
    show PluginException, PluginManifest;
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/diary_plugin.dart';
import 'package:syberia/src/data/diary_plugin_registry.dart';
import 'package:syberia/src/data/diary_plugins.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/librus/librus_logins.dart';
import 'package:syberia/src/data/librus/librus_plugin.dart';
import 'package:syberia/src/data/librus/reference_cache.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

class _OfflineCatalog extends DiaryPlugins {
  int catalogs = 0, connections = 0;
  @override
  Future<List<PluginManifest>> catalog() async {
    catalogs++;
    throw const PluginException('download_failed');
  }

  @override
  Future<PluginSignIn> connect(
    PluginManifest manifest,
    Map<String, Object?> fields,
  ) async {
    connections++;
    throw StateError('No download belongs in bundled sign-in');
  }
}

class _NativeClient extends FakeProfileClient {
  _NativeClient(super.profile, super.world);
  final sentTo = <int>[];
  @override
  Future<String> sendMessage({
    required List<int> recipientIds,
    required String subject,
    required String body,
  }) async {
    sentTo.addAll(recipientIds);
    return 'sent-native';
  }

  @override
  Future<List<SchoolMessage>> fetchSentMessages() async => [
    SchoolMessage(
      id: 'sent-native',
      sender: '',
      subject: 'Hello',
      preview: 'Body',
      receivedAt: DateTime(2026, 10, 31),
      sent: true,
    ),
  ];
  @override
  Future<Uri> fetchMessageAttachmentUrl({
    required String messageId,
    required String attachmentId,
  }) async => Uri.https('school.example', '/attachments/$attachmentId');
}

class _ReservedBuiltin extends LibrusDiaryPlugin {
  _ReservedBuiltin()
    : super(logins: LibrusLogins(), references: LibrusReferenceCache());
  @override
  DiaryDefinition get definition =>
      const DiaryDefinition.bundled(id: 'fryderyk', name: 'Local adapter');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
  });
  test(
    'bundled manifest points to the locally registered Librus entrypoint',
    () {
      final metadata = jsonDecode(
        File('../plugins/librus/plugin.json').readAsStringSync(),
      ) as Map;
      final descriptor = LibrusDiaryPlugin.descriptor;
      expect(metadata['id'], descriptor.id);
      expect(metadata['name'], descriptor.name);
      expect(descriptor.distribution, DiaryDistribution.bundled);
      expect(descriptor.release, isNull);
      expect(metadata['distribution'], 'bundled');
      expect(File('lib/src/data/librus/librus_plugin.dart').existsSync(), true);
    },
  );
  test('native Librus uses the same session API without consulting catalog or changing legacy profile IDs', () async {
    final world = FakeLibrusWorld();
    final downloads = _OfflineCatalog();
    final clients = <String, _NativeClient>{};
    final native = LibrusDiaryPlugin(
      logins: LibrusLogins(),
      references: LibrusReferenceCache(),
      clients: (profile) => profile == null
          ? FakeProfileClient(null, world)
          : clients.putIfAbsent(
              profile.id,
              () => _NativeClient(profile, world),
            ),
    );
    final registry = DiaryPluginRegistry(
      bundled: [native],
      downloads: downloads,
      defaultId: 'librus',
    );
    expect(registry.bundled.single.id, 'librus');
    final login = await registry.defaultPlugin.signIn({
      'username': familyEmail,
      'password': 'synthetic',
    });
    expect(login.account, familyAccount);
    expect(login.children, hasLength(2));
    final profile = SchoolProfile(
      id: SchoolProfile.idFor(login.account, login.children.first.id),
      account: login.account,
      synergiaLogin: login.children.first.id,
      name: login.children.first.name,
    );
    expect(profile.usesDownloadedPlugin, false);
    final registered = registry.forProfile(profile);
    expect(identical(registered, native), true);
    expect(await registered.children(profile), hasLength(2));
    final session = registered.session(profile);
    final first = (await session.sync(null))!;
    expect(first.profile.id, 's-regular');
    expect(session.studentKey, 'kid-regular');
    final previous = first.copyWith(
      messages: [
        SchoolMessage(
          id: 'cached-mail',
          sender: 'Teacher',
          subject: 'Cached',
          preview: 'Body',
          receivedAt: DateTime(2026, 10, 30),
        ),
      ],
    );
    final partial = (await session.sync(previous, parts: {DiaryPart.grades}))!;
    expect(partial.messages.single.id, 'cached-mail');
    expect(partial.lessons, first.lessons);
    final other = studentSnapshot(
      'other-child',
      'old',
    ).copyWith(messages: previous.messages);
    expect(
      (await session.sync(other, parts: {DiaryPart.grades}))!.messages,
      isEmpty,
    );
    final recipients = await session.recipients();
    expect(
      await session.send(
        recipients: recipients,
        subject: 'Hello',
        body: 'Body',
      ),
      'sent-native',
    );
    expect(clients[profile.id]!.sentTo, [1]);
    final sent = await session.sent();
    expect(sent.messages.single.id, 'sent-native');
    expect(sent.providerData, isEmpty);
    expect(
      (await session.message(sent.messages.single, first)).body,
      world.messageBody,
    );
    expect(
      await session.attachment(messageId: 'sent-native', attachmentId: '7'),
      Uri.https('school.example', '/attachments/7'),
    );
    await session.timetable(DateTime(2026, 10, 31));
    expect(world.weeks, ['kid-regular']);
    await registered.forgetProfile(profile);
    expect(world.forgotten, [profile.id]);
    expect(downloads.catalogs, 0);
    expect(downloads.connections, 0);
  });
  test('a catalog release cannot shadow a locally registered plugin', () {
    final local = _ReservedBuiltin();
    final downloads = _OfflineCatalog();
    final registry = DiaryPluginRegistry(
      bundled: [local],
      downloads: downloads,
      defaultId: 'fryderyk',
    );
    final remote = PluginManifest.fromJson(
      jsonDecode(
        File('../plugins/fryderyk/0.1.0/manifest.json').readAsStringSync(),
      ),
    );
    expect(
      () => registry.download(remote),
      throwsA(
        isA<PluginException>().having(
          (e) => e.code,
          'code',
          'reserved_plugin_id',
        ),
      ),
    );
    expect(downloads.connections, 0);
    expect(DiaryPart.grades, LibrusPart.grades);
  });

  testWidgets(
    'Librus stays available from the registry when the download catalog fails',
    (tester) async {
      final downloads = _OfflineCatalog();
      final world = FakeLibrusWorld();
      final repository = AppRepository(
        plugins: downloads,
        librusClients: (p) => FakeProfileClient(p, world),
      );
      final controller = AppController(repository, updatesEnabled: false);
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.login_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-diary')));
      await tester.pumpAndSettle();
      final librus = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Librus',
      );
      expect(librus, findsOneWidget);
      await tester.tap(librus);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(controller.defaultDiary.id, 'librus');
      expect(downloads.connections, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
