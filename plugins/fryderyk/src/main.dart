import 'dart:convert';

import 'package:diary_sdk/protocol.dart';

const tokenBase = 'https://swiadectwa.fryderyk.edu.pl/api/tokens';

class Fryderyk {
  Fryderyk(this.session, this.input, this.http);
  Map session;
  final Map input;
  final Function http;

  Map headers(bool authenticated) {
    final Map value = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'App-Version': '1.1.7',
    };
    if (authenticated)
      value['Authorization'] =
          'Bearer ${requiredString(session['accessToken'])}';
    return value;
  }

  Future<dynamic> decode(Map response) async {
    checkStatus(response);
    final value = object(jsonDecode(requiredString(response['body'])));
    if (value['success'] != true || !value.containsKey('data'))
      throw 'protocol_error';
    return value['data'];
  }

  Future<void> renew() async {
    final response = await transport(
      http,
      'POST',
      '$tokenBase/reIdentify',
      headers(false),
      jsonEncode({
        'u': requiredString(session['username']),
        't': requiredString(session['refreshToken']),
      }),
      true,
    );
    final value = object(await decode(response));
    final access = requiredString(value['access_token']);
    final refresh = requiredString(value['refresh_token']);
    session['accessToken'] = access;
    session['refreshToken'] = refresh;
  }

  Future<dynamic> call(String path, String method, dynamic body) async {
    final url = '${baseUrl(session['schoolUrl'])}/api/$path';
    Map response = await transport(
      http,
      method,
      url,
      headers(true),
      jsonEncode(body),
      method == 'POST',
    );
    return await decode(response);
  }

  String pupil() => part(identity(input['pupilId']));
  Future<List<dynamic>> accounts() async {
    final user = object(await call('users/getCurrent', 'GET', null));
    final role = requiredString(user['role']);
    if (role != 'student' && role != 'guardian') throw 'unsupported_operation';
    final children = array(user['students'] ?? []);
    if (role == 'student')
      return [
        {
          'id': identity(user['id']),
          'name': '${string(user['first_name'])} ${string(user['last_name'])}'
              .trim(),
          'parent': false,
          'school': '',
        },
      ];
    final List<dynamic> found = [];
    for (final raw in children) {
      final child = object(raw);
      found.add({
        'id': identity(child['id']),
        'name': '${string(child['first_name'])} ${string(child['last_name'])}'
            .trim(),
        'parent': role == 'guardian',
        'school': '',
      });
    }
    return found;
  }

  Future<Map> marks() async {
    final raw = object(
      await call('grades/getOverview/${pupil()}', 'GET', null),
    );
    final List<dynamic> items = [];
    final Map duplicates = {};
    var semester = 0;
    for (final period in array(raw['semesters'])) {
      semester++;
      for (final subject in array(object(period)['subjects'])) {
        final name = requiredString(object(subject)['name']);
        for (final entry in array(subject['grades'])) {
          final value = object(entry);
          final key = jsonEncode([
            period['start'],
            name,
            value['created'],
            value['text_value'],
            value['name'],
            value['comment'],
          ]);
          final occurrence = (duplicates[key] ?? 0) + 1;
          duplicates[key] = occurrence;
          items.add(
            grade(
              jsonEncode(value),
              '$key/$occurrence',
              name,
              semester,
              true,
              'current',
            ),
          );
        }
      }
    }
    // Proposed/final assessments and school period boundaries stay separate.
    return module(items, raw);
  }

  Map lesson(Map raw, String id) => {
    'id': id,
    'subject': requiredString(raw['name']),
    'teacher': array(raw['teachers'])
        .map((t) => string(object(t)['full_name']))
        .join(', '),
    'room': string(raw['room']),
    'start': date(raw['start']),
    'end': date(raw['end']),
    'cancelled': flag(raw['is_substitution']) && raw['substitution_type'] == 1,
    'substitution': flag(raw['is_substitution']),
    'originalSubject': string(raw['original_name']),
  };
  Future<Map> timetable() async {
    final start = DateTime.parse(requiredString(input['dateFrom']));
    final end = DateTime.parse(requiredString(input['dateTo']));
    final count = end.difference(start).inDays;
    if (count < 0 || count > 14) throw 'invalid_input';
    final List<dynamic> items = [];
    final List<dynamic> events = [];
    final List<dynamic> source = [];
    for (var offset = 0; offset <= count; offset++) {
      final rows = array(
        await call(
          'lessons/listAtDay/${pupil()}/${day(start.add(Duration(days: offset)))}',
          'GET',
          null,
        ),
      );
      final Map duplicates = {};
      for (final row in rows) {
        final raw = object(row);
        source.add(raw);
        final key = jsonEncode([
          raw['start'],
          raw['end'],
          raw['name'],
          raw['room'],
        ]);
        final n = (duplicates[key] ?? 0) + 1;
        duplicates[key] = n;
        final id = '$key/$n';
        items.add(lesson(raw, id));
        var index = 0;
        for (final accompaniment in array(raw['accompaniments'] ?? [])) {
          final child = object(accompaniment);
          items.add({
            'id': '$id/accompaniment/${index++}',
            'subject': requiredString(child['subject']),
            'teacher': string(child['accompanist']),
            'room': string(raw['room']),
            'start': date(child['start']),
            'end': date(child['end']),
          });
        }
        index = 0;
        for (final exam in array(raw['exams'] ?? [])) {
          final child = object(exam);
          events.add({
            'id': '$id/exam/${index++}',
            'title': string(child['description']),
            'description': string(child['description']),
            'subject': string(raw['name']),
            'date': date(child['start']),
            'kind': 'exam',
          });
        }
      }
    }
    final value = module(items, source);
    value['events'] = events;
    return value;
  }

  Future<Map> attendance() async {
    final raw = array(
      await call('lessons/listWithAbsence/${pupil()}/0', 'GET', null),
    );
    final List<dynamic> items = [];
    final Map duplicates = {};
    const kinds = {
      1: 'present',
      2: 'absent',
      3: 'absentExcused',
      4: 'absent',
      5: 'late',
      6: 'released',
      7: 'present',
      8: 'other',
    };
    const symbols = {
      1: 'OB',
      2: 'NB',
      3: 'U',
      4: 'NB',
      5: 'S',
      6: 'ZW',
      7: 'OB',
      8: '?',
    };
    for (final row in raw) {
      final value = object(row);
      final code = value['absence_type'];
      final key = jsonEncode([value['start'], value['end'], value['name']]);
      final n = (duplicates[key] ?? 0) + 1;
      duplicates[key] = n;
      items.add({
        'id': '$key/$n',
        'date': date(value['start']),
        'lessonNumber': 0,
        'subject': string(value['name']),
        'type': 'Fryderyk $code',
        'symbol': symbols[code] ?? string(code),
        'kind': kinds[code] ?? 'other',
      });
    }
    final value = module(items, raw);
    value['complete'] =
        false; // This endpoint lists absences, not the denominator.
    value['summary'] = await call(
      'attendances/getOverview/${pupil()}',
      'GET',
      null,
    );
    return value;
  }

  Future<Map> homework() async {
    final raw = array(await call('homeworks/list/${pupil()}/0', 'GET', null));
    return module(
      raw.map((entry) {
        final value = object(entry);
        return {
          'id': identity(value['id']),
          'title': string(object(value['subject'])['name']),
          'subject': string(value['subject']['name']),
          'date': date(value['finish_date']),
          'kind': 'homework',
          'description': string(value['content']),
        };
      }).toList(),
      raw,
    );
  }

  Future<Map> mail() async {
    final folder = string(input['folder'] ?? 'inbox');
    if (!['inbox', 'sent', 'trash', 'search'].contains(folder))
      throw 'invalid_input';
    final page = input['page'] ?? 1;
    if (page is! int || page < 0) throw 'invalid_input';
    final query = folder == 'search'
        ? '?query=${part(requiredString(input['query']))}'
        : '';
    final raw = array(
      await call('messages/list/$folder/$page/8$query', 'GET', null),
    );
    final value = module(
      raw
          .map((row) => message(jsonEncode(row), folder == 'sent', true))
          .toList(),
      raw,
    );
    value['nextCursor'] = raw.length == 8 ? page + 1 : null;
    return value;
  }

  Future<dynamic> operation(String op) async {
    if (op == 'authenticate') {
      final username = requiredString(input['username']).trim();
      final password = requiredString(input['password']);
      final raw = object(
        await decode(
          await transport(
            http,
            'POST',
            '$tokenBase/identify',
            headers(false),
            jsonEncode({
              'username': username,
              'password': password,
              'device': 'SiberiaGB',
            }),
            true,
          ),
        ),
      );
      final school = baseUrl(raw['url']);
      session = {
        'username': username,
        'accessToken': requiredString(raw['access_token']),
        'refreshToken': requiredString(raw['refresh_token']),
        'schoolUrl': school,
        'origins': [origin(school)],
      };
      return {'owner': '$school\n$username'};
    }
    if (op == 'refresh') {
      await renew();
      return null;
    }
    if (op == 'accounts') return await accounts();
    if (op == 'timetable') return await timetable();
    if (op == 'messages') return await mail();
    if (op == 'attendanceSummary')
      return await call('attendances/getOverview/${pupil()}', 'GET', null);
    if (op == 'absenceRequests')
      return await call(
        'attendances/listAbsenceTypeChangeRequests/${pupil()}',
        'GET',
        null,
      );
    if (op == 'recipients') {
      final raw = array(await call('messages/getRecipients', 'GET', null));
      return raw
          .map(
            (r) => {
              'id': requiredString(object(r)['key']),
              'name': requiredString(r['name']),
              'group': string(r['role']),
            },
          )
          .toList();
    }
    if (op == 'message') {
      final raw = object(input['record']);
      if (identity(raw['id']) != identity(input['id'])) throw 'invalid_input';
      await call(
        'messages/markAsRead/${part(identity(raw['id']))}',
        'POST',
        null,
      );
      return message(jsonEncode(raw), flag(input['sent']), true);
    }
    if (op == 'sendMessage') {
      final receivers = array(input['recipients']);
      if (receivers.isEmpty) throw 'invalid_input';
      final raw = object(
        await call('messages/create', 'POST', {
          'recipients': receivers,
          'cc_recipients': [],
          'bcc_recipients': [],
          'subject': requiredString(input['subject']),
          'content': requiredString(input['body']),
          'attachment_ids': [],
        }),
      );
      return {'id': identity(raw['id'])};
    }
    if (op == 'grades') return await marks();
    if (op == 'attendance') return await attendance();
    if (op == 'homework') return await homework();
    if (op == 'events') {
      final plan = await timetable();
      return module(array(plan['events']), {});
    }
    throw 'unsupported_operation';
  }
}

Future<String> main(String request, Function callback) async {
  final value = object(jsonDecode(request));
  final provider = Fryderyk(
    object(value['state']),
    object(value['input']),
    callback,
  );
  final data = await provider.operation(requiredString(value['operation']));
  return jsonEncode(result(data, provider.session));
}
