import 'dart:convert';

import 'package:diary_sdk/protocol.dart';

const agent = 'SiberiaGB (MobiReg protocol 3.1.7)';

class MobiReg {
  MobiReg(this.session, this.input, this.http);
  Map session;
  final Map input;
  final Function http;
  Map jsonHeaders() => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=UTF-8',
    'User-Agent': agent,
  };
  String schoolBase() =>
      '${baseUrl(session['server'])}/${part(requiredString(session['school']))}';
  Future<void> login() async {
    final response = await transport(
      http,
      'POST',
      '${schoolBase()}/modules/api/auth.php',
      jsonHeaders(),
      jsonEncode({
        'login': requiredString(session['username']),
        'password': requiredString(session['password']),
      }),
      true,
    );
    checkStatus(response);
    final value = object(jsonDecode(requiredString(response['body'])));
    if (response['status'] != 200 || value['status'] != 'OK')
      throw 'invalid_credentials';
    session['token'] = requiredString(value['token']);
    session.remove('mailCookie');
  }

  Future<dynamic> gateway(String view, Map extras, bool pupilRequired) async {
    final Map fields = {
      'view': view,
      'format': 'json',
      'token': requiredString(session['token']),
      'JWTToken': requiredString(session['token']),
    };
    if (pupilRequired) fields['pupilId'] = identity(input['pupilId']);
    fields.addAll(extras);
    final body = fields.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(string(e.value))}',
        )
        .join('&');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': agent,
    };
    final response = await transport(
      http,
      'POST',
      '${schoolBase()}/modules/api/app.php',
      headers,
      body,
      true,
    );
    // requestView never refreshes/replays itself. The host can reconnect safely.
    checkStatus(response);
    if (response['status'] != 200) throw 'server_error';
    final envelope = object(jsonDecode(requiredString(response['body'])));
    if ((envelope['v'] != 1 && envelope['v'] != '1') ||
        !envelope.containsKey('data'))
      throw 'protocol_error';
    final value = envelope['data'];
    if (value is Map && value.containsKey('errno')) throw 'module_unavailable';
    return value;
  }

  Future<List<dynamic>> accounts() async {
    final raw = object(await gateway('users', {}, false));
    final role = int.tryParse(string(raw['role'])) ?? 0;
    final id = int.tryParse(string(raw['id'])) ?? 0;
    final children = array(raw['pupils'] ?? []);
    if (children.isEmpty && role == 1 && id > 0)
      children.add({
        'id': id,
        'firstname': raw['firstname'],
        'lastname': raw['lastname'],
      });
    final List<dynamic> origins = [origin(requiredString(session['server']))];
    // Discover separate module endpoints, without attaching the diary JWT.
    for (final key in ['messagingUrl', 'homeworksUrl']) {
      final url = string(raw[key]);
      if (url.isNotEmpty) {
        session[key] = baseUrl(url);
        origins.add(origin(url));
      }
    }
    final token = raw['messagesToken'];
    if (token is String && token.isNotEmpty) session['messagesToken'] = token;
    session['origins'] = origins.toSet().toList();
    session['oldHomeworkModule'] = raw['oldHomeworkModule'];
    return children.map((r) {
      final child = object(r);
      if (child['id'] is! int) throw 'protocol_error';
      return {
        'id': identity(child['id']),
        'name': '${string(child['firstname'])} ${string(child['lastname'])}'
            .trim(),
        'parent': role != 1,
        'school': requiredString(session['school']),
      };
    }).toList();
  }

  List<dynamic> values(dynamic raw) {
    if (raw is List<dynamic>) return raw;
    if (raw is Map) return raw.values.toList();
    throw 'protocol_error';
  }

  List<dynamic> rows(dynamic raw) {
    if (raw is List<dynamic>) return raw;
    return array(object(raw)['data']);
  }

  void collectMarks(dynamic raw, List<dynamic> result) {
    if (raw is List<dynamic>) {
      for (final value in raw) {
        collectMarks(value, result);
      }
      return;
    }
    final value = object(raw);
    if (value.containsKey('id') &&
        value.containsKey('subjectId') &&
        value.containsKey('value')) {
      result.add(raw);
      return;
    }
    for (final child in value.values) {
      if (child is List<dynamic> || child is Map) collectMarks(child, result);
    }
  }

  Future<Map> marks() async {
    final terms = array(await gateway('terms', {}, true));
    Map? selected;
    final now = DateTime.parse(requiredString(input['now']));
    for (final row in terms) {
      final term = object(row);
      if (input['termId'] != null) {
        if (identity(term['id']) == identity(input['termId'])) selected = term;
      } else {
        final from = DateTime.tryParse(string(term['dateFrom']));
        final to = DateTime.tryParse(string(term['dateTo']));
        if (from != null &&
            to != null &&
            !now.isBefore(from) &&
            day(now).compareTo(day(to)) <= 0 &&
            (selected == null || !flag(term['isYear'])))
          selected = term;
      }
    }
    if (selected == null) throw 'module_unavailable';
    final selectedId = identity(selected['id']);
    var semester = 0;
    final selectedFrom = DateTime.tryParse(string(selected['dateFrom']));
    if (!flag(selected['isYear']) && selectedFrom != null) {
      semester = 1;
      for (final row in terms) {
        final term = object(row);
        final from = DateTime.tryParse(string(term['dateFrom']));
        if (!flag(term['isYear']) &&
            term['parentId'] == selected['parentId'] &&
            from != null &&
            from.isBefore(selectedFrom))
          semester++;
      }
    }
    final raw = object(await gateway('marks', {'termId': selectedId}, true));
    final subjects = values(raw['subjects']);
    final Map names = {};
    for (final row in subjects) {
      final s = object(row);
      names[identity(s['id'])] = string(s['label'] ?? s['name']);
    }
    final List<dynamic> marks = [];
    collectMarks(raw['grades'], marks);
    if (marks.isEmpty && values(raw['grades']).isNotEmpty)
      throw 'protocol_error';
    final List<dynamic> items = [];
    for (final entry in marks) {
      final value = object(entry);
      final name = string(value['subject_name']);
      final subject = name.isNotEmpty
          ? name
          : requiredString(names[identity(value['subjectId'])]);
      items.add(
        grade(
          jsonEncode(value),
          '$selectedId/${identity(value['id'])}',
          subject,
          semester,
          false,
          'current',
        ),
      );
    }
    return module(items, {
      'terms': terms,
      'selectedTerm': selected,
      'grid': raw,
    });
  }

  Future<Map> timetable() async {
    final raw = await gateway('timetable-events', {
      'dateFrom': requiredString(input['dateFrom']),
      'dateTo': requiredString(input['dateTo']),
    }, true);
    return module(
      rows(raw).map((r) {
        final value = object(r);
        return {
          'id': identity(value['id']),
          'subject': string(value['subjectName'] ?? 'Brak nazwy'),
          'teacher': array(value['teachers'] ?? [])
              .map((t) => senderName(t))
              .join(', '),
          'room': string(value['room'] ?? value['roomName']),
          'start': date(value['dateTimeFrom'] ?? value['startTime']),
          'end': date(value['dateTimeTo'] ?? value['endTime']),
          'cancelled': flag(value['isCanceled']),
          'substitution': flag(value['substitution']),
          'originalSubject': string(value['oldSubjectName']),
        };
      }).toList(),
      raw,
    );
  }

  Future<Map> attendance() async {
    final raw = object(await gateway('attendance-stats', {}, true));
    final Map names = {};
    for (final row in values(raw['subjects'])) {
      final s = object(row);
      names[identity(s['id'])] = string(s['label'] ?? s['name']);
    }
    final List<dynamic> items = [];
    final Map duplicates = {};
    for (final row in array(raw['records'])) {
      final value = object(row);
      final key = jsonEncode([
        value['d'],
        value['sid'],
        value['ab'],
        value['ca'],
        value['tn'],
      ]);
      final n = (duplicates[key] ?? 0) + 1;
      duplicates[key] = n;
      items.add({
        'id': '$key/$n',
        'date': date(value['d']),
        'lessonNumber': 0,
        'subject': string(names[identity(value['sid'])]),
        'type': string(value['ca'] ?? value['ab']),
        'symbol': requiredString(value['ab']),
        'kind': 'other',
      });
    }
    final value = module(items, raw);
    value['complete'] = false;
    return value;
  }

  Future<Map> events(String view, String kind) async {
    final raw = object(await gateway(view, {}, true));
    return module(
      array(raw['items']).map((r) {
        final value = object(r);
        return {
          'id': identity(value['id']),
          'title': string(value['title'] ?? value['name']),
          'subject': string(value['subjectName'] ?? value['subject_name']),
          'date': date(value['dateTime'] ?? value['date']),
          'kind': kind,
          'description': string(value['description'] ?? value['content']),
          'typeLabel': string(value['test_type']),
        };
      }).toList(),
      raw,
    );
  }

  Future<Map> notices() async {
    final raw = object(await gateway('reprimands', {'limit': '100'}, true));
    return module(
      array(raw['items']).map((r) {
        final value = object(r);
        return {
          'id': identity(value['id']),
          'text': string(value['content']),
          'category': string(value['kind']),
          'teacher': string(value['teacherName']),
          'date': date(value['getDate']),
          'tone': 'neutral',
        };
      }).toList(),
      raw,
    );
  }

  Future<Map> announcements() async {
    final raw = await gateway('announcements', {}, true);
    return module(
      rows(raw).map((r) {
        final value = object(r);
        return {
          'id': identity(value['id']),
          'title': string(value['title']),
          'content': string(value['content']),
          'author': senderName(value['author'] ?? value['login']),
          'createdAt': date(value['dateTime']),
          'validUntil': null,
          'read': flag(value['read']) || flag(value['xread']),
        };
      }).toList(),
      raw,
    );
  }

  String mailBase() {
    final url = baseUrl(session['messagingUrl']);
    return url.endsWith('/sso') ? url.substring(0, url.length - 4) : url;
  }

  Future<void> mailLogin() async {
    final url = baseUrl(session['messagingUrl']);
    final response = await transport(
      http,
      'GET',
      '$url/${part(requiredString(session['school']))}/${part(requiredString(session['messagesToken']))}',
      {'Accept': 'text/html', 'User-Agent': agent},
      null,
      false,
    );
    final status = response['status'];
    if (status is! int || status < 200 || status > 399) throw 'session_expired';
    final headers = object(response['headers']);
    final List<dynamic> cookies = [];
    for (final key in headers.keys) {
      if (string(key).toLowerCase() == 'set-cookie') {
        for (final value in array(headers[key])) {
          final pair = requiredString(value).split(';').first;
          if (pair.contains('=')) cookies.add(pair);
        }
      }
    }
    if (cookies.isEmpty) throw 'module_unavailable';
    session['mailCookie'] = cookies.join('; ');
  }

  Future<dynamic> mailCall(
    String path,
    String method,
    dynamic body,
    bool safe,
  ) async {
    if (string(session['messagingUrl']).isEmpty ||
        string(session['messagesToken']).isEmpty)
      throw 'module_unavailable';
    if (string(session['mailCookie']).isEmpty) await mailLogin();
    final headers = jsonHeaders();
    headers['Cookie'] = requiredString(session['mailCookie']);
    Map response = await transport(
      http,
      method,
      '${mailBase()}$path',
      headers,
      jsonEncode(body),
      method != 'GET',
    );
    if ((response['status'] == 401 || response['status'] == 403) && safe) {
      await mailLogin();
      headers['Cookie'] = requiredString(session['mailCookie']);
      response = await transport(
        http,
        method,
        '${mailBase()}$path',
        headers,
        jsonEncode(body),
        method != 'GET',
      );
    }
    checkStatus(response);
    return jsonDecode(requiredString(response['body']));
  }

  Future<Map> mail() async {
    final folder = string(input['folder'] ?? 'inbox');
    if (!['inbox', 'sent', 'trash', 'important'].contains(folder))
      throw 'invalid_input';
    final skip = input['page'] ?? 0;
    if (skip is! int || skip < 0) throw 'invalid_input';
    final raw = object(
      await mailCall('/api/messages/$folder', 'POST', {
        'limit': 20,
        'skip': skip,
      }, true),
    );
    final entries = array(raw['items']);
    final total = raw['total'];
    if (total is! num) throw 'protocol_error';
    final value = module(
      entries
          .map((r) => message(jsonEncode(r), folder == 'sent', false))
          .toList(),
      raw,
    );
    value['nextCursor'] = skip + entries.length < total
        ? skip + entries.length
        : null;
    return value;
  }

  Future<dynamic> operation(String op) async {
    if (op == 'authenticate') {
      final server = baseUrl(input['server']);
      final school = requiredString(input['school']).trim();
      if (school.isEmpty || school.contains('/') || school.contains('\\'))
        throw 'invalid_input';
      session = {
        'server': server,
        'school': school,
        'username': requiredString(input['username']).trim(),
        'password': requiredString(input['password']),
        'origins': [origin(server)],
      };
      await login();
      return {'owner': '$server/$school\n${session['username']}'};
    }
    if (op == 'refresh') {
      await login();
      return null;
    }
    if (op == 'accounts') return await accounts();
    if (op == 'terms') return await gateway('terms', {}, true);
    if (op == 'timetable') return await timetable();
    if (op == 'messages') return await mail();
    if (op == 'recipients') {
      final raw = await mailCall('/api/messages/receivers/search', 'POST', {
        'query': string(input['query']),
        'ids': [],
      }, true);
      final entries = raw is List<dynamic> ? raw : array(object(raw)['users']);
      return entries.map((r) {
        final value = object(r);
        var id = identity(value['id']);
        if (RegExp(r'^\d+$').hasMatch(id)) id = 'user_$id';
        return {
          'id': id,
          'name': requiredString(value['name']),
          'group': string(value['role'] ?? value['_type']),
        };
      }).toList();
    }
    if (op == 'message')
      return message(
        jsonEncode(
          await mailCall(
            '/api/messages/read/${part(identity(input['id']))}',
            'GET',
            null,
            true,
          ),
        ),
        flag(input['sent']),
        false,
      );
    if (op == 'sendMessage') {
      final recipients = array(input['recipients']);
      if (recipients.isEmpty) throw 'invalid_input';
      final value = object(
        await mailCall('/api/messages', 'PUT', {
          'title': requiredString(input['subject']),
          'content': requiredString(input['body']),
          'odbiorcy': recipients,
        }, false),
      );
      return {'id': identity(value['id'])};
    }
    if (op == 'justifications') {
      final headers = jsonHeaders();
      headers['Authorization'] = 'Bearer ${requiredString(session['token'])}';
      final response = await transport(
        http,
        'GET',
        '${schoolBase()}/api/justifications?pupil_id=${part(identity(input['pupilId']))}',
        headers,
        null,
        false,
      );
      checkStatus(response);
      final value = jsonDecode(requiredString(response['body']));
      return value is Map && value.containsKey('v') ? value['data'] : value;
    }
    if (op == 'grades') return await marks();
    if (op == 'attendance') return await attendance();
    if (op == 'homework') {
      if (string(session['homeworksUrl']).isNotEmpty)
        throw 'module_unavailable';
      return await events('homeworks', 'homework');
    }
    if (op == 'events') return await events('tests', 'exam');
    if (op == 'notices') return await notices();
    if (op == 'announcements') return await announcements();
    throw 'unsupported_operation';
  }
}

Future<String> main(String request, Function callback) async {
  final value = object(jsonDecode(request));
  final provider = MobiReg(
    object(value['state']),
    object(value['input']),
    callback,
  );
  final data = await provider.operation(requiredString(value['operation']));
  return jsonEncode(result(data, provider.session));
}
