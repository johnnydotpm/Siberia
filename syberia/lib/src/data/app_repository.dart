import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/librus_error.dart';
import '../domain/models.dart';
import '../domain/profiles.dart';
import '../homework_done.dart';
import 'demo_data.dart';
import 'librus/librus_client.dart';
import 'librus/librus_logins.dart';
import 'librus/reference_cache.dart';
import 'profile_store.dart';
import 'snapshot_store.dart';

/// Local-first repository boundary. Real e-dziennik connectors plug in behind
/// this API so provider-specific protocols never leak into the UI.
///
/// The phone keeps any number of profiles, each one student at one school.
/// What works on "the" account (sync, messages, the timetable, the
/// student's own settings) works on the open profile.
class AppRepository {
  AppRepository({
    Future<SharedPreferences>? preferences,
    FlutterSecureStorage? secureStorage,
    LibrusClient? librusClient,
    LibrusClient Function(SchoolProfile? profile)? librusClients,
    Dio? githubClient,
    SnapshotStore? snapshotStore,
    LibrusLogins? logins,
    LibrusReferenceCache? referenceCache,
  }) : this._(
         preferences ?? SharedPreferences.getInstance(),
         secureStorage: secureStorage,
         librusClient: librusClient,
         librusClients: librusClients,
         githubClient: githubClient,
         snapshotStore: snapshotStore,
         logins: logins,
         referenceCache: referenceCache,
       );

  AppRepository._(
    Future<SharedPreferences> preferences, {
    FlutterSecureStorage? secureStorage,
    LibrusClient? librusClient,
    LibrusClient Function(SchoolProfile? profile)? librusClients,
    Dio? githubClient,
    SnapshotStore? snapshotStore,
    LibrusLogins? logins,
    LibrusReferenceCache? referenceCache,
  }) : _preferences = preferences,
       _legacySnapshots =
           snapshotStore ?? SnapshotStore(preferences: preferences),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _logins = logins ?? LibrusLogins(secureStorage: secureStorage),
       _references = referenceCache ?? LibrusReferenceCache(),
       _sharedClient = librusClient,
       _clientFactory = librusClients,
       _profileStore = ProfileStore(preferences),
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

  /// Where a version before profiles kept its one student.
  static const _legacyProfileKey = 'active_profile_v1';
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

  /// The settings each profile keeps for itself.
  static const _profileSettingKeys = [
    _subjectShortNamesKey,
    _gradePlusKey,
    _gradeMinusKey,
    _gradeWeightedKey,
  ];

  DemoData? _demo;

  /// Starts an in-memory session without writing accounts or credentials.
  AppSnapshot enterDemo() => (_demo = DemoData()).snapshot;

  final Future<SharedPreferences> _preferences;
  final SnapshotStore _legacySnapshots;
  final FlutterSecureStorage _secureStorage;
  final LibrusLogins _logins;
  final LibrusReferenceCache _references;
  final LibrusClient? _sharedClient;

  /// Makes the client of a profile, or of a sign-in when given none.
  final LibrusClient Function(SchoolProfile? profile)? _clientFactory;
  final ProfileStore _profileStore;
  final Dio _githubClient;

  final _clients = <String, LibrusClient>{};
  final _stores = <String, SnapshotStore>{};
  List<SchoolProfile> _profiles = const [];
  String? _activeId;
  Future<void>? _ready;

  /// The profiles on the phone, once loaded.
  List<SchoolProfile> get profiles => _profiles;

  /// The open profile; null when signed out.
  SchoolProfile? get activeProfile {
    for (final profile in _profiles) {
      if (profile.id == _activeId) return profile;
    }
    return null;
  }

  Future<void> _ensureReady() => _ready ??= () async {
    await _migrate();
    await _readProfiles();
  }();

  Future<void> _readProfiles({bool reload = false}) async {
    _profiles = await _profileStore.read(reload: reload);
    final active = await _profileStore.readActive();
    _activeId = _profiles.any((profile) => profile.id == active)
        ? active
        : _profiles.isEmpty
        ? null
        : _profiles.first.id;
  }

