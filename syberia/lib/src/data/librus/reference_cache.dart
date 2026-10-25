import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Librus lists that hardly ever change: the account, the school, subjects,
/// teachers, classrooms and categories. Keeping them for a day saves about
/// half of the requests of every sync, in the app and in the background.
class LibrusReferences {
  const LibrusReferences({
    required this.account,
    required this.fetchedAt,
    required this.responses,
    this.knownMissing = const {},
  });

  final String account;
  final DateTime fetchedAt;

  /// Each endpoint's decoded response.
  final Map<String, Map<String, dynamic>> responses;

  /// Names the data asks for that even fresh lists did not have, such as a
  /// teacher who has left. They do not make the lists be fetched again.
  final Set<String> knownMissing;

  LibrusReferences withKnownMissing(Set<String> missing) => LibrusReferences(
    account: account,
    fetchedAt: fetchedAt,
    responses: responses,
    knownMissing: {...knownMissing, ...missing},
  );

  Map<String, dynamic> operator [](String endpoint) =>
      responses[endpoint] ?? const {};
}

/// Stores [LibrusReferences] in files of the app, one for each account, so
/// the app and its background check share them and profiles do not push
/// out each other's. Where there is no app directory (the web, unit tests)
/// they are kept in memory only.
class LibrusReferenceCache {
  LibrusReferenceCache({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  /// Where versions before profiles kept the lists of their one account.
  static const fileName = 'librus_references_v1.json';

  static String fileNameFor(String account) =>
      'librus_references_v1_$account.json';

  /// How long the lists are used before they are fetched again. A sync that
  /// meets a subject, teacher or category the lists do not know fetches them
  /// sooner.
  static const maxAge = Duration(hours: 24);

  final Future<Directory> Function() _directory;
  Future<Directory?>? _folder;
  final _memory = <String, LibrusReferences>{};

  Future<Directory?> _resolveFolder() => _folder ??= () async {
    if (kIsWeb) return null;
    try {
      return await _directory();
    } on Object {
      return null;
    }
  }();

  Future<File?> _file(String name) async {
    final folder = await _resolveFolder();
    return folder == null
        ? null
        : File('${folder.path}${Platform.pathSeparator}$name');
  }

  Future<LibrusReferences?> read(String account) async {
    final memory = _memory[account];
    if (memory != null) return memory;
    final file = await _file(fileNameFor(account));
    if (file == null) return null;
    final saved = await _readFile(file, account);
    if (saved != null) return _memory[account] = saved;
    // The lists an older version kept for the account move to its own file.
    final legacy = await _file(fileName);
    final old = legacy == null ? null : await _readFile(legacy, account);
    if (old == null) return null;
    await write(old);
    try {
      await legacy!.delete();
    } on Object {
      // Read once more next time, which is harmless.
    }
    return old;
  }

  Future<LibrusReferences?> _readFile(File file, String account) async {
    try {
      if (!await file.exists()) return null;
      final value = jsonDecode(await file.readAsString());
      if (value is! Map || value['account'] != account) return null;
      final fetchedAt = DateTime.tryParse('${value['fetchedAt']}')?.toLocal();
      final responses = value['responses'];
      final missing = value['knownMissing'];
      if (fetchedAt == null || responses is! Map) return null;
      return LibrusReferences(
        account: account,
        fetchedAt: fetchedAt,
        responses: {
          for (final entry in responses.entries)
            if (entry.value is Map)
              '${entry.key}': (entry.value as Map).cast<String, dynamic>(),
        },
        knownMissing: {
          if (missing is List)
            for (final item in missing) '$item',
        },
      );
    } on Object {
      return null;
    }
  }

  Future<void> write(LibrusReferences references) async {
    _memory[references.account] = references;
    final file = await _file(fileNameFor(references.account));
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      // A whole file or none: the app and the background check may write
      // at the same time.
      final temporary = File(
        '${file.path}.${DateTime.now().microsecondsSinceEpoch}_'
        '${Random().nextInt(1 << 30)}.tmp',
      );
      await temporary.writeAsString(
        jsonEncode({
          'account': references.account,
          // In UTC, so the hour the clocks go back reads back right.
          'fetchedAt': references.fetchedAt.toUtc().toIso8601String(),
          'responses': references.responses,
          'knownMissing': references.knownMissing.toList(),
        }),
        flush: true,
      );
      await temporary.rename(file.path);
    } on Object {
      // The lists are fetched again next time.
    }
  }

  /// Forgets the lists of [account].
  Future<void> remove(String account) async {
    _memory.remove(account);
    final file = await _file(fileNameFor(account));
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Nothing to remove.
    }
  }

  /// Forgets the lists of every account.
  Future<void> clear() async {
    _memory.clear();
    final folder = await _resolveFolder();
    if (folder == null) return;
    try {
      if (!await folder.exists()) return;
      await for (final entry in folder.list()) {
        final name = entry.uri.pathSegments.last;
        if (entry is File && name.startsWith('librus_references_v1')) {
          await entry.delete();
        }
      }
    } on Object {
      // Nothing to remove.
    }
  }
}
