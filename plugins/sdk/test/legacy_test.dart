import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_eval/dart_eval.dart';
import 'package:dio/dio.dart';
import 'package:siberia_plugins/siberia_plugins.dart';
import 'package:test/test.dart';

import 'plugins_test.dart' show MemoryHttp;

ResponseBody reply(Object? value, {int status = 200}) =>
    ResponseBody.fromString(jsonEncode(value), status);

Map<String, Object?> legacyState() => {
  'username': '001234u',
  'accessToken': 'ACCESS',
  'refreshToken': 'REFRESH',
  'accountId': '55',
  'pupilId': '100',
  'parent': false,
  'name': 'Anna Example',
  'expiresAtMs': DateTime.now()
      .add(const Duration(hours: 1))
      .millisecondsSinceEpoch,
  'origins': ['https://api.librus.pl'],
};

Map<String, Object?> mailFixture({bool read = false}) => {
  'Id': '0010',
  'Sender': {'Id': 8},
  'Subject': jsonEncode('Subject'),
  'Body': jsonEncode('First line\nSecond line'),
  'SendDate': '2026-11-09 08:00:00',
  'IsNew': !read,
  'ReadDates': [
    {'ReadDate': read ? '2026-11-09 09:00:00' : 0},
  ],
  'Receivers': [
    {'FirstName': 'Anna', 'LastName': 'Example'},
  ],
};

Object schoolFixture(String path) {
  const user = {'Id': 8, 'FirstName': 'Teacher', 'LastName': 'Example'};
  final roots = <String, Object>{
    '/2.0/Subjects': {
      'Subjects': [
        {'Id': 1, 'Name': 'Math'},
      ],
    },
    '/2.0/Users': {
      'Users': [user],
    },
    '/2.0/Messages/User': {
      'Users': [user],
    },
    '/2.0/Grades/Categories': {
      'Categories': [
        {'Id': 2, 'Name': 'Test', 'Weight': 2, 'CountToTheAverage': true},
      ],
    },
    '/2.0/Grades': {
      'Grades': [
        {
          'Id': 10,
          'Subject': {'Id': 1},
          'Category': {'Id': 2},
          'Grade': '5',
          'AddDate': DateTime.utc(2026, 11, 1).millisecondsSinceEpoch ~/ 1000,
          'Semester': {'Number': 1},
          'IsConstituent': true,
        },
        {
          'Id': 11,
          'Subject': {'Id': 1},
          'Category': {'Id': 2},
          'Grade': '6',
          'AddDate': '2026-11-02',
          'Semester': 1,
          'IsSemester': true,
        },
      ],
    },
    '/2.0/Classrooms': {
      'Classrooms': [
        {'Id': 3, 'Name': '204'},
      ],
    },
    '/2.0/Timetables': {
      'Timetable': {
        '2026-11-09': [
          [
            {
              'Id': 100,
              'Subject': {'Id': 1},
              'Teacher': {'Id': 8},
              'Classroom': {'Id': 3},
              'HourFrom': '08:00',
              'HourTo': '08:45',
              'Number': 1,
            },
          ],
        ],
      },
    },
    '/2.0/Attendances/Types': {
      'Types': [
        {
          'Id': 1,
          'Name': 'Nieobecność',
          'Short': 'nb',
          'StandardType': {'Id': 1},
        },
      ],
    },
    '/2.0/Attendances': {
      'Attendances': [
        {
          'Id': 6,
          'Date': '2026-11-09',
          'LessonNo': 1,
          'Subject': {'Id': 1},
          'Type': {'Id': 1},
          'Semester': 1,
        },
      ],
    },
    '/2.0/HomeWorks': {
      'HomeWorks': [
        {
          'Id': 9,
          'Content': 'Test',
          'Subject': {'Id': 1},
          'Date': '2026-11-11',
          'LessonNo': 1,
        },
      ],
    },
    '/2.0/HomeWorkAssignments': {
      'HomeWorkAssignments': [
        {
          'Id': 7,
          'Topic': 'Task',
          'Text': 'Read',
          'Subject': {'Id': 1},
          'DueDate': '2026-11-10',
        },
      ],
    },
    '/2.0/SchoolNotices': {
      'SchoolNotices': [
        {
          'Id': 8,
          'Subject': 'Board',
          'Content': 'Hello',
          'AddedBy': {'Id': 8},
          'CreationDate': '2026-11-01',
        },
      ],
    },
    '/2.0/Notes/Categories': {
      'Categories': [
        {'Id': 1, 'Name': 'Behaviour'},
      ],
    },
    '/2.0/Notes': {
      'Notes': [
        {
          'Id': 9,
          'Text': 'Remark',
          'Category': {'Id': 1},
          'Teacher': {'Id': 8},
          'Positive': 1,
          'Date': '2026-11-01',
        },
      ],
    },
    '/2.0/LuckyNumbers': {
      'LuckyNumber': {'LuckyNumber': 7, 'LuckyNumberDay': '2026-11-11'},
    },
    '/2.0/Messages': {
      'Messages': [mailFixture()],
    },
    '/2.0/Messages/0010': {'Message': mailFixture(read: true)},
  };
  if (!roots.containsKey(path)) {
    throw StateError('Missing synthetic route: $path');
  }
  return roots[path]!;
}

