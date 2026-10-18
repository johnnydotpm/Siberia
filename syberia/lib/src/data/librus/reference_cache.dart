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

/// Stores [LibrusReferences] for one account in a file of the app, so the
/// app and its background check share them. Where there is no app directory
/// (the web, unit tests) they are kept in memory only.
class LibrusReferenceCache {
  LibrusReferenceCache({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const fileName = 'librus_references_v1.json';

  /// How long the lists are used before they are fetched again. A sync that
  /// meets a subject, teacher or category the lists do not know fetches them
  /// sooner.
  static const maxAge = Duration(hours: 24);

  final Future<Directory> Function() _directory;
  Future<File?>? _file;
  LibrusReferences? _memory;

  Future<File?> _resolveFile() => _file ??= () async {
    if (kIsWeb) return null;
    try {
      final directory = await _directory();
      return File('${directory.path}${Platform.pathSeparator}$fileName');
    } on Object {
      return null;
    }
  }();

  Future<LibrusReferences?> read(String account) async {
    final memory = _memory;
    if (memory != null && memory.account == account) return memory;
    final file = await _resolveFile();
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final value = jsonDecode(await file.readAsString());
      if (value is! Map || value['account'] != account) return null;
      final fetchedAt = DateTime.tryParse('${value['fetchedAt']}');
      final responses = value['responses'];
      final missing = value['knownMissing'];
      if (fetchedAt == null || responses is! Map) return null;
      return _memory = LibrusReferences(
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
    _memory = references;
    final file = await _resolveFile();
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
          'fetchedAt': references.fetchedAt.toIso8601String(),
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

  Future<void> clear() async {
    _memory = null;
    final file = await _resolveFile();
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Nothing to remove.
    }
  }
}
