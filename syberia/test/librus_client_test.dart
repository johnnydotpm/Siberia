import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/librus/librus_logins.dart';
import 'package:syberia/src/data/librus/reference_cache.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/debug/diagnostics.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform({}),
  );

  test('reference lists come from the cache on the next sync', () async {
    final requests = <String>[];
    final client = LibrusClient(
      dio: Dio()
        ..httpClientAdapter = _FixtureAdapter((options) {
          requests.add(options.uri.path);
          return _successfulResponse(options);
        }),
    );
    final first = await client.loginAndFetch(
      username: 'parent@example.com',
      password: 'secret',
    );
    int count(String endpoint) =>
        requests.where((path) => path.endsWith(endpoint)).length;
    expect(count('/2.0/Subjects'), 1);
    expect(count('/2.0/Grades'), 1);
    final second = await client.fetchSnapshot();
    expect(count('/2.0/Subjects'), 1, reason: 'cached');
    expect(count('/2.0/Users'), 1, reason: 'cached');
    expect(count('/2.0/Grades'), 2);
    expect(count('/2.0/Grades/Comments'), 2, reason: 'comments are not cached');
    expect(second.grades.single.category, first.grades.single.category);
    expect(second.lessons.single.subject, 'Matematyka');
    // Only some parts.
    final partial = await client.fetchSnapshot(parts: {LibrusPart.grades});
    expect(count('/2.0/Grades'), 3);
    expect(count('/2.0/Attendances'), 2);
    expect(partial.attendance, isEmpty);
    expect(partial.messages, isEmpty);
    expect(partial.grades, isNotEmpty);
    await client.logout();
  });

  test('an unknown subject brings fresh lists once they are old', () async {
    var now = DateTime.now();
    var newSubject = false;
    final requests = <String>[];
    final client = LibrusClient(
      clock: () => now,
      dio: Dio()
        ..httpClientAdapter = _FixtureAdapter((options) {
          requests.add(options.uri.path);
          final path = options.uri.path;
          if (newSubject && path.endsWith('/2.0/Subjects')) {
            return (
              200,
              {
                'Subjects': [
                  {'Id': 10, 'Name': 'Matematyka'},
                  {'Id': 77, 'Name': 'Chemia'},
                ],
              },
            );
          }
          if (newSubject && path.endsWith('/2.0/Grades')) {
            return (
              200,
              {
                'Grades': [
                  {
                    'Id': 90,
                    'Grade': '5',
                    'Semester': 1,
                    'AddDate': '2026-09-29T10:00:00',
                    'Subject': {'Id': 77},
                    'Category': {'Id': 40},
                  },
                ],
              },
            );
          }
          return _successfulResponse(options);
        }),
    );
    await client.loginAndFetch(
      username: 'parent@example.com',
      password: 'secret',
    );
    int subjects() => requests.where((p) => p.endsWith('/2.0/Subjects')).length;
    expect(subjects(), 1);
    newSubject = true;
    // Lists fetched a moment ago are not fetched again.
    var snapshot = await client.fetchSnapshot();
    expect(subjects(), 1);
    expect(snapshot.grades.single.subject, isNot('Chemia'));
    now = now.add(const Duration(minutes: 11));
    snapshot = await client.fetchSnapshot();
    expect(subjects(), 2);
    expect(snapshot.grades.single.subject, 'Chemia');
  });

  test(
    'a name missing even from fresh lists is not looked for again',
    () async {
      var now = DateTime.now();
      final requests = <String>[];
      final client = LibrusClient(
        clock: () => now,
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            requests.add(options.uri.path);
            if (options.uri.path.endsWith('/2.0/Grades')) {
              return (
                200,
                {
                  'Grades': [
                    {
                      'Id': 90,
                      'Grade': '5',
                      'Semester': 1,
                      'AddDate': '2026-09-29T10:00:00',
                      'Subject': {'Id': 999},
                      'Category': {'Id': 40},
                    },
                  ],
                },
              );
            }
            return _successfulResponse(options);
          }),
      );
      await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      int subjects() =>
          requests.where((p) => p.endsWith('/2.0/Subjects')).length;
      expect(subjects(), 1);
      // The lists fetched at login already lacked it, so it is remembered.
      now = now.add(const Duration(minutes: 11));
      await client.fetchSnapshot();
      expect(subjects(), 1, reason: 'the missing subject is remembered');
      now = now.add(const Duration(hours: 25));
      await client.fetchSnapshot();
      expect(subjects(), 2, reason: 'old lists are fetched again');
    },
  );

  test('the request log of a sign-in and a sync shows where each request '
      'went, and nothing private', () async {
    Diagnostics.instance.clear();
    final dio = Dio()..httpClientAdapter = _FixtureAdapter(_successfulResponse);
    final client = LibrusClient(
      dio: dio,
      secureStorage: const FlutterSecureStorage(),
    );
    await client.loginAndFetch(
      username: 'parent@example.com',
      password: 'secret',
    );
    final requests = Diagnostics.instance.requests;
    expect(requests, isNotEmpty);
    expect(
      requests.map((request) => request.host).toSet(),
      containsAll(['portal.librus.pl', 'api.librus.pl']),
    );
    final report = Diagnostics.instance.report(
      about: const {},
      private: const ['Uczeń Testowy'],
      requests: Diagnostics.requestLimit,
    );
    for (final secret in [
      'secret',
      'parent@example.com',
      'parent',
      'test-student-login',
      '?',
      'Uczeń Testowy',
    ]) {
      expect(report, isNot(contains(secret)), reason: secret);
    }
  });

  test('uses Portal refresh flow and maps Librus modules', () async {
    final dio = Dio()..httpClientAdapter = _FixtureAdapter(_successfulResponse);
    final client = LibrusClient(
      dio: dio,
      secureStorage: const FlutterSecureStorage(),
    );
    final snapshot = await client.loginAndFetch(
      username: 'parent@example.com',
      password: 'secret',
    );
    expect(snapshot.profile.name, 'Uczeń Testowy');
    expect(snapshot.profile.school, 'Szkoła Przykładowa, Miasto Testowe');
    expect(snapshot.lessons.single.subject, 'Matematyka');
    expect(snapshot.lessons.single.substitution, isTrue);
    expect(snapshot.lessons.single.originalSubject, 'Fizyka');
    expect(snapshot.grades.single.value, '5');
    expect(snapshot.grades.single.replacedValues, ['-']);
    expect(snapshot.grades.single.semester, 2);
    expect(snapshot.grades.single.category, 'Sprawdzian');
    expect(snapshot.grades.single.description, 'Rozdział 1');
    expect(snapshot.events, hasLength(2));
    final exam = snapshot.events.firstWhere(
      (event) => event.kind == EventKind.exam,
    );
    expect(exam.typeLabel, 'Kartkówka');
    expect(exam.lessonNumber, 3);
    final homework = snapshot.events.singleWhere(
      (event) => event.kind == EventKind.homework,
    );
    expect(homework.subject, 'Matematyka');
    expect(homework.description, 'Strona 12');
    expect(snapshot.attendance, hasLength(6));
    expect(
      snapshot.attendance.firstWhere((item) => item.id == '80').kind,
      AttendanceKind.absentExcused,
    );
    expect(
      snapshot.attendance.firstWhere((item) => item.id == '81').kind,
      AttendanceKind.late,
    );
    expect(
      snapshot.attendance.firstWhere((item) => item.id == '82').kind,
      AttendanceKind.released,
    );
    expect(
      snapshot.attendance.firstWhere((item) => item.id == '83').kind,
      AttendanceKind.lateExcused,
    );
    expect(snapshot.absences, 2);
    expect(snapshot.announcements.single.title, 'Zebranie');
    expect(snapshot.messages.single.subject, 'Wywiadówka');
    expect(snapshot.messages.single.sender, 'Nauczyciel Testowy');
    expect(snapshot.messages.single.hasAttachments, isTrue);
    expect(snapshot.notices.single.category, 'Pochwała');

    final content = await client.fetchMessageContent(snapshot.messages.single);
    expect(content.subject, 'Wywiadówka');
    expect(content.body, 'Pełna treść wiadomości');
    expect(content.attachments.single.name, 'informacja.pdf');
    expect(
      await client.fetchMessageAttachmentUrl(
        messageId: content.id,
        attachmentId: content.attachments.single.id,
      ),
      Uri.parse('https://files.example/informacja.pdf'),
    );

    final recipients = await client.fetchMessageRecipients();
    expect(recipients, hasLength(2));
    expect(recipients.first.name, 'Nauczyciel Testowy');
    await client.sendMessage(
      recipientIds: [recipients.first.id],
      subject: 'Pytanie',
      body: 'Dzień dobry',
    );
    expect(await client.fetchTimetableWeek(DateTime(2025, 3, 3)), hasLength(1));
  });

  test(
    'reads mailbox and content when the mobile Messages API returns 403',
    () async {
      final requests = <String>[];
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            requests.add(options.uri.toString());
            if (options.uri.host == 'api.librus.pl' &&
                options.uri.path.contains('/Messages')) {
              return (403, {'Code': 'AccessDenied'});
            }
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      final content = await client.fetchMessageContent(
        snapshot.messages.single,
      );
      expect(content.body, 'Pełna treść wiadomości');
      expect(
        requests.any((url) => url.contains('api.librus.pl/2.0/Messages')),
        isTrue,
      );
      expect(requests.any((url) => url.endsWith('/module/GetMessage')), isTrue);
    },
  );

  test('accepts service-wrapped module responses and strips MAINT from the session', () async {
    final client = LibrusClient(
      dio: Dio()
        ..httpClientAdapter = _FixtureAdapter((options) {
          if (options.uri.path == '/2.0/Messages') {
            return (403, {'Code': 'AccessDenied'});
          }
          final (status, body) = _successfulResponse(options);
          if (options.uri.host == 'wiadomosci.librus.pl') {
            expect(
              options.headers['Cookie'],
              contains('DZIENNIKSID=mail-session'),
            );
            expect(options.headers['Cookie'], isNot(contains('MAINT')));
            return (status, '<service>$body</service>');
          }
          return (status, body);
        }, mailboxSession: 'mail-session-MAINT'),
    );
    final snapshot = await client.loginAndFetch(
      username: 'parent@example.com',
      password: 'secret',
    );
    expect(snapshot.messagesError, isNull);
    expect(snapshot.messages.single.id, '91');
    final content = await client.fetchMessageContent(snapshot.messages.single);
    expect(content.body, 'Pełna treść wiadomości');
  });

  test(
    'loads the classic Synergia inbox after API and XML access are denied',
    () async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (options.uri.path == '/2.0/Messages') {
              return (403, {'Code': 'AccessDenied'});
            }
            if (options.uri.path.endsWith('/Inbox/action/GetList')) {
              return (200, '<error><type>eAccessDeny</type></error>');
            }
            if (options.uri.path == '/wiadomosci/5') {
              expect(
                options.headers['Cookie'],
                contains('DZIENNIKSID=web-session'),
              );
              return (
                200,
                '<table class="decorated stretch"><tbody><tr><td><a href="/wiadomosci/1/5/91/f0">Otwórz</a></td><td><img src="attachment.png"></td><td style="font-weight:bold">Testowy Nauczyciel (Nauczyciel)</td><td>Wiadomość ze szkoły</td><td>2026-10-16 06:00:00</td></tr></tbody></table>',
              );
            }
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      expect(snapshot.messagesError, isNull);
      expect(snapshot.messages.single.subject, 'Wiadomość ze szkoły');
      expect(snapshot.messages.single.unread, isTrue);
      expect(snapshot.messages.single.hasAttachments, isTrue);
    },
  );

  test(
    'reports safe endpoint codes instead of generic errors or raw XML',
    () async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (options.uri.path == '/2.0/Messages') {
              return (403, {'Code': 'AccessDenied'});
            }
            if (options.uri.path.endsWith('/Inbox/action/GetList')) {
              return (
                200,
                '<error><type>eAccessDeny</type><messaage>private-body-and-token</messaage></error>',
              );
            }
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      expect(snapshot.messages, isEmpty);
      expect(snapshot.messagesError!.detail, contains('HTTP 403'));
      expect(
        snapshot.messagesError!.detail,
        contains('XML GetList eAccessDeny'),
      );
      expect(
        snapshot.messagesError!.detail,
        contains('Synergia inbox HTTP 404'),
      );
      expect(
        snapshot.messagesError!.detail,
        isNot(contains('private-body-and-token')),
      );
    },
  );

  (int, Object)? twoStudents(RequestOptions options, List<String> fresh) {
    if (options.uri.path.endsWith('/api/v3/SynergiaAccounts')) {
      return (
        200,
        {
          'accounts': [
            {
              'login': 'fixture-parent',
              'group': 'parent',
              'studentName': 'Uczeń',
            },
            {
              'login': 'fixture-student-u',
              'group': 'student',
              'studentName': 'Uczeń',
            },
          ],
        },
      );
    }
    if (options.uri.path.contains('/SynergiaAccounts/fresh/')) {
      fresh.add(options.uri.pathSegments.last);
      return (200, {'accessToken': 'token-${options.uri.pathSegments.last}'});
    }
    return null;
  }

  bool isRefresh(RequestOptions options) =>
      options.uri.path.endsWith('/oauth2/access_token') &&
      options.data is FormData &&
      (options.data as FormData).fields.any(
        (entry) => entry.key == 'grant_type' && entry.value == 'refresh_token',
      );

  test('signing in lists the students, and each profile client keeps its own '
      'student after Portal reauthentication', () async {
    var fixtureTime = DateTime(2026, 10, 16);
    var rejectRefresh = false;
    final freshLogins = <String>[];
    final dio = Dio()
      ..httpClientAdapter = _FixtureAdapter((options) {
        if (rejectRefresh && isRefresh(options)) {
          return (400, {'error': 'invalid_grant'});
        }
        return twoStudents(options, freshLogins) ??
            _successfulResponse(options);
      });
    final logins = LibrusLogins(clock: () => fixtureTime);
    final found = await LibrusClient(
      clock: () => fixtureTime,
      dio: dio,
      logins: logins,
    ).signIn(username: 'parent@example.com', password: 'secret');
    expect(found.account, LibrusLogin.keyOf('Parent@Example.com '));
    expect(
      [for (final student in found.students) student.login],
      ['fixture-parent', 'fixture-student-u'],
    );
    expect(
      [for (final student in found.students) student.parent],
      [true, false],
    );
    expect(freshLogins, isEmpty, reason: 'no student is fetched yet');

    LibrusClient profile(String login) => LibrusClient(
      clock: () => fixtureTime,
      dio: dio,
      logins: logins,
      account: found.account,
      synergiaLogin: login,
    );
    final parent = profile('fixture-parent');
    final student = profile('fixture-student-u');
    await parent.restoreAndFetch();
    await student.restoreAndFetch();
    expect(freshLogins, ['fixture-parent', 'fixture-student-u']);
    expect(
      (await parent.fetchSynergiaAccounts())
          .singleWhere((account) => account.selected)
          .login,
      'fixture-parent',
    );

    freshLogins.clear();
    rejectRefresh = true;
    fixtureTime = fixtureTime.add(const Duration(hours: 7));
    await parent.fetchSnapshot();
    await student.fetchSnapshot();
    expect(freshLogins, ['fixture-parent', 'fixture-student-u']);
  });

  test('two profiles of one login renew its tokens once', () async {
    var fixtureTime = DateTime(2026, 10, 16);
    final freshLogins = <String>[];
    var refreshes = 0;
    var logins = 0;
    final dio = Dio()
      ..httpClientAdapter = _FixtureAdapter((options) {
        if (isRefresh(options)) refreshes++;
        if (options.method == 'POST' &&
            options.uri.path.endsWith('/oauth2/access_token') &&
            !isRefresh(options)) {
          logins++;
        }
        return twoStudents(options, freshLogins) ??
            _successfulResponse(options);
      });
    final shared = LibrusLogins(clock: () => fixtureTime);
    final found = await LibrusClient(
      clock: () => fixtureTime,
      dio: dio,
      logins: shared,
    ).signIn(username: 'parent@example.com', password: 'secret');
    expect(logins, 1);
    LibrusClient profile(String login) => LibrusClient(
      clock: () => fixtureTime,
      dio: dio,
      logins: shared,
      account: found.account,
      synergiaLogin: login,
    );
    final parent = profile('fixture-parent');
    final student = profile('fixture-student-u');
    await Future.wait([parent.restoreAndFetch(), student.restoreAndFetch()]);
    expect(refreshes, 0, reason: 'the tokens of the sign-in are fresh');

    fixtureTime = fixtureTime.add(const Duration(hours: 7));
    await Future.wait([parent.fetchSnapshot(), student.fetchSnapshot()]);
    expect(refreshes, 1);
    expect(logins, 1);
    expect(freshLogins.sublist(2).toSet(), {
      'fixture-parent',
      'fixture-student-u',
    });
    final saved = await shared.read(found.account);
    expect(saved!.email, 'parent@example.com');
  });

  test(
    'a missing selected account does not silently switch to another student',
    () async {
      var fixtureTime = DateTime(2026, 10, 16);
      var removeAccount = false;
      final client = LibrusClient(
        clock: () => fixtureTime,
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (removeAccount &&
                options.uri.path.endsWith('/api/v3/SynergiaAccounts')) {
              return (
                200,
                {
                  'accounts': [
                    {'login': 'other-student-u'},
                  ],
                },
              );
            }
            return _successfulResponse(options);
          }),
      );
      await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      removeAccount = true;
      fixtureTime = fixtureTime.add(const Duration(hours: 7));
      await expectLater(
        client.fetchSnapshot(),
        throwsA(
          isA<LibrusException>().having(
            (error) => error.errorCode,
            'code',
            LibrusErrorCode.noSynergiaAccount,
          ),
        ),
      );
    },
  );

  test(
    'stops at AutoLogon after MultiDomainLogon establishes the mailbox session',
    () async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter(
            (options) {
              if (options.uri.path == '/2.0/Messages') {
                return (403, {'Code': 'AccessDenied'});
              }
              if (options.uri.path == '/wiadomosci2' ||
                  options.uri.path == '/MultiDomainLogon') {
                return (302, '');
              }
              if (options.uri.path == '/AutoLogon') {
                fail('AutoLogon must not replace the established session');
              }
              return _successfulResponse(options);
            },
            responseHeaders: (options) => switch (options.uri.path) {
              '/wiadomosci2' => {
                'location': ['https://wiadomosci.librus.pl/MultiDomainLogon'],
              },
              '/MultiDomainLogon' => {
                'location': ['https://wiadomosci.librus.pl/AutoLogon'],
                'set-cookie': ['DZIENNIKSID=mail-session-MAINT; Path=/'],
              },
              _ => {},
            },
          ),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      expect(snapshot.messagesError, isNull);
      expect(snapshot.messages.single.id, '91');
    },
  );

  test(
    'reuses valid School-style sessions and renews them before expiry',
    () async {
      var fixtureTime = DateTime(2026, 10, 16);
      var apiTokens = 0;
      var webLogins = 0;
      var mailboxLogins = 0;
      final client = LibrusClient(
        clock: () => fixtureTime,
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (options.uri.path.contains('/SynergiaAccounts/fresh/')) {
              apiTokens++;
            }
            if (options.uri.path.contains('/loguj/token/')) webLogins++;
            if (options.uri.path == '/wiadomosci2') mailboxLogins++;
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      await client.fetchMessageContent(snapshot.messages.single);
      await client.fetchMessageContent(snapshot.messages.single);
      expect([apiTokens, webLogins, mailboxLogins], [1, 1, 1]);
      fixtureTime = fixtureTime.add(const Duration(minutes: 45));
      await client.fetchMessageContent(snapshot.messages.single);
      expect([apiTokens, webLogins, mailboxLogins], [1, 2, 2]);
      fixtureTime = fixtureTime.add(const Duration(hours: 6));
      await client.fetchMessageContent(snapshot.messages.single);
      expect([apiTokens, webLogins, mailboxLogins], [2, 3, 3]);
    },
  );

  test(
    'renews a revoked API token once without waiting for the six-hour expiry',
    () async {
      var apiTokens = 0;
      var gradeRequests = 0;
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (options.uri.path.contains('/SynergiaAccounts/fresh/')) {
              apiTokens++;
            }
            if (options.uri.path == '/2.0/Grades' && gradeRequests++ == 0) {
              return (401, {'Code': 'TokenExpired'});
            }
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      expect(snapshot.grades, isNotEmpty);
      expect(apiTokens, 2);
      expect(gradeRequests, 2);
    },
  );

  test('keeps the working API inbox when mailbox bootstrap fails', () async {
    final client = LibrusClient(
      dio: Dio()
        ..httpClientAdapter = _FixtureAdapter((options) {
          if (options.uri.path == '/wiadomosci2') return (403, 'Forbidden');
          return _successfulResponse(options);
        }),
    );
    final snapshot = await client.loginAndFetch(
      username: 'parent@example.com',
      password: 'secret',
    );
    expect(snapshot.messages.single.id, '91');
    expect(snapshot.messagesError, isNull);
  });

  test(
    'exposes mailbox failure while other school data still synchronizes',
    () async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (options.uri.path == '/2.0/Messages') {
              return (403, {'Code': 'AccessDenied'});
            }
            if (options.uri.path == '/wiadomosci2') return (403, 'Forbidden');
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      expect(snapshot.messages, isEmpty);
      expect(snapshot.messagesError, isNotNull);
      expect(
        snapshot.messagesError!.detail,
        contains('mailbox login HTTP 403'),
      );
      expect(snapshot.grades, isNotEmpty);
    },
  );

  test(
    'uses Szkolny classic HTML content when XML mailbox is unavailable',
    () async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (options.uri.path == '/wiadomosci2') return (403, 'Forbidden');
            if (options.uri.path == '/wiadomosci/1/5/91/f0') {
              expect(
                options.headers['Cookie'],
                contains('DZIENNIKSID=web-session'),
              );
              return (
                200,
                '<table class="container-message"><tr><td>Message</td><td><div class="container-message-content">Dzień dobry<br>Treść &amp; szczegóły</div></td></tr></table>',
              );
            }
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      final content = await client.fetchMessageContent(
        snapshot.messages.single,
      );
      expect(content.body, 'Dzień dobry\nTreść & szczegóły');
    },
  );

  test('a message\'s links keep where they lead, from either mailbox', () async {
    const html =
        '<p>Plan: <a href="https://example.pl/a?x=1&amp;y=2" target="_blank">'
        '<b>plan</b></a> i <a href="https://example.pl/">https://example.pl</a>,'
        ' <a href="javascript:alert(1)">zły</a>,'
        " <a href='mailto:sekretariat@example.pl'>sekretariat@example.pl</a></p>";
    const expected =
        'Plan: plan (https://example.pl/a?x=1&y=2) i https://example.pl, zły, '
        'sekretariat@example.pl';
    for (final xml in [true, false]) {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (!xml && options.uri.path == '/wiadomosci2') {
              return (403, 'Forbidden');
            }
            if (xml && options.uri.path.endsWith('/GetMessage')) {
              final body = base64Encode(utf8.encode(html));
              return (
                200,
                '<response><GetMessage><data><Message>$body</Message>'
                    '</data></GetMessage></response>',
              );
            }
            if (options.uri.path == '/wiadomosci/1/5/91/f0') {
              return (
                200,
                '<table class="container-message"><tr><td>Message</td><td>'
                    '<div class="container-message-content">$html</div>'
                    '</td></tr></table>',
              );
            }
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      final content = await client.fetchMessageContent(
        snapshot.messages.single,
      );
      expect(content.body, expected, reason: xml ? 'XML mailbox' : 'web');
    }
  });

  test(
    'an authenticated empty inbox is different from a mailbox failure',
    () async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (options.uri.path == '/2.0/Messages') {
              return (200, {'Messages': []});
            }
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      expect(snapshot.messages, isEmpty);
      expect(snapshot.messagesError, isNull);
    },
  );

  test(
    'rejects an XML access error instead of displaying an empty body',
    () async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (options.uri.path.endsWith('/module/GetMessage')) {
              return (
                200,
                '<response><GetMessage><status>error</status><error>eAccessDeny</error></GetMessage></response>',
              );
            }
            return _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      await expectLater(
        client.fetchMessageContent(snapshot.messages.single),
        throwsA(isA<LibrusException>()),
      );
    },
  );

  test('keeps an unrelated grade separate from an improvement', () async {
    final dio = Dio()
      ..httpClientAdapter = _FixtureAdapter((options) {
        if (!options.uri.path.endsWith('/Grades')) {
          return _successfulResponse(options);
        }
        return (
          200,
          {
            'Grades': [
              {
                'Id': 50,
                'Grade': '4+',
                'Semester': 1,
                'AddDate': '2026-09-29T10:00:00',
                'Subject': {'Id': 10},
                'Category': {'Id': 40},
                'Improvement': {'Id': 49},
              },
              {
                'Id': 51,
                'Grade': '-',
                'Semester': 1,
                'AddDate': '2026-09-25T10:00:00',
                'Subject': {'Id': 10},
                'Category': {'Id': 40},
              },
              {
                'Id': 49,
                'Grade': '1',
                'Semester': 1,
                'AddDate': '2026-09-22T10:00:00',
                'Subject': {'Id': 10},
                'Category': {'Id': 40},
                'Improvement': {'Id': 48},
              },
              {
                'Id': 48,
                'Grade': '0',
                'Semester': 1,
                'AddDate': '2026-09-18T10:00:00',
                'Subject': {'Id': 10},
                'Category': {'Id': 40},
              },
            ],
          },
        );
      });
    final client = LibrusClient(
      dio: dio,
      secureStorage: const FlutterSecureStorage(),
    );
    final snapshot = await client.loginAndFetch(
      username: 'parent@example.com',
      password: 'secret',
    );

    expect(snapshot.grades, hasLength(2));
    expect(snapshot.grades.first.id, '50');
    expect(snapshot.grades.first.value, '4+');
    expect(snapshot.grades.first.replacedValues, ['0', '1']);
    expect(snapshot.grades.first.previousGrades.map((grade) => grade.id), [
      '48',
      '49',
    ]);
    expect(snapshot.grades.first.previousGrades.last.date.day, 22);
    expect(snapshot.grades.last.id, '51');
    expect(snapshot.grades.last.wasChanged, isFalse);
  });

  test('a message Librus does not confirm fails with a reason', () async {
    final dio = Dio()
      ..httpClientAdapter = _FixtureAdapter((options) {
        if (options.uri.path.endsWith('/SendMessage')) {
          return (
            200,
            // Not an error reply, just no id for a sent message.
            '<response><SendMessage><status>ok</status></SendMessage></response>',
          );
        }
        return _successfulResponse(options);
      });
    final client = LibrusClient(
      dio: dio,
      secureStorage: const FlutterSecureStorage(),
    );
    await client.loginAndFetch(
      username: 'parent@example.com',
      password: 'secret',
    );
    // The translation shows the detail, so it must never be missing.
    await expectLater(
      client.sendMessage(
        recipientIds: [20],
        subject: 'Pytanie',
        body: 'Dzień dobry',
      ),
      throwsA(
        isA<LibrusException>()
            .having(
              (error) => error.errorCode,
              'errorCode',
              LibrusErrorCode.messageNotSent,
            )
            .having((error) => error.detail, 'detail', isNotNull),
      ),
    );
  });

  group('days off', () {
    final today = DateTime.now();
    String day(int offset) {
      final value = DateTime(today.year, today.month, today.day + offset);
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }

    // Shaped as Librus sends them.
    (int, Object)? freeDays(RequestOptions options) {
      final path = options.uri.path;
      if (path.endsWith('/2.0/SchoolFreeDays')) {
        return (
          200,
          {
            'SchoolFreeDays': [
              {
                'Id': 1,
                'Name': 'Ferie zimowe',
                'DateFrom': day(30),
                'DateTo': day(43),
              },
            ],
          },
        );
      }
      if (path.endsWith('/2.0/ClassFreeDays')) {
        return (
          200,
          {
            'ClassFreeDays': [
              {
                'Id': 2,
                'Type': {'Id': 5},
                'DateFrom': day(3),
                'DateTo': day(3),
                'LessonNoFrom': 1,
                'LessonNoTo': 3,
              },
            ],
          },
        );
      }
      if (path.endsWith('/2.0/ClassFreeDays/Types')) {
        return (
          200,
          {
            'Types': [
              {'Id': 5, 'Name': 'Rekolekcje'},
            ],
          },
        );
      }
      if (path.endsWith('/2.0/TeacherFreeDays')) {
        return (
          200,
          {
            'TeacherFreeDays': [
              {
                'Id': 3,
                'Teacher': {'Id': 20},
                'Type': {'Id': 7},
                'DateFrom': day(0),
                'DateTo': day(1),
                'TimeFrom': '08:00:00',
                'TimeTo': '10:30:00',
              },
              // Over: left out.
              {
                'Id': 4,
                'Teacher': {'Id': 20},
                'DateFrom': day(-10),
                'DateTo': day(-9),
              },
            ],
          },
        );
      }
      if (path.endsWith('/2.0/TeacherFreeDays/Types')) {
        return (
          200,
          {
            'Types': [
              {'Id': 7, 'Name': 'Szkolenie'},
            ],
          },
        );
      }
      return null;
    }

    test(
      'holidays, the class days off and absences come with a sync',
      () async {
        final client = LibrusClient(
          referenceCache: _MemoryReferenceCache(),
          dio: Dio()
            ..httpClientAdapter = _FixtureAdapter(
              (options) => freeDays(options) ?? _successfulResponse(options),
            ),
        );
        final snapshot = await client.loginAndFetch(
          username: 'parent@example.com',
          password: 'secret',
        );
        final days = {for (final item in snapshot.freeDays) item.id: item};
        expect(days.keys.toSet(), {'class-2', 'teacher-3', 'school-1'});

        final holiday = days['school-1']!;
        expect(holiday.kind, FreeDayKind.school);
        expect(holiday.name, 'Ferie zimowe');
        expect(holiday.wholeDays, isTrue);
        expect(
          holiday.covers(DateTime(today.year, today.month, today.day + 30)),
          isTrue,
        );
        expect(
          holiday.covers(DateTime(today.year, today.month, today.day + 44)),
          isFalse,
        );

        final retreat = days['class-2']!;
        expect(retreat.kind, FreeDayKind.classDay);
        expect(retreat.name, 'Rekolekcje');
        expect((retreat.lessonFrom, retreat.lessonTo), (1, 3));
        expect(retreat.wholeDays, isFalse);

        final absence = days['teacher-3']!;
        expect(absence.kind, FreeDayKind.teacher);
        expect(absence.teacher, 'Nauczyciel Testowy');
        expect(absence.name, 'Szkolenie');
        expect((absence.timeFrom, absence.timeTo), (480, 630));
        // Kept for the next time the app opens offline.
        expect(
          SnapshotCache.decode(SnapshotCache.encode(snapshot))!.freeDays.map(
            (item) => (item.id, item.teacher, item.timeTo, item.lessonTo),
          ),
          snapshot.freeDays.map(
            (item) => (item.id, item.teacher, item.timeTo, item.lessonTo),
          ),
        );
      },
    );

    test("only the student's own class days off count", () async {
      Map<String, Object> classDay(int id, int? forClass) => {
        'Id': id,
        'Class': ?(forClass == null ? null : {'Id': forClass}),
        'Type': {'Id': 5},
        'DateFrom': day(-20),
        'DateTo': day(5),
      };
      Future<Set<String>> classDays({required int? ownClass}) async {
        final client = LibrusClient(
          referenceCache: _MemoryReferenceCache(),
          dio: Dio()
            ..httpClientAdapter = _FixtureAdapter((options) {
              final path = options.uri.path;
              if (path.endsWith('/2.0/Me')) {
                return (
                  200,
                  {
                    'Me': {
                      'Account': {'Id': 7},
                      'User': {'FirstName': 'Uczeń', 'LastName': 'Testowy'},
                      'Class': ?(ownClass == null ? null : {'Id': ownClass}),
                    },
                  },
                );
              }
              if (path.endsWith('/2.0/ClassFreeDays')) {
                return (
                  200,
                  {
                    'ClassFreeDays': [
                      classDay(10, 50),
                      // Another class's work placement.
                      classDay(11, 51),
                      classDay(12, null),
                    ],
                  },
                );
              }
              return freeDays(options) ?? _successfulResponse(options);
            }),
        );
        final snapshot = await client.loginAndFetch(
          username: 'parent@example.com',
          password: 'secret',
        );
        return {
          for (final item in snapshot.freeDays)
            if (item.kind == FreeDayKind.classDay) item.id,
        };
      }

      expect(await classDays(ownClass: 50), {'class-10', 'class-12'});
      // With no class known, only those named for no class.
      expect(await classDays(ownClass: null), {'class-12'});
    });

    test('without the lists of days off the sync still works', () async {
      final client = LibrusClient(
        referenceCache: _MemoryReferenceCache(),
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter(
            (options) => options.uri.path.contains('FreeDays')
                ? (403, {'Code': 'AccessDeny'})
                : _successfulResponse(options),
          ),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      expect(snapshot.freeDays, isEmpty);
      expect(snapshot.grades, isNotEmpty);
    });
  });

  group('subjects of lessons', () {
    // As Librus sends them: the lesson's id, not its subject.
    (int, Object)? lessonOnly(RequestOptions options) {
      final path = options.uri.path;
      if (path.endsWith('/2.0/Attendances')) {
        return (
          200,
          {
            'Attendances': [
              {
                'Id': 80,
                'Date': '2026-09-18',
                'LessonNo': 1,
                'Type': {'Id': 2},
                'Lesson': {
                  'Id': 500,
                  'Url': 'https://api.librus.pl/2.0/Lessons/500',
                },
              },
              {
                'Id': 81,
                'Date': '2026-09-17',
                'LessonNo': 2,
                'Type': {'Id': 2},
                'Lesson': {'Id': 999},
              },
            ],
          },
        );
      }
      if (path.endsWith('/HomeWorkAssignments')) {
        return (
          200,
          {
            'HomeWorkAssignments': [
              {
                'Id': 70,
                'Topic': 'Zadania 1–5',
                'DueDate': '2026-09-21',
                'Lesson': {'Id': 500},
              },
              {
                'Id': 71,
                'Topic': 'Wypracowanie',
                'DueDate': '2026-09-22',
                'Subject': {'Id': 10},
                'Lesson': {'Id': 999},
              },
            ],
          },
        );
      }
      return null;
    }

    String homework(AppSnapshot snapshot, String id) => snapshot.events
        .singleWhere((item) => item.id == 'homework-$id')
        .subject;

    test('attendance and homework take the subject of their lesson', () async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter(
            (options) => lessonOnly(options) ?? _successfulResponse(options),
          ),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      final attendance = {
        for (final record in snapshot.attendance) record.id: record.subject,
      };
      expect(attendance, {'80': 'Matematyka', '81': ''});
      expect(homework(snapshot, '70'), 'Matematyka');
      // A subject named directly still wins over the lesson.
      expect(homework(snapshot, '71'), 'Matematyka');
    });

    test('lists saved by an older version are fetched again at once', () async {
      final now = DateTime.now();
      final requests = <String>[];
      final cache = _MemoryReferenceCache();
      final client = LibrusClient(
        clock: () => now,
        referenceCache: cache,
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            requests.add(options.uri.path);
            return lessonOnly(options) ?? _successfulResponse(options);
          }),
      );
      await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      // The lists as an older version saved them a moment ago: no lessons.
      final saved = cache.last!;
      await cache.write(
        LibrusReferences(
          account: saved.account,
          fetchedAt: now,
          responses: {...saved.responses}..remove('Lessons'),
        ),
      );
      int lessons() => requests.where((p) => p.endsWith('/2.0/Lessons')).length;
      expect(lessons(), 1);
      final snapshot = await client.fetchSnapshot();
      expect(lessons(), 2);
      expect(snapshot.attendance.first.subject, 'Matematyka');
    });

    test('a lesson the lists do not know brings them again once old', () async {
      var now = DateTime.now();
      var newLesson = false;
      final requests = <String>[];
      final client = LibrusClient(
        clock: () => now,
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            requests.add(options.uri.path);
            final path = options.uri.path;
            if (newLesson && path.endsWith('/2.0/Attendances')) {
              return (
                200,
                {
                  'Attendances': [
                    {
                      'Id': 90,
                      'Date': '2026-09-18',
                      'LessonNo': 1,
                      'Type': {'Id': 2},
                      'Lesson': {'Id': 700},
                    },
                  ],
                },
              );
            }
            if (newLesson && path.endsWith('/2.0/Lessons')) {
              return (
                200,
                {
                  'Lessons': [
                    {
                      'Id': 700,
                      'Subject': {'Id': 11},
                    },
                  ],
                },
              );
            }
            return lessonOnly(options) ?? _successfulResponse(options);
          }),
      );
      await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      int lessons() => requests.where((p) => p.endsWith('/2.0/Lessons')).length;
      newLesson = true;
      // Lists fetched a moment ago are not fetched again.
      var snapshot = await client.fetchSnapshot();
      expect(lessons(), 1);
      expect(snapshot.attendance.single.subject, '');
      now = now.add(const Duration(minutes: 11));
      snapshot = await client.fetchSnapshot();
      expect(lessons(), 2);
      expect(snapshot.attendance.single.subject, 'Fizyka');
    });

    test(
      'the timetable names the subject when the lessons are denied',
      () async {
        final client = LibrusClient(
          dio: Dio()
            ..httpClientAdapter = _FixtureAdapter((options) {
              final path = options.uri.path;
              if (path.endsWith('/2.0/Lessons')) {
                return (403, {'Code': 'AccessDenied'});
              }
              if (path.endsWith('/Timetables')) {
                return (
                  200,
                  {
                    'Timetable': {
                      '2026-09-18': [
                        [
                          {
                            'Lesson': {'Id': '500'},
                            'LessonNo': 1,
                            'HourFrom': '08:00',
                            'HourTo': '08:45',
                            'Subject': {'Id': '11'},
                            'Teacher': {'Id': 20},
                            'Classroom': {'Id': 30},
                          },
                        ],
                        [],
                      ],
                    },
                  },
                );
              }
              return lessonOnly(options) ?? _successfulResponse(options);
            }),
        );
        final snapshot = await client.loginAndFetch(
          username: 'parent@example.com',
          password: 'secret',
        );
        final attendance = {
          for (final record in snapshot.attendance) record.id: record.subject,
        };
        // Lesson 500 is in this week's timetable; 999 is nowhere.
        expect(attendance, {'80': 'Fizyka', '81': ''});
      },
    );

    test('without the list of lessons the sync still works', () async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            if (options.uri.path.endsWith('/2.0/Lessons')) {
              return (403, {'Code': 'AccessDenied'});
            }
            return lessonOnly(options) ?? _successfulResponse(options);
          }),
      );
      final snapshot = await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      expect(snapshot.attendance, hasLength(2));
      expect(snapshot.attendance.map((item) => item.subject), everyElement(''));
      expect(snapshot.grades, isNotEmpty);
    });
  });

  group('sent messages', () {
    Future<LibrusClient> signedIn(
      (int, Object)? Function(RequestOptions options) override, {
      List<String>? requests,
    }) async {
      final client = LibrusClient(
        dio: Dio()
          ..httpClientAdapter = _FixtureAdapter((options) {
            requests?.add(options.uri.path);
            return override(options) ?? _successfulResponse(options);
          }),
      );
      await client.loginAndFetch(
        username: 'parent@example.com',
        password: 'secret',
      );
      return client;
    }

    test('come from the XML outbox with who read them', () async {
      final client = await signedIn((_) => null);
      final sent = await client.fetchSentMessages();
      expect(sent.map((item) => item.id), ['120', '121']);
      final first = sent.first;
      expect(first.sent, isTrue);
      expect(first.sender, isEmpty);
      expect(first.recipients, ['Nauczyciel Testowy']);
      expect(first.subject, 'Pytanie o sprawdzian');
      expect(first.receivedAt, DateTime(2026, 10, 17, 18, 5));
      expect(first.recipientRead, isTrue);
      expect(first.hasAttachments, isFalse);
      expect(sent.last.recipients, ['Nauczyciel Zastępczy']);
      expect(sent.last.recipientRead, isFalse);
      expect(sent.last.hasAttachments, isTrue);
    });

    test(
      'an opened sent message lists each recipient and read state',
      () async {
        final client = await signedIn((_) => null);
        final sent = await client.fetchSentMessages();
        final content = await client.fetchMessageContent(sent.first);
        expect(content.body, 'Kiedy jest sprawdzian?');
        expect(content.recipients.map((item) => item.name), [
          'Nauczyciel Testowy',
          'Nauczyciel Zastępczy',
        ]);
        expect(content.recipients.first.read, isTrue);
        expect(content.recipients.first.readAt, DateTime(2026, 10, 18, 7, 40));
        expect(content.recipients.last.read, isFalse);
        expect(content.recipients.last.readAt, isNull);
      },
    );

    test('the web Sent folder is used when the XML outbox fails', () async {
      final client = await signedIn((options) {
        if (options.uri.path.endsWith('/Outbox/action/GetList')) {
          return (200, '<error><type>eAccessDeny</type></error>');
        }
        if (options.uri.path.endsWith('/module/GetMessage')) {
          return (200, '<error><type>eAccessDeny</type></error>');
        }
        if (options.uri.path == '/wiadomosci/6') {
          return (
            200,
            '<table class="decorated stretch"><thead><tr><th></th><th></th><th>Odbiorca</th><th>Temat</th><th>Data</th></tr></thead><tbody><tr><td><a href="/wiadomosci/1/6/130/f0">Otwórz</a></td><td></td><td>Testowy Nauczyciel (Nauczyciel)</td><td>Usprawiedliwienie</td><td>2026-10-15 20:00:00</td></tr></tbody></table>',
          );
        }
        if (options.uri.path == '/wiadomosci/1/6/130/f0') {
          return (
            200,
            '<table class="container-message"><tr><td>Message</td><td><div class="container-message-content">Proszę o usprawiedliwienie</div></td></tr></table>',
          );
        }
        return null;
      });
      final sent = await client.fetchSentMessages();
      expect(sent.single.id, '130');
      expect(sent.single.sent, isTrue);
      expect(sent.single.recipients, ['Testowy Nauczyciel']);
      expect(sent.single.subject, 'Usprawiedliwienie');
      // The web folder does not say who read it.
      expect(sent.single.recipientRead, isNull);
      final content = await client.fetchMessageContent(sent.single);
      expect(content.body, 'Proszę o usprawiedliwienie');
    });

    test('both Sent folders failing gives a reason, not a list', () async {
      final client = await signedIn((options) {
        if (options.uri.path.endsWith('/Outbox/action/GetList')) {
          return (200, '<error><type>eAccessDeny</type></error>');
        }
        return null;
      });
      await expectLater(
        client.fetchSentMessages(),
        throwsA(
          isA<LibrusException>().having(
            (error) => error.detail,
            'detail',
            allOf(
              contains('XML GetList eAccessDeny'),
              contains('Synergia outbox HTTP 404'),
            ),
          ),
        ),
      );
    });

    test('sending returns the id of the new message', () async {
      final client = await signedIn((_) => null);
      expect(
        await client.sendMessage(
          recipientIds: [20],
          subject: 'Pytanie',
          body: 'Dzień dobry',
        ),
        '99',
      );
    });

    test('two mailbox calls at once log in to the mailbox once', () async {
      final requests = <String>[];
      final client = await signedIn((_) => null, requests: requests);
      // The API inbox worked, so the sync did not open the mailbox.
      expect(requests.where((path) => path == '/wiadomosci2'), isEmpty);
      final results = await Future.wait([
        client.fetchSentMessages(),
        client.fetchMessageRecipients(),
      ]);
      expect(results, everyElement(isNotEmpty));
      expect(requests.where((path) => path == '/wiadomosci2'), hasLength(1));
      expect(
        requests.where((path) => path.endsWith('/AutoLoginToken')),
        hasLength(1),
      );
    });
  });

  test('maps invalid Portal credentials to a readable error', () async {
    final dio = Dio()
      ..httpClientAdapter = _FixtureAdapter((options) {
        if (options.uri.path.endsWith('/redirect/dru')) {
          return (200, _loginPage);
        }
        return (200, '<p>Podany adres e-mail jest nieprawidłowy.</p>');
      });
    final client = LibrusClient(
      dio: dio,
      secureStorage: const FlutterSecureStorage(),
    );
    expect(
      () => client.loginAndFetch(username: 'bad', password: 'bad'),
      throwsA(
        isA<LibrusException>().having(
          (error) => error.errorCode,
          'errorCode',
          LibrusErrorCode.invalidCredentials,
        ),
      ),
    );
  });
}