  /// The profiles, read again: the background check may have changed them.
  Future<List<SchoolProfile>> loadProfiles({bool reload = false}) async {
    await _ensureReady();
    if (reload) await _readProfiles(reload: true);
    return _profiles;
  }

  /// The profiles with news the user has not seen yet.
  Future<Set<String>> loadProfileNews({bool reload = false}) =>
      _profileStore.readNews(reload: reload);

  Future<void> setProfileNews(String profileId, bool news) =>
      _profileStore.setNews(profileId, news);

  LibrusClient _clientFor(SchoolProfile profile) {
    final shared = _sharedClient;
    if (shared != null) return shared;
    final factory = _clientFactory;
    return _clients.putIfAbsent(
      profile.id,
      () =>
          factory?.call(profile) ??
          LibrusClient(
            logins: _logins,
            referenceCache: _references,
            account: profile.account.isEmpty ? null : profile.account,
            synergiaLogin: profile.synergiaLogin,
          ),
    );
  }

  SnapshotStore _storeFor(String profileId) => _stores.putIfAbsent(
    profileId,
    () => _legacySnapshots.forProfile(profileId),
  );

  SchoolProfile _profile(String id) => _profiles.firstWhere(
    (profile) => profile.id == id,
    orElse: () => throw StateError('No profile $id on the phone.'),
  );

  /// The open profile, for what needs an account.
  SchoolProfile _requireActive() =>
      activeProfile ??
      (throw const LibrusException(LibrusErrorCode.noStoredAccount));

  /// The key of [base] for the open profile. Signed out, the base key.
  String _ownKey(String base) {
    final id = _activeId;
    return id == null ? base : ProfileStore.key(base, id);
  }

  /// A version before profiles kept one student: it becomes the first
  /// profile, with its login, its data and its own settings. Each step can
  /// run again, so an interrupted move finishes the next time.
  ///
  /// The old version was signed in when it kept a Librus student, so the
  /// secure storage is read only then, as the old version did.
  Future<void> _migrate() async {
    final preferences = await _preferences;
    final rawStudent = preferences.getString(_legacyProfileKey);
    if (rawStudent == null) return;
    final student = _decodeStudent(rawStudent);
    if (student?.provider != 'Librus Synergia') {
      await preferences.remove(_legacyProfileKey);
      return;
    }
    (LibrusLogin, String?)? legacy;
    var legacyRead = true;
    try {
      legacy = await _logins.readLegacy();
    } on Object {
      // Moved without the login for now; it joins the profile next time.
      legacyRead = false;
    }
    final login = legacy?.$1;
    final account = login == null ? '' : LibrusLogin.keyOf(login.email);
    final synergiaLogin = legacy?.$2;
    if (login != null) await _logins.write(account, login);
    var profiles = await _profileStore.read();
    var profile = profiles
        .where(
          (saved) =>
              saved.account == account && saved.synergiaLogin == synergiaLogin,
        )
        .firstOrNull;
    // A move the secure storage failed made the profile without its login.
    final orphan = profiles.where((saved) => saved.account.isEmpty).firstOrNull;
    if (profile == null && login != null && orphan != null) {
      profile = SchoolProfile(
        id: orphan.id,
        account: account,
        synergiaLogin: synergiaLogin,
        name: orphan.name,
        school: orphan.school,
        label: orphan.label,
        color: orphan.color,
        slot: orphan.slot,
        notify: orphan.notify,
        studentId: orphan.studentId,
      );
      profiles = [
        for (final saved in profiles) saved.id == orphan.id ? profile : saved,
      ];
      await _profileStore.write(profiles);
    }
    if (profile == null) {
      profile = SchoolProfile(
        id: SchoolProfile.idFor(account, synergiaLogin),
        account: account,
        synergiaLogin: synergiaLogin,
        name: student!.name,
        school: student.school,
        color: freeProfileColor(profiles, student.name),
        slot: freeProfileSlot(profiles),
        studentId: student.id,
      );
      profiles = [...profiles, profile];
      await _profileStore.write(profiles);
    }
    final id = profile.id;
    if (await _profileStore.readActive() == null) {
      await _profileStore.writeActive(id);
    }
    await _storeFor(id).adopt(_legacySnapshots);
    await _moveSetting(
      preferences,
      HomeworkDoneStore.key,
      HomeworkDoneStore.keyFor(id),
    );
    for (final key in _profileSettingKeys) {
      await _moveSetting(preferences, key, ProfileStore.key(key, id));
    }
    if (!legacyRead) return;
    if (legacy != null) await _logins.removeLegacy();
    await preferences.remove(_legacyProfileKey);
  }

