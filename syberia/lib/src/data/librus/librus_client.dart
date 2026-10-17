import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xml/xml.dart';
import 'package:html/parser.dart' as html_parser;

import '../../domain/librus_error.dart';
import '../../domain/models.dart';

/// Portal-backed Synergia access and web mailbox sessions. Token and session
/// lifetimes follow Szkolny.eu: six hours for API access and 45 minutes for web.
class LibrusClient {
  LibrusClient({
    Dio? dio,
    FlutterSecureStorage? secureStorage,
    DateTime Function()? clock,
  }) : _dio = dio ?? Dio(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  static const _portalBase = 'https://portal.librus.pl';
  static const _portalApi = '$_portalBase/api/v3';
  static const _apiBase = 'https://api.librus.pl/2.0';
  static const _authorizeUrl = '$_portalBase/konto-librus/redirect/dru';
  static const _loginUrl = '$_portalBase/konto-librus/login/action';
  static const _tokenUrl = '$_portalBase/oauth2/access_token';
  static const _clientId = 'VaItV6oRutdo8fnjJwysnTjVlvaswf52ZqmXsJGP';
  static const _redirectUrl = 'app://librus';
  static const _sessionKey = 'syberia_portal_session_v1';
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/146.0 Mobile Safari/537.36 LibrusMobileApp';

  final DateTime Function() _clock;
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final List<_Cookie> _cookies = [];
  _PortalSession? _session;
  String? _synergiaToken;
  DateTime? _apiTokenExpiresAt;
  DateTime? _synergiaSessionExpiresAt;
  DateTime? _messagesSessionExpiresAt;
  Future<void>? _refreshInFlight;

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
    final email = username.trim();
    if (email.isEmpty || password.isEmpty) {
      throw const LibrusException(LibrusErrorCode.missingCredentials);
    }
    _clearRuntimeSessions();
    _session = await _loginWithPortal(email, password);
    await _saveSession();
    return fetchSnapshot();
  }

  Future<AppSnapshot?> restoreAndFetch() async {
    if (!await _restoreSession()) return null;
    return fetchSnapshot();
  }

  Future<void> logout() async {
    _clearRuntimeSessions();
    _session = null;
    await _secureStorage.delete(key: _sessionKey);
  }