const _loginPage =
    '<form><input type="hidden" name="_token" value="csrf"><input type="hidden" name="redirectTo" value="dru"></form>';

(int, Object) _successfulResponse(RequestOptions options) {
  final path = options.uri.path;
  if (path.endsWith('/AutoLoginToken')) return (200, {'Token': 'web-token'});
  if (path.contains('/loguj/token/')) return (200, 'ok');
  if (path == '/wiadomosci2') return (200, '<status>ok</status>');
  if (options.uri.host == 'wiadomosci.librus.pl') {
    expect(options.method, 'POST');
    expect(options.contentType, 'application/xml');
    expect(options.headers['Cookie'], contains('DZIENNIKSID=mail-session'));
    final request = options.data.toString();
    expect(request, contains('<service>'));
    if (path.endsWith('/Inbox/action/GetList')) {
      return (
        200,
        '<response><GetList><data><ArrayItem><messageId>91</messageId><topic>Wywiadówka</topic><senderFirstName>Nauczyciel</senderFirstName><senderLastName>Testowy</senderLastName><sendDate>2026-09-18 12:00:00</sendDate><readDate/><isAnyFileAttached>1</isAnyFileAttached></ArrayItem></data></GetList></response>',
      );
    }
    if (path.endsWith('/Outbox/action/GetList')) {
      return (
        200,
        '<response><GetList><data>'
            '<ArrayItem><messageId>120</messageId><topic>Pytanie o sprawdzian</topic><receiverFirstName>Nauczyciel</receiverFirstName><receiverLastName>Testowy</receiverLastName><sendDate>2026-10-17 18:05:00</sendDate><readDate>2026-10-18 07:40:00</readDate><isAnyFileAttached>0</isAnyFileAttached></ArrayItem>'
            '<ArrayItem><messageId>121</messageId><topic>Nieobecność</topic><receiverFirstName>Nauczyciel</receiverFirstName><receiverLastName>Zastępczy</receiverLastName><sendDate>2026-10-19 08:00:00</sendDate><readDate/><isAnyFileAttached>1</isAnyFileAttached></ArrayItem>'
            '</data></GetList></response>',
      );
    }
    if (path.endsWith('/GetMessage') &&
        request.contains('<messageId>120</messageId>')) {
      final body = base64Encode(utf8.encode('Kiedy jest sprawdzian?'));
      return (
        200,
        '<response><GetMessage><data><Message>$body</Message>'
            '<receivers>'
            '<ArrayItem><receiverId>20</receiverId><firstName>Nauczyciel</firstName><lastName>Testowy</lastName><readed>2026-10-18 07:40:00</readed></ArrayItem>'
            '<ArrayItem><receiverId>21</receiverId><firstName>Nauczyciel</firstName><lastName>Zastępczy</lastName><readed></readed></ArrayItem>'
            '</receivers></data></GetMessage></response>',
      );
    }
    if (path.endsWith('/GetMessage')) {
      expect(request, contains('<messageId>91</messageId>'));
      final body = base64Encode(utf8.encode('Pełna treść wiadomości'));
      return (
        200,
        '<response><GetMessage><data><Message>$body</Message><attachments><ArrayItem><id>7</id><filename>informacja.pdf</filename></ArrayItem></attachments></data></GetMessage></response>',
      );
    }
    if (path.endsWith('/GetFileDownloadLink')) {
      expect(request, contains('<msgId>91</msgId>'));
      return (
        200,
        '<response><GetFileDownloadLink><downloadLink>https://files.example/informacja.pdf</downloadLink></GetFileDownloadLink></response>',
      );
    }
    if (path.endsWith('/GetTypes')) {
      return (
        200,
        '<response><GetTypes><data><list><ArrayItem><id>teachers</id><name>Nauczyciele</name></ArrayItem></list></data></GetTypes></response>',
      );
    }
    if (path.endsWith('/GetListForType')) {
      return (
        200,
        '<response><GetListForType><data><ArrayItem><label>Przedmioty</label><list><ArrayItem><id>20</id><label>Nauczyciel Testowy</label></ArrayItem><ArrayItem><id>21</id><label>Nauczyciel Zastępczy</label></ArrayItem></list></ArrayItem></data></GetListForType></response>',
      );
    }
    if (path.endsWith('/SendMessage')) {
      expect(request, contains('<receivers>20</receivers>'));
      expect(request, contains(base64Encode(utf8.encode('Dzień dobry'))));
      return (
        200,
        '<response><SendMessage><status>ok</status><data>99</data></SendMessage></response>',
      );
    }
  }

  if (path.endsWith('/redirect/dru')) return (200, _loginPage);
  if (path.endsWith('/login/action')) return (302, '');
  if (path.endsWith('/oauth2/access_token')) {
    return (
      200,
      {
        'access_token': 'portal-access',
        'refresh_token': 'portal-refresh',
        'expires_in': 86400,
      },
    );
  }
  if (path.endsWith('/api/v3/SynergiaAccounts')) {
    return (
      200,
      {
        'accounts': [
          {'login': 'test-student-login'},
        ],
      },
    );
  }
  if (path.endsWith('/api/v3/SynergiaAccounts/fresh/test-student-login')) {
    return (200, {'accessToken': 'student-token'});
  }
  if (path.endsWith('/Me')) {
    return (
      200,
      {
        'Me': {
          'Account': {'Id': 7},
          'User': {'FirstName': 'Uczeń', 'LastName': 'Testowy'},
        },
      },
    );
  }
  if (path.endsWith('/Schools')) {
    return (
      200,
      {
        'School': {'Name': 'Szkoła Przykładowa', 'Town': 'Miasto Testowe'},
      },
    );
  }
  if (path.endsWith('/Subjects')) {
    return (
      200,
      {
        'Subjects': [
          {'Id': 10, 'Name': 'Matematyka'},
          {'Id': 11, 'Name': 'Fizyka'},
        ],
      },
    );
  }
  if (path.endsWith('/Users')) {
    return (
      200,
      {
        'Users': [
          {'Id': 20, 'FirstName': 'Nauczyciel', 'LastName': 'Testowy'},
        ],
      },
    );
  }
  if (path.endsWith('/Classrooms')) {
    return (
      200,
      {
        'Classrooms': [
          {'Id': 30, 'Name': 'Sala A'},
        ],
      },
    );
  }
  if (path.endsWith('/Grades/Categories')) {
    return (
      200,
      {
        'Categories': [
          {
            'Id': 40,
            'Name': 'Sprawdzian',
            'Weight': 3,
            'CountToTheAverage': true,
          },
        ],
      },
    );
  }
  if (path.endsWith('/Grades/Comments')) {
    return (
      200,
      {
        'Comments': [
          {'Id': 41, 'Text': 'Rozdział 1'},
        ],
      },
    );
  }
  if (path.endsWith('/HomeWorks/Categories')) {
    return (
      200,
      {
        'Categories': [
          {'Id': 42, 'Name': 'Kartkówka'},
        ],
      },
    );
  }
  if (path.endsWith('/Attendances/Types')) {
    return (
      200,
      {
        'Types': [
          {
            'Id': 1,
            'Name': 'Nieobecność',
            'Short': 'nb',
            'Standard': true,
            'StandardType': {'Id': 1},
          },
          {
            'Id': 2,
            'Name': 'Spóźnienie',
            'Short': 'sp',
            'Standard': true,
            'StandardType': {'Id': 2},
          },
          {
            'Id': 3,
            'Name': 'Nieobecność usprawiedliwiona',
            'Short': 'u',
            'Standard': true,
            'StandardType': {'Id': 3},
          },
          {
            'Id': 4,
            'Name': 'Zwolnienie',
            'Short': 'zw',
            'Standard': true,
            'StandardType': {'Id': 4},
          },
          {
            'Id': 5,
            'Name': 'Obecność',
            'Short': 'ob',
            'Standard': true,
            'StandardType': {'Id': 100},
          },
          {
            'Id': 6,
            'Name': 'Spóźnienie usprawiedliwione',
            'Short': 'su',
            'Standard': false,
            'StandardType': {'Id': 2},
          },
        ],
      },
    );
  }
  if (path.endsWith('/Notes/Categories')) {
    return (
      200,
      {
        'Categories': [
          {'Id': 4, 'CategoryName': 'Pochwała'},
        ],
      },
    );
  }
  if (path.endsWith('/Grades')) {
    return (
      200,
      {
        'Grades': [
          {
            'Id': 49,
            'Grade': '-',
            'Semester': 2,
            'AddDate': '2026-09-10T10:00:00',
            'Subject': {'Id': 10},
            'Category': {'Id': 40},
          },
          {
            'Id': 50,
            'Grade': '5',
            'Semester': 2,
            'AddDate': '2026-09-17T10:00:00',
            'Subject': {'Id': 10},
            'Category': {'Id': 40},
            'Improvement': {'Id': 49},
            'Comments': [
              {'Id': 41},
            ],
          },
        ],
      },
    );
  }
  if (path.endsWith('/Timetables')) {
    return (
      200,
      {
        'Timetable': {
          '2026-09-18': [
            [
              {
                'LessonNo': 1,
                'HourFrom': '08:00',
                'HourTo': '08:45',
                'Subject': {'Id': 10},
                'Teacher': {'Id': 20},
                'Classroom': {'Id': 30},
                'IsCanceled': false,
                'IsSubstitutionClass': true,
                'OrgDate': '2026-09-18',
                'OrgLessonNo': 1,
                'OrgHourFrom': '08:00',
                'OrgHourTo': '08:45',
                'OrgSubject': {'Id': 11},
                'OrgTeacher': {'Id': 20},
                'OrgClassroom': {'Id': 30},
              },
            ],
          ],
        },
      },
    );
  }
  if (path.endsWith('/HomeWorks')) {
    return (
      200,
      {
        'HomeWorks': [
          {
            'Id': 60,
            'Content': 'Kartkówka',
            'Date': '2026-09-20',
            'LessonNo': '3',
            'Subject': {'Id': 10},
            'Category': {'Id': 42},
          },
        ],
      },
    );
  }
  if (path.endsWith('/2.0/Lessons')) {
    return (
      200,
      {
        'Lessons': [
          {
            'Id': 500,
            'Teacher': {'Id': 20},
            'Subject': {'Id': 10},
          },
        ],
      },
    );
  }
  if (path.endsWith('/HomeWorkAssignments')) {
    return (
      200,
      {
        'HomeWorkAssignments': [
          {
            'Id': 70,
            'Topic': 'Zadania 1–5',
            'Text': 'Strona 12',
            'DueDate': '2026-09-21',
            'Lesson': {
              'Subject': {'Id': 10},
            },
          },
        ],
      },
    );
  }
  if (path.endsWith('/Attendances')) {
    return (
      200,
      {
        'Attendances': [
          {
            'Id': 80,
            'Date': '2026-09-18',
            'LessonNo': 1,
            'Type': {'Id': 3},
            'Lesson': {
              'Subject': {'Id': 10},
            },
          },
          {
            'Id': 81,
            'Date': '2026-09-17',
            'LessonNo': 2,
            'Type': {'Id': 2},
            'Lesson': {
              'Subject': {'Id': 10},
            },
          },
          {
            'Id': 82,
            'Date': '2026-09-16',
            'LessonNo': 3,
            'Type': {'Id': 4},
            'Lesson': {
              'Subject': {'Id': 10},
            },
          },
          {
            'Id': 83,
            'Date': '2026-09-15',
            'LessonNo': 4,
            'Type': {'Id': 6},
            'Lesson': {
              'Subject': {'Id': 10},
            },
          },
          {
            'Id': 84,
            'Date': '2026-09-14',
            'LessonNo': 5,
            'Type': {'Id': 1},
            'Lesson': {
              'Subject': {'Id': 10},
            },
          },
          {
            'Id': 85,
            'Date': '2026-09-13',
            'LessonNo': 6,
            'Type': {'Id': 5},
            'Lesson': {
              'Subject': {'Id': 10},
            },
          },
        ],
      },
    );
  }
  if (path.endsWith('/SchoolNotices')) {
    return (
      200,
      {
        'SchoolNotices': [
          {
            'Id': 90,
            'Subject': 'Zebranie',
            'Content': '<b>W czwartek</b>',
            'AddedBy': {'Id': 20},
            'CreationDate': '2026-09-18',
            'WasRead': false,
          },
        ],
      },
    );
  }
  if (path.endsWith('/Notes')) {
    return (
      200,
      {
        'Notes': [
          {
            'Id': 92,
            'Text': 'Aktywna praca',
            'Category': {'Id': 4},
            'Teacher': {'Id': 20},
            'Date': '2026-09-18',
            'Positive': 1,
          },
        ],
      },
    );
  }
  if (path.endsWith('/Messages/ReceiversGroup')) {
    return (
      200,
      {
        'ReceiversGroup': [
          {'Id': 'teachers', 'Label': 'Nauczyciele'},
          {'Id': 'parents', 'Label': 'Rodzice'},
        ],
      },
    );
  }
  if (path.endsWith('/Messages/ReceiversGroup/teachers')) {
    return (
      200,
      {
        'ReceiversGroup': [
          {
            'Id': 'teachers',
            'Label': 'Nauczyciele',
            'ReceiversSubGroup': [
              {
                'Label': 'Nauczyciele przedmiotów',
                'Receivers': [
                  {'Id': 20, 'Label': 'Nauczyciel Testowy'},
                  {'Id': 21, 'Label': 'Nauczyciel Zastępczy'},
                ],
              },
            ],
          },
        ],
      },
    );
  }
  if (path.endsWith('/Messages/91')) {
    return (
      200,
      {
        'Message': {
          'Id': 91,
          'Sender': {
            'Id': 20,
            'FirstName': 'Nauczyciel',
            'LastName': 'Testowy',
          },
          'Subject': '"Wywiadówka"',
          'Body': '"Pełna treść wiadomości"',
          'SendDate': '2026-09-18 12:00:00',
          'MessageFiles': [
            {'Id': 7, 'Name': 'informacja.pdf'},
          ],
        },
      },
    );
  }
  if (path.endsWith('/Messages/Attachment/91-7')) {
    return (200, {'DownloadUrl': 'https://files.example/informacja.pdf'});
  }
  if (path.endsWith('/Messages') && options.method == 'POST') {
    final data = options.data as Map;
    if (data['subject'] != 'Pytanie' ||
        data['body'] != 'Dzień dobry' ||
        (data['receivers'] as List).single != 20) {
      return (422, {'Code': 'InvalidPayload'});
    }
    return (
      201,
      {
        'Message': {'Id': 99},
      },
    );
  }
  if (path.endsWith('/Messages') && options.method == 'GET') {
    return (
      200,
      {
        'Messages': [
          {
            'Id': 91,
            'Sender': {'Id': 20},
            'Subject': '"Wywiadówka"',
            'Body': '"Spotkanie w czwartek"',
            'SendDate': '2026-09-18 12:00:00',
            'ReadDates': [
              {'ReadDate': 0},
            ],
            'inSended': false,
            'inTrash': false,
            'AddedFiles': true,
          },
        ],
      },
    );
  }
  return (404, {'Code': 'NotFound'});
}

