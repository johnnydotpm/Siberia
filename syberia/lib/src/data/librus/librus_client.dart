import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xml/xml.dart';
import 'package:html/parser.dart' as html_parser;

import '../../debug/diagnostics.dart';
import '../../domain/librus_error.dart';
import '../../domain/models.dart';
import '../../domain/stable_hash.dart';
import 'librus_logins.dart';
import 'reference_cache.dart';

/// The parts of a snapshot a sync can be limited to.
enum LibrusPart {
  grades,
  timetable,
  events,
  homework,
  attendance,
  announcements,
  notices,
  messages,
}

/// Portal-backed Synergia access and web mailbox sessions. Token and session
/// lifetimes follow Szkolny.eu: six hours for API access and 45 minutes for web.
class LibrusClient {
  /// A client for one student: `synergiaLogin` in the Librus login
  /// `account`, which [logins] keeps. Without them it works for the login it
  /// signs in to.
  LibrusClient({
    Dio? dio,
    FlutterSecureStorage? secureStorage,
    DateTime Function()? clock,
    LibrusReferenceCache? referenceCache,
    LibrusLogins? logins,
    this._account,
    this._synergiaLogin,
  }) : _dio = dio ?? Dio(),
       _clock = clock ?? DateTime.now,
       _referenceCache = referenceCache ?? LibrusReferenceCache(),
       _logins =
           logins ?? LibrusLogins(secureStorage: secureStorage, clock: clock) {
    // Every request goes in the debug menu's log, without its query.
    Diagnostics.instance.watch(_dio);
  }

  static const _portalBase = 'https://portal.librus.pl';
  static const _portalApi = '$_portalBase/api/v3';
  static const _apiBase = 'https://api.librus.pl/2.0';
  static const _authorizeUrl = '$_portalBase/konto-librus/redirect/dru';
  static const _loginUrl = '$_portalBase/konto-librus/login/action';
  static const _tokenUrl = '$_portalBase/oauth2/access_token';
  static const _clientId = 'VaItV6oRutdo8fnjJwysnTjVlvaswf52ZqmXsJGP';
  static const _redirectUrl = 'app://librus';
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/146.0 Mobile Safari/537.36 LibrusMobileApp';

  final DateTime Function() _clock;
  final LibrusReferenceCache _referenceCache;
  final LibrusLogins _logins;
  String? _account;
  String? _synergiaLogin;

  /// The Librus login this client works in, once known.
  String? get account => _account;

  /// The student it fetches, once chosen.
  String? get synergiaLogin => _session?.synergiaLogin ?? _synergiaLogin;
  final Dio _dio;
  final List<_Cookie> _cookies = [];
  _PortalSession? _session;
  String? _synergiaToken;
  DateTime? _apiTokenExpiresAt;
  DateTime? _synergiaSessionExpiresAt;
  DateTime? _messagesSessionExpiresAt;
  Future<void>? _refreshInFlight;
  Future<void>? _webSessionInFlight;
  Future<void>? _messagesSessionInFlight;

  bool _validUntil(DateTime? expiry) =>
      expiry != null &&
      expiry.isAfter(_clock().add(const Duration(seconds: 30)));

  bool _hasCookieFor(String url) => _cookies.any(
    (cookie) =>
        cookie.name == 'DZIENNIKSID' &&
        cookie.value.isNotEmpty &&
        cookie.matches(Uri.parse(url)),
  );

  void _clearRuntimeSessions() {
    _cookies.clear();
    _synergiaToken = null;
    _apiTokenExpiresAt = null;
    _synergiaSessionExpiresAt = null;
    _messagesSessionExpiresAt = null;
  }

  Future<AppSnapshot> loginAndFetch({
    required String username,
    required String password,
  }) async {
    await _signIn(username, password);
    return fetchSnapshot();
  }

  /// Logs in to a Librus account and lists its students, from which the app
  /// makes profiles. The login is saved for them.
  Future<LibrusSignIn> signIn({
    required String username,
    required String password,
  }) async {
    await _signIn(username, password);
    return LibrusSignIn(
      account: _account!,
      students: await _students(_session!.accessToken),
    );
  }

  Future<void> _signIn(String username, String password) async {
    final email = username.trim();
    if (email.isEmpty || password.isEmpty) {
      throw const LibrusException(LibrusErrorCode.missingCredentials);
    }
    _clearRuntimeSessions();
    _session = await _loginWithPortal(email, password);
    _account = LibrusLogin.keyOf(email);
    _synergiaLogin = null;
    await _saveSession();
  }

  /// [parts] limits the sync to these parts; the others come back empty.
  Future<AppSnapshot?> restoreAndFetch({Set<LibrusPart>? parts}) async {
    if (!await _restoreSession()) return null;
    return fetchSnapshot(parts: parts);
  }

  /// Forgets this client's session and the lists it kept, and the login
  /// itself.
  Future<void> logout() async {
    await forget();
    final account = _account;
    if (account != null) await _logins.remove(account);
  }

  /// Forgets this client's session and the lists it kept for its student.
  /// The login stays, for the other profiles in it.
  Future<void> forget() async {
    final lists = await _restoreSession() ? _referenceAccount : null;
    _clearRuntimeSessions();
    _session = null;
    if (lists != null) await _referenceCache.remove(lists);
  }

  /// The students in this client's login, the one it fetches selected.
  Future<List<LinkedSynergiaAccount>> fetchSynergiaAccounts() async {
    await _prepareFreshSession();
    final selected = _session!.synergiaLogin;
    return [
      for (final student in await _students(_session!.accessToken))
        student.copyWith(selected: student.login == selected),
    ];
  }

  Future<List<LinkedSynergiaAccount>> _students(String accessToken) async {
    final root = await _portalGet('SynergiaAccounts', accessToken);
    final accounts = _findList(root, const [
      'accounts',
      'Accounts',
      'SynergiaAccounts',
      'data',
    ]);
    return [
      for (final account in accounts)
        if (_accountLogin(account)?.isNotEmpty == true)
          LinkedSynergiaAccount(
            login: _accountLogin(account)!,
            name: account['studentName']?.toString().trim() ?? '',
            selected: false,
            account: _account ?? '',
            parent: account['group'] == 'parent',
          ),
    ];
  }