void main() {
  late Uint8List bytes;
  late Directory directory;
  late InstalledPlugin installed;
  setUpAll(() {
    bytes = Uint8List.fromList(
      (Compiler()..entrypoints.add('package:diary_sdk/protocol.dart')).compile({
        'diary': {
          'main.dart': File(
            '../librus-legacy/src/main.dart',
          ).readAsStringSync(),
        },
        'diary_sdk': {
          'protocol.dart': File('../shared/protocol.dart').readAsStringSync(),
        },
      }).write(),
    );
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('siberia-legacy-test-');
    final descriptor =
        jsonDecode(File('../librus-legacy/plugin.json').readAsStringSync())
            as Map<String, dynamic>;
    final manifest = PluginManifest.fromJson({
      ...descriptor,
      'apiVersion': 1,
      'runtime': pluginRuntimeVersion,
      'artifact': 'librus-legacy/0.1.0/plugin.evc',
      'sha256': sha256.convert(bytes).toString(),
      'bytes': bytes.length,
    });
    installed = await PluginStore(
      directory: directory,
      client: Dio()
        ..httpClientAdapter = MemoryHttp(
          (_) => ResponseBody.fromBytes(bytes, 200),
        ),
    ).install(manifest);
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<PluginResult> invoke(
    MemoryHttp http,
    String op, {
    Map<String, Object?> input = const {},
    Map<String, Object?> state = const {},
  }) => PluginRuntime(
    client: Dio()..httpClientAdapter = http,
  ).invoke(installed, operation: op, input: input, state: state);

  test(
    'numeric login keeps password bytes and determines role from API even when the suffix disagrees',
    () async {
      for (final entry in [
        ('001234u', 5, true),
        ('001234', 8, false),
        ('001234u', 8, false),
        ('001234', 6, true),
      ]) {
        final network = MemoryHttp((r) {
          if (r.uri.path == '/OAuth/Token') {
            expect(r.method, 'POST');
            expect(r.headers['Authorization'], startsWith('Basic '));
            final fields = Uri.splitQueryString(r.data as String);
            expect(fields['username'], entry.$1);
            expect(fields['password'], '  secret  ');
            expect(fields['grant_type'], 'password');
            return reply({
              'access_token': 'ACCESS',
              'refresh_token': 'REFRESH',
              'expires_in': 3600,
            });
          }
          expect(r.headers['Authorization'], 'Bearer ACCESS');
          if (r.uri.path == '/2.0/Me') {
            return reply({
              'Me': {
                'Account': {'Id': 55, 'Login': entry.$1, 'GroupId': entry.$2},
                'User': {'Id': 100, 'FirstName': 'Anna', 'LastName': 'Example'},
              },
            });
          }
          if (r.uri.path == '/2.0/Schools') {
            return reply({
              'School': {'Name': 'Synthetic school'},
            });
          }
          throw StateError('Unexpected request');
        });
        final auth = await invoke(
          network,
          'authenticate',
          input: {'username': ' ${entry.$1} ', 'password': '  secret  '},
        );
        expect(auth.errorCode, isNull);
        expect(auth.data, {'owner': 'legacy:55'});
        expect(auth.state.containsKey('password'), isFalse);
        final accounts = await invoke(network, 'accounts', state: auth.state);
        expect(accounts.errorCode, isNull);
        expect(accounts.data, [
          {
            'id': '100',
            'name': 'Anna Example',
            'school': 'Synthetic school',
            'parent': entry.$3,
          },
        ]);
        expect(
          network.requests.any((r) => r.uri.host != 'api.librus.pl'),
          isFalse,
        );
      }
    },
  );

  test(
    'non-numeric logins make no request and unverified roles never fall back to the suffix',
    () async {
      for (final login in ['name@example.com', '12x', '-12', 'u', '']) {
        final network = MemoryHttp(
          (_) => throw StateError('No credentials may leave for invalid input'),
        );
        final result = await invoke(
          network,
          'authenticate',
          input: {'username': login, 'password': 'secret'},
        );
        expect(result.errorCode, 'invalid_synergia_login');
        expect(network.requests, isEmpty);
      }
      for (final group in [null, 4, 99]) {
        final network = MemoryHttp(
          (r) => r.uri.path == '/OAuth/Token'
              ? reply({
                  'access_token': 'ACCESS',
                  'refresh_token': 'REFRESH',
                  'expires_in': 3600,
                })
              : reply({
                  'Me': {
                    'Account': {'Id': 55, 'GroupId': group},
                    'User': {
                      'Id': 100,
                      'FirstName': 'Anna',
                      'LastName': 'Example',
                    },
                  },
                }),
        );
        final result = await invoke(
          network,
          'authenticate',
          input: {'username': '001234u', 'password': 'secret'},
        );
        expect(result.errorCode, 'unsupported_account_role');
      }
    },
  );

  test(
    'refresh rotates tokens without keeping a password and reports rejected grants or required account actions',
    () async {
      final state = legacyState();
      final network = MemoryHttp((r) {
        final fields = Uri.splitQueryString(r.data as String);
        expect(fields['grant_type'], 'refresh_token');
        expect(fields['refresh_token'], 'REFRESH');
        expect(fields.containsKey('password'), isFalse);
        return reply({
          'access_token': 'NEXT',
          'refresh_token': 'ROTATED',
          'expires_in': 3600,
        });
      });
      final result = await invoke(network, 'refresh', state: state);
      expect(result.errorCode, isNull);
      expect(result.state['accessToken'], 'NEXT');
      expect(result.state['refreshToken'], 'ROTATED');
      for (final code in [
        'invalid_grant',
        'librus_captcha_needed',
        'librus_password_change_required',
      ]) {
        final failed = await invoke(
          MemoryHttp((_) => reply({'error': code}, status: 400)),
          'refresh',
          state: state,
        );
        expect(
          failed.errorCode,
          code == 'invalid_grant'
              ? 'session_expired'
              : 'account_action_required',
        );
        expect(failed.state['refreshToken'], 'REFRESH');
      }
    },
  );

  test(
    'academic modules normalize real API shapes, preserving weights and excluding semester grades from averages',
    () async {
      final state = legacyState();
      final network = MemoryHttp((r) => reply(schoolFixture(r.uri.path)));
      for (final op in [
        'grades',
        'timetable',
        'attendance',
        'homework',
        'events',
        'announcements',
        'notices',
        'luckyNumbers',
      ]) {
        final result = await invoke(
          network,
          op,
          state: state,
          input: {'pupilId': '100', 'dateFrom': '2026-11-09'},
        );
        expect(result.errorCode, isNull, reason: op);
        final items = (result.data as Map)['items'] as List;
        expect(items, isNotEmpty, reason: op);
        if (op == 'grades') {
          expect(items[0]['subject'], 'Math');
          expect(items[0]['weight'], 2);
          expect(items[0]['semester'], 1);
          expect(items[0]['countsToAverage'], isTrue);
          expect(items[1]['assessment'], 'final');
          expect(items[1]['countsToAverage'], isFalse);
        }
        if (op == 'timetable') {
          expect(items.single['room'], '204');
          expect(items.single['teacher'], 'Teacher Example');
        }
        if (op == 'attendance') {
          expect(items.single['kind'], 'absent');
          expect((result.data as Map)['complete'], isFalse);
        }
        if (op == 'luckyNumbers') {
          expect(items.single, {'number': 7, 'day': '2026-11-11'});
        }
      }
    },
  );

  test(
    'mail uses JSON-decoded content, the exact sent filter and documented compose/delete bodies',
    () async {
      final state = legacyState();
      final network = MemoryHttp((r) {
        if (r.method == 'POST') {
          expect(r.uri.path, '/2.0/Messages');
          expect(jsonDecode(r.data as String), {
            'subject': 'Plain subject',
            'body': 'One\nTwo',
            'receivers': ['8'],
          });
          return reply({
            'Message': {'Id': 99},
          });
        }
        if (r.method == 'PUT') {
          expect(r.uri.path, '/2.0/Messages/0010');
          expect(jsonDecode(r.data as String), {'action': 'delete'});
          return reply({});
        }
        return reply(schoolFixture(r.uri.path));
      });
      final inbox = await invoke(
        network,
        'messages',
        state: state,
        input: {'pupilId': '100'},
      );
      expect(inbox.errorCode, isNull);
      final mail = (inbox.data as Map)['items'][0] as Map;
      expect(mail['subject'], 'Subject');
      expect(mail['body'], 'First line\nSecond line');
      expect(mail['sender'], 'Teacher Example');
      expect(mail['unread'], isTrue);
      final sent = await invoke(
        network,
        'messages',
        state: state,
        input: {'pupilId': '100', 'folder': 'sent'},
      );
      expect(sent.errorCode, isNull);
      expect(
        network.requests.any((r) => r.uri.queryParameters['inSended'] == '1'),
        isTrue,
      );
      final read = await invoke(
        network,
        'message',
        state: state,
        input: {'pupilId': '100', 'id': '0010'},
      );
      expect(read.errorCode, isNull);
      expect((read.data as Map)['unread'], isFalse);
      final recipients = await invoke(
        network,
        'recipients',
        state: state,
        input: {'pupilId': '100'},
      );
      expect(recipients.data, [
        {'id': '8', 'name': 'Teacher Example', 'group': ''},
      ]);
      final send = await invoke(
        network,
        'sendMessage',
        state: state,
        input: {
          'pupilId': '100',
          'subject': 'Plain subject',
          'body': 'One\nTwo',
          'recipients': ['8'],
        },
      );
      expect(send.errorCode, isNull);
      expect(send.data, {'id': '99'});
      final deleted = await invoke(
        network,
        'deleteMessage',
        state: state,
        input: {'pupilId': '100', 'id': '0010'},
      );
      expect(deleted.data, {'deleted': true});
    },
  );

  test(
    'full mailbox pages advance a bounded cursor without acknowledging mail',
    () async {
      final network = MemoryHttp((r) {
        if (r.uri.path == '/2.0/Messages/User') {
          return reply(schoolFixture(r.uri.path));
        }
        expect(r.method, 'GET');
        expect(r.uri.queryParameters['limit'], '50');
        expect(r.uri.queryParameters['page'], '1');
        return reply({
          'Messages': [
            for (var i = 0; i < 50; i++) {...mailFixture(), 'Id': '$i'},
          ],
        });
      });
      final result = await invoke(
        network,
        'messages',
        state: legacyState(),
        input: {'pupilId': '100'},
      );
      expect(result.errorCode, isNull);
      expect((result.data as Map)['nextCursor'], 2);
      expect((result.data as Map)['items'], hasLength(50));
      expect(network.requests, hasLength(2));
    },
  );

  test(
    'credential preflight refreshes expired tokens without performing a mailbox mutation',
    () async {
      final network = MemoryHttp((r) {
        expect(r.uri.path, '/OAuth/Token');
        expect(
          Uri.splitQueryString(r.data as String)['grant_type'],
          'refresh_token',
        );
        return reply({
          'access_token': 'NEXT',
          'refresh_token': 'ROTATED',
          'expires_in': 3600,
        });
      });
      final result = await invoke(
        network,
        'prepare',
        state: {...legacyState(), 'expiresAtMs': 1},
      );
      expect(result.errorCode, isNull);
      expect(result.state['refreshToken'], 'ROTATED');
      expect(network.requests, hasLength(1));
      final unchanged = await invoke(network, 'prepare', state: result.state);
      expect(unchanged.errorCode, isNull);
      expect(network.requests, hasLength(1));
    },
  );

  test(
    'scope mismatch makes no request; permission and uncertain write failures never replay',
    () async {
      final state = legacyState();
      final wrong = MemoryHttp((_) => throw StateError('Wrong child'));
      final scoped = await invoke(
        wrong,
        'grades',
        state: state,
        input: {'pupilId': 'another'},
      );
      expect(scoped.errorCode, 'invalid_input');
      expect(wrong.requests, isEmpty);
      for (final status in [401, 403, 500]) {
        final network = MemoryHttp((_) => reply({}, status: status));
        final result = await invoke(
          network,
          'deleteMessage',
          state: state,
          input: {'pupilId': '100', 'id': '0010'},
        );
        expect(result.errorCode, isNotNull);
        expect(network.requests, hasLength(1));
      }
    },
  );
}
