import '../../domain/models.dart';
import '../../domain/profiles.dart';
import '../diary_plugin.dart';
import 'librus_client.dart';
import 'librus_logins.dart';
import 'reference_cache.dart';

/// Compiled into the app and registered locally; it never needs a catalog,
/// bytecode download or a second credential store.
class LibrusDiaryPlugin implements DiaryPlugin {
  LibrusDiaryPlugin({
    required this._logins,
    required this._references,
    LibrusClient? client,
    LibrusClient Function(SchoolProfile? profile)? clients,
  }) : _shared = client,
       _factory = clients;
  static const descriptor = DiaryDefinition.bundled(
    id: 'librus',
    name: 'Librus',
  );
  @override
  DiaryDefinition get definition => descriptor;
  final LibrusLogins _logins;
  final LibrusReferenceCache _references;
  final LibrusClient? _shared;
  final LibrusClient Function(SchoolProfile?)? _factory;
  final _clients = <String, LibrusClient>{};
  LibrusClient _client(SchoolProfile profile) =>
      _shared ??
      _clients.putIfAbsent(
        profile.id,
        () =>
            _factory?.call(profile) ??
            LibrusClient(
              logins: _logins,
              referenceCache: _references,
              account: profile.account.isEmpty ? null : profile.account,
              synergiaLogin: profile.synergiaLogin,
            ),
      );
  static DiaryChild _child(LinkedSynergiaAccount value) =>
      DiaryChild(id: value.login, name: value.name, parent: value.parent);
  @override
  Future<DiaryLogin> signIn(Map<String, Object?> fields) async {
    final client =
        _shared ??
        _factory?.call(null) ??
        LibrusClient(logins: _logins, referenceCache: _references);
    final result = await client.signIn(
      username: fields['username']! as String,
      password: fields['password']! as String,
    );
    return DiaryLogin(result.account, result.students.map(_child).toList());
  }

  @override
  Future<List<DiaryChild>> children(SchoolProfile profile) async =>
      (await _client(profile).fetchSynergiaAccounts()).map(_child).toList();
  @override
  DiarySession session(SchoolProfile profile) =>
      _LibrusSession(_client(profile));
  @override
  Future<void> forgetProfile(SchoolProfile profile) async {
    try {
      await _client(profile).forget();
    } finally {
      _clients.remove(profile.id);
    }
  }

  @override
  Future<void> forgetAccount(String account) => _logins.remove(account);
}

class _LibrusSession implements DiarySession {
  _LibrusSession(this.client);
  final LibrusClient client;
  @override
  String? get studentKey => client.synergiaLogin;
  @override
  Future<void> deleteMessage(SchoolMessage message) =>
      client.deleteMessage(message);
  @override
  Future<AppSnapshot?> sync(
    AppSnapshot? previous, {
    Set<DiaryPart>? parts,
  }) async {
    var fetched = await client.restoreAndFetch(parts: parts);
    // An unsupported endpoint or temporary failure is not a new draw. Keep
    // the last known number; the UI still requires an exact date match.
    final draw = fetched?.providerData['luckyNumbers'];
    if (fetched != null &&
        previous != null &&
        previous.profile.id == fetched.profile.id &&
        draw is Map &&
        !draw.containsKey('LuckyNumber')) {
      fetched = fetched.copyWith(luckyNumbers: previous.luckyNumbers);
    }
    if (fetched == null ||
        previous == null ||
        parts == null ||
        previous.profile.id != fetched.profile.id) {
      return fetched;
    }
    T pick<T>(DiaryPart part, T fresh, T kept) =>
        parts.contains(part) ? fresh : kept;
    final messages = parts.contains(DiaryPart.messages);
    final requested = parts.map((part) => part.name).toSet();
    return AppSnapshot(
      providerData: {
        for (final entry in previous.providerData.entries)
          if (!requested.contains(entry.key)) entry.key: entry.value,
        ...fetched.providerData,
      },
      moduleErrors: {
        for (final entry in previous.moduleErrors.entries)
          if (!requested.contains(entry.key)) entry.key: entry.value,
        ...fetched.moduleErrors,
      },
      attendanceComplete: parts.contains(DiaryPart.attendance)
          ? fetched.attendanceComplete
          : previous.attendanceComplete,
      profile: fetched.profile,
      lessons: pick(DiaryPart.timetable, fetched.lessons, previous.lessons),
      grades: pick(DiaryPart.grades, fetched.grades, previous.grades),
      events:
          parts.contains(DiaryPart.events) || parts.contains(DiaryPart.homework)
          ? fetched.events
          : previous.events,
      messages: messages ? fetched.messages : previous.messages,
      messagesError: messages ? fetched.messagesError : previous.messagesError,
      attendance: pick(
        DiaryPart.attendance,
        fetched.attendance,
        previous.attendance,
      ),
      announcements: pick(
        DiaryPart.announcements,
        fetched.announcements,
        previous.announcements,
      ),
      notices: pick(DiaryPart.notices, fetched.notices, previous.notices),
      freeDays: pick(DiaryPart.timetable, fetched.freeDays, previous.freeDays),
      luckyNumbers: pick(
        DiaryPart.luckyNumbers,
        fetched.luckyNumbers,
        previous.luckyNumbers,
      ),
      lastSync: fetched.lastSync,
    );
  }

  @override
  Future<List<MessageRecipient>> recipients() =>
      client.fetchMessageRecipients();
  @override
  Future<String> send({
    required List<MessageRecipient> recipients,
    required String subject,
    required String body,
  }) => client.sendMessage(
    recipientIds: recipients.map((r) => r.id as int).toSet().toList(),
    subject: subject,
    body: body,
  );
  @override
  Future<DiarySentFolder> sent() async =>
      DiarySentFolder(await client.fetchSentMessages());
  @override
  Future<SchoolMessageContent> message(
    SchoolMessage message,
    AppSnapshot? cached,
  ) => client.fetchMessageContent(message);
  @override
  Future<Uri> attachment({
    required String messageId,
    required String attachmentId,
  }) => client.fetchMessageAttachmentUrl(
    messageId: messageId,
    attachmentId: attachmentId,
  );
  @override
  Future<List<Lesson>> timetable(DateTime day) =>
      client.fetchTimetableWeek(day);
}
