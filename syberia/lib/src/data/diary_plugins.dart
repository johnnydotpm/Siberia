import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:siberia_plugins/siberia_plugins.dart';

import '../domain/librus_error.dart';
import '../domain/models.dart';
import '../domain/profiles.dart';
import 'snapshot_cache.dart';
import 'plugin_text.dart';
import '../domain/diary_part.dart';

export 'package:siberia_plugins/siberia_plugins.dart' show PluginManifest;

class PluginSignIn {
  const PluginSignIn(this.account, this.manifest, this.students);
  final String account;
  final PluginManifest manifest;
  final List<PluginStudent> students;
}

class PluginStudent {
  const PluginStudent(this.id, this.name, this.school, this.parent);
  final String id, name, school;
  final bool parent;
}

/// Only distribution, account ownership and normalized DTOs live in the app.
/// Provider-specific paths, envelopes and decoders live in downloaded bytecode.
class DiaryPlugins {
  DiaryPlugins({
    FlutterSecureStorage? storage,
    Future<Directory> Function()? directory,
    PluginRuntime? runtime,
    Dio? distributionClient,
    this.source,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _directory =
           directory ??
           (() async => Directory(
             '${(await getApplicationSupportDirectory()).path}/diary-plugins',
           )),
       _runtime = runtime ?? PluginRuntime(),
       _distribution = distributionClient;
  final FlutterSecureStorage _storage;
  final Future<Directory> Function() _directory;
  final PluginRuntime _runtime;
  final Dio? _distribution;
  final Uri? source;
  Future<PluginStore> get _store async => PluginStore(
    directory: await _directory(),
    client: _distribution,
    source: source ?? _defaultSource,
  );
  static final _defaultSource = Uri.parse(
    const String.fromEnvironment(
      'DIARY_PLUGIN_SOURCE',
      defaultValue:
          'https://raw.githubusercontent.com/johnnydotpm/Siberia/main/plugins/',
    ),
  );
  static String _key(String owner) => 'diary_plugin_account_v1_$owner';
  Future<List<PluginManifest>> catalog() async => (await _store).catalog();

  static Set<String> _origins(Object? raw) {
    if (raw is! List) throw const PluginException('invalid_origin');
    final origins = <String>{};
    for (final value in raw) {
      if (value is! String) throw const PluginException('invalid_origin');
      final uri = Uri.tryParse(value);
      if (uri == null || !isPluginHttpsUri(uri) || uri.origin != value) {
        throw const PluginException('invalid_origin');
      }
      origins.add(value);
    }
    return origins;
  }

  /// Atomic exclusive creation also serializes background/foreground isolates.
  /// A crash leaves a short-lived lease, not permanently locked credentials.
  final _leases = <String, Future<void> Function()>{};
  Future<void> _assertLease(String owner) async {
    final check = _leases[owner];
    if (check == null) throw const PluginException('account_changed');
    await check();
  }

  Future<T> _locked<T>(String owner, Future<T> Function() work) async {
    if (!RegExp(r'^plugin-[a-z][a-z0-9-]*-[a-f0-9]{64}$').hasMatch(owner)) {
      throw const PluginException('invalid_account');
    }
    final root = await _directory();
    await root.create(recursive: true);
    final file = File('${root.path}/$owner.lock');
    final token = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
    final until = DateTime.now().add(const Duration(seconds: 50));
    while (true) {
      try {
        await file.create(exclusive: true);
        await file.writeAsString(token, flush: true);
        break;
      } on FileSystemException {
        if (await file.exists() &&
            DateTime.now().difference(await file.lastModified()) >
                const Duration(minutes: 5)) {
          try {
            await file.delete();
          } on FileSystemException {
            /* Another waiter won. */
          }
        }
        if (DateTime.now().isAfter(until)) {
          throw const PluginException('account_busy');
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
    Future<void> check() async {
      if (!await file.exists() || await file.readAsString() != token) {
        throw const PluginException('account_changed');
      }
    }

    _leases[owner] = check;
    final heartbeat = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        if (await file.readAsString() == token) {
          await file.setLastModified(DateTime.now());
        }
      } on FileSystemException {
        /* Checked on completion. */
      }
    });
    try {
      return await work();
    } finally {
      heartbeat.cancel();
      if (identical(_leases[owner], check)) _leases.remove(owner);
      try {
        if (await file.readAsString() == token) await file.delete();
      } on FileSystemException {
        /* Expired lease. */
      }
    }
  }

  Future<Map<String, dynamic>> _read(String owner) async {
    final raw = await _storage.read(key: _key(owner));
    if (raw == null) {
      throw const LibrusException(LibrusErrorCode.sessionExpired);
    }
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on Object {
      throw const PluginException('invalid_account');
    }
  }

  Future<void> forget(String owner) =>
      _locked(owner, () => _storage.delete(key: _key(owner)));

  Future<PluginSignIn> connect(
    PluginManifest manifest,
    Map<String, Object?> fields,
  ) async {
    final installed = await (await _store).install(manifest);
    final configured = <String>{};
    for (final field in manifest.loginFields) {
      if (field['type'] == 'url') {
        final uri = Uri.tryParse(fields[field['id']] as String);
        if (uri == null || !isPluginHttpsUri(uri) || uri.hasQuery) {
          throw const PluginException('invalid_origin');
        }
        configured.add(uri.origin);
      }
    }
    final auth = await _runtime.invoke(
      installed,
      operation: 'authenticate',
      input: fields,
      accountOrigins: configured,
    );
    if (auth.errorCode != null) throw PluginException(auth.errorCode!);
    final ownerData = (auth.data as Map)['owner'] as String;
    final owner =
        'plugin-${manifest.id}-${sha256.convert(utf8.encode(ownerData))}';
    return _locked(owner, () async {
      final state = auth.state;
      final origins = _origins(state['origins']);
      final discovered = await _runtime.invoke(
        installed,
        operation: 'accounts',
        state: state,
        accountOrigins: origins,
      );
      if (discovered.errorCode != null) {
        throw PluginException(discovered.errorCode!);
      }
      _origins(discovered.state['origins']);
      final students = (discovered.data as List).map((raw) {
        final row = (raw as Map).cast<String, dynamic>();
        return PluginStudent(
          row['id'] as String,
          row['name'] as String,
          row['school'] as String,
          row['parent'] == true,
        );
      }).toList();
      if (students.isEmpty) throw const PluginException('no_students');
      await _assertLease(owner);
      await _storage.write(
        key: _key(owner),
        value: jsonEncode({
          'manifest': manifest.toJson(),
          'state': discovered.state,
        }),
      );
      return PluginSignIn(owner, manifest, students);
    });
  }

  Future<PluginResult> invoke(
    SchoolProfile profile,
    String operation,
    Map<String, Object?> input,
  ) => _locked(profile.account, () async {
    final record = await _read(profile.account);
    var manifest = PluginManifest.fromJson(record['manifest']);
    if (manifest.id != profile.providerId) {
      throw const PluginException('invalid_account');
    }
    // Upgrade the two first-party adapters only when a newly requested
    // operation is absent. Verify the immutable artifact before using the
    // existing session, and never expand permissions or downgrade a release.
    if (operation == 'deleteMessage' &&
        !manifest.operations.contains(operation) &&
        const {'fryderyk', 'mobireg'}.contains(manifest.id)) {
      final available = await catalog();
      final next = available.where((m) => m.id == manifest.id).firstOrNull;
      if (next == null ||
          !next.operations.contains(operation) ||
          !next.operations.containsAll(manifest.operations) ||
          !next.origins.containsAll(manifest.origins) ||
          !manifest.origins.containsAll(next.origins) ||
          jsonEncode(next.loginFields) != jsonEncode(manifest.loginFields) ||
          !_newerVersion(next.version, manifest.version)) {
        throw const PluginException('unsupported_operation');
      }
      await (await _store).install(next);
      manifest = next;
    }
    final installed = await (await _store).install(manifest);
    var state = (record['state'] as Map).cast<String, Object?>();
    Future<PluginResult> call(String op, Map<String, Object?> data) async {
      final result = await _runtime.invoke(
        installed,
        operation: op,
        input: data,
        state: state,
        accountOrigins: _origins(state['origins']),
      );
      // A failed operation may still contain a valid rotated token or SSO
      // session. Validate its origins and persist one atomic credential record.
      _origins(result.state['origins']);
      state = result.state;
      await _assertLease(profile.account);
      await _storage.write(
        key: _key(profile.account),
        value: jsonEncode({'manifest': manifest.toJson(), 'state': state}),
      );
      return result;
    }

    // Optional credential-only preflight is a separate durable checkpoint.
    // Refreshing before a mutation must never cause that mutation to replay.
    if (manifest.operations.contains('prepare') &&
        const {'message', 'sendMessage', 'deleteMessage'}.contains(operation)) {
      final prepared = await call('prepare', {
        'pupilId': profile.pluginStudent,
      });
      if (prepared.errorCode != null) {
        throw PluginException(prepared.errorCode!);
      }
    }
    var result = await call(operation, {
      ...input,
      'pupilId': profile.pluginStudent,
    });
    const safeReads = {
      'sync',
      'accounts',
      'terms',
      'timetable',
      'messages',
      'recipients',
      'attendanceSummary',
      'absenceRequests',
      'justifications',
      'grades',
      'attendance',
      'homework',
      'events',
      'notices',
      'announcements',
      'luckyNumbers',
    };
    if (result.errorCode == 'session_expired' &&
        safeReads.contains(operation) &&
        manifest.operations.contains('refresh')) {
      final refreshed = await call('refresh', {});
      if (refreshed.errorCode != null) {
        throw PluginException(refreshed.errorCode!);
      }
      final context = await call('accounts', {});
      if (context.errorCode != null) throw PluginException(context.errorCode!);
      result = await call(operation, {
        ...input,
        'pupilId': profile.pluginStudent,
      });
    }
    if (result.errorCode != null) throw PluginException(result.errorCode!);
    return result;
  });

  static String _id(SchoolProfile p, String raw) =>
      '${p.id}:${base64Url.encode(utf8.encode(raw))}';
  static String _rawId(SchoolProfile p, String id) {
    final prefix = '${p.id}:';
    if (!id.startsWith(prefix)) throw const PluginException('invalid_scope');
    return utf8.decode(base64Url.decode(id.substring(prefix.length)));
  }

  static Map<String, dynamic> _row(SchoolProfile p, Object? raw) {
    final row = (raw as Map).cast<String, dynamic>();
    return {
      ...row,
      for (final key in ['preview', 'description', 'content', 'text'])
        if (row[key] is String) key: pluginText(row[key] as String),
      'id': _id(p, row['id'] as String),
    };
  }

  Map<String, Object?> _range(DateTime date) {
    final from = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {
      'dateFrom': day(from),
      'dateTo': day(from.add(const Duration(days: 6))),
      'now': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _mailbox(
    SchoolProfile profile,
    String folder,
  ) async {
    final items = <Object?>[];
    final seen = <Object>{};
    Object? cursor;
    Map<String, Object?> module = {};
    for (var page = 0; page < 50; page++) {
      final result = await invoke(profile, 'messages', {
        'folder': folder,
        'page': ?cursor,
      });
      module = (result.data as Map).cast<String, Object?>();
      items.addAll(module['items'] as List);
      cursor = module['nextCursor'];
      if (cursor == null) break;
      if (!seen.add(cursor)) throw const PluginException('protocol_error');
    }
    return {...module, 'items': items, 'nextCursor': cursor};
  }

  Future<AppSnapshot> sync(
    SchoolProfile profile,
    AppSnapshot previous, {
    Set<DiaryPart>? parts,
  }) async {
    final wanted = (parts ?? DiaryPart.values.toSet())
        .map((part) => part.name)
        .toList();
    final modules = <String, Object?>{};
    final skippedOptional = <String>{};
    final issues = {...previous.moduleErrors}
      ..removeWhere((key, _) => wanted.contains(key));
    // Each module is a separate VM invocation and credential checkpoint. One
    // module failure cannot erase another module or lose a rotated auth token.
    for (final name in wanted) {
      try {
        modules[name] = name == 'messages'
            ? await _mailbox(profile, 'inbox')
            : (await invoke(profile, name, _range(DateTime.now()))).data;
      } on PluginException catch (error) {
        if (name == 'luckyNumbers' && error.code == 'unsupported_operation') {
          skippedOptional.add(name);
          continue;
        }
        if (error.code == 'session_expired' && name != 'messages') rethrow;
        issues[name] = error.code == 'unsupported_operation'
            ? 'module_unavailable'
            : error.code;
      }
    }
    final cached = (jsonDecode(SnapshotCache.encode(previous)) as Map)
        .cast<String, dynamic>();
    final providerData = {...previous.providerData};
    var applied = 0;
    for (final name in wanted) {
      if (skippedOptional.contains(name)) continue;
      final module = modules[name];
      if (module == null) {
        issues.putIfAbsent(name, () => 'module_unavailable');
        continue;
      }
      try {
        final normalized = (module as Map).cast<String, dynamic>();
        final items = (normalized['items'] as List).map((row) {
          if (name != 'luckyNumbers') return _row(profile, row);
          final value = row as Map;
          final number = LuckyNumber.fromJson({
            'number': value['number'],
            'day': value['day'],
          });
          if (number == null) throw const PluginException('protocol_error');
          return number.toJson();
        }).toList();
        final candidate = {...cached};
        if (name == 'events' || name == 'homework') {
          final events = cached['events'] as List;
          candidate['events'] = [
            ...events.where(
              (e) =>
                  (e as Map)['kind'] !=
                  (name == 'homework' ? 'homework' : 'exam'),
            ),
            ...items,
          ];
        } else {
          candidate[name == 'timetable' ? 'lessons' : name] = items;
        }
        if (SnapshotCache.decode(jsonEncode(candidate)) == null) {
          throw const PluginException('invalid_data');
        }
        cached.addAll(candidate);
        applied++;
        providerData[name] = normalized;
        if (name == 'attendance') {
          cached['attendanceComplete'] = normalized['complete'] != false;
        }
        if (normalized['nextCursor'] != null) issues[name] = 'partial';
      } on Object {
        issues[name] = 'protocol_error';
      }
    }
    cached['providerData'] = providerData;
    cached['moduleErrors'] = issues;
    if (applied > 0) {
      cached['lastSync'] = DateTime.now().toUtc().toIso8601String();
    }
    return SnapshotCache.decode(jsonEncode(cached)) ?? previous;
  }

  Future<List<Lesson>> timetable(SchoolProfile p, DateTime day) async {
    final result = await invoke(p, 'timetable', _range(day));
    final module = result.data as Map;
    final base =
        jsonDecode(SnapshotCache.encode(_empty(p))) as Map<String, dynamic>;
    base['lessons'] = (module['items'] as List).map((r) => _row(p, r)).toList();
    final snapshot = SnapshotCache.decode(jsonEncode(base));
    if (snapshot == null) throw const PluginException('protocol_error');
    return snapshot.lessons;
  }

  Future<List<MessageRecipient>> recipients(SchoolProfile p) async {
    final result = await invoke(p, 'recipients', {});
    return (result.data as List).map((r) {
      final row = r as Map;
      return MessageRecipient(
        id: row['id'] as String,
        owner: p.account,
        name: row['name'] as String,
        group: row['group'] as String,
      );
    }).toList();
  }

  static bool _newerVersion(String next, String current) {
    final a = next.split('.').map(int.parse).toList();
    final b = current.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  Future<void> deleteMessage(SchoolProfile p, SchoolMessage message) async {
    final rawId = _rawId(p, message.id);
    final result = await invoke(p, 'deleteMessage', {
      'id': rawId,
      'sent': message.sent,
    });
    if (result.data is! Map || (result.data as Map)['deleted'] != true) {
      throw const PluginException('protocol_error');
    }
  }

  Future<String> send(
    SchoolProfile p,
    List<MessageRecipient> recipients,
    String subject,
    String body,
  ) async {
    if (recipients.any((r) => r.owner != p.account || r.id is! String)) {
      throw const PluginException('invalid_scope');
    }
    try {
      final result = await invoke(p, 'sendMessage', {
        'recipients': recipients.map((r) => r.id.toString()).toList(),
        'subject': subject,
        'body': body,
      });
      return _id(p, (result.data as Map)['id'] as String);
    } on PluginException catch (error) {
      if (const {
        'invalid_input',
        'session_expired',
        'invalid_credentials',
        'unsupported_operation',
        'invalid_scope',
      }.contains(error.code)) {
        rethrow;
      }
      throw const PluginException('send_uncertain');
    } on Object {
      throw const PluginException('send_uncertain');
    }
  }

  Future<SchoolMessageContent> message(
    SchoolProfile p,
    SchoolMessage message,
    AppSnapshot snapshot,
  ) async {
    final rawId = _rawId(p, message.id);
    Object? record;
    for (final key in ['messages', 'sentMessages']) {
      final module = snapshot.providerData[key];
      if (module is! Map) continue;
      for (final item in module['items'] as List? ?? const []) {
        if ((item as Map)['id'] == rawId) record = item['raw'];
      }
    }
    if (record == null && message.sent) {
      final module = await _mailbox(p, 'sent');
      for (final item in module['items'] as List) {
        if ((item as Map)['id'] == rawId) record = item['raw'];
      }
    }
    final response = await invoke(p, 'message', {
      'id': rawId,
      'sent': message.sent,
      'record': ?record,
    });
    final row = response.data as Map;
    return SchoolMessageContent(
      id: message.id,
      sender: row['sender'] as String,
      subject: row['subject'] as String,
      body: pluginText(row['body'] as String),
      receivedAt: DateTime.parse(row['receivedAt'] as String),
      attachments: const [],
    );
  }

  Future<(List<SchoolMessage>, Map<String, Object?>)> sent(
    SchoolProfile p,
  ) async {
    final module = await _mailbox(p, 'sent');
    final value =
        jsonDecode(SnapshotCache.encode(_empty(p))) as Map<String, dynamic>;
    value['messages'] = (module['items'] as List)
        .map((r) => _row(p, r))
        .toList();
    final snapshot = SnapshotCache.decode(jsonEncode(value));
    if (snapshot == null) throw const PluginException('protocol_error');
    return (snapshot.messages, module);
  }

  static StudentProfile student(SchoolProfile p) => StudentProfile(
    id: p.studentId ?? '${p.account}/${p.pluginStudent}',
    name: p.name,
    school: p.school,
    provider: p.providerName.isEmpty ? p.providerId : p.providerName,
    pluginId: p.providerId,
  );
  static AppSnapshot _empty(SchoolProfile p) => AppSnapshot(
    profile: student(p),
    lessons: const [],
    grades: const [],
    events: const [],
    messages: const [],
    attendance: const [],
    announcements: const [],
    notices: const [],
    lastSync: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
