import 'dart:convert';

import 'package:diary_sdk/protocol.dart';

const apiBase = 'https://api.librus.pl/2.0';
const tokenUrl = 'https://api.librus.pl/OAuth/Token';
// Public legacy OAuth client identifier, as documented by Szkolny.eu.
const clientAuthorization = 'Mjg6ODRmZGQzYTg3YjAzZDNlYTZmZmU3NzdiNThiMzMyYjE=';

String ref(dynamic value) {
  if (value == null) return '';
  if (value is Map) {
    final row = object(value);
    return string(row['Id'] ?? '');
  }
  return string(value);
}

String fullName(String rawJson) {
  if (rawJson == 'null') return '';
  final value = object(jsonDecode(rawJson));
  final first = string(value['FirstName'] ?? '');
  final last = string(value['LastName'] ?? '');
  return '$first $last'.trim();
}

String stamp(dynamic value) {
  final raw = requiredString(string(value));
  final unix = int.tryParse(raw);
  if (unix != null) {
    final epoch = DateTime.parse('1970-01-01T00:00:00Z');
    final seconds = Duration(seconds: unix);
    final value = epoch.add(seconds);
    return value.toIso8601String();
  }
  return DateTime.parse(raw).toIso8601String();
}

String contentText(dynamic value) {
  final text = string(value);
  // Synergia JSON-encodes Subject/Body strings inside its JSON response.
  if (text.startsWith('"') && text.endsWith('"'))
    return requiredString(jsonDecode(text));
  return text;
}

int semester(dynamic value) {
  if (value is Map) return int.tryParse(string(value['Number'])) ?? 1;
  return int.tryParse(string(value)) ?? 1;
}

Map indexed(dynamic values) {
  final Map result = {};
  for (final raw in array(values)) {
    final row = object(raw);
    result[identity(row['Id'])] = row;
  }
  return result;
}

String named(String rawValue, String rawReferences) {
  final value = jsonDecode(rawValue);
  final references = object(jsonDecode(rawReferences));
  if (value is Map) {
    final row = object(value);
    final name = string(row['Name'] ?? '');
    if (name.isNotEmpty) return name;
  }
  final key = ref(value);
  final raw = references[key];
  if (raw == null) return '';
  final entry = object(raw);
  return string(entry['Name'] ?? '');
}

class Legacy {
  Legacy(this.session, this.input, this.http);
  Map session;
  final Map input;
  final Function http;

  bool expired() {
    final expiry = int.tryParse(string(session['expiresAtMs']));
    final now = DateTime.now();
    return expiry != null && expiry <= now.millisecondsSinceEpoch + 30000;
  }

