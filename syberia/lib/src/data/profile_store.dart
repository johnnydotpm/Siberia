import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profiles.dart';

/// The profiles on the phone, the one open, and which have news the user
/// has not seen.
class ProfileStore {
  ProfileStore(this._preferences);

  static const listKey = 'profiles_v1';
  static const activeKey = 'active_profile_id_v1';

  /// Kept apart from the list: the background check writes it, and a
  /// change made in the app meanwhile is not lost.
  static const newsKey = 'profile_news_v1';

  final Future<SharedPreferences> _preferences;

  /// The key of a setting each profile keeps for itself.
  static String key(String base, String profileId) => '${base}_$profileId';

  /// [reload] reads what another isolate, as the background check, wrote.
  Future<List<SchoolProfile>> read({bool reload = false}) async {
    final preferences = await _preferences;
    if (reload) await preferences.reload();
    final raw = preferences.getString(listKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final seen = <String>{};
      return List.unmodifiable([
        for (final item in decoded)
          if (SchoolProfile.fromJson(item) case final profile?)
            if (seen.add(profile.id)) profile,
      ]);
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(List<SchoolProfile> profiles) async {
    final preferences = await _preferences;
    if (profiles.isEmpty) {
      await preferences.remove(listKey);
      return;
    }
    await preferences.setString(
      listKey,
      jsonEncode([for (final profile in profiles) profile.toJson()]),
    );
  }

  Future<String?> readActive() async =>
      (await _preferences).getString(activeKey);

  Future<void> writeActive(String? id) async {
    final preferences = await _preferences;
    if (id == null) {
      await preferences.remove(activeKey);
    } else {
      await preferences.setString(activeKey, id);
    }
  }

  Future<Set<String>> readNews({bool reload = false}) async {
    final preferences = await _preferences;
    if (reload) await preferences.reload();
    return (preferences.getStringList(newsKey) ?? const <String>[]).toSet();
  }

  Future<void> setNews(String profileId, bool news) async {
    final preferences = await _preferences;
    await preferences.reload();
    final current = (preferences.getStringList(newsKey) ?? const <String>[])
        .toSet();
    final changed = news ? current.add(profileId) : current.remove(profileId);
    if (!changed) return;
    if (current.isEmpty) {
      await preferences.remove(newsKey);
    } else {
      await preferences.setStringList(newsKey, current.toList()..sort());
    }
  }
}
