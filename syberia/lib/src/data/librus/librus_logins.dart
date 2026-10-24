import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/librus_error.dart';
import '../../domain/stable_hash.dart';

/// A Librus login kept on the phone: the address and password of the Librus
/// account, and the portal's tokens. The password lets the app log in again
/// when Librus no longer takes the tokens, as the official app does.
@immutable
class LibrusLogin {
  const LibrusLogin({
    required this.email,
    required this.password,
    this.accessToken = '',
    this.refreshToken = '',
  });

  final String email;
  final String password;
  final String accessToken;
  final String refreshToken;

  /// The name of the login on the phone: one for an address however it is
  /// typed.
  static String keyOf(String email) => stableHash(email.trim().toLowerCase());

  LibrusLogin copyWith({String? accessToken, String? refreshToken}) =>
      LibrusLogin(
        email: email,
        password: password,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
      );

  Map<String, String> toJson() => {
    'email': email,
    'password': password,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };

  /// Null for anything that is not a saved login.
  static LibrusLogin? fromJson(Object? json) {
    if (json is! Map) return null;
    final email = json['email'];
    final password = json['password'];
    if (email is! String || password is! String) return null;
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    return LibrusLogin(
      email: email,
      password: password,
      accessToken: access is String ? access : '',
      refreshToken: refresh is String ? refresh : '',
    );
  }
}

/// The phone's Librus logins, in the secure storage. One login serves every
/// profile that comes from it.
class LibrusLogins {
  LibrusLogins({
    FlutterSecureStorage? secureStorage,
    DateTime Function()? clock,
  }) : _storage = secureStorage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  static const storageKey = 'syberia_portal_accounts_v2';

  /// Where versions before profiles kept their one login, together with the
  /// student chosen in it.
  static const legacyKey = 'syberia_portal_session_v1';

  /// Tokens another profile of the login renewed this recently serve the
  /// next profile as they are, so a sync of several profiles renews them
  /// once.
  static const reuse = Duration(minutes: 1);

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  Future<void> _changes = Future.value();
  final _turns = <String, Future<void>>{};
  final _renewedAt = <String, DateTime>{};

  Future<Map<String, LibrusLogin>> all() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          '${entry.key}': ?LibrusLogin.fromJson(entry.value),
      };
    } on FormatException {
      return {};
    }
  }

  Future<LibrusLogin?> read(String account) async => (await all())[account];

  /// [fresh] says the tokens were made just now, by logging in: the next
  /// sync uses them rather than renewing them at once.
  Future<void> write(
    String account,
    LibrusLogin login, {
    bool fresh = false,
  }) async {
    await _change((logins) => logins[account] = login);
    if (fresh) _renewedAt[account] = _clock();
  }

  Future<void> remove(String account) {
    _renewedAt.remove(account);
    return _change((logins) => logins.remove(account));
  }

  Future<void> clear() {
    _renewedAt.clear();
    return _enqueue(() => _storage.delete(key: storageKey));
  }

  /// Fresh portal tokens for [account]: [renew] makes them from the saved
  /// login, unless another profile of the login renewed them a moment ago.
  /// Renewals of one login take turns, so two profiles never spend the same
  /// refresh token.
  Future<LibrusLogin> renewed(
    String account,
    Future<LibrusLogin> Function(LibrusLogin current) renew,
  ) {
    final turn = (_turns[account] ?? Future<void>.value()).then((_) async {
      final current = await read(account);
      if (current == null) {
        throw const LibrusException(LibrusErrorCode.noStoredAccount);
      }
      final last = _renewedAt[account];
      if (last != null) {
        final since = _clock().difference(last);
        if (!since.isNegative && since < reuse) return current;
      }
      final fresh = await renew(current);
      await write(account, fresh);
      _renewedAt[account] = _clock();
      return fresh;
    });
    _turns[account] = turn.then<void>((_) {}, onError: (Object _) {});
    return turn;
  }

  /// The login of a version before profiles, with its chosen student, if
  /// the phone still has it.
  Future<(LibrusLogin, String?)?> readLegacy() async {
    final raw = await _storage.read(key: legacyKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      final login = LibrusLogin.fromJson(decoded);
      if (login == null) return null;
      final student = (decoded as Map)['synergiaLogin'];
      return (login, student is String && student.isNotEmpty ? student : null);
    } on Object {
      return null;
    }
  }

  Future<void> removeLegacy() => _storage.delete(key: legacyKey);

  Future<void> _change(void Function(Map<String, LibrusLogin> logins) change) =>
      _enqueue(() async {
        final logins = await all();
        change(logins);
        if (logins.isEmpty) {
          await _storage.delete(key: storageKey);
          return;
        }
        await _storage.write(
          key: storageKey,
          value: jsonEncode({
            for (final entry in logins.entries) entry.key: entry.value.toJson(),
          }),
        );
      });

  /// Changes go one after another, so none is lost to another.
  Future<void> _enqueue(Future<void> Function() action) {
    final next = _changes.then((_) => action());
    _changes = next.catchError((Object _) {});
    return next;
  }
}