  Future<List<LinkedSynergiaAccount>> fetchSynergiaAccounts() async {
    await _prepareFreshSession();
    final root = await _portalGet('SynergiaAccounts', _session!.accessToken);
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
            selected: _accountLogin(account) == _session!.synergiaLogin,
          ),
    ];
  }

  Future<AppSnapshot> selectSynergiaAccount(String login) async {
    await _prepareFreshSession();
    final previous = _session!;
    final previousToken = _synergiaToken;
    final previousTokenExpiry = _apiTokenExpiresAt;
    _session = previous.copyWith(synergiaLogin: login);
    _clearRuntimeSessions();
    try {
      return await fetchSnapshot();
    } on Object {
      _session = previous;
      _synergiaToken = previousToken;
      _apiTokenExpiresAt = previousTokenExpiry;
      _cookies.clear();
      await _saveSession();
      rethrow;
    }
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

  Future<void> sendMessage({
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
    if (!response.findAllElements('status').any((e) => e.innerText == 'ok') ||
        !response
            .findAllElements('data')
            .any((e) => int.tryParse(e.innerText.trim()) != null)) {
      throw const LibrusException(LibrusErrorCode.messageNotSent);
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

  Future<AppSnapshot> fetchSnapshot() async {
    await _prepareFreshSession();
    final references = await Future.wait([
      _apiGet('Me'),
      _apiGet('Schools'),
      _apiGet('Subjects'),
      _apiGet('Users'),
      _apiGet('Classrooms'),
      _apiGet('Grades/Categories'),
      _apiGet('Attendances/Types', optional: true),
      _apiGet('Notes/Categories', optional: true),
      _apiGet('Grades/Comments', optional: true),
      _apiGet('HomeWorks/Categories', optional: true),
    ]);
    final me = _map(references[0]['Me']);
    final account = _map(me?['Account']);
    final user = _map(me?['User']);
    final school = _map(references[1]['School']);
    final subjects = _idNameMap(references[2], 'Subjects', 'Name');
    final people = _peopleMap(references[3], 'Users');
    final classrooms = _idNameMap(references[4], 'Classrooms', 'Name');
    final categories = _gradeCategories(references[5]);
    final attendanceTypes = _attendanceTypes(references[6]);
    final noticeCategories = _idNameMap(
      references[7],
      'Categories',
      'CategoryName',
    );
    final gradeComments = _idNameMap(references[8], 'Comments', 'Text');
    final eventTypes = _idNameMap(references[9], 'Categories', 'Name');

    final week = _dateOnly(librusSyncWeekStart(DateTime.now()));
    final data = await Future.wait([
      _apiGet('Grades'),
      _apiGet('Timetables?weekStart=$week'),
      _apiGet('HomeWorks'),
      _apiGet('HomeWorkAssignments', optional: true),
      _apiGet('Attendances', optional: true),
      _apiGet('SchoolNotices', optional: true),
      _apiGet('Notes', optional: true),
    ]);

    final profileName = _fullName(user?['FirstName'], user?['LastName']);
    final profile = StudentProfile(
      id: 'librus-${account?['Id'] ?? user?['Id'] ?? _session!.synergiaLogin ?? 'account'}',
      name: profileName.isEmpty ? 'Użytkownik Librus' : profileName,
      school: _schoolName(school),
      provider: 'Librus Synergia',
    );
    final events = <SchoolEvent>[
      ..._parseEvents(data[2], subjects, eventTypes),
      ..._parseHomework(data[3], subjects),
    ]..sort((a, b) => a.date.compareTo(b.date));
    var messages = <SchoolMessage>[];
    AppError? messagesError;
    try {
      messages = await _fetchMessages(people);
    } on Object catch (error) {
      messagesError = AppError.from(
        error is DioException ? _networkException(error) : error,
      );
    }
    return AppSnapshot(
      profile: profile,
      lessons: _parseTimetable(
        data[1],
        subjects: subjects,
        teachers: people,
        classrooms: classrooms,
      ),
      grades: _parseGrades(
        data[0],
        subjects: subjects,
        categories: categories,
        comments: gradeComments,
      ),
      events: events,
      messages: messages,
      messagesError: messagesError,
      attendance: _parseAttendance(data[4], subjects, attendanceTypes),
      announcements: _parseAnnouncements(data[5], people),
      notices: _parseNotices(data[6], noticeCategories, people),
      lastSync: DateTime.now(),
    );
  }

  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async {
    await _prepareFreshSession();
    final references = await Future.wait([
      _apiGet('Subjects'),
      _apiGet('Users'),
      _apiGet('Classrooms'),
    ]);
    final monday = _startOfWeek(day);
    final timetable = await _apiGet(
      'Timetables?weekStart=${_dateOnly(monday)}',
    );
    return _parseTimetable(
      timetable,
      subjects: _idNameMap(references[0], 'Subjects', 'Name'),
      teachers: _peopleMap(references[1], 'Users'),
      classrooms: _idNameMap(references[2], 'Classrooms', 'Name'),
    );
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
    final selectedLogin = session.synergiaLogin;
    try {
      if (session.refreshToken.isNotEmpty) {
        final token = await _exchangeToken({
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': session.refreshToken,
        });
        session = session.copyWith(
          accessToken: token['access_token']?.toString(),
          refreshToken: token['refresh_token']?.toString(),
        );
      }
    } on LibrusException {
      _cookies.clear();
      session = (await _loginWithPortal(
        session.email,
        session.password,
      )).copyWith(synergiaLogin: selectedLogin);
    }
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
    await _saveSession();
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

  Future<void> _prepareSynergiaWebSession() async {
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

  Future<void> _prepareMessagesSession() async {
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

  Future<List<SchoolMessage>> _fetchMessages(Map<int, String> people) async {
    // The mobile inbox works on accounts which deny the mobile content endpoint.
    // Do not discard those messages when web mailbox login is unavailable.
    String apiFailure = 'Messages: API inbox unexpected JSON';
    try {
      final root = await _apiGet(
        'Messages?alternativeBody=true&changeNewLine=1&afterId=0&limit=50&page=1',
      );
      if (root['Messages'] is List) {
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
                    (readDates.isNotEmpty &&
                        (readValue == 0 || readValue == '0')),
                hasAttachments:
                    item['AddedFiles'] == true ||
                    item['HasAttachment'] == true ||
                    _list(item['MessageFiles']).isNotEmpty,
              );
            })
            .toList(growable: false);
      }
    } on LibrusException catch (error) {
      apiFailure = _mailboxFailure(error);
    } on DioException catch (error) {
      apiFailure = _mailboxFailure(error);
    }
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
      'https://synergia.librus.pl/wiadomosci/1/5/${Uri.encodeComponent(summary.id)}/f0',
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

  Future<void> _saveSession() => _secureStorage.write(
    key: _sessionKey,
    value: jsonEncode(_session!.toJson()),
  );
  Future<bool> _restoreSession() async {
    if (_session != null) return true;
    final raw = await _secureStorage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return false;
    try {
      _session = _PortalSession.fromJson(_map(jsonDecode(raw))!);
      return true;
    } on Object {
      await logout();
      return false;
    }
  }

  List<Lesson> _parseTimetable(
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

  List<Grade> _parseGrades(
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

  List<SchoolEvent> _parseEvents(
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

  List<SchoolEvent> _parseHomework(
    Map<String, dynamic> root,
    Map<int, String> subjects,
  ) => _list(root['HomeWorkAssignments'])
      .map((item) {
        final topic = item['Topic']?.toString().trim() ?? '';
        final text = item['Text']?.toString().trim() ?? '';
        final lesson = _map(item['Lesson']);
        final subjectId =
            _referenceId(item['Subject']) ?? _referenceId(lesson?['Subject']);
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

  List<AttendanceRecord> _parseAttendance(
    Map<String, dynamic> root,
    Map<int, String> subjects,
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
            final embeddedSubject = _map(
              _map(item['Lesson'])?['Subject'],
            )?['Name']?.toString();
            return AttendanceRecord(
              id: item['Id']?.toString() ?? item.hashCode.toString(),
              date: _parseDate(item['Date']) ?? DateTime.now(),
              lessonNumber: _integer(item['LessonNo']) ?? 0,
              subject:
                  embeddedSubject ??
                  subjects[_referenceId(_map(item['Lesson'])?['Subject'])] ??
                  '',
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

  AttendanceKind _attendanceKind(_AttendanceType type) {
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

  List<SchoolAnnouncement> _parseAnnouncements(
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

  List<StudentNotice> _parseNotices(
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

  Map<int, String> _idNameMap(
    Map<String, dynamic> root,
    String key,
    String nameKey,
  ) => {
    for (final item in _list(root[key]))
      ?_integer(item['Id']): item[nameKey]?.toString() ?? '',
  };
  Map<int, String> _peopleMap(Map<String, dynamic> root, String key) => {
    for (final item in _list(root[key]))
      ?_integer(item['Id']): _fullName(item['FirstName'], item['LastName']),
  };
  Map<int, _GradeCategory> _gradeCategories(Map<String, dynamic> root) => {
    for (final item in _list(root['Categories']))
      ?_integer(item['Id']): _GradeCategory(
        name: item['Name']?.toString() ?? '',
        weight: item['CountToTheAverage'] == true
            ? (_number(item['Weight']) ?? 0).toDouble()
            : 0,
      ),
  };
  Map<int, _AttendanceType> _attendanceTypes(Map<String, dynamic> root) => {
    for (final item in _list(root['Types']))
      ?_integer(item['Id']): _AttendanceType(
        name: item['Name']?.toString() ?? '',
        short: item['Short']?.toString() ?? '',
        standard: item['Standard'] == true,
        standardId: _referenceId(item['StandardType']) ?? _integer(item['Id'])!,
      ),
  };
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
  _PortalSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? synergiaLogin,
  }) => _PortalSession(
    email: email,
    password: password,
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    synergiaLogin: synergiaLogin ?? this.synergiaLogin,
  );
  Map<String, Object?> toJson() => {
    'email': email,
    'password': password,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'synergiaLogin': synergiaLogin,
  };
  factory _PortalSession.fromJson(Map<String, dynamic> json) => _PortalSession(
    email: json['email'] as String,
    password: json['password'] as String,
    accessToken: json['accessToken'] as String? ?? '',
    refreshToken: json['refreshToken'] as String? ?? '',
    synergiaLogin: json['synergiaLogin'] as String?,
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
  return now.weekday > DateTime.friday
      ? weekStart.add(const Duration(days: 7))
      : weekStart;
}

DateTime _startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

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