  Future<void> token(bool refresh) async {
    final Map fields = {
      'grant_type': refresh ? 'refresh_token' : 'password',
      'librus_long_term_token': '1',
    };
    if (refresh) {
      final saved = string(session['refreshToken']);
      if (saved.isEmpty) throw 'session_expired';
      fields['refresh_token'] = saved;
    } else {
      fields['username'] = requiredString(session['username']);
      fields['password'] = requiredString(input['password']);
    }
    final body = fields.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(string(e.value))}',
        )
        .join('&');
    final response = await transport(
      http,
      'POST',
      tokenUrl,
      {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic $clientAuthorization',
      },
      body,
      true,
    );
    final root = object(jsonDecode(requiredString(response['body'])));
    if (response['status'] != 200) {
      final code = string(root['error']);
      if (code == 'invalid_grant') {
        if (refresh) throw 'session_expired';
        throw 'invalid_credentials';
      }
      if ([
        'librus_captcha_needed',
        'librus_reg_accept_needed',
        'librus_change_password_error',
        'librus_password_change_required',
      ].contains(code))
        throw 'account_action_required';
      throw 'server_error';
    }
    final access = requiredString(root['access_token']);
    final renew = string(root['refresh_token']);
    final seconds = int.tryParse(string(root['expires_in']));
    if (seconds == null || seconds <= 0) throw 'protocol_error';
    session['accessToken'] = access;
    if (renew.isNotEmpty) session['refreshToken'] = renew;
    final now = DateTime.now();
    session['expiresAtMs'] = now.millisecondsSinceEpoch + seconds * 1000;
  }

  Future<Map> api(String path, String method, dynamic body) async {
    if (expired()) throw 'session_expired';
    final response = await transport(
      http,
      method,
      '$apiBase/$path',
      {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${requiredString(session['accessToken'])}',
      },
      jsonEncode(body),
      method == 'POST' || method == 'PUT',
    );
    if (response['status'] == 403 || response['status'] == 404)
      throw 'module_unavailable';
    checkStatus(response);
    if (response['status'] == 204) return {};
    return object(jsonDecode(requiredString(response['body'])));
  }

  Future<List<dynamic>> rows(String path, String key) async {
    final root = await api(path, 'GET', null);
    return array(root[key]);
  }

  Future<Map> identify() async {
    final root = await api('Me', 'GET', null);
    final me = object(root['Me']);
    final account = object(me['Account']);
    final user = object(me['User']);
    final group = int.tryParse(string(account['GroupId']));
    // API groups, never the optional "u" suffix. Reject unverified roles.
    if (group != 8 && group != 5 && group != 6)
      throw 'unsupported_account_role';
    final owner = identity(account['Id']);
    final pupil = identity(user['Id']);
    if (session['accountId'] != null && session['accountId'] != owner)
      throw 'session_expired';
    if (session['pupilId'] != null && session['pupilId'] != pupil)
      throw 'session_expired';
    session['accountId'] = owner;
    session['pupilId'] = pupil;
    session['parent'] = group == 5 || group == 6;
    session['name'] = requiredString(fullName(jsonEncode(user)));
    return me;
  }

  Future<List<dynamic>> accounts() async {
    await identify();
    final root = await api('Schools', 'GET', null);
    final school = object(root['School']);
    return [
      {
        'id': requiredString(session['pupilId']),
        'name': requiredString(session['name']),
        'school': string(school['Name']),
        'parent': session['parent'] == true,
      },
    ];
  }

  Future<Map> grades() async {
    final raw = await rows('Grades', 'Grades');
    final subjects = indexed(await rows('Subjects', 'Subjects'));
    final categories = indexed(await rows('Grades/Categories', 'Categories'));
    final List<dynamic> items = [];
    for (final value in raw) {
      final row = object(value);
      final category = object(categories[ref(row['Category'])] ?? {});
      String assessment = 'current';
      if (flag(row['IsProposition'])) assessment = 'proposed';
      if (flag(row['IsFinalProposition'])) assessment = 'proposed';
      if (flag(row['IsSemesterProposition'])) assessment = 'proposed';
      if (flag(row['IsFinal'])) assessment = 'final';
      if (flag(row['IsSemester'])) assessment = 'final';
      final weight = double.tryParse(string(category['Weight']));
      final comments = row['Comments'];
      final List<dynamic> details = [];
      if (comments is List) {
        for (final rawComment in comments) {
          final comment = object(rawComment);
          if (string(comment['Text']).isNotEmpty)
            details.add(string(comment['Text']));
        }
      }
      items.add({
        'id': identity(row['Id']),
        'subject': named(jsonEncode(row['Subject']), jsonEncode(subjects)),
        'value': string(row['Grade']),
        'description': details.join('\n'),
        'date': stamp(row['AddDate']),
        'weight': weight ?? 0,
        'semester': semester(row['Semester']),
        'category': string(category['Name']),
        'assessment': assessment,
        'countsToAverage':
            assessment == 'current' &&
            weight != null &&
            weight > 0 &&
            (category['CountToTheAverage'] == null ||
                flag(category['CountToTheAverage'])),
      });
    }
    return module(items, raw);
  }

  Future<Map> timetable() async {
    final from = DateTime.parse(requiredString(input['dateFrom']));
    final monday = DateTime(from.year, from.month, from.day - from.weekday + 1);
    final root = await api('Timetables?weekStart=${day(monday)}', 'GET', null);
    final plan = object(root['Timetable']);
    final subjects = indexed(await rows('Subjects', 'Subjects'));
    final users = indexed(await rows('Users', 'Users'));
    final rooms = indexed(await rows('Classrooms', 'Classrooms'));
    final List<dynamic> items = [];
    for (final entry in plan.entries) {
      for (final slot in array(entry.value)) {
        for (final value in array(slot)) {
          final row = object(value);
          final teacher = users[ref(row['Teacher'])];
          final id = row['Id'] == null
              ? '${ref(row['Subject'])}:${ref(row['Teacher'])}:${ref(row['Classroom'])}:${string(row['Number'])}'
              : identity(row['Id']);
          items.add({
            'id': '$id:${entry.key}:${string(row['HourFrom'])}',
            'subject': named(jsonEncode(row['Subject']), jsonEncode(subjects)),
            'teacher': fullName(jsonEncode(teacher)),
            'room': named(jsonEncode(row['Classroom']), jsonEncode(rooms)),
            'start': stamp('${entry.key}T${requiredString(row['HourFrom'])}'),
            'end': stamp('${entry.key}T${requiredString(row['HourTo'])}'),
            'cancelled': flag(row['IsCanceled']),
            'substitution': flag(row['IsSubstitutionClass']),
            'originalSubject': named(
              jsonEncode(row['OrgSubject']),
              jsonEncode(subjects),
            ),
            'originalTeacher': fullName(
              jsonEncode(users[ref(row['OrgTeacher'])]),
            ),
            'originalRoom': named(
              jsonEncode(row['OrgClassroom']),
              jsonEncode(rooms),
            ),
            'number': int.tryParse(string(row['LessonNo'] ?? row['Number'])),
          });
        }
      }
    }
    return module(items, root);
  }

  Future<Map> events(bool homework) async {
    final key = homework ? 'HomeWorkAssignments' : 'HomeWorks';
    final raw = await rows(key, key);
    final subjects = indexed(await rows('Subjects', 'Subjects'));
    final List<dynamic> items = [];
    for (final value in raw) {
      final row = object(value);
      final lesson = row['Lesson'];
      final subject =
          row['Subject'] ?? (lesson is Map ? lesson['Subject'] : null);
      final title = homework ? string(row['Topic']) : string(row['Content']);
      items.add({
        'id': identity(row['Id']),
        'title': title.isEmpty ? string(row['Text']) : title,
        'subject': named(jsonEncode(subject), jsonEncode(subjects)),
        'date': stamp(row[homework ? 'DueDate' : 'Date']),
        'kind': homework ? 'homework' : 'exam',
        'typeLabel': '',
        'description': homework ? string(row['Text']) : '',
        'lessonNumber': int.tryParse(string(row['LessonNo'])),
      });
    }
    return module(items, raw);
  }

  Future<Map> attendance() async {
    final raw = await rows('Attendances', 'Attendances');
    final types = indexed(await rows('Attendances/Types', 'Types'));
    final subjects = indexed(await rows('Subjects', 'Subjects'));
    final List<dynamic> items = [];
    for (final value in raw) {
      final row = object(value);
      final type = object(types[ref(row['Type'])] ?? row['Type']);
      final standard =
          int.tryParse(ref(type['StandardType'])) ?? int.tryParse(ref(type));
      if (standard != 100) {
        final name = string(type['Name']);
        final lower = name.toLowerCase();
        final excused = lower.contains('uspraw') || lower.contains('excused');
        String kind = 'other';
        if (standard == 1)
          kind = excused ? 'absentExcused' : 'absent';
        else if (standard == 2)
          kind = excused ? 'lateExcused' : 'late';
        else if (standard == 3)
          kind = 'absentExcused';
        else if (standard == 4)
          kind = 'released';
        else if (flag(type['Standard']))
          kind = 'present';
        final lesson = row['Lesson'];
        final subject =
            row['Subject'] ?? (lesson is Map ? lesson['Subject'] : null);
        items.add({
          'id': identity(row['Id']),
          'date': stamp(row['Date']),
          'lessonNumber': int.tryParse(string(row['LessonNo'])) ?? 0,
          'subject': named(jsonEncode(subject), jsonEncode(subjects)),
          'type': name,
          'symbol': string(type['Short']),
          'kind': kind,
          'semester': semester(row['Semester']),
        });
      }
    }
    final result = module(items, raw);
    result['complete'] = false;
    return result;
  }

  Future<Map> notices(bool announcement) async {
    final key = announcement ? 'SchoolNotices' : 'Notes';
    final raw = await rows(key, key);
    final users = indexed(await rows('Users', 'Users'));
    final Map categories = announcement
        ? {}
        : indexed(await rows('Notes/Categories', 'Categories'));
    final List<dynamic> items = [];
    for (final value in raw) {
      final row = object(value);
      if (announcement) {
        final Map item = {
          'id': identity(row['Id']),
          'title': string(row['Subject']),
          'content': string(row['Content']),
          'author': fullName(jsonEncode(users[ref(row['AddedBy'])])),
          'createdAt': stamp(row['CreationDate'] ?? row['StartDate']),
          'validUntil': row['EndDate'],
          'read': flag(row['WasRead']),
        };
        if (row['EndDate'] != null) item['validUntil'] = stamp(row['EndDate']);
        items.add(item);
      } else {
        final positive = int.tryParse(string(row['Positive']));
        items.add({
          'id': identity(row['Id']),
          'text': string(row['Text']),
          'date': stamp(row['Date']),
          'teacher': fullName(jsonEncode(users[ref(row['Teacher'])])),
          'category': named(
            jsonEncode(row['Category']),
            jsonEncode(categories),
          ),
          'tone': positive == 1
              ? 'positive'
              : positive == 0
              ? 'negative'
              : 'neutral',
        });
      }
    }
    return module(items, raw);
  }

  Map mailRow(String rawJson, bool sent, Map users) {
    final row = object(jsonDecode(rawJson));
    final sender = row['Sender'];
    final List<dynamic> receivers = array(row['Receivers'] ?? []);
    final List<dynamic> readDates = array(row['ReadDates'] ?? []);
    final List<dynamic> names = [];
    for (final receiver in receivers) {
      final value = receiver is Map ? receiver : users[ref(receiver)];
      final name = fullName(jsonEncode(value));
      if (name.isNotEmpty) names.add(name);
    }
    dynamic senderValue = users[ref(sender)];
    if (sender is Map) {
      final row = object(sender);
      if (row['FirstName'] != null) senderValue = row;
    }
    final senderLabel = fullName(jsonEncode(senderValue));
    final files = array(row['MessageFiles'] ?? []);
    bool unread = flag(row['IsNew']);
    if (readDates.length > 0)
      unread = string(object(readDates[0])['ReadDate']) == '0';
    return {
      'id': identity(row['Id']),
      'sender': senderLabel,
      'subject': contentText(row['Subject']),
      'preview': contentText(row['Body']),
      'body': contentText(row['Body']),
      'receivedAt': stamp(row['SendDate']),
      'unread': !sent && unread,
      'sent': sent,
      'recipients': names,
      'hasAttachments':
          flag(row['AddedFiles']) ||
          flag(row['HasAttachment']) ||
          files.length > 0,
      'raw': row,
    };
  }

  Future<Map> messages() async {
    final sent = string(input['folder'] ?? 'inbox') == 'sent';
    final page = input['page'] ?? 1;
    if (page is! int || page < 1) throw 'invalid_input';
    final filter = sent ? '&inSended=1' : '';
    final raw = await rows(
      'Messages?alternativeBody=true&changeNewLine=1&afterId=0&limit=50&page=$page$filter',
      'Messages',
    );
    final users = indexed(await rows('Messages/User', 'Users'));
    final List<dynamic> items = [];
    for (final value in raw) items.add(mailRow(jsonEncode(value), sent, users));
    final result = module(items, {});
    if (raw.length == 50) result['nextCursor'] = page + 1;
    return result;
  }

  Future<dynamic> operation(String op) async {
    if (op == 'authenticate') {
      final username = string(input['username']).trim().toLowerCase();
      final digits = username.endsWith('u')
          ? username.substring(0, username.length - 1)
          : username;
      if (digits.isEmpty) throw 'invalid_synergia_login';
      for (final char in digits.split('')) {
        if (!'0123456789'.contains(char)) throw 'invalid_synergia_login';
      }
      session = {
        'username': username,
        'origins': ['https://api.librus.pl'],
      };
      await token(false);
      await identify();
      return {'owner': 'legacy:${requiredString(session['accountId'])}'};
    }
    if (op == 'refresh') {
      await token(true);
      return null;
    }
    if (op == 'prepare') {
      if (expired()) await token(true);
      return null;
    }
    if (op == 'accounts') return await accounts();
    if (identity(input['pupilId']) != requiredString(session['pupilId']))
      throw 'invalid_input';
    if (op == 'grades') return await grades();
    if (op == 'timetable') return await timetable();
    if (op == 'events') return await events(false);
    if (op == 'homework') return await events(true);
    if (op == 'attendance') return await attendance();
    if (op == 'announcements') return await notices(true);
    if (op == 'notices') return await notices(false);
    if (op == 'luckyNumbers') {
      final root = await api('LuckyNumbers', 'GET', null);
      final value = root['LuckyNumber'];
      final List<dynamic> items = [];
      if (value is Map) {
        final n = int.tryParse(string(value['LuckyNumber']));
        if (n != null && n > 0)
          items.add({
            'number': n,
            'day': requiredString(value['LuckyNumberDay']),
          });
      }
      return module(items, root);
    }
    if (op == 'messages') return await messages();
    if (op == 'message') {
      final root = await api(
        'Messages/${part(identity(input['id']))}?alternativeBody=true&changeNewLine=1',
        'GET',
        null,
      );
      final users = indexed(await rows('Messages/User', 'Users'));
      return mailRow(jsonEncode(root['Message']), flag(input['sent']), users);
    }
    if (op == 'recipients') {
      final raw = await rows('Messages/User', 'Users');
      final List<dynamic> items = [];
      for (final value in raw) {
        final row = object(value);
        items.add({
          'id': identity(row['Id']),
          'name': requiredString(fullName(jsonEncode(row))),
          'group': '',
        });
      }
      return items;
    }
    if (op == 'sendMessage') {
      final receivers = array(input['recipients']);
      if (receivers.length == 0) throw 'invalid_input';
      final root = await api('Messages', 'POST', {
        'subject': requiredString(input['subject']),
        'body': requiredString(input['body']),
        'receivers': receivers,
      });
      final value = root['Message'];
      return {'id': identity(value is Map ? value['Id'] : root['Id'])};
    }
    if (op == 'deleteMessage') {
      await api('Messages/${part(identity(input['id']))}', 'PUT', {
        'action': 'delete',
      });
      return {'deleted': true};
    }
    throw 'unsupported_operation';
  }
}

Future<String> main(String request, Function callback) async {
  final value = object(jsonDecode(request));
  final provider = Legacy(
    object(value['state']),
    object(value['input']),
    callback,
  );
  final data = await provider.operation(requiredString(value['operation']));
  return jsonEncode(result(data, provider.session));
}
