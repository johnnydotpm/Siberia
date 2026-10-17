import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'snapshot_cache.dart';

/// Keeps the last Librus snapshot in a file of its own.
///
/// A large snapshot used to live in SharedPreferences, which Android loads
/// into memory as a whole with every preference. In a file it is read only
/// when needed, and decoding and encoding run off the UI isolate. On the web,
/// and where no app directory is available (unit tests), the snapshot stays
/// in SharedPreferences.
class SnapshotStore {
  SnapshotStore({
    required this._preferences,
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? getApplicationSupportDirectory;

  /// Where the snapshot used to be kept, and still is when there is no file.
  static const preferencesKey = 'last_librus_snapshot_v1';
  static const fileName = 'librus_snapshot_v1.json';

  final Future<SharedPreferences> _preferences;
  final Future<Directory> Function() _directory;
  Future<File?>? _file;
  Future<void> _writes = Future.value();

  Future<File?> _resolveFile() => _file ??= () async {
    if (kIsWeb) return null;
    try {
      final directory = await _directory();
      return File('${directory.path}${Platform.pathSeparator}$fileName');
    } on Object {
      return null;
    }
  }();

  Future<AppSnapshot?> read() async {
    final preferences = await _preferences;
    final file = await _resolveFile();
    final legacy = preferences.getString(preferencesKey);
    if (file == null) return SnapshotCache.decode(legacy);
    await _writes;
    if (legacy != null) {
      // Moves a snapshot saved by an older version into the file, once.
      final snapshot = await compute(SnapshotCache.decode, legacy);
      if (snapshot != null) {
        await _enqueue(() => compute(_writeRaw, (file.path, legacy)));
      }
      await preferences.remove(preferencesKey);
      return snapshot;
    }
    return compute(_readFile, file.path);
  }

  Future<void> write(AppSnapshot snapshot) async {
    final file = await _resolveFile();
    if (file == null) {
      await (await _preferences).setString(
        preferencesKey,
        SnapshotCache.encode(snapshot),
      );
      return;
    }
    await _enqueue(() => compute(_writeSnapshot, (file.path, snapshot)));
  }

  Future<void> clear() async {
    await (await _preferences).remove(preferencesKey);
    final file = await _resolveFile();
    if (file == null) return;
    await _enqueue(() async {
      if (await file.exists()) await file.delete();
    });
  }

  /// Writes go one after another, so an older snapshot cannot land last.
  Future<void> _enqueue(Future<void> Function() write) {
    final next = _writes.then((_) => write());
    _writes = next.catchError((Object _) {});
    return next;
  }
}

Future<AppSnapshot?> _readFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return SnapshotCache.decode(await file.readAsString());
}

Future<void> _writeSnapshot((String, AppSnapshot) request) =>
    _writeRaw((request.$1, SnapshotCache.encode(request.$2)));

/// Writes to a temporary file and renames it, so a reader (the app or the
/// background check) never sees half of a snapshot.
Future<void> _writeRaw((String, String) request) async {
  final (path, contents) = request;
  final file = File(path);
  await file.parent.create(recursive: true);
  final temporary = File(
    '$path.${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}.tmp',
  );
  await temporary.writeAsString(contents, flush: true);
  await temporary.rename(path);
}