class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(
    this.handler, {
    this.mailboxSession = 'mail-session',
    this.responseHeaders,
  });
  final Map<String, List<String>> Function(RequestOptions)? responseHeaders;
  final String mailboxSession;
  final (int, Object) Function(RequestOptions options) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = handler(options);
    final isString = body is String;
    return ResponseBody.fromString(
      isString ? body : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          isString ? Headers.textPlainContentType : Headers.jsonContentType,
        ],
        if (options.uri.path.contains('/loguj/token/'))
          'set-cookie': ['DZIENNIKSID=web-session; Path=/'],
        if (status == 200 && options.uri.path == '/wiadomosci2')
          'set-cookie': [
            'DZIENNIKSID=$mailboxSession; Path=/; Domain=wiadomosci.librus.pl',
          ],
        if (status == 302 && options.uri.path.endsWith('/login/action'))
          'location': ['app://librus?code=test-code'],
        ...?responseHeaders?.call(options),
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Keeps the lists in memory and remembers the last ones written.
class _MemoryReferenceCache extends LibrusReferenceCache {
  _MemoryReferenceCache()
    : super(directory: () async => throw const FileSystemException('none'));

  LibrusReferences? last;

  @override
  Future<void> write(LibrusReferences references) async {
    last = references;
    await super.write(references);
  }
}
