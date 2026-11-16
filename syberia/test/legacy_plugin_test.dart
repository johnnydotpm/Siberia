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

class _Http implements HttpClientAdapter {
  _Http(this.reply);
  final ResponseBody Function(RequestOptions) reply;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? value, {int status = 200}) =>
    ResponseBody.fromString(jsonEncode(value), status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map<String, String> credentials;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('siberia-legacy-install-');
    credentials = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      credentials,
    );
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async => root.delete(recursive: true));

  test('published optional package installs before sign-in, isolates parent/student credentials and checkpoints refresh before deletion', () async {
    final release = PluginManifest.fromJson(
      jsonDecode(
        File('../plugins/librus-legacy/0.1.0/manifest.json').readAsStringSync(),
      ),
    );
    final downloads = _Http((r) {
      if (r.uri.path.endsWith('/catalog.json')) {
        return _json({
          'schemaVersion': 1,
          'plugins': [release.toJson()],
        });
      }
      expect(r.uri.path, endsWith('/librus-legacy/0.1.0/plugin.evc'));
      return ResponseBody.fromBytes(
        File('../plugins/librus-legacy/0.1.0/plugin.evc').readAsBytesSync(),
        200,
      );
    });
    var failDelete = true;
    var deleteAttempts = 0;
    var refreshes = 0;
    final school = _Http((r) {
      expect(r.uri.host, 'api.librus.pl');
      expect(
        root
            .listSync(recursive: true)
            .any((file) => file.path.endsWith('.evc')),
        isTrue,
        reason:
            'verify/install the downloaded plugin before sending credentials',
      );
      if (r.uri.path == '/OAuth/Token') {
        final fields = Uri.splitQueryString(r.data as String);
        if (fields['grant_type'] == 'refresh_token') {
          refreshes++;
          expect(fields['refresh_token'], 'REFRESH-STUDENT');
          expect(fields.containsKey('password'), isFalse);
          return _json({
            'access_token': 'ACCESS-STUDENT',
            'refresh_token': 'ROTATED-STUDENT',
            'expires_in': 3600,
          });
        }
        expect(fields['password'], '  secret  ');
        final type = fields['username'] == '001234u' ? 'STUDENT' : 'PARENT';
        return _json({
          'access_token': 'ACCESS-$type',
          'refresh_token': 'REFRESH-$type',
          'expires_in': 3600,
        });
      }
      final parent = r.headers['Authorization'] == 'Bearer ACCESS-PARENT';
      if (r.uri.path == '/2.0/Me') {
        return _json({
          'Me': {
            'Account': {'Id': parent ? 600 : 500, 'GroupId': parent ? 5 : 8},
            'User': {'Id': 100, 'FirstName': 'Anna', 'LastName': 'Example'},
          },
        });
      }
      if (r.uri.path == '/2.0/Schools') {
        return _json({
          'School': {'Name': 'Synthetic school'},
        });
      }
      if (r.uri.path == '/2.0/Subjects') {
        return _json({
          'Subjects': [
            {'Id': 1, 'Name': 'Math'},
          ],
        });
      }
      if (r.uri.path == '/2.0/Grades/Categories') {
        return _json({
          'Categories': [
            {'Id': 2, 'Name': 'Test', 'Weight': 2},
          ],
        });
      }
      if (r.uri.path == '/2.0/Grades') {
        return _json({
          'Grades': [
            {
              'Id': 10,
              'Subject': {'Id': 1},
              'Category': {'Id': 2},
              'Grade': parent ? '6' : '5',
              'AddDate': '2026-11-12',
              'Semester': 1,
            },
          ],
        });
      }
      if (r.uri.path == '/2.0/Messages/User') {
        return _json({
          'Users': [
            {'Id': 8, 'FirstName': 'Teacher', 'LastName': 'Example'},
          ],
        });
      }
      if (r.uri.path == '/2.0/Messages') {
        return _json({
          'Messages': [
            {
              'Id': 91,
              'Sender': {'Id': 8},
              'Subject': jsonEncode('Subject'),
              'Body': jsonEncode('Body'),
              'SendDate': '2026-11-12 08:00:00',
              'IsNew': true,
            },
          ],
        });
      }
      if (r.uri.path == '/2.0/Messages/91' && r.method == 'PUT') {
        deleteAttempts++;
        expect(jsonDecode(r.data as String), {'action': 'delete'});
        final stored = credentials.values
            .map((v) => jsonDecode(v) as Map)
            .firstWhere((v) => (v['state'] as Map)['accountId'] == '500');
        expect(
          stored['state']['refreshToken'],
          'ROTATED-STUDENT',
          reason: 'the renewed credential must be durable before a mutation',
        );
        if (failDelete) {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return _json({});
      }
      return _json({}, status: 403);
    });
    final host = DiaryPlugins(
      directory: () async => root,
      source: Uri.parse(
        'https://raw.githubusercontent.com/johnnydotpm/Siberia/dev/plugins/',
      ),
      distributionClient: Dio()..httpClientAdapter = downloads,
      runtime: PluginRuntime(client: Dio()..httpClientAdapter = school),
    );
    final repo = AppRepository(plugins: host);
    expect(repo.defaultDiary.id, 'librus');
    expect(repo.bundledDiaries.map((p) => p.id), ['librus']);
    expect((await repo.diaryPlugins()).single.id, 'librus-legacy');
    final studentLogin = await repo.signInPlugin(release, {
      'username': '001234u',
      'password': '  secret  ',
    });
    final student = (await repo.addPluginProfiles(
      studentLogin,
      studentLogin.students,
    )).single;
    expect(student.usesDownloadedPlugin, isTrue);
    expect(student.parent, isFalse);
    final parentLogin = await repo.signInPlugin(release, {
      'username': '001234',
      'password': '  secret  ',
    });
    final parent = (await repo.addPluginProfiles(
      parentLogin,
      parentLogin.students,
    )).single;
    expect(parent.parent, isTrue);
    expect(parent.account, isNot(student.account));
    expect(parent.id, isNot(student.id));
    final studentData = await repo.syncProfile(student.id);
    final parentData = await repo.syncProfile(parent.id);
    expect(studentData.grades.single.value, '5');
    expect(parentData.grades.single.value, '6');
    expect(studentData.messages.single.sender, 'Teacher Example');
    expect(studentData.messages.single.id, startsWith('${student.id}:'));
    expect(parentData.messages.single.id, startsWith('${parent.id}:'));
    expect(credentials, hasLength(2));
    expect(
      credentials.values.any((value) => value.contains('  secret  ')),
      isFalse,
    );
    final key = credentials.entries
        .firstWhere(
          (entry) =>
              (jsonDecode(entry.value)['state'] as Map)['accountId'] == '500',
        )
        .key;
    final expired = jsonDecode(credentials[key]!) as Map;
    expired['state']['expiresAtMs'] = 1;
    credentials[key] = jsonEncode(expired);
    await expectLater(
      repo.deleteMessage(studentData.messages.single, profileId: student.id),
      throwsA(isA<PluginException>()),
    );
    expect(refreshes, 1);
    expect(
      deleteAttempts,
      1,
      reason: 'an uncertain deletion is never replayed',
    );
    expect(
      jsonDecode(credentials[key]!)['state']['refreshToken'],
      'ROTATED-STUDENT',
    );
    expect((await repo.loadProfileSnapshot(student.id)).messages, hasLength(1));
    expect((await repo.loadProfileSnapshot(parent.id)).messages, hasLength(1));
    failDelete = false;
    await repo.deleteMessage(
      studentData.messages.single,
      profileId: student.id,
    );
    expect(deleteAttempts, 2);
    expect(refreshes, 1);
    expect((await repo.loadProfileSnapshot(student.id)).messages, isEmpty);
    expect((await repo.loadProfileSnapshot(parent.id)).messages, hasLength(1));
    expect(repo.defaultDiary.id, 'librus');
    expect(
      downloads.requests.where((r) => r.uri.path.endsWith('.evc')),
      hasLength(1),
    );
  });
}
