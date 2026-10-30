import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'package:dio/dio.dart';

import 'manifest.dart';
import 'plugin_store.dart';

/// One invocation has no global state. The application owns and securely saves
/// the returned auth state per provider/tenant/account, outside this runtime.
class PluginResult {
  const PluginResult(this.data, this.state);
  final Object? data;
  final Map<String, dynamic> state;
}

/// Interprets precompiled bytecode; does not download native code or use a JIT.
/// Each invocation runs in a killable isolate, with no VM resource permissions.
/// Only the host callback can issue HTTP, to exact manifest-declared origins.
class PluginRuntime {
  PluginRuntime({Dio? client})
    : _client =
          client ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  final Dio _client;
  static const maxJsonBytes = 1024 * 1024;

  Future<PluginResult> invoke(
    InstalledPlugin plugin, {
    required String operation,
    Map<String, Object?> input = const {},
    Map<String, Object?> state = const {},
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (!plugin.manifest.operations.contains(operation)) {
      throw const PluginException('unsupported_operation');
    }
    final request = jsonEncode({
      'operation': operation,
      'input': input,
      'state': state,
    });
    if (utf8.encode(request).length > maxJsonBytes) {
      throw const PluginException('input_too_large');
    }
    final events = ReceivePort();
    final done = Completer<PluginResult>();
    // A very short deadline can elapse while Isolate.spawn is still starting.
    // Attach an error listener now; the caller still awaits the same future.
    done.future.ignore();
    final cancel = CancelToken();
    SendPort? replies;
    var requests = 0;
    Isolate? isolate;
    void fail(String code) {
      if (!done.isCompleted) done.completeError(PluginException(code));
    }

    final subscription = events.listen((dynamic event) async {
      if (done.isCompleted) return;
      if (event is SendPort) {
        replies = event;
      } else if (event is List && event.length == 3 && event[0] == 'http') {
        if (++requests > 64 || event[1] is! int || event[2] is! String) {
          fail('too_many_requests');
          return;
        }
        try {
          final response = await _http(
            plugin.manifest,
            event[2] as String,
            cancel,
          );
          if (!done.isCompleted) replies?.send([event[1], true, response]);
        } on Object {
          // Fail closed: plugins cannot turn a denied request into empty data.
          fail('http_failed');
        }
      } else if (event is List && event.length == 2 && event[0] == 'result') {
        try {
          final raw = event[1];
          if (raw is! String || utf8.encode(raw).length > maxJsonBytes) {
            throw const PluginException('invalid_result');
          }
          final result = jsonDecode(raw);
          if (result is! Map<String, dynamic> ||
              !result.containsKey('data') ||
              result['state'] is! Map<String, dynamic>) {
            throw const PluginException('invalid_result');
          }
          done.complete(
            PluginResult(
              result['data'],
              result['state'] as Map<String, dynamic>,
            ),
          );
        } on Object {
          fail('invalid_result');
        }
      } else {
        fail('execution_failed');
      }
    });
    final timer = Timer(timeout, () => fail('execution_timeout'));
    try {
      isolate = await Isolate.spawn(
        _execute,
        [events.sendPort, plugin.bytecode, request],
        onError: events.sendPort,
        onExit: events.sendPort,
        errorsAreFatal: true,
      );
      return await done.future;
    } finally {
      timer.cancel();
      cancel.cancel();
      isolate?.kill(priority: Isolate.immediate);
      await subscription.cancel();
      events.close();
    }
  }

  Future<String> _http(
    PluginManifest manifest,
    String raw,
    CancelToken cancel,
  ) async {
    if (utf8.encode(raw).length > maxJsonBytes) {
      throw const PluginException('http_request_too_large');
    }
    final request = jsonDecode(raw);
    if (request is! Map<String, dynamic>) {
      throw const PluginException('invalid_http_request');
    }
    final uri = Uri.tryParse(request['url'] as String? ?? '');
    final method = request['method'];
    final headers = request['headers'] ?? <String, String>{};
    final body = request['body'];
    if (uri == null ||
        !isPluginHttpsUri(uri) ||
        !manifest.origins.contains(uri.origin) ||
        !const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method) ||
        headers is! Map<String, dynamic> ||
        headers.length > 32 ||
        headers.entries.any(
          (entry) =>
              entry.value is! String ||
              !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(entry.key) ||
              const {
                'host',
                'connection',
                'content-length',
                'transfer-encoding',
                'proxy-authorization',
              }.contains(entry.key.toLowerCase()) ||
              (entry.value as String).contains(RegExp(r'[\r\n]')),
        ) ||
        (body != null && body is! String)) {
      throw const PluginException('http_denied');
    }
    final response = await _client.request<ResponseBody>(
      uri.toString(),
      data: body,
      cancelToken: cancel,
      options: Options(
        method: method as String,
        headers: headers,
        responseType: ResponseType.stream,
        followRedirects: false,
        maxRedirects: 0,
        validateStatus: (_) => true,
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final data = response.data;
    if (data == null) throw const PluginException('empty_http_response');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in data.stream.timeout(
      const Duration(seconds: 15),
    )) {
      if (bytes.length + chunk.length > maxJsonBytes) {
        throw const PluginException('http_response_too_large');
      }
      bytes.add(chunk);
    }
    return jsonEncode({
      'status': response.statusCode,
      'headers': response.headers.map,
      'body': utf8.decode(bytes.takeBytes()),
    });
  }
}

@pragma('vm:entry-point')
void _execute(List<Object> args) {
  // Provider libraries must never print credentials, bodies or stack traces.
  runZonedGuarded(
    () async {
      final host = args[0] as SendPort;
      final replies = ReceivePort();
      final pending = <int, Completer<String>>{};
      var sequence = 0;
      host.send(replies.sendPort);
      replies.listen((dynamic event) {
        if (event is List && event.length == 3) {
          final completer = pending.remove(event[0]);
          if (completer != null) completer.complete(event[2] as String);
        }
      });
      final runtime = Runtime(ByteData.sublistView(args[1] as Uint8List));
      final callback = $Closure((runtime, target, args) {
        final raw = args.single?.$value;
        if (raw is! String) throw const PluginException('invalid_http_request');
        final id = sequence++;
        final completer = Completer<String>();
        pending[id] = completer;
        host.send(['http', id, raw]);
        return $Future.wrap(completer.future.then($String.new));
      });
      Object? result = runtime.executeLib('package:diary/main.dart', 'main', [
        $String(args[2] as String),
        callback,
      ]);
      if (result is Future) result = await result;
      if (result is $Value) result = result.$value;
      host.send(['result', result is String ? result : null]);
      replies.close();
    },
    (error, stack) => (args[0] as SendPort).send(['error']),
    zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
  );
}