  static StudentProfile? _decodeStudent(String? raw) {
    if (raw == null) return null;
    try {
      return StudentProfile.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return null;
    }
  }

  /// Moves the value of [from] to [to], unless [to] has one already.
  static Future<void> _moveSetting(
    SharedPreferences preferences,
    String from,
    String to,
  ) async {
    final value = preferences.get(from);
    if (value == null) return;
    if (preferences.get(to) == null) {
      switch (value) {
        case String text:
          await preferences.setString(to, text);
        case bool flag:
          await preferences.setBool(to, flag);
        case int number:
          await preferences.setInt(to, number);
        case double number:
          await preferences.setDouble(to, number);
        case List<Object?> list:
          await preferences.setStringList(
            to,
            list.whereType<String>().toList(),
          );
      }
    }
    await preferences.remove(from);
  }

  /// Reads the open profile and its last snapshot without the network, so
  /// the app opens at once; the launch sync refreshes it afterwards.
  Future<AppSnapshot> load() async {
    await _ensureReady();
    if (_demo != null) return _demo!.snapshot;
    final profile = activeProfile;
    return profile == null
        ? _emptySnapshot(_signedOutProfile)
        : loadProfileSnapshot(profile.id);
  }

  /// The last snapshot of the profile [profileId], without the network.
  Future<AppSnapshot> loadProfileSnapshot(String profileId) async {
    await _ensureReady();
    final profile = _profile(profileId);
    return await _storeFor(profile.id).read() ??
        _emptySnapshot(_studentOf(profile));
  }

  static StudentProfile _studentOf(SchoolProfile profile) => StudentProfile(
    id: profile.studentId ?? profile.id,
    name: profile.name,
    school: profile.school,
    provider: 'Librus Synergia',
  );

  /// Opens the profile [profileId] with its saved data.
  Future<AppSnapshot> switchProfile(String profileId) async {
    await _ensureReady();
    final profile = _profile(profileId);
    _activeId = profile.id;
    await _profileStore.writeActive(profile.id);
    return loadProfileSnapshot(profile.id);
  }

  /// Logs in to a Librus account and lists its students, those the phone
  /// has profiles for selected.
  Future<LibrusSignIn> signIn({
    required String username,
    required String password,
  }) async {
    if (_demo != null) {
      throw StateError('Exit demo mode before connecting an account.');
    }
    await _ensureReady();
    if (_profiles.isEmpty) {
      // Logins an earlier install left in the keychain, which outlives the
      // app on iPhone, are of no use to anyone now.
      await _logins.clear();
      await _logins.removeLegacy();
    }
    final client =
        _sharedClient ??
        _clientFactory?.call(null) ??
        LibrusClient(logins: _logins, referenceCache: _references);
    final found = await client.signIn(username: username, password: password);
    return LibrusSignIn(
      account: found.account,
      students: [
        for (final student in found.students)
          student.copyWith(selected: _hasProfile(found.account, student.login)),
      ],
    );
  }

  bool _hasProfile(String account, String login) => _profiles.any(
    (profile) => profile.account == account && profile.synergiaLogin == login,
  );

  /// The students in the phone's Librus logins, those with a profile
  /// selected. A login that cannot be reached leaves out its students.
  Future<List<LinkedSynergiaAccount>> availableStudents() async {
    if (_demo != null) return const [];
    await _ensureReady();
    final students = <LinkedSynergiaAccount>[];
    Object? failure;
    final accounts = <String>{};
    for (final profile in _profiles) {
      if (profile.account.isEmpty || !accounts.add(profile.account)) continue;
      try {
        for (final student in await _clientFor(
          profile,
        ).fetchSynergiaAccounts()) {
          students.add(
            student.copyWith(
              selected: _hasProfile(profile.account, student.login),
            ),
          );
        }
      } on Object catch (error) {
        failure ??= error;
      }
    }
    if (students.isEmpty && failure != null) throw failure;
    return students;
  }

