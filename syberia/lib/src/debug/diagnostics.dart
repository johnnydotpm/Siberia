import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A failure the app ran into, with what is private already taken out.
class DiagnosticError {
  DiagnosticError({
    required this.at,
    required this.source,
    required this.type,
    required this.message,
    required this.stack,
  });

  /// When it last happened, and how many times in a row.
  DateTime at;
  int times = 1;

  /// Where it was caught: "flutter", "platform", or what the app was doing.
  final String source;
  final String type;
  final String message;

  /// The first frames of the stack, if there was one.
  final String stack;
}

/// One request to Librus: where to, without its query, and how it went.
class DiagnosticRequest {
  const DiagnosticRequest({
    required this.at,
    required this.method,
    required this.host,
    required this.path,
    required this.took,
    this.status,
    this.failure,
  });

  final DateTime at;
  final String method;
  final String host;

  /// The path with numbers and long codes in it replaced by `:id`.
  final String path;
  final Duration took;
  final int? status;

  /// What kind of failure it was, when it got no answer.
  final String? failure;
}

/// What went wrong lately and what was asked of Librus, kept in memory only
/// for the debug menu and a report the user can choose to send. Nothing is
/// written to disk or sent anywhere.
class Diagnostics {
  Diagnostics({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  /// The app's one record.
  static final instance = Diagnostics();

  static const errorLimit = 50;
  static const requestLimit = 200;

  DateTime Function() clock;
  final _errors = ListQueue<DiagnosticError>();
  final _requests = ListQueue<DiagnosticRequest>();

  /// Oldest first.
  List<DiagnosticError> get errors => List.unmodifiable(_errors);
  List<DiagnosticRequest> get requests => List.unmodifiable(_requests);

  /// Adds the request log to [dio], once however many clients share it.
  void watch(Dio dio) {
    if (dio.interceptors.any(
      (each) => each is _RequestLog && each.of == this,
    )) {
      return;
    }
    dio.interceptors.add(_RequestLog(this));
  }

  /// Records uncaught errors too, and leaves whatever handled them before
  /// to handle them still.
  void watchUncaught() {
    final flutter = FlutterError.onError;
    FlutterError.onError = (details) {
      recordError(details.exception, details.stack, source: 'flutter');
      flutter?.call(details);
    };
    final platform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, source: 'platform');
      return platform?.call(error, stack) ?? false;
    };
  }

  void recordError(Object error, StackTrace? stack, {required String source}) {
    final type = error.runtimeType.toString();
    final message = _cut(scrub(error.toString()), 400);
    final last = _errors.isEmpty ? null : _errors.last;
    if (last != null &&
        last.source == source &&
        last.type == type &&
        last.message == message) {
      last
        ..times += 1
        ..at = clock();
      return;
    }
    _errors.add(
      DiagnosticError(
        at: clock(),
        source: source,
        type: type,
        message: message,
        stack: _frames(stack),
      ),
    );
    while (_errors.length > errorLimit) {
      _errors.removeFirst();
    }
  }

  void recordRequest(DiagnosticRequest request) {
    _requests.add(request);
    while (_requests.length > requestLimit) {
      _requests.removeFirst();
    }
  }

  void clear() {
    _errors.clear();
    _requests.clear();
  }

  /// A plain-text report: [about] first, as given, then the errors and the
  /// latest requests. Every text in [private] (names, logins, schools) is
  /// replaced, and so is anything that looks like an e-mail, a password, a
  /// token or a cookie.
  String report({
    required Map<String, String> about,
    Iterable<String> private = const [],
    int requests = 50,
  }) {
    final out = StringBuffer('SiberiaGB diagnostics\n');
    for (final MapEntry(:key, :value) in about.entries) {
      out.writeln('$key: $value');
    }
    out.writeln('\nErrors (${_errors.length}):');
    if (_errors.isEmpty) out.writeln('none');
    for (final error in _errors) {
      final times = error.times > 1 ? ' ×${error.times}' : '';
      out.writeln(
        '${_time(error.at)} [${error.source}] ${error.type}$times: '
        '${error.message}',
      );
      if (error.stack.isNotEmpty) out.writeln(_indent(error.stack));
    }
    final latest = _requests.skip(
      _requests.length > requests ? _requests.length - requests : 0,
    );
    out.writeln('\nRequests (last ${latest.length} of ${_requests.length}):');
    if (latest.isEmpty) out.writeln('none');
    for (final request in latest) {
      out.writeln(describe(request));
    }
    return scrub(out.toString(), private: private);
  }