  Future<List<MessageRecipient>> fetchMessageRecipients() async {
    await _prepareMessagesSession();
    final types = await _messagesRequest('Receivers/action/GetTypes', {
      'includeClass': 1,
    });
    final recipients = <int, MessageRecipient>{};
    for (final type in types.findAllElements('ArrayItem')) {
      final id = _xmlText(type, 'id');
      if (id.isEmpty || id == 'contactsGroups') continue;
      final response = await _messagesRequest(
        'Receivers/action/GetListForType',
        {'receiverType': id},
      );
      void append(XmlElement element, String group) {
        final list = element.getElement('list');
        if (list != null) {
          for (final child in list.findElements('ArrayItem')) {
            append(child, _xmlText(element, 'label'));
          }
          return;
        }
        final recipientId = int.tryParse(_xmlText(element, 'id'));
        final name = _xmlText(element, 'label');
        if (recipientId != null && name.isNotEmpty) {
          recipients.putIfAbsent(
            recipientId,
            () => MessageRecipient(id: recipientId, name: name, group: group),
          );
        }
      }

      for (final data in response.findAllElements('data')) {
        for (final item in data.findElements('ArrayItem')) {
          append(item, _xmlText(type, 'name'));
        }
      }
    }
    return recipients.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Returns the id of the new message.
  Future<String> sendMessage({
    required List<int> recipientIds,
    required String subject,
    required String body,
  }) async {
    if (recipientIds.isEmpty || subject.trim().isEmpty || body.trim().isEmpty) {
      throw const LibrusException(LibrusErrorCode.incompleteMessageForm);
    }
    await _prepareMessagesSession();
    final response = await _messagesRequest('SendMessage', {
      'topic': base64Encode(utf8.encode(subject.trim())),
      'message': base64Encode(utf8.encode(body.trim())),
      'receivers': recipientIds.toSet().join(','),
      'actions': base64Encode(utf8.encode('<Actions/>')),
    });
    final confirmed = response
        .findAllElements('status')
        .any((e) => e.innerText == 'ok');
    final id = response
        .findAllElements('data')
        .map((e) => int.tryParse(e.innerText.trim()))
        .nonNulls
        .firstOrNull;
    if (!confirmed || id == null) {
      // The translation shows the detail, so there always is one.
      throw LibrusException(
        LibrusErrorCode.messageNotSent,
        detail: confirmed
            ? 'Messages: XML SendMessage no message id'
            : 'Messages: XML SendMessage not confirmed',
      );
    }
    return '$id';
  }

  /// The messages the student sent this school year. The XML mailbox says
  /// who read them; the web mailbox is tried when it fails.
  Future<List<SchoolMessage>> fetchSentMessages() async {
    try {
      return await _fetchXmlOutbox();
    } on LibrusException catch (xmlError) {
      try {
        return await _fetchSynergiaOutbox();
      } on LibrusException catch (webError) {
        throw LibrusException(
          LibrusErrorCode.serverReply,
          detail: '${_mailboxFailure(xmlError)}; ${_mailboxFailure(webError)}',
        );
      }
    }
  }

  Future<Uri> fetchMessageAttachmentUrl({
    required String messageId,
    required String attachmentId,
  }) async {
    await _prepareMessagesSession();
    final response = await _messagesRequest('GetFileDownloadLink', {
      'fileId': attachmentId,
      'msgId': messageId,
      'archive': 0,
    });
    final links = response.findAllElements('downloadLink');
    final uri = links.isEmpty
        ? null
        : Uri.tryParse(links.first.innerText.trim());
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.toString().contains('CSDownloadFailed')) {
      throw const LibrusException(LibrusErrorCode.attachmentFetchFailed);
    }
    // Return the download landing page; sandbox links may require browser setup.
    return uri;
  }

  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage summary,
  ) async {
    try {
      return await _fetchXmlMessageContent(summary);
    } on LibrusException catch (xmlError) {
      try {
        return await _fetchSynergiaMessageContent(summary);
      } on LibrusException catch (webError) {
        throw LibrusException(
          LibrusErrorCode.serverReply,
          detail: '${_mailboxFailure(xmlError)}; ${_mailboxFailure(webError)}',
        );
      }
    }
  }

  Future<SchoolMessageContent> _fetchXmlMessageContent(
    SchoolMessage summary,
  ) async {
    await _prepareMessagesSession();
    final response = await _messagesRequest('GetMessage', {
      'messageId': summary.id,
      'archive': 0,
    });
    final data = response
        .findAllElements('GetMessage')
        .firstOrNull
        ?.getElement('data');
    final encoded = data == null ? '' : _xmlText(data, 'Message');
    if (data == null || data.getElement('Message') == null) {
      throw const LibrusException(
        LibrusErrorCode.serverReply,
        detail: 'Messages: GetMessage missing body',
      );
    }
    String body;
    try {
      body = utf8.decode(base64.decode(base64.normalize(encoded)));
    } on FormatException {
      throw const LibrusException(
        LibrusErrorCode.serverReply,
        detail: 'Messages: GetMessage invalid Base64',
      );
    }
    return SchoolMessageContent(
      id: summary.id,
      sender: summary.sender,
      subject: summary.subject,
      body: _plainText(body.replaceAll('<![CDATA[', '').replaceAll(']]>', '')),
      receivedAt: summary.receivedAt,
      recipients: summary.sent
          ? [
              for (final receiver
                  in data.getElement('receivers')?.findElements('ArrayItem') ??
                      <XmlElement>[])
                if (_fullName(
                  _xmlText(receiver, 'firstName'),
                  _xmlText(receiver, 'lastName'),
                ).isNotEmpty)
                  _receiver(receiver),
            ]
          : const [],
      attachments: [
        for (final attachment
            in data.getElement('attachments')?.findElements('ArrayItem') ??
                <XmlElement>[])
          if (_xmlText(attachment, 'id').isNotEmpty &&
              _xmlText(attachment, 'filename').isNotEmpty)
            MessageAttachment(
              id: _xmlText(attachment, 'id'),
              name: _xmlText(attachment, 'filename'),
            ),
      ],
    );
  }

  /// [parts] limits the sync to these parts; the others come back empty.
  Future<AppSnapshot> fetchSnapshot({Set<LibrusPart>? parts}) async {
    final wanted = parts ?? LibrusPart.values.toSet();
    await _prepareFreshSession();
    final week = _dateOnly(librusSyncWeekStart(DateTime.now()));
    Future<Map<String, dynamic>> data(
      LibrusPart part,
      String endpoint, {
      bool optional = false,
    }) => wanted.contains(part)
        ? _apiGet(endpoint, optional: optional)
        : Future.value(const <String, dynamic>{});
    final withMessages = wanted.contains(LibrusPart.messages);
    // Everything starts at once: the reference lists (usually from the
    // cache), the data and the inbox.
    final responses = await Future.wait<Object?>([
      _referenceLists(),
      Future.wait([
        data(LibrusPart.grades, 'Grades'),
        data(LibrusPart.timetable, 'Timetables?weekStart=$week'),
        data(LibrusPart.events, 'HomeWorks'),
        data(LibrusPart.homework, 'HomeWorkAssignments', optional: true),
        data(LibrusPart.attendance, 'Attendances', optional: true),
        data(LibrusPart.announcements, 'SchoolNotices', optional: true),
        data(LibrusPart.notices, 'Notes', optional: true),
        data(LibrusPart.grades, 'Grades/Comments', optional: true),
        data(LibrusPart.timetable, 'TeacherFreeDays', optional: true),
      ]),
      if (withMessages)
        _apiGet(_apiInboxEndpoint).then<Object?>(
          (root) => root,
          // The other mailboxes are tried below.
          onError: (Object error) => error,
        ),
    ]);
    var (references, fresh) = responses[0]! as (LibrusReferences, bool);
    final fetched = responses[1]! as List<Map<String, dynamic>>;
    final inbox = withMessages ? responses[2] : null;
    _SnapshotInput input(LibrusReferences references) => (
      references: references.responses,
      knownMissing: references.knownMissing,
      data: fetched,
      inbox: inbox is Map<String, dynamic> ? inbox : null,
      login: _session!.synergiaLogin,
    );
    // Turning the responses into the app's data runs off the UI isolate, so
    // a sync never makes scrolling stutter.
    var parsed = await compute(_parseSnapshot, input(references));
    if (parsed.unknown.isNotEmpty) {
      if (!fresh && _referencesMayBeStale(references)) {
        // A new subject, teacher or category: the lists are fetched again.
        (references, fresh) = await _referenceLists(fresh: true);
        parsed = await compute(_parseSnapshot, input(references));
      }
      if (fresh) await _rememberMissing(references, parsed.unknown);
    }

    var messages = <SchoolMessage>[];
    AppError? messagesError;
    if (withMessages) {
      try {
        messages =
            parsed.apiMessages ??
            await _fallbackMessages(switch (inbox) {
              LibrusException() || DioException() => _mailboxFailure(inbox!),
              Map() => 'Messages: API inbox unexpected JSON',
              _ => throw inbox!,
            });
      } on Object catch (error) {
        messagesError = AppError.from(
          error is DioException ? _networkException(error) : error,
        );
      }
    }
    return AppSnapshot(
      profile: parsed.profile,
      lessons: parsed.lessons,
      grades: parsed.grades,
      events: parsed.events,
      messages: messages,
      messagesError: messagesError,
      attendance: parsed.attendance,
      announcements: parsed.announcements,
      notices: parsed.notices,
      freeDays: parsed.freeDays,
      lastSync: DateTime.now(),
    );
  }

  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async {
    await _prepareFreshSession();
    final monday = _startOfWeek(day);
    final responses = await Future.wait<Object>([
      _referenceLists(),
      _apiGet('Timetables?weekStart=${_dateOnly(monday)}'),
    ]);
    var (references, fresh) = responses[0] as (LibrusReferences, bool);
    final timetable = responses[1] as Map<String, dynamic>;
    (List<Lesson>, Set<String>) parse(LibrusReferences references) {
      final unknown = _UnknownReferences(references.knownMissing);
      final lessons = _parseTimetable(
        timetable,
        subjects: unknown.track(
          'subject',
          _idNameMap(references['Subjects'], 'Subjects', 'Name'),
        ),
        teachers: unknown.track(
          'user',
          _peopleMap(references['Users'], 'Users'),
        ),
        classrooms: unknown.track(
          'classroom',
          _idNameMap(references['Classrooms'], 'Classrooms', 'Name'),
        ),
      );
      return (lessons, unknown.found);
    }

    var (lessons, unknown) = parse(references);
    if (unknown.isNotEmpty) {
      if (!fresh && _referencesMayBeStale(references)) {
        (references, fresh) = await _referenceLists(fresh: true);
        (lessons, unknown) = parse(references);
      }
      if (fresh) await _rememberMissing(references, unknown);
    }
    return lessons;
  }

  /// Names that lists fetched just now still lack are not looked for again
  /// until the lists are next fetched.
  Future<void> _rememberMissing(
    LibrusReferences references,
    Set<String> unknown,
  ) async {
    if (unknown.isEmpty || references.knownMissing.containsAll(unknown)) {
      return;
    }
    await _referenceCache.write(references.withKnownMissing(unknown));
  }

  static const _apiInboxEndpoint =
      'Messages?alternativeBody=true&changeNewLine=1&afterId=0&limit=50&page=1';

  /// The lists the sync looks names up in, and whether failing to get each
  /// may be tolerated.
  static const _referenceEndpoints = {
    'Me': false,
    'Schools': false,
    'Subjects': false,
    'Users': false,
    'Classrooms': false,
    'Grades/Categories': false,
    'Attendances/Types': true,
    // Which subject each lesson is: attendance names only the lesson.
    'Lessons': true,
    'Notes/Categories': true,
    'HomeWorks/Categories': true,
    // Holidays and the class's days off change seldom; teachers' absences
    // come with each sync.
    'SchoolFreeDays': true,
    'ClassFreeDays': true,
    'ClassFreeDays/Types': true,
    'TeacherFreeDays/Types': true,
  };

  /// Names the cached lists after the account without storing its address.
  String get _referenceAccount =>
      stableHash('${_session!.email}\n${_session!.synergiaLogin ?? ''}');

  /// Lists fetched a while ago may lack what was added since. Lists only a
  /// few minutes old are not fetched again yet.
  bool _referencesMayBeStale(LibrusReferences references) =>
      _clock().difference(references.fetchedAt) > const Duration(minutes: 10);

  /// The lists, and whether they were downloaded just now.
  Future<(LibrusReferences, bool)> _referenceLists({bool fresh = false}) async {
    final account = _referenceAccount;
    if (!fresh) {
      final cached = await _referenceCache.read(account);
      // A list that failed is saved empty; one missing altogether means an
      // older version saved them, before that list was fetched.
      final complete =
          cached != null &&
          _referenceEndpoints.keys.every(cached.responses.containsKey);
      if (cached != null && complete) {
        final age = _clock().difference(cached.fetchedAt);
        if (!age.isNegative && age < LibrusReferenceCache.maxAge) {
          return (cached, false);
        }
      }
    }
    final endpoints = _referenceEndpoints.entries.toList(growable: false);
    final responses = await Future.wait([
      for (final endpoint in endpoints)
        _apiGet(endpoint.key, optional: endpoint.value),
    ]);
    final references = LibrusReferences(
      account: account,
      fetchedAt: _clock(),
      responses: {
        for (final (index, endpoint) in endpoints.indexed)
          endpoint.key: responses[index],
      },
    );
    await _referenceCache.write(references);
    return (references, true);
  }

  Future<_PortalSession> _loginWithPortal(String email, String password) async {
    try {
      final page = await _request('GET', _authorizeUrl, stopAtExternal: true);
      final html = page.data?.toString() ?? '';
      final hidden = _hiddenInputs(html);
      final csrf = _firstMatch(
        html,
        RegExp(
          r'<meta[^>]+name=["\x27]csrf-token["\x27][^>]+content=["\x27]([^"\x27]+)',
          caseSensitive: false,
        ),
      );
      final login = await _request(
        'POST',
        _loginUrl,
        data: {...hidden, 'email': email, 'password': password},
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': page.realUri.toString(),
          'X-Requested-With': 'pl.librus.synergiaDru2',
          if (csrf != null) 'X-CSRF-TOKEN': _htmlDecode(csrf),
        },
        stopAtExternal: true,
      );
      final combined =
          '${login.realUri}\n${login.headers.value('location') ?? ''}\n${login.data ?? ''}';
      final code = _firstMatch(
        combined,
        RegExp(r'app://librus\?code=([^&\s"\x27<]+)'),
      );
      if (code == null) {
        if (combined.contains('robotem') || combined.contains('g-recaptcha')) {
          throw const LibrusException(LibrusErrorCode.captchaRequired);
        }
        if (combined.contains('nieprawidłow') ||
            combined.contains('Nieprawidłow') ||
            combined.contains('Upewnij się')) {
          throw const LibrusException(LibrusErrorCode.invalidCredentials);
        }
        throw const LibrusException(LibrusErrorCode.loginFailed);
      }
      final token = await _exchangeToken({
        'grant_type': 'authorization_code',
        'client_id': _clientId,
        'redirect_uri': _redirectUrl,
        'code': Uri.decodeComponent(code),
      });
      return _PortalSession(
        email: email,
        password: password,
        accessToken: token['access_token']!.toString(),
        refreshToken: token['refresh_token']!.toString(),
        synergiaLogin: null,
      );
    } on LibrusException {
      rethrow;
    } on DioException catch (error) {
      throw _networkException(error);
    }
  }

  Future<void> _refreshPortalAndSynergia() async {
    var session = _session!;
    final account = _account;
    // The login's other profiles share its tokens: they are renewed one
    // profile at a time, and saved as they are renewed.
    session = session.withLogin(
      account == null
          ? await _renewLogin(session.login)
          : await _logins.renewed(account, _renewLogin),
    );
    final accountsResponse = await _portalGet(
      'SynergiaAccounts',
      session.accessToken,
    );
    final accounts = _findList(accountsResponse, const [
      'accounts',
      'Accounts',
      'SynergiaAccounts',
      'data',
    ]);
    final savedLogin = session.synergiaLogin;
    final selected = savedLogin == null
        ? accounts.firstWhere(
            (item) =>
                item['group'] == 'student' ||
                (_accountLogin(item)?.toLowerCase().endsWith('u') ?? false),
            orElse: () =>
                accounts.isEmpty ? <String, dynamic>{} : accounts.first,
          )
        : accounts.firstWhere(
            (item) => _accountLogin(item) == savedLogin,
            orElse: () => <String, dynamic>{},
          );
    final login = _accountLogin(selected);
    if (login == null || login.isEmpty) {
      throw const LibrusException(LibrusErrorCode.noSynergiaAccount);
    }
    final fresh = await _portalGet(
      'SynergiaAccounts/fresh/${Uri.encodeComponent(login)}',
      session.accessToken,
    );
    final accessToken = _deepString(fresh, const [
      'accessToken',
      'AccessToken',
      'token',
    ]);
    if (accessToken == null || accessToken.isEmpty) {
      throw const LibrusException(LibrusErrorCode.noSynergiaToken);
    }
    _synergiaToken = accessToken;
    _apiTokenExpiresAt = _clock().add(const Duration(hours: 6));
    _session = session.copyWith(synergiaLogin: login);
  }

  /// New portal tokens for [current]: refreshed, or from logging in again
  /// with the password when Librus refuses the refresh.
  Future<LibrusLogin> _renewLogin(LibrusLogin current) async {
    if (current.refreshToken.isEmpty) return current;
    try {
      final token = await _exchangeToken({
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': current.refreshToken,
      });
      return current.copyWith(
        accessToken: token['access_token']?.toString(),
        refreshToken: token['refresh_token']?.toString(),
      );
    } on LibrusException {
      _cookies.clear();
      final fresh = await _loginWithPortal(current.email, current.password);
      return current.copyWith(
        accessToken: fresh.accessToken,
        refreshToken: fresh.refreshToken,
      );
    }
  }

  Future<void> _prepareFreshSession() async {
    if (_session == null && !await _restoreSession()) {
      throw const LibrusException(LibrusErrorCode.noStoredAccount);
    }
    if (_synergiaToken != null && _validUntil(_apiTokenExpiresAt)) return;
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final refresh = _refreshPortalAndSynergia();
    _refreshInFlight = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  Future<Map<String, dynamic>> _exchangeToken(Map<String, String> data) async {
    final response = await _dio.post<Object?>(
      _tokenUrl,
      data: FormData.fromMap(data),
      options: Options(
        validateStatus: (status) => status != null && status < 600,
        headers: {'User-Agent': _userAgent},
      ),
    );
    final json = _map(response.data) ?? _decodeMap(response.data);
    if (response.statusCode == 200 &&
        json?['access_token'] != null &&
        json?['refresh_token'] != null) {
      return json!;
    }
    final reply =
        json?['hint']?.toString() ?? json?['error_description']?.toString();
    throw reply == null
        ? const LibrusException(LibrusErrorCode.sessionRenewFailed)
        : LibrusException(LibrusErrorCode.serverReply, detail: reply);
  }

  Future<Map<String, dynamic>> _portalGet(
    String endpoint,
    String accessToken,
  ) async {
    final response = await _dio.get<Object?>(
      '$_portalApi/$endpoint',
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
          'User-Agent': _userAgent,
        },
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    final json = _map(response.data) ?? _decodeMap(response.data);
    if (response.statusCode == 200 && json != null) return json;
    throw LibrusException(
      LibrusErrorCode.portalRejected,
      detail: '${response.statusCode ?? '?'}',
    );
  }

  Future<Map<String, dynamic>> _apiGet(
    String endpoint, {
    bool optional = false,
    String method = 'GET',
    bool retrySession = true,
  }) async {
    final requestToken = _synergiaToken;
    try {
      final response = await _dio.request<Object?>(
        '$_apiBase/$endpoint',
        options: Options(
          method: method,
          headers: {
            'Authorization': 'Bearer $requestToken',
            'Accept': 'application/json',
            'User-Agent': _userAgent,
          },
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final json = _map(response.data) ?? _decodeMap(response.data);
      if (response.statusCode == 200 && json != null) return json;
      if (response.statusCode == 401 && retrySession) {
        if (requestToken == _synergiaToken) {
          _apiTokenExpiresAt = null;
          await _prepareFreshSession();
        }
        return await _apiGet(
          endpoint,
          optional: optional,
          method: method,
          retrySession: false,
        );
      }
      if (optional) return const {};
      throw LibrusException(
        LibrusErrorCode.apiRejected,
        detail: '${response.statusCode ?? '?'}',
        code: json?['Code']?.toString(),
      );
    } on DioException catch (error) {
      if (optional) return const {};
      throw _networkException(error);
    }
  }

  // Protocol reference: szkolny-eu/szkolny-android, LibrusLoginMessages
  // and LibrusMessages*. Implemented in Dart for the cross-platform client.
  static const _messagesBase = 'https://wiadomosci.librus.pl/module';
  static const _webUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/62.0';

  /// Logging in twice at once would clear the cookies of the first login.
  Future<void> _prepareSynergiaWebSession() => _webSessionInFlight ??=
      _openSynergiaWebSession().whenComplete(() => _webSessionInFlight = null);

  Future<void> _prepareMessagesSession() =>
      _messagesSessionInFlight ??= _openMessagesSession().whenComplete(
        () => _messagesSessionInFlight = null,
      );

  Future<void> _openSynergiaWebSession() async {
    await _prepareFreshSession();
    if (_validUntil(_synergiaSessionExpiresAt) &&
        _hasCookieFor('https://synergia.librus.pl/')) {
      return;
    }
    _synergiaSessionExpiresAt = null;
    _messagesSessionExpiresAt = null;
    _cookies.removeWhere(
      (cookie) =>
          cookie.domain == 'synergia.librus.pl' ||
          cookie.domain == 'wiadomosci.librus.pl',
    );
    final tokenJson = await _apiGet('AutoLoginToken', method: 'POST');
    final token = _deepString(tokenJson, const ['Token', 'token']);
    if (token == null || token.isEmpty) {
      throw const LibrusException(LibrusErrorCode.noSynergiaToken);
    }
    final login = await _request(
      'GET',
      'https://synergia.librus.pl/loguj/token/${Uri.encodeComponent(token)}/przenies/uczen/widok/centrum_powiadomien',
    );
    if (!_cookies.any(
      (cookie) =>
          cookie.name == 'DZIENNIKSID' &&
          cookie.matches(Uri.parse('https://synergia.librus.pl/')),
    )) {
      throw LibrusException(
        LibrusErrorCode.serverReply,
        detail:
            'Messages: Synergia login HTTP ${login.statusCode ?? 0}, missing session',
      );
    }
    _synergiaSessionExpiresAt = _clock().add(const Duration(minutes: 45));
  }

  Future<void> _openMessagesSession() async {
    await _prepareSynergiaWebSession();
    if (_validUntil(_messagesSessionExpiresAt) &&
        _hasCookieFor(_messagesBase)) {
      return;
    }
    _messagesSessionExpiresAt = null;
    _cookies.removeWhere((cookie) => cookie.domain == 'wiadomosci.librus.pl');
    final response = await _request(
      'GET',
      'https://synergia.librus.pl/wiadomosci2',
      stopAtMessagesAutoLogon: true,
      headers: {'User-Agent': _webUserAgent},
    );
    final text = response.data?.toString() ?? '';
    if (text.contains('grecaptcha.ready')) {
      throw const LibrusException(LibrusErrorCode.captchaRequired);
    }
    // AutoLogon may redirect to a landing page after issuing the session.
    // Szkolny.eu validates the cookie, not the final landing page's status.
    if (!_cookies.any(
      (cookie) =>
          cookie.name == 'DZIENNIKSID' &&
          cookie.matches(Uri.parse(_messagesBase)) &&
          cookie.value.isNotEmpty,
    )) {
      throw LibrusException(
        LibrusErrorCode.serverReply,
        detail:
            'Messages: mailbox login HTTP ${response.statusCode ?? 0}, missing session',
      );
    }
    _messagesSessionExpiresAt = _clock().add(const Duration(minutes: 45));
  }

  String _xmlText(XmlElement element, String name) =>
      element.getElement(name)?.innerText.trim() ?? '';

  Future<XmlDocument> _messagesRequest(
    String endpoint,
    Map<String, Object> parameters, {
    bool retrySession = true,
  }) async {
    for (var index = 0; index < _cookies.length; index++) {
      final cookie = _cookies[index];
      if (cookie.name == 'DZIENNIKSID' &&
          cookie.matches(Uri.parse(_messagesBase))) {
        _cookies[index] = _Cookie(
          name: cookie.name,
          value: cookie.value.replaceAll('-MAINT', '').replaceAll('MAINT', ''),
          domain: cookie.domain,
          path: cookie.path,
        );
      }
    }
    final builder = XmlBuilder();
    builder.element(
      'service',
      nest: () {
        builder.element('header');
        builder.element(
          'data',
          nest: () {
            for (final entry in parameters.entries) {
              builder.element(entry.key, nest: entry.value.toString());
            }
          },
        );
      },
    );
    final response = await _request(
      'POST',
      '$_messagesBase/$endpoint',
      data: builder.buildDocument().toXmlString(),
      contentType: 'application/xml',
      headers: {'User-Agent': _webUserAgent},
    );
    final action = endpoint.split('/').last;
    if (response.statusCode != 200) {
      throw LibrusException(
        LibrusErrorCode.serverReply,
        detail: 'Messages: XML $action HTTP ${response.statusCode ?? 0}',
      );
    }
    try {
      final doc = XmlDocument.parse(response.data?.toString() ?? '');
      final type = doc.findAllElements('type').firstOrNull?.innerText.trim();
      final safeType =
          type != null && RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,79}$').hasMatch(type)
          ? type
          : null;
      final hasError =
          doc.rootElement.name.local == 'error' ||
          doc.findAllElements('error').isNotEmpty ||
          doc
              .findAllElements('status')
              .any((e) => e.innerText.trim() == 'error');
      if (safeType == 'eAccessDeny' &&
          retrySession &&
          endpoint != 'SendMessage') {
        _messagesSessionExpiresAt = null;
        await _prepareMessagesSession();
        return await _messagesRequest(
          endpoint,
          parameters,
          retrySession: false,
        );
      }
      if (hasError ||
          safeType == 'eAccessDeny' ||
          safeType == 'eVarWhitThisNameNotExists') {
        throw LibrusException(
          LibrusErrorCode.serverReply,
          detail: 'Messages: XML $action ${safeType ?? "server error"}',
        );
      }
      if (doc.findAllElements('response').isEmpty ||
          doc.findAllElements(action).isEmpty) {
        throw LibrusException(
          LibrusErrorCode.serverReply,
          detail: 'Messages: XML $action unexpected response structure',
        );
      }
      return doc;
    } on XmlException {
      throw LibrusException(
        LibrusErrorCode.serverReply,
        detail: 'Messages: XML $action invalid XML',
      );
    }
  }

  // Diagnostic codes only: never include response bodies, cookies or tokens.
  String _mailboxFailure(Object error) {
    if (error is LibrusException) {
      if (error.errorCode == LibrusErrorCode.serverReply &&
          error.detail?.startsWith('Messages:') == true) {
        return error.detail!;
      }
      final code = error.code;
      final safeCode =
          code != null && RegExp(r'^[A-Za-z0-9_]{1,80}$').hasMatch(code)
          ? ' $code'
          : '';
      final status =
          error.detail != null && RegExp(r'^[0-9]{3}$').hasMatch(error.detail!)
          ? ' HTTP ${error.detail}'
          : '';
      return 'Messages: ${error.errorCode.name}$status$safeCode';
    }
    if (error is DioException) {
      return 'Messages: ${_networkException(error).errorCode.name}';
    }
    return 'Messages: unexpected response';
  }

  /// The messages of the mobile inbox, or null when it answered with
  /// something else.
  static List<SchoolMessage>? _apiMessages(
    Map<String, dynamic> root,
    Map<int, String> people,
  ) {
    if (root['Messages'] is! List) return null;
    return _list(root['Messages'])
        .where(
          (item) =>
              item['inSended'] != true &&
              item['inSended'] != 1 &&
              item['InSent'] != true &&
              item['inTrash'] != true &&
              item['inTrash'] != 1,
        )
        .map((item) {
          final readDates = _list(item['ReadDates']);
          final readValue = readDates.isEmpty
              ? null
              : readDates.first['ReadDate'];
          return SchoolMessage(
            id: item['Id'].toString(),
            sender:
                people[_referenceId(item['Sender'])] ??
                _fullName(
                  _map(item['Sender'])?['FirstName'],
                  _map(item['Sender'])?['LastName'],
                ),
            subject: _jsonText(item['Subject']),
            preview: _plainText(_jsonText(item['Body'])),
            receivedAt: _flexDate(item['SendDate']) ?? DateTime.now(),
            unread:
                item['IsNew'] == true ||
                (readDates.isNotEmpty && (readValue == 0 || readValue == '0')),
            hasAttachments:
                item['AddedFiles'] == true ||
                item['HasAttachment'] == true ||
                _list(item['MessageFiles']).isNotEmpty,
          );
        })
        .toList(growable: false);
  }

  /// The mobile inbox works on accounts which deny the mobile content
  /// endpoint. When it fails, the XML and then the web mailbox are tried.
  Future<List<SchoolMessage>> _fallbackMessages(String apiFailure) async {
    try {
      return await _fetchXmlInbox();
    } on LibrusException catch (xmlError) {
      try {
        return await _fetchSynergiaInbox();
      } on LibrusException catch (webError) {
        throw LibrusException(
          LibrusErrorCode.serverReply,
          detail:
              '$apiFailure; ${_mailboxFailure(xmlError)}; ${_mailboxFailure(webError)}',
        );
      }
    }
  }

  Future<List<SchoolMessage>> _fetchXmlInbox() async {
    await _prepareMessagesSession();
    final response = await _messagesRequest('Inbox/action/GetList', {
      'archive': 0,
    });
    final data = response
        .findAllElements('GetList')
        .firstOrNull
        ?.getElement('data');
    if (data == null) {
      throw const LibrusException(
        LibrusErrorCode.serverReply,
        detail: 'Messages: invalid inbox response',
      );
    }
    return [
      for (final item in data.childElements)
        if (_xmlText(item, 'messageId').isNotEmpty)
          SchoolMessage(
            id: _xmlText(item, 'messageId'),
            sender: _fullName(
              _xmlText(item, 'senderFirstName'),
              _xmlText(item, 'senderLastName'),
            ),
            subject: _xmlText(item, 'topic'),
            preview: '',
            receivedAt: _flexDate(_xmlText(item, 'sendDate')) ?? DateTime.now(),
            unread:
                _xmlText(item, 'readDate').isEmpty ||
                _xmlText(item, 'readDate') == '0',
            hasAttachments: _xmlText(item, 'isAnyFileAttached') == '1',
          ),
    ];
  }

  Future<List<SchoolMessage>> _fetchXmlOutbox() async {
    await _prepareMessagesSession();
    final response = await _messagesRequest('Outbox/action/GetList', {
      'archive': 0,
    });
    final data = response
        .findAllElements('GetList')
        .firstOrNull
        ?.getElement('data');
    if (data == null) {
      throw const LibrusException(
        LibrusErrorCode.serverReply,
        detail: 'Messages: invalid outbox response',
      );
    }
    return [
      for (final item in data.childElements)
        if (_xmlText(item, 'messageId').isNotEmpty)
          SchoolMessage(
            id: _xmlText(item, 'messageId'),
            sender: '',
            subject: _xmlText(item, 'topic'),
            preview: '',
            receivedAt: _flexDate(_xmlText(item, 'sendDate')) ?? DateTime.now(),
            hasAttachments: _xmlText(item, 'isAnyFileAttached') == '1',
            sent: true,
            recipients: [
              _fullName(
                _xmlText(item, 'receiverFirstName'),
                _xmlText(item, 'receiverLastName'),
              ),
            ].where((name) => name.isNotEmpty).toList(growable: false),
            recipientRead: item.getElement('readDate') == null
                ? null
                : _readDate(_xmlText(item, 'readDate')) != null,
          ),
    ];
  }

  /// A recipient in GetMessage: "readed" holds when they read it.
  MessageReceiver _receiver(XmlElement receiver) {
    final field =
        receiver.getElement('readed') ?? receiver.getElement('readDate');
    final readAt = field == null ? null : _readDate(field.innerText.trim());
    return MessageReceiver(
      name: _fullName(
        _xmlText(receiver, 'firstName'),
        _xmlText(receiver, 'lastName'),
      ),
      read: field == null ? null : readAt != null,
      readAt: readAt,
    );
  }

  /// Unread messages have an empty, zero or all-zero read date.
  static DateTime? _readDate(String value) =>
      value.isEmpty || value == '0' || value.startsWith('0000')
      ? null
      : _flexDate(value);

  Future<List<SchoolMessage>> _fetchSynergiaOutbox() async {
    await _prepareSynergiaWebSession();
    final response = await _request(
      'GET',
      'https://synergia.librus.pl/wiadomosci/6',
      headers: {'User-Agent': _webUserAgent},
    );
    final doc = html_parser.parse(response.data?.toString() ?? '');
    final table = doc.querySelector('.decorated.stretch');
    if (response.statusCode != 200 || table == null) {
      throw LibrusException(
        LibrusErrorCode.serverReply,
        detail:
            'Messages: Synergia outbox HTTP ${response.statusCode ?? 0}, missing outbox',
      );
    }
    final messages = <SchoolMessage>[];
    for (final row in table.querySelectorAll('tbody > tr')) {
      final cells = row.children;
      final link = row.querySelector('a[href]')?.attributes['href'] ?? '';
      final id = RegExp(r'(?:^|/)wiadomosci/1/6/([0-9]+)(?:/|$)')
          .firstMatch(link)
          ?.group(1);
      if (id == null) continue;
      if (cells.length < 5) {
        throw const LibrusException(
          LibrusErrorCode.serverReply,
          detail: 'Messages: Synergia outbox invalid row',
        );
      }
      final recipient = cells[2].text.split('(').first.trim();
      messages.add(
        SchoolMessage(
          id: id,
          sender: '',
          subject: cells[3].text.trim(),
          preview: '',
          receivedAt: _flexDate(cells[4].text.trim()) ?? DateTime.now(),
          hasAttachments: cells[1].querySelector('img') != null,
          sent: true,
          recipients: [if (recipient.isNotEmpty) recipient],
        ),
      );
    }
    // A login or error page is not an empty outbox.
    if (messages.isEmpty &&
        (table.querySelector('tbody') == null ||
            !table
                .querySelectorAll('th')
                .any(
                  (cell) => const [
                    'temat',
                    'subject',
                  ].contains(cell.text.trim().toLowerCase()),
                ))) {
      throw const LibrusException(
        LibrusErrorCode.serverReply,
        detail: 'Messages: Synergia outbox missing rows',
      );
    }
    return messages;
  }

  Future<List<SchoolMessage>> _fetchSynergiaInbox() async {
    await _prepareSynergiaWebSession();
    final response = await _request(
      'GET',
      'https://synergia.librus.pl/wiadomosci/5',
      headers: {'User-Agent': _webUserAgent},
    );
    final doc = html_parser.parse(response.data?.toString() ?? '');
    final table = doc.querySelector('.decorated.stretch');
    if (response.statusCode != 200 || table == null) {
      throw LibrusException(
        LibrusErrorCode.serverReply,
        detail:
            'Messages: Synergia inbox HTTP ${response.statusCode ?? 0}, missing inbox',
      );
    }
    final messages = <SchoolMessage>[];
    for (final row in table.querySelectorAll('tbody > tr')) {
      final cells = row.children;
      final link = row.querySelector('a[href]')?.attributes['href'] ?? '';
      final id = RegExp(r'(?:^|/)wiadomosci/1/5/([0-9]+)(?:/|$)')
          .firstMatch(link)
          ?.group(1);
      if (id == null) continue;
      if (cells.length < 5) {
        throw const LibrusException(
          LibrusErrorCode.serverReply,
          detail: 'Messages: Synergia inbox invalid row',
        );
      }
      messages.add(
        SchoolMessage(
          id: id,
          sender: cells[2].text.split('(').first.trim(),
          subject: cells[3].text.trim(),
          preview: '',
          receivedAt: _flexDate(cells[4].text.trim()) ?? DateTime.now(),
          unread: cells[2].attributes['style']?.trim().isNotEmpty == true,
          hasAttachments: cells[1].querySelector('img') != null,
        ),
      );
    }
    // Login and error pages must never be treated as an authenticated empty inbox.
    if (messages.isEmpty &&
        (table.querySelector('tbody') == null ||
            !table
                .querySelectorAll('th')
                .any(
                  (cell) => const [
                    'temat',
                    'subject',
                  ].contains(cell.text.trim().toLowerCase()),
                ))) {
      throw const LibrusException(
        LibrusErrorCode.serverReply,
        detail: 'Messages: Synergia inbox missing rows',
      );
    }
    return messages;
  }

  Future<SchoolMessageContent> _fetchSynergiaMessageContent(
    SchoolMessage summary,
  ) async {
    await _prepareSynergiaWebSession();
    final response = await _request(
      'GET',
      'https://synergia.librus.pl/wiadomosci/1/${summary.sent ? 6 : 5}/${Uri.encodeComponent(summary.id)}/f0',
      headers: {'User-Agent': _webUserAgent},
    );
    final doc = html_parser.parse(response.data?.toString() ?? '');
    final content = doc.querySelector('.container-message-content');
    if (response.statusCode != 200 || content == null) {
      throw LibrusException(
        LibrusErrorCode.serverReply,
        detail:
            'Messages: Synergia content HTTP ${response.statusCode ?? 0}, ${content == null ? "missing message" : "invalid response"}',
      );
    }
    final attachments = <String, MessageAttachment>{};
    for (final row in doc.querySelectorAll('.container-message tr')) {
      final links = row.querySelectorAll('[href], [onclick]');
      for (final link in links) {
        final target =
            '${link.attributes['href'] ?? ''} ${link.attributes['onclick'] ?? ''}';
        final id = RegExp(r'wiadomosci/pobierz_zalacznik/[0-9]+/([0-9]+)')
            .firstMatch(target)
            ?.group(1);
        final name = row.querySelector('td')?.text.trim() ?? '';
        if (id != null && name.isNotEmpty) {
          attachments[id] = MessageAttachment(id: id, name: name);
        }
      }
    }
    return SchoolMessageContent(
      id: summary.id,
      sender: summary.sender,
      subject: summary.subject,
      body: _plainText(content.innerHtml),
      receivedAt: summary.receivedAt,
      attachments: attachments.values.toList(),
    );
  }

  Future<Response<Object?>> _request(
    String method,
    String url, {
    Object? data,
    String? contentType,
    Map<String, Object>? headers,
    bool stopAtExternal = false,
    bool stopAtMessagesAutoLogon = false,
  }) async {
    var uri = Uri.parse(url);
    var requestMethod = method;
    var requestData = data;
    for (var redirects = 0; redirects < 18; redirects++) {
      final cookieHeader = _cookieHeader(uri);
      final response = await _dio.requestUri<Object?>(
        uri,
        data: requestData,
        options: Options(
          method: requestMethod,
          contentType: contentType,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 600,
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'application/json, text/html, */*',
            ...?headers,
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
        ),
      );
      _storeCookies(uri, response.headers['set-cookie']);
      final location = response.headers.value('location');
      final status = response.statusCode ?? 0;
      if (status < 300 || status >= 400 || location == null) return response;
      final next = uri.resolve(location);
      if (stopAtMessagesAutoLogon &&
          next.host == 'wiadomosci.librus.pl' &&
          next.path.contains('AutoLogon') &&
          _cookies.any(
            (cookie) =>
                cookie.name == 'DZIENNIKSID' &&
                cookie.matches(Uri.parse(_messagesBase)),
          )) {
        return response;
      }
      if (next.scheme != 'http' && next.scheme != 'https') {
        if (stopAtExternal) return response;
        return response;
      }
      uri = next;
      if (status == 303 ||
          ((status == 301 || status == 302) && requestMethod == 'POST')) {
        requestMethod = 'GET';
        requestData = null;
        contentType = null;
      }
    }
    throw DioException(
      requestOptions: RequestOptions(path: url),
      message: 'Zbyt wiele przekierowań Librus.',
    );
  }

  String _cookieHeader(Uri uri) => _cookies
      .where((cookie) => cookie.matches(uri))
      .map((cookie) => '${cookie.name}=${cookie.value}')
      .join('; ');

  void _storeCookies(Uri uri, List<String>? headers) {
    if (headers == null) return;
    for (final header in headers) {
      final parts = header.split(';');
      final equals = parts.first.indexOf('=');
      if (equals < 1) continue;
      final name = parts.first.substring(0, equals).trim();
      final value = parts.first.substring(equals + 1).trim();
      var domain = uri.host;
      var path = '/';
      for (final attribute in parts.skip(1)) {
        final pair = attribute.trim().split('=');
        if (pair.first.toLowerCase() == 'domain' && pair.length > 1) {
          domain = pair.sublist(1).join('=').replaceFirst(RegExp(r'^\.'), '');
        }
        if (pair.first.toLowerCase() == 'path' && pair.length > 1) {
          path = pair.sublist(1).join('=');
        }
      }
      _cookies.removeWhere(
        (cookie) =>
            cookie.name == name &&
            cookie.domain == domain &&
            cookie.path == path,
      );
      if (value.isNotEmpty) {
        _cookies.add(
          _Cookie(name: name, value: value, domain: domain, path: path),
        );
      }
    }
  }

  Future<void> _saveSession() async {
    final account = _account;
    if (account != null) {
      await _logins.write(account, _session!.login, fresh: true);
    }
  }

  Future<bool> _restoreSession() async {
    if (_session != null) return true;
    final account = _account;
    if (account == null) return false;
    final login = await _logins.read(account);
    if (login == null) return false;
    _session = _PortalSession.of(login, synergiaLogin: _synergiaLogin);
    return true;
  }

  static List<Lesson> _parseTimetable(
    Map<String, dynamic> root, {
    required Map<int, String> subjects,
    required Map<int, String> teachers,
    required Map<int, String> classrooms,
  }) {
    final timetable = _map(root['Timetable']);
    if (timetable == null) return const [];
    final result = <Lesson>[];
    for (final day in timetable.entries) {
      final date = DateTime.tryParse(day.key);
      if (date == null || day.value is! List) continue;
      for (final range in day.value as List<Object?>) {
        if (range is! List) continue;
        for (final raw in range) {
          final item = _map(raw);
          if (item == null) continue;
          final start = _withTime(date, item['HourFrom']);
          final end = _withTime(date, item['HourTo']);
          if (start == null || end == null) continue;
          final substitution = item['IsSubstitutionClass'] == true;
          final cancelled = item['IsCanceled'] == true;
          final originalSubject = substitution
              ? subjects[_referenceId(item['OrgSubject'])] ?? ''
              : '';
          final originalTeacher = substitution
              ? teachers[_referenceId(item['OrgTeacher'])] ?? ''
              : '';
          final originalRoom = substitution
              ? classrooms[_referenceId(item['OrgClassroom'])] ?? ''
              : '';
          final newDate = _parseDate(item['NewDate']);
          final movedTo = substitution && cancelled && newDate != null
              ? _withTime(newDate, item['NewHourFrom'])
              : null;
          result.add(
            Lesson(
              id: '${day.key}-${item['LessonNo'] ?? start.millisecondsSinceEpoch}',
              subject: subjects[_referenceId(item['Subject'])] ?? 'Lekcja',
              teacher: teachers[_referenceId(item['Teacher'])] ?? '',
              room: classrooms[_referenceId(item['Classroom'])] ?? '',
              start: start,
              end: end,
              cancelled: cancelled,
              substitution: substitution,
              originalSubject: originalSubject,
              originalTeacher: originalTeacher,
              originalRoom: originalRoom,
              movedTo: movedTo,
              lessonNumber: int.tryParse('${item['LessonNo'] ?? ''}'),
            ),
          );
        }
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  static List<Grade> _parseGrades(
    Map<String, dynamic> root, {
    required Map<int, String> subjects,
    required Map<int, _GradeCategory> categories,
    required Map<int, String> comments,
  }) {
    final rawGrades = _list(root['Grades']);
    final grades = rawGrades
        .map((item) {
          final category = categories[_referenceId(item['Category'])];
          final semester = item['Semester'];
          return Grade(
            id: item['Id']?.toString() ?? item.hashCode.toString(),
            subject: subjects[_referenceId(item['Subject'])] ?? 'Przedmiot',
            value: item['Grade']?.toString().trim() ?? '',
            description: _gradeDescription(item, comments),
            date: _parseDate(item['AddDate']) ?? DateTime.now(),
            weight: category?.weight ?? 0,
            semester:
                _integer(semester) ?? _integer(_map(semester)?['Number']) ?? 1,
            category: category?.name ?? '',
          );
        })
        .toList(growable: false);
    final byId = {for (final grade in grades) grade.id: grade};
    final previousIdByCurrent = <String, String>{};
    for (final item in rawGrades) {
      final id = item['Id']?.toString();
      final previousId = _referenceId(item['Improvement'])?.toString();
      if (id != null &&
          previousId != null &&
          previousId != id &&
          byId.containsKey(previousId)) {
        previousIdByCurrent[id] = previousId;
      }
    }

    final replacedIds = previousIdByCurrent.values.toSet();
    final visible = <Grade>[];
    for (final grade in grades) {
      if (replacedIds.contains(grade.id)) continue;
      final history = <Grade>[];
      final seen = <String>{grade.id};
      var previousId = previousIdByCurrent[grade.id];
      while (previousId != null && seen.add(previousId)) {
        final previous = byId[previousId];
        if (previous == null) break;
        history.insert(0, previous);
        previousId = previousIdByCurrent[previousId];
      }
      visible.add(
        history.isEmpty ? grade : grade.copyWith(previousGrades: history),
      );
    }
    visible.sort((a, b) => b.date.compareTo(a.date));
    return visible;
  }

  static List<SchoolEvent> _parseEvents(
    Map<String, dynamic> root,
    Map<int, String> subjects,
    Map<int, String> eventTypes,
  ) => _list(root['HomeWorks'])
      .map(
        (item) => SchoolEvent(
          id: 'event-${item['Id'] ?? item.hashCode}',
          title: item['Content']?.toString().trim().isNotEmpty == true
              ? item['Content'].toString().trim()
              : 'Wydarzenie',
          subject: subjects[_referenceId(item['Subject'])] ?? 'Librus',
          date: _parseDate(item['Date']) ?? DateTime.now(),
          kind: EventKind.exam,
          typeLabel:
              eventTypes[_referenceId(item['Category'])] ??
              _map(item['Category'])?['Name']?.toString() ??
              (item['Category'] is String ? item['Category'].toString() : ''),
          lessonNumber: int.tryParse('${item['LessonNo'] ?? ''}'),
        ),
      )
      .toList(growable: false);

  static List<SchoolEvent> _parseHomework(
    Map<String, dynamic> root,
    Map<int, String> subjects,
    Map<int, int> lessonSubjects,
  ) => _list(root['HomeWorkAssignments'])
      .map((item) {
        final topic = item['Topic']?.toString().trim() ?? '';
        final text = item['Text']?.toString().trim() ?? '';
        final lesson = _map(item['Lesson']);
        // Only when neither names the subject: the lesson it belongs to.
        final subjectId =
            _referenceId(item['Subject']) ??
            _referenceId(lesson?['Subject']) ??
            switch (_referenceId(lesson)) {
              final id? => lessonSubjects[id],
              null => null,
            };
        return SchoolEvent(
          id: 'homework-${item['Id'] ?? item.hashCode}',
          title: topic.isNotEmpty
              ? topic
              : (text.isNotEmpty ? text : 'Zadanie domowe'),
          subject: subjects[subjectId] ?? '',
          date: _parseDate(item['DueDate']) ?? DateTime.now(),
          kind: EventKind.homework,
          typeLabel: 'Zadanie domowe',
          description: text,
        );
      })
      .toList(growable: false);

  static List<AttendanceRecord> _parseAttendance(
    Map<String, dynamic> root,
    Map<int, String> subjects,
    Map<int, int> lessonSubjects,
    Map<int, _AttendanceType> types,
  ) =>
      _list(root['Attendances'])
          .map((item) {
            final embeddedType = _map(item['Type']);
            final type =
                types[_referenceId(item['Type'])] ??
                _AttendanceType(
                  name: embeddedType?['Name']?.toString() ?? '',
                  short: embeddedType?['Short']?.toString() ?? '',
                  standard: embeddedType?['Standard'] == true,
                  standardId:
                      _referenceId(embeddedType?['StandardType']) ??
                      _integer(embeddedType?['Id']) ??
                      -1,
                );
            final lesson = _map(item['Lesson']);
            final embeddedSubject = _map(
              lesson?['Subject'],
            )?['Name']?.toString();
            // Librus sends only the lesson's id; its subject comes from the
            // list of lessons.
            final subjectId =
                _referenceId(lesson?['Subject']) ??
                switch (_referenceId(lesson)) {
                  final id? => lessonSubjects[id],
                  null => null,
                };
            return AttendanceRecord(
              id: item['Id']?.toString() ?? item.hashCode.toString(),
              date: _parseDate(item['Date']) ?? DateTime.now(),
              lessonNumber: _integer(item['LessonNo']) ?? 0,
              subject: embeddedSubject ?? subjects[subjectId] ?? '',
              type:
                  (type.name.isNotEmpty ? type.name : null) ??
                  _map(item['Type'])?['Name']?.toString() ??
                  'Nieobecność',
              symbol:
                  (type.short.isNotEmpty ? type.short : null) ??
                  _map(item['Type'])?['Short']?.toString() ??
                  '?',
              kind: _attendanceKind(type),
              semester: _integer(item['Semester']) ?? 1,
            );
          })
          .toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));

  static AttendanceKind _attendanceKind(_AttendanceType type) {
    final name = type.name.toLowerCase();
    final excused = name.contains('uspraw') || name.contains('excused');
    return switch (type.standardId) {
      1 => excused ? AttendanceKind.absentExcused : AttendanceKind.absent,
      2 => excused ? AttendanceKind.lateExcused : AttendanceKind.late,
      3 => AttendanceKind.absentExcused,
      4 => AttendanceKind.released,
      _ when name.contains('spó') || name.contains('late') =>
        excused ? AttendanceKind.lateExcused : AttendanceKind.late,
      _ when name.contains('zwol') || name.contains('release') =>
        AttendanceKind.released,
      _ when name.contains('nieobec') || name.contains('absen') =>
        excused ? AttendanceKind.absentExcused : AttendanceKind.absent,
      _
          when type.standard ||
              name.contains('obecn') ||
              name.contains('presen') =>
        AttendanceKind.present,
      _ => AttendanceKind.other,
    };
  }

  static List<SchoolAnnouncement> _parseAnnouncements(
    Map<String, dynamic> root,
    Map<int, String> people,
  ) =>
      _list(root['SchoolNotices'])
          .map(
            (item) => SchoolAnnouncement(
              id: item['Id']?.toString() ?? item.hashCode.toString(),
              title: item['Subject']?.toString() ?? '',
              content: _plainText(item['Content']?.toString() ?? ''),
              author: people[_referenceId(item['AddedBy'])] ?? '',
              createdAt:
                  _parseDate(item['CreationDate']) ??
                  _parseDate(item['StartDate']) ??
                  DateTime.now(),
              validUntil: _parseDate(item['EndDate']),
              read: item['WasRead'] == true,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static List<StudentNotice> _parseNotices(
    Map<String, dynamic> root,
    Map<int, String> categories,
    Map<int, String> people,
  ) =>
      _list(root['Notes'])
          .map((item) {
            final positive = _integer(item['Positive']) ?? 2;
            return StudentNotice(
              id: item['Id']?.toString() ?? item.hashCode.toString(),
              text: item['Text']?.toString() ?? '',
              category: categories[_referenceId(item['Category'])] ?? '',
              teacher: people[_referenceId(item['Teacher'])] ?? '',
              date: _parseDate(item['Date']) ?? DateTime.now(),
              tone: switch (positive) {
                0 => NoticeTone.negative,
                1 => NoticeTone.positive,
                _ => NoticeTone.neutral,
              },
            );
          })
          .toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Holidays, the class's days off and teachers' absences, by their first
  /// day. Absences that are over are left out: a school lists everyone's.
  static List<FreeDay> _parseFreeDays({
    required Map<String, dynamic> school,
    required Map<String, dynamic> classDays,
    required Map<int, String> classTypes,
    required Map<String, dynamic> teacherDays,
    required Map<int, String> teacherTypes,
    required Map<int, String> people,
    required DateTime today,
    int? ownClass,
  }) {
    final days = <FreeDay>[];
    (DateTime, DateTime)? range(Map<String, dynamic> item) {
      final from = _parseDate(item['DateFrom']);
      final to = _parseDate(item['DateTo']) ?? from;
      return from == null || to == null ? null : (from, to);
    }

    int? lesson(Object? value) => switch (_integer(value)) {
      final number? when number > 0 => number,
      _ => null,
    };
    for (final item in _list(school['SchoolFreeDays'])) {
      if (range(item) case (final from, final to)) {
        days.add(
          FreeDay(
            id: 'school-${item['Id']}',
            kind: FreeDayKind.school,
            name: item['Name']?.toString().trim() ?? '',
            from: from,
            to: to,
          ),
        );
      }
    }
    for (final item in _list(classDays['ClassFreeDays'])) {
      // Librus lists every class's days off, a work placement of another
      // class among them: only the student's own class counts, and with
      // no class known, none named for a class does.
      final forClass = _referenceId(item['Class']);
      if (forClass != null && forClass != ownClass) continue;
      if (range(item) case (final from, final to)) {
        days.add(
          FreeDay(
            id: 'class-${item['Id']}',
            kind: FreeDayKind.classDay,
            name:
                classTypes[_referenceId(item['Type'])]?.trim() ??
                item['Name']?.toString().trim() ??
                '',
            from: from,
            to: to,
            lessonFrom: lesson(item['LessonNoFrom']),
            lessonTo: lesson(item['LessonNoTo']),
          ),
        );
      }
    }
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    for (final item in _list(teacherDays['TeacherFreeDays'])) {
      final teacher = people[_referenceId(item['Teacher'])] ?? '';
      if (teacher.isEmpty) continue;
      if (range(item) case (final from, final to) when to.isAfter(yesterday)) {
        days.add(
          FreeDay(
            id: 'teacher-${item['Id']}',
            kind: FreeDayKind.teacher,
            name: teacherTypes[_referenceId(item['Type'])]?.trim() ?? '',
            from: from,
            to: to,
            teacher: teacher,
            timeFrom: _minutesOfDay(item['TimeFrom']),
            timeTo: _minutesOfDay(item['TimeTo']),
          ),
        );
      }
    }
    return days..sort((a, b) => a.from.compareTo(b.from));
  }

  /// "08:30:00" as minutes after midnight.
  static int? _minutesOfDay(Object? value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${value ?? ''}');
    if (match == null) return null;
    return int.parse(match[1]!) * 60 + int.parse(match[2]!);
  }

  static Map<int, String> _idNameMap(
    Map<String, dynamic> root,
    String key,
    String nameKey,
  ) => {
    for (final item in _list(root[key]))
      ?_integer(item['Id']): item[nameKey]?.toString() ?? '',
  };

  /// Lesson id to subject id. A lesson is a subject taught by a teacher to
  /// a class; attendance and homework point at it instead of the subject.
  static Map<int, int> _lessonSubjects(Map<String, dynamic> root) => {
    for (final item in _list(root['Lessons']))
      ?_integer(item['Id']): ?_referenceId(item['Subject']),
  };

  /// The same from the timetable, which every sync fetches: each entry
  /// names its lesson and its subject. A week holds nearly every lesson.
  static Map<int, int> _timetableLessonSubjects(Map<String, dynamic> root) => {
    for (final day in (_map(root['Timetable']) ?? const {}).values)
      if (day is List)
        for (final range in day)
          if (range is List)
            for (final item in range)
              ?_referenceId(_map(item)?['Lesson']): ?_referenceId(
                _map(item)?['Subject'],
              ),
  };
  static Map<int, String> _peopleMap(Map<String, dynamic> root, String key) => {
    for (final item in _list(root[key]))
      ?_integer(item['Id']): _fullName(item['FirstName'], item['LastName']),
  };
  static Map<int, _GradeCategory> _gradeCategories(Map<String, dynamic> root) =>
      {
        for (final item in _list(root['Categories']))
          ?_integer(item['Id']): _GradeCategory(
            name: item['Name']?.toString() ?? '',
            weight: item['CountToTheAverage'] == true
                ? (_number(item['Weight']) ?? 0).toDouble()
                : 0,
          ),
      };
  static Map<int, _AttendanceType> _attendanceTypes(
    Map<String, dynamic> root,
  ) => {
    for (final item in _list(root['Types']))
      ?_integer(item['Id']): _AttendanceType(
        name: item['Name']?.toString() ?? '',
        short: item['Short']?.toString() ?? '',
        standard: item['Standard'] == true,
        standardId: _referenceId(item['StandardType']) ?? _integer(item['Id'])!,
      ),
  };
}

/// What a sync hands to the isolate that turns responses into data.
typedef _SnapshotInput = ({
  Map<String, Map<String, dynamic>> references,
  Set<String> knownMissing,
  List<Map<String, dynamic>> data,
  Map<String, dynamic>? inbox,
  String? login,
});

class _ParsedSnapshot {
  const _ParsedSnapshot({
    required this.profile,
    required this.lessons,
    required this.grades,
    required this.events,
    required this.attendance,
    required this.announcements,
    required this.notices,
    required this.freeDays,
    required this.apiMessages,
    required this.unknown,
  });

  final StudentProfile profile;
  final List<Lesson> lessons;
  final List<Grade> grades;
  final List<SchoolEvent> events;
  final List<AttendanceRecord> attendance;
  final List<SchoolAnnouncement> announcements;
  final List<StudentNotice> notices;
  final List<FreeDay> freeDays;

  /// The mobile inbox, or null when it gave no messages.
  final List<SchoolMessage>? apiMessages;

  /// Subjects, teachers and categories the reference lists did not have.
  final Set<String> unknown;
}

/// Runs in a background isolate: everything it uses comes in [input].
_ParsedSnapshot _parseSnapshot(_SnapshotInput input) {
  final references = input.references;
  Map<String, dynamic> reference(String endpoint) =>
      references[endpoint] ?? const {};
  final data = input.data;
  final unknown = _UnknownReferences(input.knownMissing);

  final me = _map(reference('Me')['Me']);
  final account = _map(me?['Account']);
  final user = _map(me?['User']);
  final school = _map(reference('Schools')['School']);
  final subjects = unknown.track(
    'subject',
    LibrusClient._idNameMap(reference('Subjects'), 'Subjects', 'Name'),
  );
  // Old records keep naming people who have since left the school, so only
  // the timetable's teachers count as unknown.
  final people = LibrusClient._peopleMap(reference('Users'), 'Users');
  final classrooms = unknown.track(
    'classroom',
    LibrusClient._idNameMap(reference('Classrooms'), 'Classrooms', 'Name'),
  );
  final categories = unknown.track(
    'gradeCategory',
    LibrusClient._gradeCategories(reference('Grades/Categories')),
  );
  final attendanceTypes = unknown.track(
    'attendanceType',
    LibrusClient._attendanceTypes(reference('Attendances/Types')),
  );
  final noticeCategories = unknown.track(
    'noticeCategory',
    LibrusClient._idNameMap(
      reference('Notes/Categories'),
      'Categories',
      'CategoryName',
    ),
  );
  final eventTypes = unknown.track(
    'eventType',
    LibrusClient._idNameMap(
      reference('HomeWorks/Categories'),
      'Categories',
      'Name',
    ),
  );
  final lessonSubjects = unknown.track('lesson', {
    ...LibrusClient._timetableLessonSubjects(data[1]),
    ...LibrusClient._lessonSubjects(reference('Lessons')),
  });
  final gradeComments = LibrusClient._idNameMap(data[7], 'Comments', 'Text');

  final profileName = _fullName(user?['FirstName'], user?['LastName']);
  final inbox = input.inbox;
  return _ParsedSnapshot(
    profile: StudentProfile(
      id: 'librus-${account?['Id'] ?? user?['Id'] ?? input.login ?? 'account'}',
      name: profileName.isEmpty ? 'Użytkownik Librus' : profileName,
      school: _schoolName(school),
      provider: 'Librus Synergia',
    ),
    lessons: LibrusClient._parseTimetable(
      data[1],
      subjects: subjects,
      teachers: unknown.track('user', people),
      classrooms: classrooms,
    ),
    grades: LibrusClient._parseGrades(
      data[0],
      subjects: subjects,
      categories: categories,
      comments: gradeComments,
    ),
    events: [
      ...LibrusClient._parseEvents(data[2], subjects, eventTypes),
      ...LibrusClient._parseHomework(data[3], subjects, lessonSubjects),
    ]..sort((a, b) => a.date.compareTo(b.date)),
    attendance: LibrusClient._parseAttendance(
      data[4],
      subjects,
      lessonSubjects,
      attendanceTypes,
    ),
    announcements: LibrusClient._parseAnnouncements(data[5], people),
    notices: LibrusClient._parseNotices(data[6], noticeCategories, people),
    freeDays: LibrusClient._parseFreeDays(
      school: reference('SchoolFreeDays'),
      classDays: reference('ClassFreeDays'),
      classTypes: LibrusClient._idNameMap(
        reference('ClassFreeDays/Types'),
        'Types',
        'Name',
      ),
      teacherDays: data[8],
      teacherTypes: LibrusClient._idNameMap(
        reference('TeacherFreeDays/Types'),
        'Types',
        'Name',
      ),
      people: people,
      today: DateTime.now(),
      ownClass: _referenceId(me?['Class']),
    ),
    apiMessages: inbox == null
        ? null
        : LibrusClient._apiMessages(inbox, people),
    unknown: unknown.found,
  );
}

/// Notes which ids the data asks for that a reference list does not have.
class _UnknownReferences {
  _UnknownReferences(this.ignored);

  /// Ids already known to be missing, as `kind:id`.
  final Set<String> ignored;
  final Set<String> found = {};

  Map<int, V> track<V>(String kind, Map<int, V> names) =>
      _TrackedMap(kind, names, this);
}

class _TrackedMap<V> extends MapBase<int, V> {
  _TrackedMap(this._kind, this._names, this._unknown);

  final String _kind;
  final Map<int, V> _names;
  final _UnknownReferences _unknown;

  @override
  V? operator [](Object? key) {
    final value = _names[key];
    if (value == null && key is int && key > 0) {
      final id = '$_kind:$key';
      if (!_unknown.ignored.contains(id)) _unknown.found.add(id);
    }
    return value;
  }

  @override
  void operator []=(int key, V value) => _names[key] = value;

  @override
  void clear() => _names.clear();

  @override
  Iterable<int> get keys => _names.keys;

  @override
  V? remove(Object? key) => _names.remove(key);
}

class _PortalSession {
  const _PortalSession({
    required this.email,
    required this.password,
    required this.accessToken,
    required this.refreshToken,
    required this.synergiaLogin,
  });
  final String email;
  final String password;
  final String accessToken;
  final String refreshToken;
  final String? synergiaLogin;
  factory _PortalSession.of(LibrusLogin login, {String? synergiaLogin}) =>
      _PortalSession(
        email: login.email,
        password: login.password,
        accessToken: login.accessToken,
        refreshToken: login.refreshToken,
        synergiaLogin: synergiaLogin,
      );

  LibrusLogin get login => LibrusLogin(
    email: email,
    password: password,
    accessToken: accessToken,
    refreshToken: refreshToken,
  );

  _PortalSession withLogin(LibrusLogin login) =>
      _PortalSession.of(login, synergiaLogin: synergiaLogin);

  _PortalSession copyWith({String? synergiaLogin}) => _PortalSession(
    email: email,
    password: password,
    accessToken: accessToken,
    refreshToken: refreshToken,
    synergiaLogin: synergiaLogin ?? this.synergiaLogin,
  );
}

class _Cookie {
  const _Cookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
  });
  final String name;
  final String value;
  final String domain;
  final String path;
  bool matches(Uri uri) =>
      (uri.host == domain || uri.host.endsWith('.$domain')) &&
      uri.path.startsWith(path);
}

class _GradeCategory {
  const _GradeCategory({required this.name, required this.weight});
  final String name;
  final double weight;
}

class _AttendanceType {
  const _AttendanceType({
    required this.name,
    required this.short,
    required this.standard,
    required this.standardId,
  });
  final String name;
  final String short;
  final bool standard;
  final int standardId;
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}

Map<String, dynamic>? _decodeMap(Object? value) {
  if (value is! String) return null;
  try {
    return _map(jsonDecode(value));
  } on FormatException {
    return null;
  }
}

List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value.map(_map).whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];
List<Map<String, dynamic>> _findList(
  Map<String, dynamic> root,
  List<String> keys,
) {
  for (final key in keys) {
    final direct = _list(root[key]);
    if (direct.isNotEmpty) return direct;
    final nested = _map(root[key]);
    if (nested != null) {
      final found = _findList(nested, keys);
      if (found.isNotEmpty) return found;
    }
  }
  return const [];
}

String? _deepString(Map<String, dynamic> root, List<String> keys) {
  for (final key in keys) {
    final value = root[key];
    if (value != null && value is! Map && value is! List) {
      return value.toString();
    }
  }
  for (final value in root.values) {
    final nested = _map(value);
    if (nested != null) {
      final found = _deepString(nested, keys);
      if (found != null) return found;
    }
  }
  return null;
}

String? _accountLogin(Map<String, dynamic> item) =>
    _deepString(item, const ['login', 'Login']);
int? _integer(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};
num? _number(Object? value) => switch (value) {
  num number => number,
  String text => num.tryParse(text.replaceFirst(',', '.')),
  _ => null,
};
int? _referenceId(Object? value) => _integer(_map(value)?['Id']);
DateTime? _parseDate(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty
      ? null
      : DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

DateTime? _withTime(DateTime date, Object? value) {
  final parts = value?.toString().split(':');
  if (parts == null || parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  return hour == null || minute == null
      ? null
      : DateTime(date.year, date.month, date.day, hour, minute);
}

/// The Monday of the timetable week a sync fetches: this week, or the next
/// one at the weekend.
DateTime librusSyncWeekStart(DateTime now) {
  final weekStart = _startOfWeek(now);
  // The next Monday by the calendar. The week the clocks go back is an hour
  // longer, and seven times 24 hours from its Monday end on its Sunday: the
  // week asked of Librus then started on a Sunday.
  return now.weekday > DateTime.friday
      ? DateTime(weekStart.year, weekStart.month, weekStart.day + 7)
      : weekStart;
}

/// The Monday of [date]'s week, counted in calendar days.
DateTime _startOfWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

String _dateOnly(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _fullName(Object? first, Object? last) => [first, last]
    .map((value) => value?.toString().trim() ?? '')
    .where((value) => value.isNotEmpty)
    .join(' ');
String _schoolName(Map<String, dynamic>? school) {
  if (school == null) return 'Librus Synergia';
  final name = school['Name']?.toString().trim() ?? '';
  final town = school['Town']?.toString().trim() ?? '';
  return name.isEmpty
      ? 'Librus Synergia'
      : (town.isEmpty ? name : '$name, $town');
}

String _gradeDescription(
  Map<String, dynamic> item,
  Map<int, String> comments,
) => _list(item['Comments'])
    .map(
      (comment) =>
          comment['Text']?.toString().trim() ??
          comments[_integer(comment['Id'])] ??
          '',
    )
    .where((text) => text.isNotEmpty)
    .join(' · ');

String _plainText(String text) => text
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .trim();
String _jsonText(Object? value) {
  final text = value?.toString() ?? '';
  try {
    final decoded = jsonDecode(text);
    return decoded is String ? decoded : text;
  } on FormatException {
    return text;
  }
}

DateTime? _flexDate(Object? value) {
  if (value is num) {
    final milliseconds = value > 100000000000
        ? value.toInt()
        : value.toInt() * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
  final text = value?.toString() ?? '';
  final number = int.tryParse(text);
  if (number != null) return _flexDate(number);
  return _parseDate(text);
}

String? _firstMatch(String text, RegExp expression) =>
    expression.firstMatch(text)?.group(1);
Map<String, String> _hiddenInputs(String html) {
  final result = <String, String>{};
  final tags = RegExp(
    r'<input\b[^>]*type=["\x27]hidden["\x27][^>]*>',
    caseSensitive: false,
  ).allMatches(html);
  for (final match in tags) {
    final tag = match.group(0)!;
    final name = _firstMatch(
      tag,
      RegExp(r'name=["\x27]([^"\x27]+)', caseSensitive: false),
    );
    final value = _firstMatch(
      tag,
      RegExp(r'value=["\x27]([^"\x27]*)', caseSensitive: false),
    );
    if (name != null) result[_htmlDecode(name)] = _htmlDecode(value ?? '');
  }
  return result;
}

String _htmlDecode(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&#039;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');
LibrusException _networkException(DioException error) => switch (error.type) {
  DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout =>
    const LibrusException(LibrusErrorCode.networkTimeout),
  DioExceptionType.connectionError => const LibrusException(
    LibrusErrorCode.networkUnavailable,
  ),
  _ =>
    error.message == null
        ? const LibrusException(LibrusErrorCode.networkUnknown)
        : LibrusException(LibrusErrorCode.networkOther, detail: error.message),
};