  /// Makes profiles for [students]; those the phone has already are left.
  /// The new profiles come back in the order given, without data yet.
  Future<List<SchoolProfile>> addProfiles(
    List<LinkedSynergiaAccount> students,
  ) async {
    if (_demo != null) {
      throw StateError('Exit demo mode before connecting an account.');
    }
    await _ensureReady();
    final profiles = [..._profiles];
    final added = <SchoolProfile>[];
    for (final student in students) {
      if (profiles.length >= SchoolProfile.maxProfiles) break;
      if (profiles.any(
        (profile) =>
            profile.account == student.account &&
            profile.synergiaLogin == student.login,
      )) {
        continue;
      }
      final profile = SchoolProfile(
        id: SchoolProfile.idFor(student.account, student.login),
        account: student.account,
        synergiaLogin: student.login,
        name: student.name,
        color: freeProfileColor(profiles, student.name),
        slot: freeProfileSlot(profiles),
        parent: student.parent,
      );
      profiles.add(profile);
      added.add(profile);
    }
    _profiles = List.unmodifiable(profiles);
    await _profileStore.write(_profiles);
    if (activeProfile == null && added.isNotEmpty) {
      _activeId = added.first.id;
      await _profileStore.writeActive(_activeId);
    }
    return added;
  }

  /// Gives the profile [profileId] the user's own name; empty brings back
  /// the student's.
  Future<void> renameProfile(String profileId, String? label) {
    final own = label?.trim() ?? '';
    return _changeProfile(
      profileId,
      (saved) => saved.copyWith(label: () => own.isEmpty ? null : own),
    );
  }

  Future<void> setProfileColor(String profileId, int color) => _changeProfile(
    profileId,
    (saved) => saved.copyWith(color: color % profileColorCount),
  );

  /// Whether the profile's news and reminders come as notifications.
  Future<void> setProfileNotify(String profileId, bool notify) =>
      _changeProfile(profileId, (saved) => saved.copyWith(notify: notify));

  /// Changes one profile as it is saved now. The background check may have
  /// changed the profiles meanwhile, and none of that is lost.
  Future<void> _changeProfile(
    String profileId,
    SchoolProfile Function(SchoolProfile saved) change,
  ) async {
    await _ensureReady();
    final saved = [...await _profileStore.read(reload: true)];
    final index = saved.indexWhere((profile) => profile.id == profileId);
    if (index < 0) return;
    final changed = change(saved[index]);
    if (changed != saved[index]) {
      saved[index] = changed;
      await _profileStore.write(saved);
    }
    _profiles = List.unmodifiable(saved);
  }

  /// Forgets the login [account] when no profile came from it, as when the
  /// user signed in and then added none of its students.
  Future<void> discardLogin(String account) async {
    await _ensureReady();
    if (_profiles.any((profile) => profile.account == account)) return;
    await _logins.remove(account);
  }

  /// Removes the profile [profileId] with its data and settings; its login
  /// goes when no profile is left in it. Returns the open profile's data,
  /// or none when no profile is left.
  Future<AppSnapshot> removeProfile(String profileId) async {
    await _ensureReady();
    final profile = _profile(profileId);
    await _forget(profile);
    final rest = [
      for (final other in _profiles)
        if (other.id != profile.id) other,
    ];
    if (profile.account.isNotEmpty &&
        !rest.any((other) => other.account == profile.account)) {
      await _logins.remove(profile.account);
    }
    _profiles = List.unmodifiable(rest);
    await _profileStore.write(_profiles);
    if (_activeId == profile.id) {
      _activeId = rest.isEmpty ? null : rest.first.id;
      await _profileStore.writeActive(_activeId);
    }
    return load();
  }

  Future<void> _forget(SchoolProfile profile) async {
    try {
      await _clientFor(profile).forget();
    } on Object {
      // Its lists are fetched again if it ever comes back.
    }
    _clients.remove(profile.id);
    await _storeFor(profile.id).clear();
    _stores.remove(profile.id);
    final preferences = await _preferences;
    await preferences.remove(HomeworkDoneStore.keyFor(profile.id));
    for (final key in _profileSettingKeys) {
      await preferences.remove(ProfileStore.key(key, profile.id));
    }
    await _profileStore.setNews(profile.id, false);
  }