  /// One line for [request], as the log and the report show it.
  static String describe(DiagnosticRequest request) {
    final outcome =
        request.failure ?? (request.status?.toString() ?? 'no answer');
    return '${_time(request.at)} ${request.method} ${request.host}'
        '${request.path} $outcome ${request.took.inMilliseconds} ms';
  }

  /// [text] with private things replaced: every text in [private], and
  /// whatever looks like an e-mail, a password, a token, a cookie or a
  /// URL's query.
  static String scrub(String text, {Iterable<String> private = const []}) {
    var result = text
        .replaceAllMapped(
          RegExp(r'''(https?://[^\s?#'"<>]+)[?#][^\s'"<>]*'''),
          (match) => match[1]!,
        )
        .replaceAll(RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+'), '<e-mail>')
        .replaceAll(
          RegExp(r'Bearer\s+[^\s,;"]+', caseSensitive: false),
          'Bearer <hidden>',
        )
        .replaceAllMapped(
          RegExp(
            '("?\\b(?:$_secretNames)\\b"?\\s*[:=]\\s*)("[^"]*"|[^\\s&;,"]+)',
            caseSensitive: false,
          ),
          (match) => '${match[1]}<hidden>',
        )
        .replaceAll(
          RegExp(r'[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'),
          '<hidden>',
        )
        .replaceAll(RegExp(r'\b[A-Za-z0-9_-]{32,}\b'), '<hidden>');
    final names = {
      for (final each in private)
        if (each.trim().length >= 3) each.trim(),
    }.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final name in names) {
      result = result.replaceAll(
        RegExp(RegExp.escape(name), caseSensitive: false),
        '<private>',
      );
    }
    return result;
  }

  static const _secretNames =
      'password|passwd|pass|pwd|login|username|user|email|token|'
      'access_token|refresh_token|id_token|code|secret|session|sessid|'
      'sid|DZIENNIKSID|SDZIENNIKSID|cookie|set-cookie|authorization';

  /// The parts of a path the next part of which is a token or a login:
  /// `loguj/token/…` and `SynergiaAccounts/fresh/…`.
  static const _beforeCodes = {'token', 'fresh'};

  /// [path] with every part that is a number or a code as `:id`, and the
  /// part after `token` or `fresh` too; a short version such as `2.0`
  /// stays.
  static String plainPath(String path) {
    final parts = path.split('/');
    for (var index = 0; index < parts.length; index++) {
      final part = parts[index];
      final digits = RegExp(r'\d').allMatches(part).length;
      final code =
          part.length >= 24 ||
          digits >= 4 ||
          (part.length >= 12 && digits > 0) ||
          (index > 0 && _beforeCodes.contains(parts[index - 1].toLowerCase()));
      if (code && part.isNotEmpty) parts[index] = ':id';
    }
    return parts.join('/');
  }

  static String _frames(StackTrace? stack) {
    if (stack == null) return '';
    final lines = stack
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(6);
    return scrub(lines.join('\n'));
  }

  static String _cut(String text, int length) =>
      text.length <= length ? text : '${text.substring(0, length)}…';

  static String _indent(String text) =>
      text.split('\n').map((line) => '    $line').join('\n');

  static String _time(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}

/// Writes down each request [of] the diagnostics sees go out, when its
/// answer, or its failure, comes back.
class _RequestLog extends Interceptor {
  _RequestLog(this.of);

  final Diagnostics of;
  final _started = Expando<DateTime>();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _started[options] = of.clock();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _record(response.requestOptions, status: response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    _record(
      error.requestOptions,
      status: error.response?.statusCode,
      failure: error.response == null ? error.type.name : null,
    );
    handler.next(error);
  }

  void _record(RequestOptions options, {int? status, String? failure}) {
    final uri = options.uri;
    final now = of.clock();
    of.recordRequest(
      DiagnosticRequest(
        at: now,
        method: options.method,
        host: uri.host,
        path: Diagnostics.plainPath(uri.path),
        took: now.difference(_started[options] ?? now),
        status: status,
        failure: failure,
      ),
    );
  }
}
