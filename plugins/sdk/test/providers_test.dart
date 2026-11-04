import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dart_eval/dart_eval.dart';
import 'package:dio/dio.dart';
import 'package:siberia_plugins/siberia_plugins.dart';
import 'package:test/test.dart';
import 'plugins_test.dart' show MemoryHttp;

ResponseBody jsonReply(
  Object? value, {
  int status = 200,
  Map<String, List<String>>? headers,
}) =>
    ResponseBody.fromString(jsonEncode(value), status, headers: headers ?? {});
ResponseBody fry(Object? data) => jsonReply({'success': true, 'data': data});
ResponseBody mob(Object? data) => jsonReply({'v': 1, 'data': data});

void main() {
  final compiled = <String, Uint8List>{};
  late Directory temp;
  setUpAll(() {
    for (final provider in ['fryderyk', 'mobireg']) {
      compiled[provider] = Uint8List.fromList(
        (Compiler()..entrypoints.add('package:diary_sdk/protocol.dart'))
            .compile({
              'diary': {
                'main.dart': File(
                  '../$provider/src/main.dart',
                ).readAsStringSync(),
              },
              'diary_sdk': {
                'protocol.dart': File(
                  '../shared/protocol.dart',
                ).readAsStringSync(),
              },
            })
            .write(),
      );
    }
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('siberia-provider-');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  Future<InstalledPlugin> plugin(String name) async {
    final bytes = compiled[name]!;
    final descriptor =
        jsonDecode(File('../$name/plugin.json').readAsStringSync())
            as Map<String, dynamic>;
    final manifest = PluginManifest.fromJson({
      ...descriptor,
      'apiVersion': 1,
      'runtime': pluginRuntimeVersion,
      'artifact': '$name/${descriptor['version']}/plugin.evc',
      'bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
    });
    return PluginStore(
      directory: temp,
      client: Dio()
        ..httpClientAdapter = MemoryHttp(
          (_) => ResponseBody.fromBytes(bytes, 200),
        ),
    ).install(manifest);
  }

  Future<PluginResult> invoke(
    InstalledPlugin p,
    MemoryHttp network,
    String op, {
    Map<String, Object?> state = const {},
    Map<String, Object?> input = const {},
    Set<String> origins = const {},
  }) => PluginRuntime(client: Dio()..httpClientAdapter = network).invoke(
    p,
    operation: op,
    state: state,
    input: input,
    accountOrigins: origins,
  );
  Map body(RequestOptions r) => (jsonDecode(r.data as String) as Map);

  test(
    'Fryderyk mobile identify preserves password, then discovers two children on returned origin',
    () async {
      final p = await plugin('fryderyk');
      final network = MemoryHttp((r) {
        if (r.uri.path.endsWith('/identify')) {
          expect(
            r.uri.toString(),
            'https://swiadectwa.fryderyk.edu.pl/api/tokens/identify',
          );
          expect(body(r), {
            'username': 'm.synthetic',
            'password': '  secret  ',
            'device': 'SiberiaGB',
          });
          return fry({
            'access_token': 'ACCESS',
            'refresh_token': 'REFRESH',
            'url': 'https://music.example',
          });
        }
        expect(r.uri.toString(), 'https://music.example/api/users/getCurrent');
        expect(r.headers['Authorization'], 'Bearer ACCESS');
        return fry({
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
              'students': <Object?>[],
            },
            {
              'id': 2,
              'role': 'student',
              'first_name': 'Jan',
              'last_name': 'Example',
              'students': <Object?>[],
            },
          ],
        });
      });
      final auth = await invoke(
        p,
        network,
        'authenticate',
        input: {'username': ' m.synthetic ', 'password': '  secret  '},
      );
      expect(auth.errorCode, isNull);
      expect(auth.state['origins'], ['https://music.example']);
      final users = await invoke(
        p,
        network,
        'accounts',
        state: auth.state,
        origins: {'https://music.example'},
      );
      expect(users.errorCode, isNull);
      expect(users.data, [
        {'id': '1', 'name': 'Anna Example', 'parent': true, 'school': ''},
        {'id': '2', 'name': 'Jan Example', 'parent': true, 'school': ''},
      ]);
    },
  );

  final fryState = <String, Object?>{
    'username': 'm.synthetic',
    'schoolUrl': 'https://music.example',
    'accessToken': 'ACCESS',
    'refreshToken': 'REFRESH',
    'origins': ['https://music.example'],
  };
  test(
    'Fryderyk grades preserve text, periods and final assessments without mixing final into the average',
    () async {
      final p = await plugin('fryderyk');
      final raw = {
        'semesters': [
          {
            'name': 'I',
            'start': '2026-09-01',
            'end': '2027-01-31',
            'subjects': [
              {
                'name': 'Piano',
                'short_name': 'P',
                'color': 'ff112233',
                'predicted_grade': {'value': '5'},
                'final_grade': {'value': '6'},
                'grades': [
                  {
                    'text_value': 'bardzo dobry',
                    'numeric_value': '5',
                    'weight': '2',
                    'name': 'Exam',
                    'comment': 'Synthetic',
                    'created': '2026-10-20T10:00:00',
                    'subject_color': 'ff112233',
                  },
                ],
              },
            ],
          },
        ],
      };
      final response = await invoke(
        p,
        MemoryHttp((r) {
          expect(r.uri.path, '/api/grades/getOverview/1');
          return fry(raw);
        }),
        'grades',
        state: fryState,
        origins: {'https://music.example'},
        input: {
          'pupilId': '1',
          'parts': ['grades'],
        },
      );
      expect(response.errorCode, isNull);
      final data = response.data as Map;
      final grades = data;
      expect(
        (grades['items'] as List).single,
        containsPair('value', 'bardzo dobry'),
      );
      expect((grades['items'] as List).single, containsPair('weight', 2.0));
      expect(grades['metadata'], raw);
    },
  );

  test(
    'Fryderyk precise durations, cancellation, accompaniment and exams',
    () async {
      final p = await plugin('fryderyk');
      final response = await invoke(
        p,
        MemoryHttp(
          (_) => fry([
            {
              'name': 'Piano',
              'room': '12',
              'start': '2026-10-26T09:40:00',
              'end': '2026-10-26T11:25:00',
              'is_substitution': true,
              'substitution_type': 1,
              'teachers': [
                {'id': 3, 'full_name': 'Teacher Example'},
              ],
              'accompaniments': [
                {
                  'subject': 'Accompaniment',
                  'accompanist': 'Example',
                  'start': '2026-10-26T10:00:00',
                  'end': '2026-10-26T10:15:00',
                },
              ],
              'exams': [
                {
                  'description': 'Scales',
                  'start': '2026-10-26T09:40:00',
                  'end': '2026-10-26T09:55:00',
                },
              ],
            },
          ]),
        ),
        'timetable',
        state: fryState,
        origins: {'https://music.example'},
        input: {
          'pupilId': '1',
          'dateFrom': '2026-10-26',
          'dateTo': '2026-10-26',
        },
      );
      expect(response.errorCode, isNull);
      final result = response.data as Map;
      expect(result['items'], hasLength(2));
      expect((result['items'] as List).first, containsPair('cancelled', true));
      expect(result['events'], hasLength(1));
    },
  );

  test(
    'Fryderyk refresh rotates pair atomically; failed module is not an empty success',
    () async {
      final p = await plugin('fryderyk');
      final network = MemoryHttp((r) {
        if (r.uri.path.endsWith('/reIdentify')) {
          expect(body(r), {'u': 'm.synthetic', 't': 'REFRESH'});
          return fry({'access_token': 'A2', 'refresh_token': 'R2'});
        }
        return jsonReply({
          'success': false,
          'error': {'code': 'X'},
        }, status: 500);
      });
      final refreshed = await invoke(p, network, 'refresh', state: fryState);
      expect(refreshed.errorCode, isNull);
      expect(refreshed.state['accessToken'], 'A2');
      expect(refreshed.state['refreshToken'], 'R2');
      final sync = await invoke(
        p,
        network,
        'grades',
        state: refreshed.state,
        origins: {'https://music.example'},
        input: {
          'pupilId': '1',
          'parts': ['grades', 'notices'],
        },
      );
      expect(sync.errorCode, 'server_error');
    },
  );

  test(
    'Fryderyk recipients remain opaque and send has exact keys without automatic replay',
    () async {
      final p = await plugin('fryderyk');
      final network = MemoryHttp((r) {
        if (r.uri.path.endsWith('/getRecipients')) {
          return fry([
            {'key': 'teacher:0007', 'name': 'Example', 'role': 'teacher'},
          ]);
        }
        expect(r.method, 'POST');
        expect(r.uri.path, '/api/messages/create');
        expect(body(r), {
          'recipients': ['teacher:0007'],
          'cc_recipients': <Object?>[],
          'bcc_recipients': <Object?>[],
          'subject': 'Hello',
          'content': 'Synthetic',
          'attachment_ids': <Object?>[],
        });
        return fry({'id': 8});
      });
      final recipients = await invoke(
        p,
        network,
        'recipients',
        state: fryState,
        origins: {'https://music.example'},
      );
      expect(
        (recipients.data as List).single,
        containsPair('id', 'teacher:0007'),
      );
      final send = await invoke(
        p,
        network,
        'sendMessage',
        state: fryState,
        origins: {'https://music.example'},
        input: {
          'recipients': ['teacher:0007'],
          'subject': 'Hello',
          'body': 'Synthetic',
        },
      );
      expect(send.data, {'id': '8'});
      expect(
        network.requests.where((r) => r.uri.path.endsWith('/create')),
        hasLength(1),
      );
    },
  );

  test(
    'Fryderyk deletes with POST JSON null, confirms the envelope and does not retry',
    () async {
      final p = await plugin('fryderyk');
      for (final status in [200, 401, 500]) {
        final network = MemoryHttp((r) {
          expect(r.method, 'POST');
          expect(r.uri.path, '/api/messages/delete/0007');
          expect(r.data, 'null');
          expect(r.headers['Authorization'], 'Bearer ACCESS');
          return jsonReply({
            'success': status == 200,
            'data': null,
          }, status: status);
        });
        final result = await invoke(
          p,
          network,
          'deleteMessage',
          state: fryState,
          origins: {'https://music.example'},
          input: {'id': '0007'},
        );
        expect(network.requests, hasLength(1));
        if (status == 200) {
          expect(result.errorCode, isNull);
          expect(result.data, {'deleted': true});
        } else {
          expect(result.errorCode, isNotNull);
        }
      }
    },
  );

  final mobState = <String, Object?>{
    'server': 'https://diary.example',
    'school': 'SYNTHETIC',
    'username': 'parent',
    'password': '  secret  ',
    'token': 'JWT',
    'origins': ['https://diary.example'],
  };
  test(
    'MobiReg deletes once with mailbox cookie and no body, including empty 204 replies',
    () async {
      final p = await plugin('mobireg');
      for (final status in [204, 401, 500]) {
        final network = MemoryHttp((r) {
          expect(r.method, 'DELETE');
          expect(r.uri.path, '/api/messages/0007');
          expect(r.data, isNull);
          expect(r.headers['Cookie'], 'MAIL=SYNTHETIC');
          expect(r.headers.containsKey('Authorization'), isFalse);
          return ResponseBody.fromString('', status);
        });
        final result = await invoke(
          p,
          network,
          'deleteMessage',
          state: {
            ...mobState,
            'messagingUrl': 'https://mail.example/sso',
            'messagesToken': 'MODULE',
            'mailCookie': 'MAIL=SYNTHETIC',
            'origins': ['https://diary.example', 'https://mail.example'],
          },
          origins: {'https://diary.example', 'https://mail.example'},
          input: {'id': '0007'},
        );
        expect(network.requests, hasLength(1));
        if (status == 204) {
          expect(result.errorCode, isNull);
          expect(result.data, {'deleted': true});
        } else {
          expect(result.errorCode, isNotNull);
        }
      }
    },
  );

  test(
    'MobiReg modern password and gateway aliases; users never has fabricated pupil',
    () async {
      final p = await plugin('mobireg');
      final network = MemoryHttp((r) {
        if (r.uri.path.endsWith('/auth.php')) {
          expect(body(r), {'login': 'parent', 'password': '  secret  '});
          return jsonReply({'status': 'OK', 'token': 'JWT'});
        }
        final fields = Uri.splitQueryString(r.data as String);
        expect(fields, {
          'view': 'users',
          'format': 'json',
          'token': 'JWT',
          'JWTToken': 'JWT',
        });
        return mob({
          'id': 5,
          'role': 2,
          'firstname': 'Parent',
          'lastname': 'Example',
          'pupils': [
            {'id': 6, 'firstname': 'Anna', 'lastname': 'Example'},
          ],
          'messagingUrl': 'https://mail.example/base/sso',
          'homeworksUrl': 'https://tasks.example',
          'messagesToken': 'MODULE-TOKEN',
        });
      });
      final auth = await invoke(
        p,
        network,
        'authenticate',
        origins: {'https://diary.example'},
        input: {
          'server': 'https://diary.example',
          'school': ' SYNTHETIC ',
          'username': ' parent ',
          'password': '  secret  ',
        },
      );
      expect(auth.errorCode, isNull);
      final users = await invoke(
        p,
        network,
        'accounts',
        state: auth.state,
        origins: {'https://diary.example'},
      );
      expect(users.errorCode, isNull);
      expect((users.data as List).single, containsPair('parent', true));
      expect(
        users.state['origins'],
        containsAll(['https://mail.example', 'https://tasks.example']),
      );
    },
  );

  test(
    'MobiReg grades use current server term and preserve count exclusions',
    () async {
      final p = await plugin('mobireg');
      final network = MemoryHttp((r) {
        final fields = Uri.splitQueryString(r.data as String);
        expect(fields['pupilId'], '6');
        if (fields['view'] == 'terms') {
          return mob([
            {
              'id': 4,
              'parentId': 3,
              'label': 'I',
              'isYear': 0,
              'dateFrom': '2026-09-01',
              'dateTo': '2027-01-31',
            },
          ]);
        }
        expect(fields['termId'], '4');
        return mob({
          'subjects': [
            {'id': 8, 'label': 'Piano', 'name': 'Piano'},
          ],
          'teachers': <Object?>[],
          'markGroups': <Object?>[],
          'grades': [
            {
              'id': 10,
              'subjectId': 8,
              'value': 'bardzo dobry',
              'weight': '3',
              'date': '2026-10-20',
              'count_to_avg': 0,
              'subject_name': '',
              'description': 'Synthetic',
              'kindLabel': 'Practice',
            },
          ],
        });
      });
      final response = await invoke(
        p,
        network,
        'grades',
        state: mobState,
        origins: {'https://diary.example'},
        input: {
          'pupilId': '6',
          'now': '2026-10-31T12:00:00',
          'parts': ['grades'],
        },
      );
      expect(response.errorCode, isNull);
      final grade = ((response.data as Map)['items'] as List).single as Map;
      expect(grade['value'], 'bardzo dobry');
      expect(grade['countsToAverage'], false);
    },
  );

  test(
    'MobiReg rejects incompatible envelope instead of reporting no grades',
    () async {
      final p = await plugin('mobireg');
      final response = await invoke(
        p,
        MemoryHttp((_) => jsonReply({'v': 2, 'data': <Object?>[]})),
        'grades',
        state: mobState,
        origins: {'https://diary.example'},
        input: {
          'pupilId': '6',
          'now': '2026-10-31',
          'parts': ['grades'],
        },
      );
      expect(response.errorCode, 'protocol_error');
      expect(response.data, isNull);
    },
  );

  test(
    'MobiReg mail SSO accepts cookies on 302, keeps base path and distinct module auth',
    () async {
      final p = await plugin('mobireg');
      final state = {
        ...mobState,
        'messagingUrl': 'https://mail.example/base/sso',
        'messagesToken': 'TOKEN/+',
        'origins': ['https://diary.example', 'https://mail.example'],
      };
      final network = MemoryHttp((r) {
        expect(r.headers.containsKey('Authorization'), false);
        if (r.uri.path.contains('/base/sso/')) {
          expect(
            r.uri.toString(),
            'https://mail.example/base/sso/SYNTHETIC/TOKEN%2F%2B',
          );
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'set-cookie': ['MAIL=synthetic; Path=/; Secure'],
            },
          );
        }
        expect(r.headers['Cookie'], 'MAIL=synthetic');
        expect(r.uri.path, '/base/api/messages/receivers/search');
        return jsonReply([
          {'id': '0007', 'name': 'Teacher', 'role': 'teacher'},
          {'id': 'group:3', 'name': 'Group', 'role': 'group'},
        ]);
      });
      final response = await invoke(
        p,
        network,
        'recipients',
        state: state,
        origins: {'https://diary.example', 'https://mail.example'},
      );
      expect(response.errorCode, isNull);
      expect((response.data as List).map((r) => (r as Map)['id']), [
        'user_0007',
        'group:3',
      ]);
      expect(response.state['mailCookie'], 'MAIL=synthetic');
    },
  );

  test(
    'MobiReg uncertain send is attempted once, and retains independent mailbox state',
    () async {
      final p = await plugin('mobireg');
      final state = {
        ...mobState,
        'messagingUrl': 'https://mail.example/sso',
        'messagesToken': 'MODULE',
        'mailCookie': 'MAIL=SYNTHETIC',
        'origins': ['https://diary.example', 'https://mail.example'],
      };
      final network = MemoryHttp((r) {
        expect(r.method, 'PUT');
        expect(body(r), {
          'title': 'Hello',
          'content': 'Synthetic',
          'odbiorcy': ['user_0007'],
        });
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        );
      });
      final response = await invoke(
        p,
        network,
        'sendMessage',
        state: state,
        origins: {'https://mail.example'},
        input: {
          'recipients': ['user_0007'],
          'subject': 'Hello',
          'body': 'Synthetic',
        },
      );
      expect(response.errorCode, isNotNull);
      expect(network.requests, hasLength(1));
      expect(response.state['mailCookie'], 'MAIL=SYNTHETIC');
    },
  );
  test(
    'Fryderyk attendance, homework and message reading normalize all basic DTOs',
    () async {
      final p = await plugin('fryderyk');
      final record = {
        'id': 5,
        'subject': 'Synthetic',
        'content': '<p>Hello</p>',
        'sent_date': '2026-10-20T10:00:00',
        'sender': {'key': 'teacher:1', 'name': 'Teacher'},
        'recipients_v2': <Object?>[],
        'is_read': false,
        'attachments': <Object?>[],
      };
      final network = MemoryHttp((r) {
        if (r.uri.path.contains('/listWithAbsence/')) {
          return fry([
            {
              'name': 'Piano',
              'start': '2026-10-20T10:00:00',
              'end': '2026-10-20T11:00:00',
              'absence_type': 2,
            },
          ]);
        }
        if (r.uri.path.contains('/attendances/getOverview/')) {
          return fry({
            'year': {'attendancePercentage': 87.5},
            'months': <Object?>[],
          });
        }
        if (r.uri.path.contains('/homeworks/list/')) {
          return fry([
            {
              'id': 4,
              'subject': {'name': 'Piano'},
              'publish_date': '2026-10-20',
              'finish_date': '2026-10-23',
              'content': 'Practice',
              'attachments': <Object?>[],
            },
          ]);
        }
        if (r.uri.path.contains('/markAsRead/')) {
          expect(r.method, 'POST');
          expect(r.data, 'null');
          return fry(null);
        }
        expect(r.uri.path, '/api/messages/list/inbox/1/8');
        return fry([record]);
      });
      final attendance = await invoke(
        p,
        network,
        'attendance',
        state: fryState,
        origins: {'https://music.example'},
        input: {'pupilId': '1'},
      );
      expect(attendance.errorCode, isNull);
      expect((attendance.data as Map)['complete'], false);
      expect(
        ((attendance.data as Map)['items'] as List).single,
        containsPair('kind', 'absent'),
      );
      final homework = await invoke(
        p,
        network,
        'homework',
        state: fryState,
        origins: {'https://music.example'},
        input: {'pupilId': '1'},
      );
      expect(homework.errorCode, isNull);
      expect(
        ((homework.data as Map)['items'] as List).single,
        containsPair('kind', 'homework'),
      );
      final mail = await invoke(
        p,
        network,
        'messages',
        state: fryState,
        origins: {'https://music.example'},
      );
      expect(mail.errorCode, isNull);
      expect(
        ((mail.data as Map)['items'] as List).single,
        containsPair('sender', 'Teacher'),
      );
      final detail = await invoke(
        p,
        network,
        'message',
        state: fryState,
        origins: {'https://music.example'},
        input: {'id': '5', 'record': record, 'sent': false},
      );
      expect(detail.errorCode, isNull);
      expect((detail.data as Map)['body'], '<p>Hello</p>');
    },
  );
  test(
    'MobiReg timetable, attendance, events, homework, remarks and announcements',
    () async {
      final p = await plugin('mobireg');
      final network = MemoryHttp((r) {
        final fields = Uri.splitQueryString(r.data as String);
        expect(fields['pupilId'], '6');
        switch (fields['view']) {
          case 'timetable-events':
            return mob([
              {
                'id': 1,
                'subjectName': 'Piano',
                'dateTimeFrom': '2026-10-26T09:40:00',
                'dateTimeTo': '2026-10-26T11:25:00',
                'room': '12',
                'teachers': ['Teacher'],
                'isCanceled': true,
              },
            ]);
          case 'attendance-stats':
            return mob({
              'subjects': [
                {'id': 8, 'label': 'Piano'},
              ],
              'terms': <Object?>[],
              'records': [
                {
                  'd': '2026-10-20',
                  'sid': 8,
                  'ab': 'custom',
                  'ca': 'unknown',
                  'tn': 'Teacher',
                },
              ],
            });
          case 'tests':
            return mob({
              'teachers': <Object?>[],
              'items': [
                {
                  'id': 9,
                  'title': 'Exam',
                  'subjectName': 'Piano',
                  'dateTime': '2026-10-30T10:00:00',
                },
              ],
            });
          case 'homeworks':
            return mob({
              'teachers': <Object?>[],
              'items': [
                {
                  'id': 9,
                  'title': 'Practice',
                  'subjectName': 'Piano',
                  'dateTime': '2026-10-30T10:00:00',
                },
              ],
            });
          case 'reprimands':
            expect(fields['limit'], '100');
            return mob({
              'items': [
                {
                  'id': 10,
                  'content': 'Synthetic',
                  'kind': 'unknown',
                  'teacherName': 'Teacher',
                  'getDate': '2026-10-29T10:00:00',
                },
              ],
            });
          case 'announcements':
            return mob([
              {
                'id': 11,
                'title': 'Synthetic',
                'content': 'Details',
                'author': 'Teacher',
                'dateTime': '2026-10-30T12:00:00',
                'read': 1,
              },
            ]);
        }
        throw StateError('Unexpected synthetic operation');
      });
      for (final op in [
        'timetable',
        'attendance',
        'events',
        'homework',
        'notices',
        'announcements',
      ]) {
        final response = await invoke(
          p,
          network,
          op,
          state: mobState,
          origins: {'https://diary.example'},
          input: {
            'pupilId': '6',
            'dateFrom': '2026-10-26',
            'dateTo': '2026-11-01',
          },
        );
        expect(response.errorCode, isNull, reason: op);
        expect((response.data as Map)['items'], hasLength(1), reason: op);
      }
      final unavailable = await invoke(
        p,
        network,
        'homework',
        state: {...mobState, 'homeworksUrl': 'https://tasks.example'},
        origins: {'https://diary.example'},
        input: {'pupilId': '6'},
      );
      expect(unavailable.errorCode, 'module_unavailable');
    },
  );
  test(
    'MobiReg inbox and detail retain raw thread data and pagination',
    () async {
      final p = await plugin('mobireg');
      final state = {
        ...mobState,
        'messagingUrl': 'https://mail.example/sso',
        'messagesToken': 'MODULE',
        'mailCookie': 'MAIL=SYNTHETIC',
        'origins': ['https://diary.example', 'https://mail.example'],
      };
      final raw = {
        'id': 5,
        'subject': 'Hello',
        'content': 'Synthetic',
        'author': {'id': 1, 'name': 'Teacher'},
        'date': '2026-10-31T09:00:00',
        'read_at': null,
        'recipients': <Object?>[],
        'files': <Object?>[],
        'previous': <Object?>[],
      };
      final network = MemoryHttp((r) {
        expect(r.headers['Cookie'], 'MAIL=SYNTHETIC');
        if (r.method == 'GET') return jsonReply(raw);
        expect(body(r), {'limit': 20, 'skip': 0});
        return jsonReply({
          'items': [raw],
          'total': 1,
        });
      });
      final inbox = await invoke(
        p,
        network,
        'messages',
        state: state,
        origins: {'https://mail.example'},
      );
      expect(inbox.errorCode, isNull);
      expect((inbox.data as Map)['nextCursor'], isNull);
      expect(
        ((inbox.data as Map)['items'] as List).single,
        containsPair('raw', raw),
      );
      final detail = await invoke(
        p,
        network,
        'message',
        state: state,
        origins: {'https://mail.example'},
        input: {'id': '5'},
      );
      expect(detail.errorCode, isNull);
      expect((detail.data as Map)['body'], 'Synthetic');
    },
  );
}