  /// Signs in and opens the first student of the login: the student's own
  /// account when there is one.
  Future<AppSnapshot> loginLibrus({
    required String username,
    required String password,
  }) async {
    final found = await signIn(username: username, password: password);
    if (found.students.isEmpty) {
      throw const LibrusException(LibrusErrorCode.noSynergiaAccount);
    }
    final student = found.students.firstWhere(
      (student) => !student.parent,
      orElse: () => found.students.first,
    );
    final id = SchoolProfile.idFor(found.account, student.login);
    if (!_hasProfile(found.account, student.login)) {
      await addProfiles([student]);
    }
    await switchProfile(id);
    return syncProfile(id);
  }

  Future<AppSnapshot> sync(AppSnapshot current) async {
    if (_demo != null) {
      return _demo!.snapshot = current.copyWith(lastSync: DateTime.now());
    }
    if (current.profile.provider != 'Librus Synergia') {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      return current.copyWith(lastSync: DateTime.now());
    }
    await _ensureReady();
    final profile = activeProfile;
    if (profile == null) {
      throw const LibrusException(LibrusErrorCode.sessionExpired);
    }
    return _sync(profile, current);
  }

  /// Syncs the profile [profileId], open or not, from its saved data.
  Future<AppSnapshot> syncProfile(String profileId) async {
    await _ensureReady();
    final profile = _profile(profileId);
    return _sync(profile, await _storeFor(profile.id).read());
  }

  Future<AppSnapshot> _sync(SchoolProfile profile, AppSnapshot? current) async {
    final client = _clientFor(profile);
    final snapshot = await client.restoreAndFetch();
    if (snapshot == null) {
      throw const LibrusException(LibrusErrorCode.sessionExpired);
    }
    final withMessages =
        current != null &&
            snapshot.messagesError != null &&
            snapshot.profile.id == current.profile.id
        ? snapshot.copyWith(messages: current.messages)
        : snapshot;
    final result = _keepSent(
      _keepLaterWeeks(withMessages, current, DateTime.now()),
      current,
    );
    await _storeFor(profile.id).write(result);
    await _remember(profile, result, client);
    await _replaceStale(profile.id, result.profile.id);
    return result;
  }

  /// A profile moved from before profiles without its login, as when the
  /// phone's backup brought back the data but not the keychain, cannot sync.
  /// Once the user adds the student again, the new profile takes its place
  /// and its settings.
  Future<void> _replaceStale(String profileId, String studentId) async {
    final stale = [
      for (final saved in _profiles)
        if (saved.id != profileId &&
            saved.account.isEmpty &&
            saved.studentId == studentId)
          saved,
    ];
    if (stale.isEmpty) return;
    final preferences = await _preferences;
    for (final old in stale) {
      await _moveSetting(
        preferences,
        HomeworkDoneStore.keyFor(old.id),
        HomeworkDoneStore.keyFor(profileId),
      );
      for (final key in _profileSettingKeys) {
        await _moveSetting(
          preferences,
          ProfileStore.key(key, old.id),
          ProfileStore.key(key, profileId),
        );
      }
      await _forget(old);
    }
    final ids = {for (final old in stale) old.id};
    _profiles = List.unmodifiable([
      for (final saved in _profiles)
        if (!ids.contains(saved.id)) saved,
    ]);
    await _profileStore.write(_profiles);
    if (ids.contains(_activeId)) {
      _activeId = profileId;
      await _profileStore.writeActive(profileId);
    }
  }

  /// Fills in what the profile learns from its first syncs: its school, its
  /// student's id, and the student chosen for a profile from before
  /// profiles.
  Future<void> _remember(
    SchoolProfile profile,
    AppSnapshot snapshot,
    LibrusClient client,
  ) async {
    final fetched = snapshot.profile;
    if (fetched.provider != 'Librus Synergia') return;
    SchoolProfile learn(SchoolProfile saved) => saved.copyWith(
      name: saved.name.isEmpty ? fetched.name : null,
      school: fetched.school.isEmpty ? null : fetched.school,
      studentId: fetched.id,
      synergiaLogin: saved.synergiaLogin ?? client.synergiaLogin,
    );
    final known = _profiles
        .where((saved) => saved.id == profile.id)
        .firstOrNull;
    // Saving reads the profiles again, which only a change is worth.
    if (known == null || learn(known) == known) return;
    await _changeProfile(profile.id, learn);
  }

