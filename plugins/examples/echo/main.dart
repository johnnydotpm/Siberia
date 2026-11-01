// SDK fixture, never a selectable diary or a source of school data.
// All input/output uses JSON strings; the host provides the HTTP callback.
import 'dart:convert';

Future<String> main(String requestJson, Function http) async {
  final request = jsonDecode(requestJson);
  return jsonEncode({'data': request['input'], 'state': request['state']});
}
