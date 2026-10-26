import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/debug/diagnostics.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

/// Answers every request with [status], or fails it as [failure] would.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, this.failure});

  final int status;
  final DioExceptionType? failure;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failure case final type?) {
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody.fromString('{}', status);
  }

  @override
  void close({bool force = false}) {}
}

/// Fails to fetch the recipients, as Librus would when it cannot be
/// reached.
class _Unreachable extends AppRepository {
  @override
  Future<List<MessageRecipient>> fetchMessageRecipients() async =>
      throw const LibrusException(LibrusErrorCode.networkTimeout);
}

void main() {
  // Made up, as a real user's would be.
  const name = 'Uczeń Testowy';
  const login = 'uczen.testowy';
  const school = 'Szkoła Przykładowa';
  const email = 'rodzic.testowy@example.com';
  const password = 'Haslo-Tajne-123';
  const token =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTYifQ.c2lnbmF0dXJlLXRlc3Q';

  group('a report', () {
    test('keeps out names, logins, e-mails, passwords, tokens and cookies, '
        'and keeps what explains the failure', () {
      final diagnostics = Diagnostics(clock: () => DateTime(2026, 10, 25, 9));
      diagnostics
        ..recordError(
          Exception(
            'Sign-in of $email failed: password=$password '
            'Authorization: Bearer $token',
          ),
          StackTrace.fromString('#0 signIn (package:syberia/x.dart:1:1)'),
          source: 'sign-in',
        )
        ..recordError(
          StateError(
            'Cookie DZIENNIKSID=abcdef0123456789 for $login at '
            'https://api.librus.pl/2.0/Me?access_token=$token, statusCode: 503',
          ),
          null,
          source: 'sync',
        )
        ..recordError(
          FormatException('{"password":"$password","login":"$login"}'),
          null,
          source: 'sync',
        )
        ..recordError(
          Exception('Lessons for $name, ${school.toUpperCase()}'),
          null,
          source: 'timetable',
        );
      final report = diagnostics.report(
        about: {'Version': '1.5.0 (abc123)', 'Profiles': '1'},
        private: [name, login, school],
      );

      for (final secret in [
        name,
        login,
        school,
        school.toUpperCase(),
        email,
        password,
        token,
        'abcdef0123456789',
        'access_token=',
      ]) {
        expect(report, isNot(contains(secret)), reason: secret);
      }
      expect(report, contains('Version: 1.5.0 (abc123)'));
      expect(report, contains('[sign-in] _Exception'));
      expect(report, contains('https://api.librus.pl/2.0/Me'));
      expect(report, contains('statusCode: 503'));
      expect(report, contains('package:syberia/x.dart'));
      expect(report, contains('<e-mail>'));
      expect(report, contains('<private>'));
    });

    test('says when there is nothing to report', () {
      final report = Diagnostics().report(about: const {});
      expect(report, contains('Errors (0):\nnone'));
      expect(report, contains('Requests (last 0 of 0):\nnone'));
    });
  });

  group('the error log', () {
    test('keeps the latest 50, and counts an error that repeats', () {
      final diagnostics = Diagnostics();
      for (var index = 0; index < 60; index++) {
        diagnostics.recordError(StateError('error $index'), null, source: 's');
      }
      expect(diagnostics.errors, hasLength(Diagnostics.errorLimit));
      expect(diagnostics.errors.first.message, contains('error 10'));
      for (var index = 0; index < 3; index++) {
        diagnostics.recordError(StateError('again'), null, source: 's');
      }
      expect(diagnostics.errors.last.times, 3);
      expect(diagnostics.errors, hasLength(Diagnostics.errorLimit));
    });

    test('notes uncaught errors and still passes them on', () {
      final flutter = FlutterError.onError;
      final platform = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = flutter;
        PlatformDispatcher.instance.onError = platform;
      });
      final passed = <Object>[];
      FlutterError.onError = (details) => passed.add(details.exception);
      PlatformDispatcher.instance.onError = (error, _) {
        passed.add(error);
        return true;
      };
      final diagnostics = Diagnostics()..watchUncaught();

      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('in a frame')),
      );
      final handled = PlatformDispatcher.instance.onError!(
        StateError('in a future'),
        StackTrace.empty,
      );

      expect(handled, isTrue, reason: 'as the earlier handler said');
      expect(passed.map((error) => '$error'), [
        'Bad state: in a frame',
        'Bad state: in a future',
      ]);
      expect(diagnostics.errors.map((error) => error.source), [
        'flutter',
        'platform',
      ]);
    });

    test('notes what the app was doing when Librus failed', () async {
      SharedPreferences.setMockInitialValues({});
      Diagnostics.instance.clear();
      final controller = AppController(_Unreachable(), updatesEnabled: false);
      await expectLater(
        controller.fetchMessageRecipients(),
        throwsA(isA<LibrusException>()),
      );
      final error = Diagnostics.instance.errors.single;
      expect(error.source, 'recipients');
      expect(error.message, 'networkTimeout');
      expect(error.stack, isNotEmpty);
      controller.dispose();
    });
  });

  group('the request log', () {
    test('keeps where a request went, without its query or the codes in its '
        'path, and how it went', () async {
      var now = DateTime(2026, 10, 25, 9);
      final diagnostics = Diagnostics(clock: () => now);
      final dio = Dio()..httpClientAdapter = _Adapter(status: 401);
      diagnostics.watch(dio);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            now = now.add(const Duration(milliseconds: 120));
            handler.next(options);
          },
        ),
      );
      await dio.get<Object?>(
        'https://api.librus.pl/2.0/Timetables'
        '?weekStart=2026-10-19&access_token=$token',
        options: Options(validateStatus: (_) => true),
      );
      await dio.get<Object?>(
        'https://synergia.librus.pl/loguj/token/AbCdEf/przenies',
        options: Options(validateStatus: (_) => true),
      );
      await dio.get<Object?>(
        'https://portal.librus.pl/api/v3/SynergiaAccounts/fresh/abc',
        options: Options(validateStatus: (_) => true),
      );
      await dio.get<Object?>(
        'https://synergia.librus.pl/wiadomosci/1/5/987654/f0',
        options: Options(validateStatus: (_) => true),
      );

      final [timetable, autoLogin, account, message] = diagnostics.requests;
      expect(timetable.method, 'GET');
      expect(timetable.host, 'api.librus.pl');
      expect(timetable.path, '/2.0/Timetables');
      expect(timetable.status, 401);
      expect(timetable.took, const Duration(milliseconds: 120));
      expect(autoLogin.path, '/loguj/token/:id/przenies');
      expect(account.path, '/api/v3/SynergiaAccounts/fresh/:id');
      expect(message.path, '/wiadomosci/1/5/:id/f0');
      expect(
        Diagnostics.describe(timetable),
        '2026-10-25 09:00:00 GET api.librus.pl/2.0/Timetables 401 120 ms',
      );
    });

    test('says how a request failed when no answer came', () async {
      final diagnostics = Diagnostics();
      final dio = Dio()
        ..httpClientAdapter = _Adapter(
          failure: DioExceptionType.connectionTimeout,
        );
      diagnostics.watch(dio);
      await expectLater(
        dio.get<Object?>('https://portal.librus.pl/api/v3/SynergiaAccounts'),
        throwsA(isA<DioException>()),
      );
      final request = diagnostics.requests.single;
      expect(request.status, isNull);
      expect(request.failure, 'connectionTimeout');
      expect(Diagnostics.describe(request), contains('connectionTimeout'));
    });

    test('keeps the latest 200', () {
      final diagnostics = Diagnostics();
      for (var index = 0; index < 250; index++) {
        diagnostics.recordRequest(
          DiagnosticRequest(
            at: DateTime(2026, 10, 25, 9, 0, index ~/ 60, index % 60),
            method: 'GET',
            host: 'api.librus.pl',
            path: '/2.0/Grades',
            took: Duration.zero,
            status: index,
          ),
        );
      }
      expect(diagnostics.requests, hasLength(Diagnostics.requestLimit));
      expect(diagnostics.requests.first.status, 50);
      expect(diagnostics.report(about: const {}), contains('last 50 of 200'));
    });

    test(
      'logs each request once, however many clients share a connection',
      () async {
        Diagnostics.instance.clear();
        final dio = Dio()..httpClientAdapter = _Adapter();
        LibrusClient(dio: dio, secureStorage: const FlutterSecureStorage());
        LibrusClient(dio: dio, secureStorage: const FlutterSecureStorage());
        await dio.get<Object?>('https://api.librus.pl/2.0/Me');
        expect(Diagnostics.instance.requests, hasLength(1));
      },
    );
  });
}
