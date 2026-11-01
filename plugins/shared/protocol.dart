import 'dart:convert';

Map object(dynamic value) {
  if (value is! Map) throw 'protocol_error';
  return value;
}

List<dynamic> array(dynamic value) {
  if (value is! List<dynamic>) throw 'protocol_error';
  return value;
}

String string(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num || value is bool) return jsonEncode(value);
  throw 'protocol_error';
}

String requiredString(dynamic value) {
  if (value is! String || value.isEmpty) throw 'protocol_error';
  return value;
}

String identity(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  if (value is int) return jsonEncode(value);
  throw 'protocol_error';
}

bool flag(dynamic value) => value == true || value == 1 || value == '1';
String date(dynamic value) =>
    DateTime.parse(requiredString(value)).toIso8601String();
String day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String part(String value) => Uri.encodeComponent(value);
String origin(String value) {
  final uri = Uri.parse(value);
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.port != 443)
    throw 'invalid_origin';
  return uri.origin;
}

String baseUrl(dynamic value) {
  final raw = requiredString(value);
  origin(raw);
  final uri = Uri.parse(raw);
  if (uri.hasQuery) throw 'invalid_origin';
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}

Future<Map> transport(
  Function http,
  String method,
  String url,
  Map headers,
  dynamic body,
  bool includeBody,
) async {
  final Map request = {'method': method, 'url': url, 'headers': headers};
  if (includeBody) request['body'] = body;
  return object(jsonDecode(await http(jsonEncode(request))));
}

void checkStatus(Map response) {
  final status = response['status'];
  if (status == 401 || status == 403) throw 'session_expired';
  if (status == 426) throw 'unsupported_version';
  if (status is! int || status < 200 || status >= 300) throw 'server_error';
}

String errorCode(dynamic error) {
  if (error is! String) return 'protocol_error';
  final text = requiredString(error);
  const known = [
    'protocol_error',
    'invalid_origin',
    'session_expired',
    'invalid_credentials',
    'unsupported_version',
    'server_error',
    'unsupported_operation',
    'module_unavailable',
    'invalid_input',
    'page_limit',
  ];
  return known.contains(text) ? text : 'protocol_error';
}

Map result(dynamic data, Map state) => {'data': data, 'state': state};
Map failure(dynamic error) => {
  'error': {'code': errorCode(error)},
  'state': {},
};
Map module(List<dynamic> items, dynamic raw) => {
  'items': items,
  'metadata': raw,
};
String senderName(dynamic raw) {
  if (raw is Map) return string(raw['name'] ?? raw['full_name']);
  return string(raw);
}

Map message(String rawJson, bool sent, bool fryderyk) {
  final raw = object(jsonDecode(rawJson));
  final recipients = array(
    raw[fryderyk ? 'recipients_v2' : 'recipients'] ?? [],
  );
  final attachments = array(raw[fryderyk ? 'attachments' : 'files'] ?? []);
  final body = string(raw['content']);
  return {
    'id': identity(raw['id']),
    'subject': string(raw['subject']),
    'sender': senderName(raw[fryderyk ? 'sender' : 'author']),
    'preview': body,
    'body': body,
    'receivedAt': date(raw[fryderyk ? 'sent_date' : 'date']),
    'unread': fryderyk ? !flag(raw['is_read']) : raw['read_at'] == null,
    'sent': sent,
    'hasAttachments': attachments.length > 0,
    'recipients': recipients.map((r) => senderName(r)).toList(),
    'attachments': attachments
        .map(
          (a) => {
            'id': identity(object(a)['id']),
            'name': requiredString(a['name']),
            'url': requiredString(a['url']),
          },
        )
        .toList(),
    'raw': raw,
  };
}

Map grade(
  String rawJson,
  String id,
  String subject,
  int semester,
  bool fryderyk,
  String assessment,
) {
  final raw = object(jsonDecode(rawJson));
  final weight = double.tryParse(string(raw['weight']));
  final counts = raw['count_to_avg'] ?? raw['countToAvg'];
  return {
    'id': id,
    'subject': subject,
    'value': string(raw[fryderyk ? 'text_value' : 'value']),
    'description': string(raw[fryderyk ? 'comment' : 'description']),
    'date': date(raw[fryderyk ? 'created' : 'date']),
    'weight': weight != null && weight > 0 ? weight : 0,
    'semester': semester,
    'category': string(raw[fryderyk ? 'name' : 'kindLabel']),
    'countsToAverage':
        assessment == 'current' && (counts == null || flag(counts)),
    'assessment': assessment,
  };
}
