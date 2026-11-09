import 'package:siberia_plugins/siberia_plugins.dart' show PluginManifest;

import '../domain/diary_part.dart';
import '../domain/models.dart';
import '../domain/profiles.dart';

export '../domain/diary_part.dart';

/// Distribution describes installation, not which diary API the app uses.
enum DiaryDistribution { bundled, downloadable }

class DiaryDefinition {
  const DiaryDefinition.bundled({required this.id, required this.name})
    : distribution = DiaryDistribution.bundled,
      release = null;
  DiaryDefinition.downloadable(PluginManifest manifest)
    : id = manifest.id,
      name = manifest.name,
      distribution = DiaryDistribution.downloadable,
      release = manifest;
  const DiaryDefinition.installed({required this.id, required this.name})
    : distribution = DiaryDistribution.downloadable,
      release = null;
  final String id, name;
  final DiaryDistribution distribution;
  final PluginManifest? release;
  bool get isBundled => distribution == DiaryDistribution.bundled;
}

class DiaryChild {
  const DiaryChild({
    required this.id,
    required this.name,
    this.school = '',
    this.parent = false,
  });
  final String id, name, school;
  final bool parent;
}

class DiaryLogin {
  const DiaryLogin(this.account, this.children);
  final String account;
  final List<DiaryChild> children;
}

/// Native bundled adapters and the downloaded-bytecode adapter implement the
/// same account/session boundary. Transport-specific types stay behind it.
abstract interface class DiaryPlugin {
  DiaryDefinition get definition;
  Future<DiaryLogin> signIn(Map<String, Object?> fields);
  Future<List<DiaryChild>> children(SchoolProfile profile);
  DiarySession session(SchoolProfile profile);
  Future<void> forgetProfile(SchoolProfile profile);
  Future<void> forgetAccount(String account);
}

class DiarySentFolder {
  const DiarySentFolder(this.messages, {this.providerData = const {}});
  final List<SchoolMessage> messages;
  final Map<String, Object?> providerData;
}

/// A diary session whose own module keeps excuse notes and the school's
/// answers to them.
abstract interface class JustificationSource {
  Future<List<SchoolJustification>> justifications();
}

abstract interface class DiarySession {
  /// Selected account/child identity, learned during restoration if necessary.
  String? get studentKey;

  /// Returns a complete snapshot, retaining modules omitted by [parts].
  Future<AppSnapshot?> sync(AppSnapshot? previous, {Set<DiaryPart>? parts});
  Future<List<MessageRecipient>> recipients();
  Future<String> send({
    required List<MessageRecipient> recipients,
    required String subject,
    required String body,
  });
  Future<DiarySentFolder> sent();
  Future<void> deleteMessage(SchoolMessage message);
  Future<SchoolMessageContent> message(
    SchoolMessage message,
    AppSnapshot? cached,
  );
  Future<Uri> attachment({
    required String messageId,
    required String attachmentId,
  });
  Future<List<Lesson>> timetable(DateTime day);
}
