import 'package:siberia_plugins/siberia_plugins.dart'
    show PluginManifest, PluginException;

import '../domain/librus_error.dart';
import '../domain/models.dart';
import '../domain/profiles.dart';
import 'diary_plugin.dart';
import 'diary_plugins.dart';

/// Bundled registration wins locally and cannot be replaced by a catalog entry.
/// Restoring an installed profile does not fetch the catalog.
class DiaryPluginRegistry {
  DiaryPluginRegistry({
    required List<DiaryPlugin> bundled,
    required this.downloads,
    required this.defaultId,
  }) : _bundled = {for (final plugin in bundled) plugin.definition.id: plugin} {
    if (_bundled.length != bundled.length ||
        !_bundled.containsKey(defaultId) ||
        bundled.any((p) => !p.definition.isBundled)) {
      throw ArgumentError('Invalid bundled diary registration');
    }
  }
  final Map<String, DiaryPlugin> _bundled;
  final DiaryPlugins downloads;
  final String defaultId;
  List<DiaryDefinition> get bundled =>
      List.unmodifiable(_bundled.values.map((p) => p.definition));
  DiaryPlugin get defaultPlugin => _bundled[defaultId]!;
  DiaryPlugin forProfile(SchoolProfile profile) =>
      _bundled[profile.providerId] ??
      _DownloadedPlugin(
        downloads,
        DiaryDefinition.installed(
          id: profile.providerId,
          name: profile.providerName.isEmpty
              ? profile.providerId
              : profile.providerName,
        ),
      );
  Future<void> forgetUnclaimedAccount(String account) =>
      account.startsWith('plugin-')
      ? downloads.forget(account)
      : defaultPlugin.forgetAccount(account);
  DiaryPlugin download(PluginManifest manifest) {
    if (_bundled.containsKey(manifest.id)) {
      throw const PluginException('reserved_plugin_id');
    }
    return _DownloadedPlugin(downloads, DiaryDefinition.downloadable(manifest));
  }
}

class _DownloadedPlugin implements DiaryPlugin {
  _DownloadedPlugin(this.host, this.definition);
  final DiaryPlugins host;
  @override
  final DiaryDefinition definition;
  @override
  Future<DiaryLogin> signIn(Map<String, Object?> fields) async {
    final release = definition.release;
    if (release == null) throw const PluginException('missing_manifest');
    final value = await host.connect(release, fields);
    return DiaryLogin(value.account, [
      for (final child in value.students)
        DiaryChild(
          id: child.id,
          name: child.name,
          school: child.school,
          parent: child.parent,
        ),
    ]);
  }

  @override
  Future<List<DiaryChild>> children(SchoolProfile profile) async {
    final result = await host.invoke(profile, 'accounts', {});
    return [
      for (final raw in result.data as List)
        DiaryChild(
          id: (raw as Map)['id'] as String,
          name: raw['name'] as String,
          school: raw['school'] as String,
          parent: raw['parent'] == true,
        ),
    ];
  }

  @override
  DiarySession session(SchoolProfile profile) =>
      _DownloadedSession(host, profile);
  @override
  Future<void> forgetProfile(SchoolProfile profile) async {} // No persistent per-child VM.
  @override
  Future<void> forgetAccount(String account) => host.forget(account);
}

class _DownloadedSession implements DiarySession {
  _DownloadedSession(this.host, this.profile);
  final DiaryPlugins host;
  final SchoolProfile profile;
  @override
  String? get studentKey => profile.pluginStudent;
  @override
  Future<void> deleteMessage(SchoolMessage message) =>
      host.deleteMessage(profile, message);
  @override
  Future<AppSnapshot?> sync(AppSnapshot? previous, {Set<DiaryPart>? parts}) =>
      host.sync(
        profile,
        previous ??
            AppSnapshot(
              profile: DiaryPlugins.student(profile),
              lessons: const [],
              grades: const [],
              events: const [],
              messages: const [],
              attendance: const [],
              announcements: const [],
              notices: const [],
              lastSync: DateTime.fromMillisecondsSinceEpoch(0),
            ),
        parts: parts,
      );
  @override
  Future<List<MessageRecipient>> recipients() => host.recipients(profile);
  @override
  Future<String> send({
    required List<MessageRecipient> recipients,
    required String subject,
    required String body,
  }) => host.send(profile, recipients, subject, body);
  @override
  Future<DiarySentFolder> sent() async {
    final (messages, module) = await host.sent(profile);
    return DiarySentFolder(messages, providerData: {'sentMessages': module});
  }

  @override
  Future<SchoolMessageContent> message(
    SchoolMessage message,
    AppSnapshot? cached,
  ) {
    if (cached == null) throw const PluginException('missing_snapshot');
    return host.message(profile, message, cached);
  }

  @override
  Future<Uri> attachment({
    required String messageId,
    required String attachmentId,
  }) async =>
      throw const LibrusException(LibrusErrorCode.attachmentFetchFailed);
  @override
  Future<List<Lesson>> timetable(DateTime day) => host.timetable(profile, day);
}
