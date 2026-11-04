import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siberia_plugins/siberia_plugins.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/diary_plugins.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';

class _Http implements HttpClientAdapter {
  _Http(this.reply);
  final ResponseBody Function(RequestOptions) reply;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    return reply(request);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? value, {int status = 200}) =>
    ResponseBody.fromString(jsonEncode(value), status);
ResponseBody _fry(Object? value) => _json({'success': true, 'data': value});
ResponseBody _mob(Object? value) => _json({'v': 1, 'data': value});
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map<String, String> secrets;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('siberia-installed-plugin-');
    secrets = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secrets,
    );
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  PluginManifest release(String id) => PluginManifest.fromJson(
    jsonDecode(File('../plugins/$id/0.1.0/manifest.json').readAsStringSync()),
  );
  _Http distribution(String id) => _Http(
    (request) => ResponseBody.fromBytes(
      File('../plugins/$id/0.1.0/plugin.evc').readAsBytesSync(),
      200,
    ),
  );

  test('an older account upgrades its verified package for delete, persists the release and never replays a failure', () async {
    const profile = SchoolProfile(
      id: 'test-profile',
      account: 'plugin-fryderyk-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      synergiaLogin: null,
      name: 'Synthetic',
      providerId: 'fryderyk',
      providerName: 'Fryderyk',
      pluginStudent: '1',
    );
    final old = release('fryderyk');
    final next = PluginManifest.fromJson(
      jsonDecode(
        File('../plugins/fryderyk/0.1.1/manifest.json').readAsStringSync(),
      ),
    );
    secrets['diary_plugin_account_v1_${profile.account}'] = jsonEncode({
      'manifest': old.toJson(),
      'state': {
        'username': 'm.test',
        'schoolUrl': 'https://music.example',
        'accessToken': 'ACCESS',
        'refreshToken': 'REFRESH',
        'origins': ['https://music.example'],
      },
    });
    final downloads = _Http((r) {
      if (r.uri.path.endsWith('/catalog.json')) {
        return _json({
          'schemaVersion': 1,
          'plugins': [next.toJson()],
        });
      }
      expect(r.uri.path, endsWith('/fryderyk/0.1.1/plugin.evc'));
      return ResponseBody.fromBytes(
        File('../plugins/fryderyk/0.1.1/plugin.evc').readAsBytesSync(),
        200,
      );
    });
    var attempts = 0;
    final school = _Http((r) {
      attempts++;
      expect(r.uri.path, '/api/messages/delete/0007');
      expect(r.method, 'POST');
      return attempts == 1 ? _fry(null) : _json({}, status: 401);
    });
    final host = DiaryPlugins(
      directory: () async => root,
      distributionClient: Dio()..httpClientAdapter = downloads,
      runtime: PluginRuntime(client: Dio()..httpClientAdapter = school),
    );
    final message = SchoolMessage(
      id: '${profile.id}:${base64Url.encode(utf8.encode('0007'))}',
      sender: '',
      subject: '',
      preview: '',
      receivedAt: DateTime(2026),
      unread: true,
      hasAttachments: false,
    );
    await host.deleteMessage(profile, message);
    expect(attempts, 1);
    expect(downloads.requests, hasLength(2));
    expect(jsonDecode(secrets.values.single)['manifest']['version'], '0.1.1');
    expect(
      jsonDecode(secrets.values.single)['state']['refreshToken'],
      'REFRESH',
    );
    await expectLater(
      host.deleteMessage(profile, message),
      throwsA(isA<PluginException>()),
    );
    expect(
      attempts,
      2,
      reason: '401 on a mutation must not trigger account recovery/replay',
    );
    expect(
      downloads.requests,
      hasLength(2),
      reason: 'the verified release is cached',
    );
  });

  test('an unverified upgrade never receives a stored session or performs deletion', () async {
    const profile = SchoolProfile(
      id: 'test-profile',
      account: 'plugin-fryderyk-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      synergiaLogin: null,
      name: 'Synthetic',
      providerId: 'fryderyk',
      pluginStudent: '1',
    );
    final old = release('fryderyk');
    final next = PluginManifest.fromJson(
      jsonDecode(
        File('../plugins/fryderyk/0.1.1/manifest.json').readAsStringSync(),
      ),
    );
    secrets['diary_plugin_account_v1_${profile.account}'] = jsonEncode({
      'manifest': old.toJson(),
      'state': {
        'origins': ['https://music.example'],
        'refreshToken': 'KEEP',
      },
    });
    final school = _Http(
      (_) => throw StateError('Must not receive credentials'),
    );
    final host = DiaryPlugins(
      directory: () async => root,
      distributionClient: Dio()
        ..httpClientAdapter = _Http(
          (r) => r.uri.path.endsWith('/catalog.json')
              ? _json({
                  'schemaVersion': 1,
                  'plugins': [next.toJson()],
                })
              : ResponseBody.fromBytes([0, 1, 2], 200),
        ),
      runtime: PluginRuntime(client: Dio()..httpClientAdapter = school),
    );
    await expectLater(
      host.invoke(profile, 'deleteMessage', {'id': '7'}),
      throwsA(
        isA<PluginException>().having(
          (error) => error.code,
          'code',
          'integrity_failed',
        ),
      ),
    );
    expect(school.requests, isEmpty);
    expect(jsonDecode(secrets.values.single)['manifest']['version'], '0.1.0');
    expect(jsonDecode(secrets.values.single)['state']['refreshToken'], 'KEEP');
  });

  test('published Fryderyk package installs before credentials, restores offline, and retains grades on partial failure', () async {
    final downloads = distribution('fryderyk');
    var failed = false;
    final school = _Http((r) {
      // The verified package must exist before any auth request is issued.
      expect(downloads.requests, hasLength(1));
      if (r.uri.path.endsWith('/identify')) {
        return _fry({
          'access_token': 'ACCESS',
          'refresh_token': 'REFRESH',
          'url': 'https://music.example',
        });
      }
      if (r.uri.path.endsWith('/getCurrent')) {
        return _fry({
          'id': 9,
          'role': 'guardian',
          'first_name': 'Parent',
          'last_name': 'Example',
          'students': [
            {
              'id': 1,
              'role': 'student',
              'first_name': 'Anna',
              'last_name': 'Example',
              'students': [],
            },
            {
              'id': 2,
              'role': 'student',
              'first_name': 'Jan',
              'last_name': 'Example',
              'students': [],
            },
          ],
        });
      }
      if (r.uri.path.endsWith('/getRecipients')) {
        return _fry([
          {'key': 'teacher:0007', 'name': 'Teacher', 'role': 'teacher'},
        ]);
      }
      if (r.uri.path.endsWith('/messages/create')) {
        final request = jsonDecode(r.data as String) as Map;
        expect(request['recipients'], ['teacher:0007']);
        return _fry({'id': 99});
      }
      if (r.uri.path.contains('/grades/getOverview/')) {
        if (failed) return _json({'error': 'synthetic'}, status: 500);
        return _fry({
          'semesters': [
            {
              'name': 'I',
              'start': '2026-09-01',
              'end': '2027-01-31',
              'subjects': [
                {
                  'name': 'Piano',
                  'grades': [
                    {
                      'text_value': '5',
                      'numeric_value': '5',
                      'weight': '2',
                      'created': '2026-10-20T09:00:00',
                      'name': 'Practice',
                      'comment': 'Synthetic',
                    },
                  ],
                  'predicted_grade': {},
                  'final_grade': {},
                },
              ],
            },
          ],
        });
      }
      if (r.uri.path.contains('/attendances/getOverview/')) {
        return _fry({
          'year': {'attendancePercentage': 87.5},
          'months': [],
        });
      }
      return _fry(<Object?>[]);
    });
    final service = DiaryPlugins(
      directory: () => Future.value(root),
      distributionClient: Dio()..httpClientAdapter = downloads,
      runtime: PluginRuntime(client: Dio()..httpClientAdapter = school),
    );
    final repo = AppRepository(plugins: service);
    final login = await repo.signInPlugin(release('fryderyk'), {
      'username': 'm.synthetic',
      'password': '  secret  ',
    });
    final profiles = await repo.addPluginProfiles(login, login.students);
    await repo.switchProfile(profiles.first.id);
    final initial = await repo.syncProfile(profiles.first.id);
    expect(initial.grades.single.value, '5');
    expect(initial.moduleErrors['announcements'], 'module_unavailable');
    expect(initial.attendanceComplete, false);
    expect(secrets.values.single, contains('REFRESH'));
    expect(secrets.values.single, isNot(contains('  secret  ')));
    final recipients = await repo.fetchMessageRecipients(
      profileId: profiles.first.id,
    );
    expect(recipients.single.owner, profiles.first.account);
    final sent = await repo.sendMessage(
      recipients: recipients,
      subject: 'Hello',
      body: 'Synthetic',
      profileId: profiles.first.id,
    );
    expect(sent.id, startsWith('${profiles.first.id}:'));
    failed = true;
    final stale = await repo.syncProfile(profiles.first.id);
    expect(stale.grades.single.value, '5');
    expect(stale.moduleErrors['grades'], 'server_error');
    // A fresh repository/runtime can restore the pinned release from disk even
    // when its catalog/distribution server is unavailable.
    final offline = DiaryPlugins(
      directory: () => Future.value(root),
      distributionClient: Dio()
        ..httpClientAdapter = _Http(
          (_) => throw StateError('distribution offline'),
        ),
      runtime: PluginRuntime(client: Dio()..httpClientAdapter = school),
    );
    final restored = AppRepository(plugins: offline);
    expect((await restored.load()).grades.single.value, '5');
    expect(
      (await restored.syncProfile(profiles.first.id)).moduleErrors['grades'],
      'server_error',
    );
    await restored.removeProfile(profiles.first.id);
    expect(secrets, isNotEmpty);
    await restored.removeProfile(profiles.last.id);
    expect(secrets, isEmpty);
  });

  test('published MobiReg package shares auth across children while keeping DTO IDs and cache separate', () async {
    final downloads = distribution('mobireg');
    final school = _Http((r) {
      if (r.uri.path.endsWith('/auth.php')) {
        return _json({'status': 'OK', 'token': 'JWT'});
      }
      final form = Uri.splitQueryString(r.data as String);
      switch (form['view']) {
        case 'users':
          return _mob({
            'id': 9,
            'role': 2,
            'firstname': 'Parent',
            'lastname': 'Example',
            'pupils': [
              {'id': 1, 'firstname': 'Anna', 'lastname': 'Example'},
              {'id': 2, 'firstname': 'Jan', 'lastname': 'Example'},
            ],
          });
        case 'terms':
          return _mob([
            {
              'id': 4,
              'parentId': 3,
              'label': 'I',
              'isYear': 0,
              'dateFrom': '2020-01-01',
              'dateTo': '2100-01-01',
            },
          ]);
        case 'marks':
          return _mob({
            'subjects': [
              {'id': 8, 'label': 'Piano'},
            ],
            'teachers': [],
            'markGroups': [],
            'grades': [
              {
                'id': 10,
                'subjectId': 8,
                'value': form['pupilId'] == '1' ? '5' : '3',
                'weight': 2,
                'date': '2026-10-20',
                'count_to_avg': 1,
                'subject_name': 'Piano',
              },
            ],
          });
        case 'attendance-stats':
          return _mob({'subjects': [], 'terms': [], 'records': []});
        case 'tests':
        case 'homeworks':
        case 'reprimands':
          return _mob({'items': []});
        default:
          return _mob(<Object?>[]);
      }
    });
    final service = DiaryPlugins(
      directory: () => Future.value(root),
      distributionClient: Dio()..httpClientAdapter = downloads,
      runtime: PluginRuntime(client: Dio()..httpClientAdapter = school),
    );
    final repo = AppRepository(plugins: service);
    final login = await repo.signInPlugin(release('mobireg'), {
      'server': 'https://diary.example',
      'school': 'SYNTHETIC',
      'username': 'parent',
      'password': '  secret  ',
    });
    final profiles = await repo.addPluginProfiles(login, login.students);
    final a = await repo.syncProfile(profiles.first.id);
    final b = await repo.syncProfile(profiles.last.id);
    expect(a.grades.single.value, '5');
    expect(b.grades.single.value, '3');
    expect(a.grades.single.id, isNot(b.grades.single.id));
    expect(
      (await repo.loadProfileSnapshot(profiles.first.id)).grades.single.value,
      '5',
    );
    final scoped = await service.invoke(profiles.first, 'grades', {
      'pupilId': '2',
      'now': DateTime.now().toIso8601String(),
    });
    expect(((scoped.data as Map)['items'] as List).single['value'], '5');
    final count = school.requests.length;
    await expectLater(
      service.send(
        profiles.first,
        const [
          MessageRecipient(
            id: 'teacher:7',
            name: 'Wrong owner',
            group: 'teacher',
            owner: 'different-account',
          ),
        ],
        'Hello',
        'Synthetic',
      ),
      throwsA(
        isA<PluginException>().having((e) => e.code, 'code', 'invalid_scope'),
      ),
    );
    expect(school.requests, hasLength(count));
    expect(secrets, hasLength(1));
    expect(
      jsonDecode(secrets.values.single)['state']['password'],
      '  secret  ',
    );
    expect(downloads.requests, hasLength(1));
    await repo.logout();
    expect(secrets, isEmpty);
  });
}