  /// A sync does not fetch the Sent folder, so the one loaded earlier stays.
  AppSnapshot _keepSent(AppSnapshot fetched, AppSnapshot? previous) =>
      previous == null ||
          previous.profile.id != fetched.profile.id ||
          previous.sentMessages.isEmpty
      ? fetched
      : fetched.copyWith(sentMessages: previous.sentMessages);

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
    final weekStart = librusSyncWeekStart(now);
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final later = previous.lessons.where(
      (lesson) => !lesson.start.isBefore(weekEnd),
    );
    if (later.isEmpty) return fetched;
    return fetched.copyWith(
      lessons: [...fetched.lessons, ...later]
        ..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  /// A background sync shortly after the app synced finds nothing new.
  static const backgroundPause = Duration(minutes: 20);

  /// The background check of the open profile. [parts] are what
  /// notifications are on for; the rest is kept from the saved snapshot
  /// instead of being downloaded.
  Future<AppSnapshot?> fetchBackgroundSnapshot({Set<LibrusPart>? parts}) async {
    await _ensureReady();
    final profile = activeProfile;
    return profile == null ? null : _backgroundSnapshot(profile, parts);
  }

  /// The background check of every profile with notifications on. A profile
  /// that cannot be fetched is left out.
  Future<List<(SchoolProfile, AppSnapshot)>> fetchBackgroundSnapshots({
    Set<LibrusPart>? parts,
  }) async {
    await _ensureReady();
    final results = <(SchoolProfile, AppSnapshot)>[];
    for (final profile in _profiles) {
      if (!profile.notify) continue;
      try {
        final snapshot = await _backgroundSnapshot(profile, parts);
        if (snapshot != null) results.add((profile, snapshot));
      } on Object {
        // The next check tries again.
      }
    }
    return results;
  }

  /// The saved data of every profile with notifications on, for the test
  /// reminders.
  Future<List<(SchoolProfile, AppSnapshot)>> notifyingSnapshots() async {
    await _ensureReady();
    return [
      for (final profile in _profiles)
        if (profile.notify) (profile, await loadProfileSnapshot(profile.id)),
    ];
  }

  Future<AppSnapshot?> _backgroundSnapshot(
    SchoolProfile profile,
    Set<LibrusPart>? parts,
  ) async {
    if (_demo != null) return null;
    if (!await loadAutoSyncOnOpen()) return null;
    if (parts != null && parts.isEmpty) return null;
    final store = _storeFor(profile.id);
    final previous = await store.read();
    if (previous != null) {
      final sinceSync = DateTime.now().difference(previous.lastSync);
      if (!sinceSync.isNegative && sinceSync < backgroundPause) return null;
    }
    // Without a saved snapshot there is nothing to keep, so all of it comes.
    final wanted = previous == null ? null : parts;
    final client = _clientFor(profile);
    final fetched = await client.restoreAndFetch(parts: wanted);
    if (fetched == null) return null;
    final merged = previous == null || wanted == null
        ? fetched
        : _keepUnfetchedParts(fetched, previous, wanted);
    final preserved =
        merged.messagesError != null &&
            previous != null &&
            previous.profile.id == merged.profile.id
        ? merged.copyWith(messages: previous.messages)
        : merged;
    // The app may have removed the profile while it was fetched.
    final stillThere = await _profileStore.read(reload: true);
    if (!stillThere.any((saved) => saved.id == profile.id)) return null;
    // Kept lessons already include the later weeks.
    final live = _keepSent(
      wanted == null || wanted.contains(LibrusPart.timetable)
          ? _keepLaterWeeks(preserved, previous, DateTime.now())
          : preserved,
      previous,
    );
    await store.write(live);
    await _remember(profile, live, client);
    return live;
  }

  AppSnapshot _keepUnfetchedParts(
    AppSnapshot fetched,
    AppSnapshot previous,
    Set<LibrusPart> parts,
  ) {
    T pick<T>(LibrusPart part, T current, T kept) =>
        parts.contains(part) ? current : kept;
    final messages = parts.contains(LibrusPart.messages);
    return AppSnapshot(
      profile: fetched.profile,
      lessons: pick(LibrusPart.timetable, fetched.lessons, previous.lessons),
      grades: pick(LibrusPart.grades, fetched.grades, previous.grades),
      // Events and homework share one list and are fetched together.
      events:
          parts.contains(LibrusPart.events) ||
              parts.contains(LibrusPart.homework)
          ? fetched.events
          : previous.events,
      messages: messages ? fetched.messages : previous.messages,
      messagesError: messages ? fetched.messagesError : previous.messagesError,
      attendance: pick(
        LibrusPart.attendance,
        fetched.attendance,
        previous.attendance,
      ),
      announcements: pick(
        LibrusPart.announcements,
        fetched.announcements,
        previous.announcements,
      ),
      notices: pick(LibrusPart.notices, fetched.notices, previous.notices),
      // Teachers' absences come with the timetable.
      freeDays: pick(LibrusPart.timetable, fetched.freeDays, previous.freeDays),
      lastSync: fetched.lastSync,
    );
  }

  Future<bool> loadAutoSyncOnOpen() async =>
      (await _preferences).getBool(_autoSyncKey) ?? true;

  Future<void> saveAutoSyncOnOpen(bool enabled) async =>
      (await _preferences).setBool(_autoSyncKey, enabled);

  /// Signs out of every profile: their data, settings and logins go.
  Future<AppSnapshot> logout() async {
    if (_demo != null) {
      _demo = null;
      return _emptySnapshot(_signedOutProfile);
    }
    await _ensureReady();
    for (final profile in _profiles) {
      await _forget(profile);
    }
    _profiles = const [];
    _activeId = null;
    await _profileStore.write(const []);
    await _profileStore.writeActive(null);
    await _logins.clear();
    await _references.clear();
    await clearCredential();
    final preferences = await _preferences;
    await preferences.remove(_legacyProfileKey);
    await preferences.remove(HomeworkDoneStore.key);
    await _legacySnapshots.clear();
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
    await _ensureReady();
    final preferences = await _preferences;
    const defaults = GradeAverageSettings();
    double modifier(String key, double fallback) {
      final saved = preferences.getDouble(key);
      return GradeAverageSettings.modifierOptions.contains(saved)
          ? saved!
          : fallback;
    }

    return GradeAverageSettings(
      plus: modifier(_ownKey(_gradePlusKey), defaults.plus),
      minus: modifier(_ownKey(_gradeMinusKey), defaults.minus),
      weighted:
          preferences.getBool(_ownKey(_gradeWeightedKey)) ?? defaults.weighted,
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

  Future<Map<String, DateTime>> loadDoneHomework() async {
    if (_demo != null) return _demo!.doneHomework;
    await _ensureReady();
    return HomeworkDoneStore.read(await _preferences, key: _homeworkKey);
  }

  Future<void> saveDoneHomework(Map<String, DateTime> marks) async {
    if (_demo != null) {
      _demo!.doneHomework = Map.of(marks);
      return;
    }
    await _ensureReady();
    await HomeworkDoneStore.write(await _preferences, marks, key: _homeworkKey);
  }

  /// The open profile's homework marks; signed out, the base key.
  String get _homeworkKey {
    final id = _activeId;
    return id == null ? HomeworkDoneStore.key : HomeworkDoneStore.keyFor(id);
  }

  Future<TodayLayout> loadTodayLayout() async {
    final saved = (await _preferences).getStringList(_todayLayoutKey);
    return saved == null ? TodayLayout.defaults : TodayLayout.decode(saved);
  }

  Future<void> saveTodayLayout(TodayLayout layout) async =>
      (await _preferences).setStringList(_todayLayoutKey, layout.encode());

  Future<Map<String, String>> loadSubjectShortNames() async {
    await _ensureReady();
    final raw = (await _preferences).getString(_ownKey(_subjectShortNamesKey));
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

  Future<void> saveSubjectShortNames(Map<String, String> names) async {
    await _ensureReady();
    await (await _preferences).setString(
      _ownKey(_subjectShortNamesKey),
      jsonEncode(names),
    );
  }

  Future<void> saveGradeAverageSettings(GradeAverageSettings settings) async {
    await _ensureReady();
    final preferences = await _preferences;
    await preferences.setDouble(_ownKey(_gradePlusKey), settings.plus);
    await preferences.setDouble(_ownKey(_gradeMinusKey), settings.minus);
    await preferences.setBool(_ownKey(_gradeWeightedKey), settings.weighted);
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
    if (_demo != null) return null;
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

  /// Forgets the app settings, every profile's grade average settings
  /// among them; the profiles, their data and subject short names are kept.
  Future<void> resetPreferences() async {
    await _ensureReady();
    final preferences = await _preferences;
    for (final key in [
      _localeKey,
      _attendanceChartStyleKey,
      _designKey,
      _colorModeKey,
      for (final base in const [
        _gradePlusKey,
        _gradeMinusKey,
        _gradeWeightedKey,
      ]) ...[
        base,
        for (final profile in _profiles) ProfileStore.key(base, profile.id),
      ],
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

  Future<List<MessageRecipient>> fetchMessageRecipients() async {
    if (_demo != null) return DemoData.recipients;
    await _ensureReady();
    return _clientFor(_requireActive()).fetchMessageRecipients();
  }

  /// Sends a message and puts it at the top of the saved Sent folder.
  Future<SchoolMessage> sendMessage({
    required List<MessageRecipient> recipients,
    required String subject,
    required String body,
  }) async {
    if (_demo != null) {
      return _demo!.sendMessage(
        recipients: recipients,
        subject: subject,
        body: body,
      );
    }
    await _ensureReady();
    final profile = _requireActive();
    final names = {
      for (final recipient in recipients) recipient.id: recipient.name,
    };
    final id = await _clientFor(profile).sendMessage(
      recipientIds: names.keys.toList(),
      subject: subject,
      body: body,
    );
    final message = SchoolMessage(
      id: id,
      sender: '',
      subject: subject.trim(),
      preview: body.trim(),
      receivedAt: DateTime.now(),
      sent: true,
      recipients: names.values.toList(growable: false),
      recipientRead: false,
    );
    await _updateCached(profile.id, (cached) => cached.withSent(message));
    return message;
  }

  Future<List<SchoolMessage>> fetchSentMessages() async {
    if (_demo != null) return _demo!.snapshot.sentMessages;
    await _ensureReady();
    final profile = _requireActive();
    final sent = await _clientFor(profile).fetchSentMessages();
    await _updateCached(
      profile.id,
      (cached) => cached.copyWith(sentMessages: sent),
    );
    return sent;
  }

  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage message,
  ) async {
    if (_demo != null) return _demo!.openMessage(message);
    await _ensureReady();
    final profile = _requireActive();
    final content = await _clientFor(profile).fetchMessageContent(message);
    await _updateCached(
      profile.id,
      (cached) => cached.withOpened(message, content),
    );
    return content;
  }

  /// Changes the saved snapshot of the profile [profileId], if the phone
  /// still has it: the user may have switched profiles meanwhile, and the
  /// change still belongs to that profile's data.
  Future<void> _updateCached(
    String profileId,
    AppSnapshot Function(AppSnapshot cached) change,
  ) async {
    if (!_profiles.any((profile) => profile.id == profileId)) return;
    final store = _storeFor(profileId);
    final cached = await store.read();
    if (cached != null) await store.write(change(cached));
  }

  Future<Uri> fetchMessageAttachmentUrl({
    required String messageId,
    required String attachmentId,
  }) async {
    if (_demo != null) {
      throw UnsupportedError('Demo messages have no attachments.');
    }
    await _ensureReady();
    return _clientFor(_requireActive()).fetchMessageAttachmentUrl(
      messageId: messageId,
      attachmentId: attachmentId,
    );
  }

  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async {
    final demo = _demo?.timetableWeek(day);
    if (demo != null) return demo;
    await _ensureReady();
    return _clientFor(_requireActive()).fetchTimetableWeek(day);
  }

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
