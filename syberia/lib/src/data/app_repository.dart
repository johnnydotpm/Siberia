import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/librus_error.dart';
import '../domain/models.dart';
import 'librus/librus_client.dart';
import 'snapshot_store.dart';

/// Local-first repository boundary. Real e-dziennik connectors plug in behind
/// this API so provider-specific protocols never leak into the UI.
class AppRepository {
  AppRepository({
    Future<SharedPreferences>? preferences,
    FlutterSecureStorage? secureStorage,
    LibrusClient? librusClient,
    Dio? githubClient,
    SnapshotStore? snapshotStore,
  }) : this._(
         preferences ?? SharedPreferences.getInstance(),
         secureStorage: secureStorage,
         librusClient: librusClient,
         githubClient: githubClient,
         snapshotStore: snapshotStore,
       );

  AppRepository._(
    Future<SharedPreferences> preferences, {
    FlutterSecureStorage? secureStorage,
    LibrusClient? librusClient,
    Dio? githubClient,
    SnapshotStore? snapshotStore,
  }) : _preferences = preferences,
       _snapshots = snapshotStore ?? SnapshotStore(preferences: preferences),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _librusClient =
           librusClient ?? LibrusClient(secureStorage: secureStorage),
       _githubClient =
           githubClient ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 5),
               receiveTimeout: const Duration(seconds: 5),
               headers: const {
                 'Accept': 'application/vnd.github+json',
                 'X-GitHub-Api-Version': '2022-11-28',
                 'User-Agent': 'SiberiaGB-Flutter',
               },
             ),
           );

  static const _profileKey = 'active_profile_v1';
  static const _autoSyncKey = 'auto_sync_on_open_v1';
  static const _credentialKey = 'active_profile_credential';
  static const _localeKey = 'app_locale_v1';
  static const _attendanceChartStyleKey = 'attendance_chart_style_v1';
  static const _designKey = 'app_design_v1';
  static const _colorModeKey = 'app_color_mode_v1';
  static const _gradePlusKey = 'grade_plus_value_v1';
  static const _gradeMinusKey = 'grade_minus_value_v1';
  static const _gradeWeightedKey = 'grade_weighted_average_v1';
  static const _subjectShortNamesKey = 'subject_short_names_v1';
  static const _timetableViewKey = 'timetable_view_v1';
  static const _mergeTimetableLessonsKey = 'merge_timetable_lessons_v1';
  static const _showTimetableBreaksKey = 'show_timetable_breaks_v1';
  static const _messageListStyleKey = 'message_list_style_v1';
  static const _gradesViewKey = 'grades_view_v1';
  static const _todayLayoutKey = 'today_layout_v1';
  static const _dismissedUpdateKey = 'dismissed_update_version_v1';
  static const _latestReleaseUrl =
      'https://api.github.com/repos/johnnydotpm/Siberia/releases/latest';

  final Future<SharedPreferences> _preferences;
  final SnapshotStore _snapshots;
  final FlutterSecureStorage _secureStorage;
  final LibrusClient _librusClient;
  final Dio _githubClient;

  /// Reads the saved account and its last snapshot without the network, so
  /// the app opens at once; the launch sync refreshes it afterwards.
  Future<AppSnapshot> load() async {
    final preferences = await _preferences;
    final rawProfile = preferences.getString(_profileKey);
    final profile = rawProfile == null
        ? _signedOutProfile
        : StudentProfile.fromJson(
            jsonDecode(rawProfile) as Map<String, Object?>,
          );

    if (profile.provider == 'Librus Synergia') {
      final saved = await _snapshots.read();
      return saved?.profile.id == profile.id ? saved! : _emptySnapshot(profile);
    }
    if (profile.provider != 'Librus Synergia') {
      await preferences.remove(_profileKey);
    }
    return _emptySnapshot(_signedOutProfile);
  }

  Future<AppSnapshot> loginLibrus({
    required String username,
    required String password,
  }) async {
    final snapshot = await _librusClient.loginAndFetch(
      username: username,
      password: password,
    );
    final preferences = await _preferences;
    await preferences.setString(
      _profileKey,
      jsonEncode(snapshot.profile.toJson()),
    );
    await _cacheSnapshot(snapshot);
    return snapshot;
  }

  Future<List<LinkedSynergiaAccount>> fetchSynergiaAccounts() =>
      _librusClient.fetchSynergiaAccounts();

  Future<AppSnapshot> selectSynergiaAccount(String login) async {
    final snapshot = await _librusClient.selectSynergiaAccount(login);
    final preferences = await _preferences;
    await preferences.setString(
      _profileKey,
      jsonEncode(snapshot.profile.toJson()),
    );
    await _cacheSnapshot(snapshot);
    return snapshot;
  }

  Future<AppSnapshot> sync(AppSnapshot current) async {
    if (current.profile.provider != 'Librus Synergia') {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      return current.copyWith(lastSync: DateTime.now());
    }
    final snapshot = await _librusClient.restoreAndFetch();
    if (snapshot == null) {
      throw const LibrusException(LibrusErrorCode.sessionExpired);
    }
    final withMessages =
        snapshot.messagesError != null &&
            snapshot.profile.id == current.profile.id
        ? snapshot.copyWith(messages: current.messages)
        : snapshot;
    final result = _keepLaterWeeks(withMessages, current, DateTime.now());
    await _cacheSnapshot(result);
    return result;
  }

  /// A sync fetches a single timetable week. Later weeks the app has already
  /// loaded stay, so the next lessons on the Today screen and in the home
  /// screen widget do not vanish after a sync once this week is over.
  AppSnapshot _keepLaterWeeks(
    AppSnapshot fetched,
    AppSnapshot? previous,
    DateTime now,
  ) {
    if (previous == null || previous.profile.id != fetched.profile.id) {
      return fetched;
    }
    final weekEnd = librusSyncWeekStart(now).add(const Duration(days: 7));
    final later = previous.lessons.where(
      (lesson) => !lesson.start.isBefore(weekEnd),
    );
    if (later.isEmpty) return fetched;
    return fetched.copyWith(
      lessons: [...fetched.lessons, ...later]
        ..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  Future<AppSnapshot?> fetchBackgroundSnapshot() async {
    if (!await loadAutoSyncOnOpen()) return null;
    final preferences = await _preferences;
    final rawProfile = preferences.getString(_profileKey);
    if (rawProfile == null) return null;
    final profile = StudentProfile.fromJson(
      (jsonDecode(rawProfile) as Map).cast<String, Object?>(),
    );
    if (profile.provider != 'Librus Synergia') return null;
    final fetched = await _librusClient.restoreAndFetch();
    if (fetched == null) return null;
    final live = _keepLaterWeeks(
      await _preserveCachedMessages(fetched),
      await _snapshots.read(),
      DateTime.now(),
    );
    await _cacheSnapshot(live);
    return live;
  }

  Future<bool> loadAutoSyncOnOpen() async =>
      (await _preferences).getBool(_autoSyncKey) ?? true;

  Future<void> saveAutoSyncOnOpen(bool enabled) async =>
      (await _preferences).setBool(_autoSyncKey, enabled);

  Future<AppSnapshot> _preserveCachedMessages(AppSnapshot snapshot) async {
    if (snapshot.messagesError == null) return snapshot;
    final cached = await _snapshots.read();
    return cached?.profile.id == snapshot.profile.id
        ? snapshot.copyWith(messages: cached!.messages)
        : snapshot;
  }

  Future<void> _cacheSnapshot(AppSnapshot snapshot) =>
      _snapshots.write(snapshot);

  Future<AppSnapshot> logout() async {
    await _librusClient.logout();
    await clearCredential();
    final preferences = await _preferences;
    await preferences.remove(_profileKey);
    await _snapshots.clear();
    return _emptySnapshot(_signedOutProfile);
  }

  Future<void> saveCredential(String value) =>
      _secureStorage.write(key: _credentialKey, value: value);

  Future<void> clearCredential() => _secureStorage.delete(key: _credentialKey);

  Future<String?> loadLocale() async =>
      (await _preferences).getString(_localeKey);

  Future<void> saveLocale(String? languageCode) async {
    final preferences = await _preferences;
    if (languageCode == null) {
      await preferences.remove(_localeKey);
    } else {
      await preferences.setString(_localeKey, languageCode);
    }
  }

  Future<AttendanceChartStyle> loadAttendanceChartStyle() async {
    final saved = (await _preferences).getString(_attendanceChartStyleKey);
    return AttendanceChartStyle.values.firstWhere(
      (style) => style.name == saved,
      orElse: () => AttendanceChartStyle.ring,
    );
  }

  Future<void> saveAttendanceChartStyle(AttendanceChartStyle style) async =>
      (await _preferences).setString(_attendanceChartStyleKey, style.name);

  Future<AppColorMode> loadColorMode() async {
    final saved = (await _preferences).getString(_colorModeKey);
    return AppColorMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => AppColorMode.system,
    );
  }

  Future<void> saveColorMode(AppColorMode mode) async =>
      (await _preferences).setString(_colorModeKey, mode.name);

  Future<GradeAverageSettings> loadGradeAverageSettings() async {
    final preferences = await _preferences;
    const defaults = GradeAverageSettings();
    double modifier(String key, double fallback) {
      final saved = preferences.getDouble(key);
      return GradeAverageSettings.modifierOptions.contains(saved)
          ? saved!
          : fallback;
    }

    return GradeAverageSettings(
      plus: modifier(_gradePlusKey, defaults.plus),
      minus: modifier(_gradeMinusKey, defaults.minus),
      weighted: preferences.getBool(_gradeWeightedKey) ?? defaults.weighted,
    );
  }

  Future<TimetableView> loadTimetableView() async {
    final saved = (await _preferences).getString(_timetableViewKey);
    return TimetableView.values.firstWhere(
      (view) => view.name == saved,
      orElse: () => TimetableView.timeline,
    );
  }

  Future<void> saveTimetableView(TimetableView view) async =>
      (await _preferences).setString(_timetableViewKey, view.name);

  Future<bool> loadMergeTimetableLessons() async =>
      (await _preferences).getBool(_mergeTimetableLessonsKey) ?? false;

  Future<void> saveMergeTimetableLessons(bool enabled) async =>
      (await _preferences).setBool(_mergeTimetableLessonsKey, enabled);

  Future<bool> loadShowTimetableBreaks() async =>
      (await _preferences).getBool(_showTimetableBreaksKey) ?? false;

  Future<void> saveShowTimetableBreaks(bool enabled) async =>
      (await _preferences).setBool(_showTimetableBreaksKey, enabled);

  Future<MessageListStyle> loadMessageListStyle() async {
    final saved = (await _preferences).getString(_messageListStyleKey);
    return MessageListStyle.values.firstWhere(
      (style) => style.name == saved,
      orElse: () => MessageListStyle.list,
    );
  }

  Future<void> saveMessageListStyle(MessageListStyle style) async =>
      (await _preferences).setString(_messageListStyleKey, style.name);

  Future<GradesView> loadGradesView() async {
    final saved = (await _preferences).getString(_gradesViewKey);
    return GradesView.values.firstWhere(
      (view) => view.name == saved,
      orElse: () => GradesView.compact,
    );
  }

  Future<void> saveGradesView(GradesView view) async =>
      (await _preferences).setString(_gradesViewKey, view.name);

  Future<TodayLayout> loadTodayLayout() async {
    final saved = (await _preferences).getStringList(_todayLayoutKey);
    return saved == null ? TodayLayout.defaults : TodayLayout.decode(saved);
  }

  Future<void> saveTodayLayout(TodayLayout layout) async =>
      (await _preferences).setStringList(_todayLayoutKey, layout.encode());

  Future<Map<String, String>> loadSubjectShortNames() async {
    final raw = (await _preferences).getString(_subjectShortNamesKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is String)
            entry.key.toString(): entry.value as String,
      };
    } on FormatException {
      return const {};
    }
  }

  Future<void> saveSubjectShortNames(Map<String, String> names) async =>
      (await _preferences).setString(_subjectShortNamesKey, jsonEncode(names));

  Future<void> saveGradeAverageSettings(GradeAverageSettings settings) async {
    final preferences = await _preferences;
    await preferences.setDouble(_gradePlusKey, settings.plus);
    await preferences.setDouble(_gradeMinusKey, settings.minus);
    await preferences.setBool(_gradeWeightedKey, settings.weighted);
  }

  Future<AppDesign> loadDesign() async {
    final saved = (await _preferences).getString(_designKey);
    return AppDesign.values.firstWhere(
      (design) => design.name == saved,
      orElse: () => AppDesign.glass,
    );
  }

  Future<void> saveDesign(AppDesign design) async =>
      (await _preferences).setString(_designKey, design.name);

  Future<String?> fetchLatestReleaseVersion() async {
    try {
      final response = await _githubClient.get<Object?>(_latestReleaseUrl);
      final data = response.data;
      if (data is! Map) return null;
      final tag = data['tag_name']?.toString().trim();
      return tag == null || tag.isEmpty ? null : tag;
    } on Object {
      return null;
    }
  }

  /// Forgets the app settings; the account, its data and subject short
  /// names are kept.
  Future<void> resetPreferences() async {
    final preferences = await _preferences;
    for (final key in const [
      _localeKey,
      _attendanceChartStyleKey,
      _designKey,
      _colorModeKey,
      _gradePlusKey,
      _gradeMinusKey,
      _gradeWeightedKey,
      _timetableViewKey,
      _mergeTimetableLessonsKey,
      _showTimetableBreaksKey,
      _messageListStyleKey,
      _gradesViewKey,
      _todayLayoutKey,
      _autoSyncKey,
    ]) {
      await preferences.remove(key);
    }
  }

  Future<String?> loadDismissedUpdateVersion() async =>
      (await _preferences).getString(_dismissedUpdateKey);

  Future<void> dismissUpdatesForVersion(String version) async {
    await (await _preferences).setString(_dismissedUpdateKey, version);
  }

  Future<List<MessageRecipient>> fetchMessageRecipients() =>
      _librusClient.fetchMessageRecipients();

  Future<void> sendMessage({
    required List<int> recipientIds,
    required String subject,
    required String body,
  }) => _librusClient.sendMessage(
    recipientIds: recipientIds,
    subject: subject,
    body: body,
  );

  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage message,
  ) async {
    final preferences = await _preferences;
    final profile = preferences.getString(_profileKey);
    final content = await _librusClient.fetchMessageContent(message);
    // Do not change the cache if the user switched accounts while loading.
    if (profile != null && preferences.getString(_profileKey) == profile) {
      final cached = await _snapshots.read();
      if (cached != null) {
        await _cacheSnapshot(
          cached.copyWith(
            messages: cached.messages
                .map(
                  (item) => item.id == message.id
                      ? item.copyWith(unread: false)
                      : item,
                )
                .toList(growable: false),
          ),
        );
      }
    }
    return content;
  }

  Future<Uri> fetchMessageAttachmentUrl({
    required String messageId,
    required String attachmentId,
  }) => _librusClient.fetchMessageAttachmentUrl(
    messageId: messageId,
    attachmentId: attachmentId,
  );

  Future<List<Lesson>> fetchTimetableWeek(DateTime day) =>
      _librusClient.fetchTimetableWeek(day);

  AppSnapshot _emptySnapshot(StudentProfile profile) => AppSnapshot(
    profile: profile,
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

const _signedOutProfile = StudentProfile(
  id: 'signed-out',
  name: 'SiberiaGB',
  school: '',
  provider: 'Signed out',
);
