import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import '../app_build_info.dart';
import '../background_notifications.dart';
import '../data/app_repository.dart';
import '../debug/diagnostics.dart';
import '../domain/librus_error.dart';
import '../domain/models.dart';
import '../domain/profiles.dart';
import '../domain/parent.dart';
import '../domain/sync_news.dart';
import '../domain/together.dart';
import '../domain/together.dart'
    as together_lib
    show togetherName, togetherSign;
import '../home_widget.dart';
import '../home_widget.dart' as home_widget show displaySubject;
import '../l10n/app_localizations.dart';
import '../school_notifications.dart';
import '../test_reminders.dart';

/// The parts of signing in to Librus, in the order they happen.
enum SignInStage {
  /// Librus checks the e-mail and the password.
  checking,

  /// The user picks the students to add.
  choosing,

  /// The first student's data loads.
  loading,
}

class AppController extends ChangeNotifier {
  AppController(
    this._repository, {
    this.updatesEnabled = true,
    this.notifications,
    this.backgroundScheduling,
    this.homeWidget,
  });

  final AppRepository _repository;
  final bool updatesEnabled;
  final SchoolNotificationService? notifications;
  final Future<void> Function(bool enabled)? backgroundScheduling;
  final HomeWidgetBridge? homeWidget;
  AppSnapshot? _snapshot;
  List<SchoolProfile> _profiles = const [];
  Set<String> _profileNews = const {};

  /// The profiles a sync runs for; '' stands for none, as in demo mode.
  final _syncingProfiles = <String>{};
  bool _signingIn = false;
  bool _onboardingDone = true;
  Duration? _intro;
  SignInStage? _signInStage;
  bool _markingMessagesRead = false;
  bool _loadingSentMessages = false;
  AppError? _sentMessagesError;
  DateTime? _sentMessagesLoadedAt;
  int _tabIndex = 0;
  AppError? _error;
  Locale? _locale;
  String? _latestVersion;
  bool _updateAvailable = false;
  AttendanceChartStyle _attendanceChartStyle = AttendanceChartStyle.ring;
  AppDesign _design = AppDesign.glass;
  AppColorMode _colorMode = AppColorMode.system;
  GradeAverageSettings _gradeAverage = const GradeAverageSettings();
  Map<String, String> _subjectShortNames = const {};
  TimetableView _timetableView = TimetableView.timeline;
  bool _mergeTimetableLessons = false;
  bool _showTimetableBreaks = false;
  MessageListStyle _messageListStyle = MessageListStyle.list;
  GradesView _gradesView = GradesView.compact;
  TodayLayout _todayLayout = TodayLayout.defaults;
  Map<String, DateTime> _doneHomework = const {};
  SyncNews? _syncNews;
  Timer? _homeWidgetDebounce;
  bool _homeWidgetWriting = false;
  bool _homeWidgetAgain = false;
  String? _widgetProfileId;
  SchoolNotificationSettings _notificationSettings =
      const SchoolNotificationSettings();
  bool _autoSyncOnOpen = true;

  /// Whether every profile in the view together is shown at once.
  bool _together = false;

  /// In the view together: the data of each profile in it, in their order.
  Map<String, AppSnapshot> _parts = const {};

  /// In the view together: the settings and marks of each profile in it.
  Map<String, GradeAverageSettings> _gradeAverages = const {};
  Map<String, Map<String, String>> _shortNamesOf = const {};
  Map<String, Map<String, DateTime>> _doneOf = const {};

  /// The profile of the last error in the view together, if it had one.
  String? _errorSource;

  AppSnapshot get snapshot => _snapshot!;
  bool get isParent => together
      ? togetherProfiles.isNotEmpty &&
            togetherProfiles.every(
              (profile) => profile.role == ProfileRole.parent,
            )
      : activeProfile?.role == ProfileRole.parent;
  bool canUseStudentToolsFor(String? source) {
    final profile = profileOf(source) ?? activeProfile;
    return profile?.role != ProfileRole.parent ||
        (profile?.parentPreferences.studentTools ?? false);
  }

  bool get canUseStudentTools =>
      !isParent || (activeProfile?.parentPreferences.studentTools ?? false);
  List<int> get bottomTabs => activeProfile?.bottomTabs ?? const [0, 1, 2, 5];
  Future<void> setProfileRole(String id, ProfileRole? role) async {
    await notifications?.cancelParentSchedules(profileOf(id));
    await _repository.setProfileRole(id, role);
    _profiles = _repository.profiles;
    if (notifications != null) {
      _notificationSettings = await notifications!.settingsForProfile(
        activeProfile,
      );
    }
    notifyListeners();
    await _updateReminders();
  }

  Future<void> setParentPreferences(
    String id,
    ParentPreferences preferences,
  ) async {
    await _repository.setParentPreferences(id, preferences);
    _profiles = _repository.profiles;
    await notifications?.cancelParentSchedules(profileOf(id));
    notifyListeners();
    await _updateReminders();
  }

  Future<void> setBottomTabs(String id, List<int> tabs) async {
    if (tabs.length != 4 ||
        tabs.toSet().length != 4 ||
        tabs.any((tab) => tab < 0 || tab >= 10)) {
      return;
    }
    await _repository.setProfileTabs(id, tabs);
    _profiles = _repository.profiles;
    notifyListeners();
  }

  Future<List<(SchoolProfile, AppSnapshot)>> parentOverview() async => [
    for (final profile in profiles)
      if (profile.role == ProfileRole.parent)
        (
          profile,
          _ownData(profile.id) ??
              await _repository.loadProfileSnapshot(profile.id),
        ),
  ];
  Future<AppSnapshot> absenceSnapshot(String id) =>
      _repository.loadProfileSnapshot(id);
  Future<List<AbsenceRequest>> absenceRequests(String id) =>
      _repository.absenceRequests(id);
  final _sendingAbsences = <String>{};
  Future<void> sendAbsenceRequest({
    required String profileId,
    required Set<String> recordIds,
    required MessageRecipient recipient,
    required String subject,
    required String body,
  }) async {
    final profile = profileOf(profileId);
    if (profile == null ||
        profile.role != ProfileRole.parent ||
        recordIds.isEmpty ||
        subject.trim().isEmpty ||
        body.trim().isEmpty) {
      throw ArgumentError('Invalid absence request');
    }
    if (!_sendingAbsences.add(profileId)) {
      throw StateError('Sending in progress');
    }
    final requestId = '$profileId-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final data = await _repository.loadProfileSnapshot(profileId);
      final allowed = unexcusedAbsences(data.attendance)
          .map((record) => record.id)
          .toSet();
      if (!allowed.containsAll(recordIds)) {
        throw StateError('Attendance changed; refresh the selection');
      }
      final recipients = await _repository.fetchMessageRecipients(
        profileId: profileId,
      );
      if (!recipients.any((item) => item.id == recipient.id) ||
          !profiles.any((item) => item.id == profileId)) {
        throw StateError('Recipient or profile no longer available');
      }
      final at = DateTime.now();
      AbsenceRequest entry(AbsenceRequestState state, String messageId) =>
          AbsenceRequest(
            id: requestId,
            profileId: profileId,
            messageId: messageId,
            at: at,
            subject: subject,
            body: body,
            recipient: recipient.name,
            recordIds: recordIds.toList(),
            state: state,
          );
      // Persist uncertainty before the request: interruption must not invite an automatic resend.
      await _repository.recordAbsenceRequest(
        entry(AbsenceRequestState.uncertain, ''),
      );
      final message = await _repository.sendMessage(
        recipients: [recipient],
        subject: subject,
        body: body,
        profileId: profileId,
      );
      await _repository.recordAbsenceRequest(
        entry(AbsenceRequestState.sent, message.id),
      );
      if (_together) {
        _changePart(profileId, (snapshot) => snapshot.withSent(message));
      } else if (activeProfile?.id == profileId) {
        _snapshot = snapshot.withSent(message);
      }
      notifyListeners();
    } finally {
      _sendingAbsences.remove(profileId);
    }
  }

  bool get isDemo => _snapshot?.profile.provider == 'Demo';

  /// The login screen's hidden gesture enters a disposable local session.
  void startDemo() {
    if (syncing ||
        _markingMessagesRead ||
        snapshot.profile.provider != 'Signed out') {
      return;
    }
    _snapshot = _repository.enterDemo();
    _profiles = _repository.profiles;
    _doneHomework = const {};
    _forgetSentMessages();
    _error = null;
    _tabIndex = 0;
    notifyListeners();
    _updateHomeWidget();
  }

  /// Whether the first setup has been gone through. Until then it is what
  /// the app shows, and nothing asks for the notification permission
  /// before the setup's own step explains it.
  bool get onboardingDone => _onboardingDone;

  bool get _signedIn =>
      isDemo || snapshot.profile.provider == 'Librus Synergia';

  /// Ends the setup and opens the app.
  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    notifyListeners();
    await _repository.saveOnboardingDone();
    await configureBackground();
  }

  /// Goes through the setup again, from the settings, opening on the logo
  /// animation as a first launch does.
  void restartOnboarding() {
    _onboardingDone = false;
    _intro = Duration.zero;
    notifyListeners();
  }

  /// Has the setup open on the startup animation, carried on [from] where the
  /// startup screen got to and played to the whole logo.
  void playIntro({Duration from = Duration.zero}) => _intro = from;

  /// The animation the setup is to open on, given once.
  Duration? takeIntro() {
    final intro = _intro;
    _intro = null;
    return intro;
  }

  /// Whether the open profile is syncing, or an account is being added.
  /// Another profile's sync goes on unseen.
  bool get syncing => _signingIn || _syncingProfiles.contains(_syncKey);

  String get _syncKey =>
      _together ? togetherId : _repository.activeProfile?.id ?? '';

  /// The profiles on the phone, in the order they were added.
  List<SchoolProfile> get profiles => _profiles;

  /// The open profile; null when signed out, in demo mode, or for data from
  /// a repository without profiles.
  SchoolProfile? get activeProfile => _repository.activeProfile;

  /// Whether the profile [profileId] has news the user has not seen.
  bool profileHasNews(String profileId) => _profileNews.contains(profileId);

  /// Whether a profile other than the open one has news.
  bool get otherProfilesHaveNews => _profileNews.any(
    (id) => _together ? !_isTogether(id) : id != activeProfile?.id,
  );

  /// Whether every profile in the view together is shown at once.
  bool get together => _together;

  /// The profiles in the view together, in their order.
  List<SchoolProfile> get togetherProfiles => [
    for (final profile in _profiles)
      if (profile.together) profile,
  ];

  /// Whether the view together can open: two profiles at least are in it.
  bool get canBeTogether => togetherProfiles.length >= 2;

  bool _isTogether(String profileId) =>
      togetherProfiles.any((profile) => profile.id == profileId);

  /// The profile an item of the view together comes from.
  SchoolProfile? profileOf(String? source) => source == null
      ? null
      : _profiles.where((profile) => profile.id == source).firstOrNull;

  /// How an item of the view together shows the profile [source] it comes
  /// from: by the profile's name on its colour, or by its school when
  /// another profile in the view has the same name, as one child at two
  /// schools does. Nothing outside the view together.
  ({String name, int color})? profileMark(String? source) {
    if (!_together) return null;
    final profile = profileOf(source);
    if (profile == null) return null;
    return (name: togetherName(profile), color: profile.color);
  }

  /// The name [profile] goes by beside the others in the view together:
  /// its own, or its school when another one in it has the same name.
  String togetherName(SchoolProfile profile) =>
      together_lib.togetherName(profile, togetherProfiles);

  /// What the initials of [profile] come from in the view together.
  String togetherSign(SchoolProfile profile) =>
      together_lib.togetherSign(profile, togetherProfiles);

  /// The profile the last error came from, in the view together.
  SchoolProfile? get errorProfile =>
      _together && _error != null ? profileOf(_errorSource) : null;

  /// The name and colour the open profile is shown with.
  ({String name, String school, int color}) get profileLook {
    final profile = activeProfile;
    if (profile != null) {
      return (
        name: profile.displayName,
        school: profile.school.isEmpty
            ? snapshot.profile.school
            : profile.school,
        color: profile.color,
      );
    }
    final student = snapshot.profile;
    return (
      name: student.name,
      school: student.school,
      color: freeProfileColor(const [], student.name),
    );
  }

  bool get markingMessagesRead => _markingMessagesRead;
  bool get loadingSentMessages => _loadingSentMessages;
  AppError? get sentMessagesError => _sentMessagesError;
  int get tabIndex => _tabIndex;
  AppError? get error => _error;
  Locale? get locale => _locale;
  String? get latestVersion => _latestVersion;
  bool get updateAvailable => _updateAvailable;
  AttendanceChartStyle get attendanceChartStyle => _attendanceChartStyle;
  AppDesign get design => _design;
  AppColorMode get colorMode => _colorMode;
  GradeAverageSettings get gradeAverage => _gradeAverage;

  /// The grade average settings of [source], the profile of an item; the
  /// open profile's for a single profile's items.
  GradeAverageSettings gradeAverageFor(String? source) =>
      (source == null ? null : _gradeAverages[source]) ?? _gradeAverage;

  /// The subjects' short names; in the view together, those of every
  /// profile in it, the first profile's where two differ.
  Map<String, String> get subjectShortNames => !_together
      ? _subjectShortNames
      : {for (final names in _shortNamesOf.values.toList().reversed) ...names};
  TimetableView get timetableView => _timetableView;
  bool get mergeTimetableLessons => _mergeTimetableLessons;
  bool get showTimetableBreaks => _showTimetableBreaks;
  MessageListStyle get messageListStyle => _messageListStyle;
  GradesView get gradesView => _gradesView;
  TodayLayout get todayLayout => _todayLayout;

  /// What the last sync brought, until it is seen or dismissed.
  SyncNews? get syncNews => _syncNews;

  void dismissSyncNews() {
    if (_syncNews == null) return;
    _syncNews = null;
    notifyListeners();
  }

  /// Whether the student marked [item] as done.
  bool isHomeworkDone(SchoolEvent item) {
    final source = item.source;
    if (source == null) return _doneHomework.containsKey(item.id);
    return _doneOf[source]?.containsKey(localId(item.id, source)) ?? false;
  }

  /// The name to show for [subject]: the student's short name if they set one.
  String displaySubject(String subject) =>
      home_widget.displaySubject(subject, subjectShortNames);
  SchoolNotificationSettings get notificationSettings => _notificationSettings;
  bool get autoSyncOnOpen => _autoSyncOnOpen;

  /// Loads settings and the saved snapshot. It never waits on the network;
  /// [startAutoSync] refreshes the data once the app is on screen.
  Future<void> bootstrap() async {
    await _loadPreferences();
    _snapshot = await _repository.load();
    _profiles = _repository.profiles;
    if (await _repository.loadTogether() && canBeTogether) {
      _together = true;
      await _loadParts(open: _snapshot);
      await _loadProfileSettings();
    }
    _profileNews = await _repository.loadProfileNews();
    _widgetProfileId = await _repository.loadWidgetProfile();
    _onboardingDone = await _repository.loadOnboardingDone();
    if (!_onboardingDone && _signedIn) {
      // In use before the setup existed: it is not shown to them.
      _onboardingDone = true;
      await _repository.saveOnboardingDone();
    }
    await _recordNotifications();
    _updateHomeWidget();
    if (updatesEnabled) unawaited(checkForUpdate());
  }

  /// The sync when the app opens, if automatic sync is on and a Librus
  /// account is signed in. The saved data stays on screen meanwhile.
  Future<void> startAutoSync() async {
    if (!_autoSyncOnOpen) return;
    if (snapshot.profile.provider != 'Librus Synergia') return;
    await sync();
  }

  Future<void> _loadPreferences() async {
    final languageCode = await _repository.loadLocale();
    _locale = languageCode == null ? null : Locale(languageCode);
    _attendanceChartStyle = await _repository.loadAttendanceChartStyle();
    _design = await _repository.loadDesign();
    _colorMode = await _repository.loadColorMode();
    await _loadProfileSettings();
    _timetableView = await _repository.loadTimetableView();
    _mergeTimetableLessons = await _repository.loadMergeTimetableLessons();
    _showTimetableBreaks = await _repository.loadShowTimetableBreaks();
    _messageListStyle = await _repository.loadMessageListStyle();
    _gradesView = await _repository.loadGradesView();
    _todayLayout = await _repository.loadTodayLayout();
    _autoSyncOnOpen = await _repository.loadAutoSyncOnOpen();
    if (notifications != null) {
      _notificationSettings = await notifications!.settingsForProfile(
        activeProfile,
      );
    }
  }

  /// The settings each profile keeps for itself.
  Future<void> _loadProfileSettings() async {
    if (notifications != null) {
      _notificationSettings = await notifications!.settingsForProfile(
        activeProfile,
      );
    }
    _gradeAverage = await _repository.loadGradeAverageSettings();
    _subjectShortNames = await _repository.loadSubjectShortNames();
    _doneHomework = await _repository.loadDoneHomework();
    final included = _together ? togetherProfiles : const <SchoolProfile>[];
    _gradeAverages = {
      for (final profile in included)
        profile.id: await _repository.loadGradeAverageSettings(
          profileId: profile.id,
        ),
    };
    _shortNamesOf = {
      for (final profile in included)
        profile.id: await _repository.loadSubjectShortNamesOf(profile.id),
    };
    _doneOf = {
      for (final profile in included)
        profile.id: await _repository.loadDoneHomework(profileId: profile.id),
    };
    // The settings screen shows the first profile's in the view together.
    if (included.isNotEmpty) _gradeAverage = _gradeAverages[included.first.id]!;
  }

  /// Puts every setting back to its default. The account, the school data,
  /// subject short names and home screen widgets stay as they are.
  Future<void> resetSettings() async {
    await _repository.resetPreferences();
    await notifications?.saveSettings(const SchoolNotificationSettings());
    await _loadPreferences();
    notifyListeners();
    _updateHomeWidget();
    await configureBackground();
    await _updateReminders();
  }

  Future<void> configureBackground() async {
    try {
      await backgroundScheduling?.call(
        _autoSyncOnOpen &&
            _notificationSettings.needsBackgroundCheck &&
            snapshot.profile.provider == 'Librus Synergia' &&
            // Nothing to check when every profile has notifications off.
            (_profiles.isEmpty || _profiles.any((profile) => profile.notify)),
      );
    } on Object {
      // The manual sync button remains usable if scheduling is unavailable.
    }
  }

  /// The profile the widgets show, unless an Android widget has its own:
  /// the one chosen in the settings, or the first.
  String? get widgetProfileId {
    final chosen = _widgetProfileId;
    // Every profile together, while two at least are in it.
    if (chosen == togetherId && canBeTogether) return chosen;
    if (_profiles.any((profile) => profile.id == chosen)) return chosen;
    return _profiles.isEmpty ? null : _profiles.first.id;
  }

  Future<void> setWidgetProfile(String profileId) async {
    _widgetProfileId = profileId;
    notifyListeners();
    _updateHomeWidget();
    await _repository.saveWidgetProfile(profileId);
  }

  /// Writes the widgets' lessons. A change while a write is running is
  /// written right after it, from the state of then, so the last state
  /// always lands last and a burst of changes writes once more, not each.
  void _updateHomeWidget() {
    if (homeWidget == null) return;
    if (_homeWidgetWriting) {
      _homeWidgetAgain = true;
      return;
    }
    unawaited(_writeHomeWidgets());
  }

  Future<void> _writeHomeWidgets() async {
    _homeWidgetWriting = true;
    try {
      do {
        _homeWidgetAgain = false;
        try {
          await _writeHomeWidget();
        } on Object {
          // A widget that cannot be refreshed must not disturb the app.
        }
      } while (_homeWidgetAgain);
    } finally {
      _homeWidgetWriting = false;
    }
  }

  Future<void> _writeHomeWidget() async {
    final widget = homeWidget!;
    if (!isDemo && snapshot.profile.provider != 'Librus Synergia') {
      await widget.clear();
      return;
    }
    final l10n = AppLocalizations(
      _locale ?? PlatformDispatcher.instance.locale,
    );
    final now = DateTime.now();
    final open = activeProfile;
    if (open == null || _profiles.length < 2) {
      await widget.update(
        buildHomeWidgetPayload(
          snapshot,
          now,
          l10n,
          shortNames: _subjectShortNames,
        ),
      );
      return;
    }
    Future<String> lessonsOf(SchoolProfile profile) async =>
        buildHomeWidgetPayload(
          _ownData(profile.id) ??
              await _repository.loadProfileSnapshot(profile.id),
          now,
          l10n,
          shortNames: profile.id == open.id && !_together
              ? _subjectShortNames
              : _shortNamesOf[profile.id] ??
                    await _repository.loadSubjectShortNamesOf(profile.id),
        );
    // The lessons of every profile together, for widgets set to show them.
    Future<String>? together;
    Future<String> togetherLessons() => together ??= () async {
      final included = togetherProfiles;
      return buildHomeWidgetPayload(
        mergeSnapshots([
          for (final profile in included)
            (
              profile,
              _ownData(profile.id) ??
                  await _repository.loadProfileSnapshot(profile.id),
            ),
        ]),
        now,
        l10n,
        shortNames: {
          // The first profile's where two differ, as in the app.
          for (final profile in included.reversed)
            ...(_shortNamesOf[profile.id] ??
                await _repository.loadSubjectShortNamesOf(profile.id)),
        },
      );
    }();
    final shown = _profiles.firstWhere(
      (profile) => profile.id == widgetProfileId,
      orElse: () => open,
    );
    await widget.update(
      widgetProfileId == togetherId
          ? await togetherLessons()
          : await lessonsOf(shown),
      profiles: widget.configurableInApp
          ? {
              for (final profile in _profiles)
                profile.id: await lessonsOf(profile),
              if (canBeTogether) togetherId: await togetherLessons(),
            }
          : const {},
    );
  }

  /// The data of the profile [profileId] the app holds: the open profile's,
  /// or in the view together, each of its profiles'.
  AppSnapshot? _ownData(String profileId) => _together
      ? _parts[profileId]
      : profileId == activeProfile?.id
      ? snapshot
      : null;

  /// Reads the data of every profile in the view together. The open one's
  /// is [open] when given, as it holds timetable weeks loaded since.
  Future<void> _loadParts({AppSnapshot? open}) async {
    final openId = activeProfile?.id;
    _parts = {
      for (final profile in togetherProfiles)
        profile.id: open != null && profile.id == openId
            ? open
            : await _repository.loadProfileSnapshot(profile.id),
    };
    _mergeParts();
  }

  /// Shows the parts as one.
  void _mergeParts() {
    _snapshot = mergeSnapshots([
      for (final profile in togetherProfiles)
        if (_parts[profile.id] case final data?) (profile, data),
    ]);
  }

  /// Changes the data of the profile [profileId] in the view together.
  void _changePart(String profileId, AppSnapshot Function(AppSnapshot) change) {
    final part = _parts[profileId];
    if (!_together || part == null) return;
    _parts = {..._parts, profileId: change(part)};
    _mergeParts();
  }

  /// Opens the view of every profile in it at once, with their saved data.
  Future<void> openTogether() async {
    if (_together || !canBeTogether) return;
    _together = true;
    await _loadParts(open: snapshot);
    await _loadProfileSettings();
    _syncNews = null;
    _forgetSentMessages();
    _error = null;
    for (final profile in togetherProfiles) {
      _seeNews(profile.id);
    }
    notifyListeners();
    _updateHomeWidget();
    if (!isDemo) await _repository.saveTogether(true);
    final age = DateTime.now().difference(snapshot.lastSync);
    if (_autoSyncOnOpen && age >= switchSyncAfter) unawaited(sync());
  }

  /// Leaves the view together, for one profile's.
  void _leaveTogether() {
    if (!_together) return;
    _together = false;
    _parts = const {};
    _errorSource = null;
    if (!isDemo) unawaited(_repository.saveTogether(false));
  }

  Future<void> setSubjectShortName(String subject, String shortName) async {
    if (_together) return _setSubjectShortNameTogether(subject, shortName);
    final names = Map<String, String>.of(_subjectShortNames);
    final trimmed = shortName.trim();
    if (trimmed.isEmpty) {
      names.remove(subject);
    } else {
      names[subject] = trimmed;
    }
    _subjectShortNames = Map.unmodifiable(names);
    notifyListeners();
    // Typing a name changes it with every key; the widget follows once the
    // typing pauses.
    _homeWidgetDebounce?.cancel();
    _homeWidgetDebounce = Timer(
      const Duration(milliseconds: 600),
      _updateHomeWidget,
    );
    await _repository.saveSubjectShortNames(names);
  }

  /// In the view together a short name is every profile's in it.
  Future<void> _setSubjectShortNameTogether(
    String subject,
    String shortName,
  ) async {
    final trimmed = shortName.trim();
    final changed = <String, Map<String, String>>{};
    for (final MapEntry(key: id, value: saved) in _shortNamesOf.entries) {
      final names = Map<String, String>.of(saved);
      if (trimmed.isEmpty) {
        names.remove(subject);
      } else {
        names[subject] = trimmed;
      }
      changed[id] = Map.unmodifiable(names);
    }
    _shortNamesOf = changed;
    if (changed[activeProfile?.id] case final open?) _subjectShortNames = open;
    notifyListeners();
    _homeWidgetDebounce?.cancel();
    _homeWidgetDebounce = Timer(
      const Duration(milliseconds: 600),
      _updateHomeWidget,
    );
    for (final MapEntry(key: id, value: names) in changed.entries) {
      await _repository.saveSubjectShortNames(names, profileId: id);
    }
  }

  @override
  void dispose() {
    _homeWidgetDebounce?.cancel();
    super.dispose();
  }

  Future<void> _recordNotifications() async {
    if (_together) {
      for (final MapEntry(key: id, value: data) in _parts.entries) {
        await _notify(data, profileOf(id));
      }
    } else {
      await _notify(snapshot, activeProfile);
    }
    // Scheduling takes a round trip per reminder, so it never holds the app
    // opening or a sync.
    unawaited(_updateReminders());
  }

  /// Notifies of what is new in [data] of [profile]; a profile with
  /// notifications off only marks it as seen.
  Future<void> _notify(AppSnapshot data, SchoolProfile? profile) async {
    try {
      await notifications?.processSnapshot(
        data,
        profile: profile,
        name: _notificationName(profile),
        quiet: profile != null && !profile.notify,
      );
    } on Object {
      // Notifications cannot turn a successful Librus sync into an error.
    }
  }

  /// With more than one profile, notifications start with its name.
  String? _notificationName(SchoolProfile? profile) =>
      profile != null &&
          (_profiles.length > 1 || profile.role == ProfileRole.parent)
      ? profile.notificationName
      : null;

  /// Opens what a tapped notification is about: its profile, then its page.
  Future<void> openNotification(NotificationTarget target) async {
    final profileId = target.profileId;
    // In the view together, a profile in it is already on screen.
    if (profileId != null &&
        profileId != activeProfile?.id &&
        !(_together && _isTogether(profileId)) &&
        _profiles.any((profile) => profile.id == profileId)) {
      await switchProfile(profileId);
    }
    selectTab(target.category.tabIndex);
  }

  Future<bool> requestNotificationPermissionIfEnabled() async {
    // During the first setup its notifications step asks, saying why.
    if (!_onboardingDone) return true;
    return askNotificationPermission();
  }

  /// Asks the system for the notification permission when notifications
  /// are on: the setup's notifications step, and every change that turns
  /// one on. True when allowed, or when nothing needs it.
  Future<bool> askNotificationPermission() async {
    if (!_notificationSettings.needsBackgroundCheck ||
        snapshot.profile.provider != 'Librus Synergia') {
      return true;
    }
    return await notifications?.requestPermission() ?? true;
  }

  // The notification setters return what the system answered when they had
  // to ask for the permission: false when it refused, true when it allowed
  // it or nothing needs it. null means nothing was asked, as when turning
  // something off.
  Future<bool?> setNotificationsEnabled(bool enabled) async {
    if (!enabled) {
      for (final profile in profiles) {
        await notifications?.cancelParentSchedules(profile);
      }
    }
    _notificationSettings = _notificationSettings.copyWith(enabled: enabled);
    notifyListeners();
    await notifications?.saveSettings(_notificationSettings);
    await configureBackground();
    await _updateReminders();
    return enabled ? requestNotificationPermissionIfEnabled() : null;
  }

  /// Every kind of notification on, and the reminders as they come.
  Future<bool?> useAllNotifications() async {
    _notificationSettings = const SchoolNotificationSettings();
    notifyListeners();
    await notifications?.saveSettings(_notificationSettings);
    await configureBackground();
    await _updateReminders();
    return requestNotificationPermissionIfEnabled();
  }

  Future<bool?> setNotificationCategoryEnabled(
    SchoolNotificationCategory category,
    bool enabled,
  ) async {
    _notificationSettings = _notificationSettings.copyWith(
      category: category,
      categoryEnabled: enabled,
    );
    notifyListeners();
    await notifications?.saveSettings(_notificationSettings);
    await configureBackground();
    return enabled ? requestNotificationPermissionIfEnabled() : null;
  }

  /// Limits the attendance and timetable notifications to these kinds.
  Future<bool?> setNotificationKinds({
    Set<AttendanceKind>? attendance,
    Set<TimetableChange>? timetable,
  }) async {
    final before = _notificationSettings;
    _notificationSettings = before.copyWith(
      attendanceKinds: attendance,
      timetableChanges: timetable,
    );
    notifyListeners();
    await notifications?.saveSettings(_notificationSettings);
    await configureBackground();
    // Choosing a kind can be what turns notifications back on.
    final gained = SchoolNotificationCategory.values.any(
      (category) =>
          _notificationSettings.allows(category) && !before.allows(category),
    );
    return gained ? requestNotificationPermissionIfEnabled() : null;
  }

  /// Changes when tests are reminded of and schedules the reminders again
  /// right away.
  Future<bool?> setTestReminders(TestReminderSettings reminders) async {
    if (_notificationSettings.reminders == reminders) return null;
    _notificationSettings = _notificationSettings.copyWith(
      reminders: reminders,
    );
    notifyListeners();
    await notifications?.saveSettings(_notificationSettings);
    await configureBackground();
    await _updateReminders();
    return reminders.any ? requestNotificationPermissionIfEnabled() : null;
  }

  /// Schedules the test reminders of every profile with notifications on,
  /// as one list.
  Future<void> _updateReminders() async {
    final service = notifications;
    if (service == null) return;
    try {
      final open = activeProfile;
      final sources = <ReminderSource>[];
      if (open == null) {
        sources.add(ReminderSource(snapshot));
      } else {
        for (final profile in _profiles) {
          if (!profile.notify) continue;
          sources.add(
            ReminderSource(
              _ownData(profile.id) ??
                  await _repository.loadProfileSnapshot(profile.id),
              profile: profile,
              name: _notificationName(profile),
            ),
          );
        }
      }
      await service.updateAllReminders(sources);
    } on Object {
      // Reminders are best effort.
    }
  }

  Future<void> setAutoSyncOnOpen(bool enabled) async {
    if (_autoSyncOnOpen == enabled) return;
    _autoSyncOnOpen = enabled;
    notifyListeners();
    await _repository.saveAutoSyncOnOpen(enabled);
    await configureBackground();
  }

  Future<void> checkForUpdate() async {
    final dismissedVersion = await _repository.loadDismissedUpdateVersion();
    if (dismissedVersion == AppBuildInfo.version) return;
    final latest = await _repository.fetchLatestReleaseVersion();
    if (latest == null) return;
    _latestVersion = latest;
    _updateAvailable = isNewerVersion(latest, AppBuildInfo.version);
    notifyListeners();
  }

  /// Asks for the latest release even if its banner was dismissed. Returns
  /// its version, or null when it could not be found out.
  Future<String?> checkForUpdateNow() async {
    final latest = await _repository.fetchLatestReleaseVersion();
    if (latest == null) return null;
    _latestVersion = latest;
    _updateAvailable = isNewerVersion(latest, AppBuildInfo.version);
    notifyListeners();
    return latest;
  }

  Future<void> dismissUpdate() async {
    _updateAvailable = false;
    notifyListeners();
    await _repository.dismissUpdatesForVersion(AppBuildInfo.version);
  }

  /// For the debug menu: [category]'s notification, as it would come.
  Future<void> showSampleNotification(SchoolNotificationCategory category) =>
      notifications?.showSample(category) ?? Future.value();

  /// For the debug menu: the test reminders the phone holds.
  Future<List<String>> scheduledReminders() async =>
      await notifications?.scheduledReminders() ?? const [];

  /// For the debug menu: the background check, run now. Gives how many
  /// profiles it fetched.
  Future<int> checkInBackgroundNow() async {
    final service = notifications;
    if (service == null || isDemo) return 0;
    final checked = await checkProfilesInBackground(
      _repository,
      service,
      await service.loadSettings(),
    );
    await refreshProfiles();
    return checked;
  }

  /// For the debug menu: when each profile last synced, in the profiles'
  /// order.
  Future<List<DateTime>> profileSyncTimes() async => [
    for (final profile in _profiles)
      (await _repository.loadProfileSnapshot(profile.id)).lastSync,
  ];

  /// For the debug menu: the logo event, by name, to show at every launch,
  /// or none.
  Future<void> saveLogoChoice(String? event) =>
      _repository.saveBrandEventOverride(event);

  /// For the debug menu: the home screen widgets drawn again.
  void refreshHomeWidget() => _updateHomeWidget();

  /// What the screens show for [error], noted for the debug menu too.
  AppError _failed(Object error, StackTrace stack, String doing) {
    Diagnostics.instance.recordError(error, stack, source: doing);
    return AppError.from(error);
  }

  /// Who the profile [profileId], or the open one, can write to.
  Future<List<MessageRecipient>> fetchMessageRecipients({
    String? profileId,
  }) async {
    _error = null;
    try {
      return await _repository.fetchMessageRecipients(profileId: profileId);
    } on Object catch (error, stack) {
      _error = _failed(error, stack, 'recipients');
      notifyListeners();
      rethrow;
    }
  }

  /// Sends a message from the profile [from], or the open one; it shows in
  /// the Sent folder at once.
  Future<void> sendMessage({
    required List<MessageRecipient> recipients,
    required String subject,
    required String body,
    String? from,
  }) async {
    _error = null;
    final profileId = snapshot.profile.id;
    try {
      final message = await _repository.sendMessage(
        recipients: recipients,
        subject: subject,
        body: body,
        profileId: from,
      );
      if (_together && from != null) {
        _changePart(from, (data) => data.withSent(message));
        notifyListeners();
      } else if (snapshot.profile.id == profileId) {
        _snapshot = snapshot.withSent(message);
        notifyListeners();
      }
    } on Object catch (error, stack) {
      _error = _failed(error, stack, 'send');
      notifyListeners();
      rethrow;
    }
  }

  /// A Sent folder loaded this recently is not loaded again on its own.
  static const sentMessagesPause = Duration(minutes: 2);

  /// Loads the Sent folder, which a sync leaves out. Without [force] it is
  /// not loaded again within [sentMessagesPause].
  Future<void> refreshSentMessages({bool force = false}) async {
    if (_loadingSentMessages) return;
    if (!isDemo && snapshot.profile.provider != 'Librus Synergia') return;
    final loadedAt = _sentMessagesLoadedAt;
    if (!force &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < sentMessagesPause) {
      return;
    }
    final profileId = snapshot.profile.id;
    _loadingSentMessages = true;
    _sentMessagesError = null;
    notifyListeners();
    try {
      if (_together) {
        for (final id in [..._parts.keys]) {
          final sent = await _repository.fetchSentMessages(profileId: id);
          if (snapshot.profile.id != profileId) break;
          _changePart(id, (data) => data.copyWith(sentMessages: sent));
        }
        if (snapshot.profile.id == profileId) {
          _sentMessagesLoadedAt = DateTime.now();
        }
        return;
      }
      final sent = await _repository.fetchSentMessages();
      if (snapshot.profile.id == profileId) {
        _snapshot = snapshot.copyWith(sentMessages: sent);
        _sentMessagesLoadedAt = DateTime.now();
      }
    } on Object catch (error, stack) {
      if (snapshot.profile.id == profileId) {
        _sentMessagesError = _failed(error, stack, 'sent messages');
      }
    } finally {
      _loadingSentMessages = false;
      notifyListeners();
    }
  }

  /// Another account, or none: its Sent folder is loaded afresh.
  void _forgetSentMessages() {
    _sentMessagesLoadedAt = null;
    _sentMessagesError = null;
  }

  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage message,
  ) async {
    _error = null;
    final source = message.source;
    if (source != null) return _fetchMessageContentOf(source, message);
    final profileId = snapshot.profile.id;
    try {
      final content = await _repository.fetchMessageContent(message);
      if (snapshot.profile.id == profileId) {
        _snapshot = snapshot.withOpened(message, content);
        notifyListeners();
      }
      return content;
    } on Object catch (error, stack) {
      _error = _failed(error, stack, 'message');
      notifyListeners();
      rethrow;
    }
  }

  /// Opens [message] of the view together from its own profile [source].
  /// The content keeps the id of the view together, as its attachments
  /// come from that profile too.
  Future<SchoolMessageContent> _fetchMessageContentOf(
    String source,
    SchoolMessage message,
  ) async {
    final own = message.withSource(null, id: localId(message.id, source));
    try {
      final content = await _repository.fetchMessageContent(
        own,
        profileId: source,
      );
      _changePart(source, (data) => data.withOpened(own, content));
      notifyListeners();
      return SchoolMessageContent(
        id: message.id,
        sender: content.sender,
        subject: content.subject,
        body: content.body,
        receivedAt: content.receivedAt,
        attachments: content.attachments,
        recipients: content.recipients,
      );
    } on Object catch (error, stack) {
      _error = _failed(error, stack, 'message');
      _errorSource = source;
      notifyListeners();
      rethrow;
    }
  }

  /// Marks one message read in Librus, which happens when it is fetched.
  Future<void> markMessageRead(SchoolMessage message) async {
    if (!message.unread) return;
    await fetchMessageContent(message);
  }

  Future<void> markAllMessagesRead() async {
    if (_markingMessagesRead || syncing) return;
    final profileId = snapshot.profile.id;
    final unread = snapshot.messages
        .where((message) => message.unread)
        .toList();
    _markingMessagesRead = true;
    _error = null;
    notifyListeners();
    Object? firstError;
    try {
      for (final message in unread) {
        if (snapshot.profile.id != profileId) break;
        try {
          // GetMessage marks the message as read in Librus, just as opening it.
          await fetchMessageContent(message);
        } on Object catch (error) {
          firstError ??= error;
        }
      }
      if (firstError != null) {
        // Each failure is already in the diagnostics, from opening it.
        _error = AppError.from(firstError);
        throw firstError;
      }
    } finally {
      _markingMessagesRead = false;
      notifyListeners();
    }
  }

  Future<Uri> fetchMessageAttachmentUrl({
    required String messageId,
    required String attachmentId,
  }) {
    final source = _together ? sourceOfId(messageId, _parts.keys) : null;
    return _repository.fetchMessageAttachmentUrl(
      messageId: localId(messageId, source),
      attachmentId: attachmentId,
      profileId: source,
    );
  }

  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async {
    _error = null;
    if (_together) return _fetchTimetableWeekTogether(day);
    try {
      final lessons = await _repository.fetchTimetableWeek(day);
      _snapshot = snapshot.copyWith(
        lessons: _withWeek(snapshot.lessons, lessons, day),
      );
      notifyListeners();
      _updateHomeWidget();
      return lessons;
    } on Object catch (error, stack) {
      _error = _failed(error, stack, 'timetable');
      notifyListeners();
      rethrow;
    }
  }

  /// The week of [day] of every profile in the view together. A profile
  /// that cannot load it leaves the others'; only when none can, it fails.
  Future<List<Lesson>> _fetchTimetableWeekTogether(DateTime day) async {
    final week = <Lesson>[];
    (String, Object, StackTrace)? failed;
    var loaded = 0;
    for (final id in [..._parts.keys]) {
      try {
        final lessons = await _repository.fetchTimetableWeek(
          day,
          profileId: id,
        );
        loaded++;
        _changePart(
          id,
          (data) =>
              data.copyWith(lessons: _withWeek(data.lessons, lessons, day)),
        );
        week.addAll([
          for (final lesson in lessons)
            lesson.withSource(id, id: sourcedId(id, lesson.id)),
        ]);
      } on Object catch (error, stack) {
        failed ??= (id, error, stack);
      }
    }
    if (failed case (final id, final error, final stack)) {
      _error = _failed(error, stack, 'timetable');
      _errorSource = id;
    }
    notifyListeners();
    _updateHomeWidget();
    if (loaded == 0 && failed != null) throw failed.$2;
    return week..sort((a, b) => a.start.compareTo(b.start));
  }

  /// [lessons] with the week of [day] in place of what they had for it.
  static List<Lesson> _withWeek(
    List<Lesson> lessons,
    List<Lesson> week,
    DateTime day,
  ) {
    // Calendar days: a week the clocks change in is not 7 × 24 hours.
    final weekStart = DateTime(
      day.year,
      day.month,
      day.day - (day.weekday - 1),
    );
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    return lessons
        .where(
          (lesson) =>
              lesson.start.isBefore(weekStart) ||
              !lesson.start.isBefore(weekEnd),
        )
        .followedBy(week)
        .toList(growable: false)
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    _updateHomeWidget();
    await _repository.saveLocale(locale?.languageCode);
  }

  Future<void> setAttendanceChartStyle(AttendanceChartStyle style) async {
    if (_attendanceChartStyle == style) return;
    _attendanceChartStyle = style;
    notifyListeners();
    await _repository.saveAttendanceChartStyle(style);
  }

  Future<void> setColorMode(AppColorMode mode) async {
    if (_colorMode == mode) return;
    _colorMode = mode;
    notifyListeners();
    await _repository.saveColorMode(mode);
  }

  Future<void> setTimetableView(TimetableView view) async {
    if (_timetableView == view) return;
    _timetableView = view;
    notifyListeners();
    await _repository.saveTimetableView(view);
  }

  Future<void> setMergeTimetableLessons(bool enabled) async {
    if (_mergeTimetableLessons == enabled) return;
    _mergeTimetableLessons = enabled;
    notifyListeners();
    await _repository.saveMergeTimetableLessons(enabled);
  }

  Future<void> setShowTimetableBreaks(bool enabled) async {
    if (_showTimetableBreaks == enabled) return;
    _showTimetableBreaks = enabled;
    notifyListeners();
    await _repository.saveShowTimetableBreaks(enabled);
  }

  Future<void> setMessageListStyle(MessageListStyle style) async {
    if (_messageListStyle == style) return;
    _messageListStyle = style;
    notifyListeners();
    await _repository.saveMessageListStyle(style);
  }

  Future<void> setGradesView(GradesView view) async {
    if (_gradesView == view) return;
    _gradesView = view;
    notifyListeners();
    await _repository.saveGradesView(view);
  }

  /// Marks [item] as done, or not. Done work is no longer reminded of.
  Future<void> setHomeworkDone(SchoolEvent item, bool done) async {
    if (!canUseStudentToolsFor(item.source)) return;
    if (isHomeworkDone(item) == done) return;
    final source = item.source;
    if (source != null) {
      final id = localId(item.id, source);
      final marks = {
        for (final entry in (_doneOf[source] ?? const {}).entries)
          if (entry.key != id) entry.key: entry.value,
        if (done) id: item.date,
      };
      _doneOf = {..._doneOf, source: marks};
      if (source == activeProfile?.id) _doneHomework = marks;
      notifyListeners();
      await _repository.saveDoneHomework(marks, profileId: source);
      await _updateReminders();
      return;
    }
    _doneHomework = {
      for (final entry in _doneHomework.entries)
        if (entry.key != item.id) entry.key: entry.value,
      if (done) item.id: item.date,
    };
    notifyListeners();
    await _repository.saveDoneHomework(_doneHomework);
    await _updateReminders();
  }

  Future<void> setTodayLayout(TodayLayout layout) async {
    if (_todayLayout == layout) return;
    _todayLayout = layout;
    notifyListeners();
    await _repository.saveTodayLayout(layout);
  }

  /// The settings of the grade average; in the view together, of every
  /// profile in it.
  Future<void> setGradeAverageSettings(GradeAverageSettings settings) async {
    if (_together) {
      if (_gradeAverages.values.every((saved) => saved == settings)) return;
      _gradeAverage = settings;
      _gradeAverages = {for (final id in _gradeAverages.keys) id: settings};
      notifyListeners();
      for (final id in _gradeAverages.keys) {
        await _repository.saveGradeAverageSettings(settings, profileId: id);
      }
      return;
    }
    if (_gradeAverage == settings) return;
    _gradeAverage = settings;
    notifyListeners();
    await _repository.saveGradeAverageSettings(settings);
  }

  Future<void> setDesign(AppDesign design) async {
    if (_design == design) return;
    _design = design;
    notifyListeners();
    await _repository.saveDesign(design);
  }

  void selectTab(int value) {
    if (_tabIndex == value) return;
    _tabIndex = value;
    notifyListeners();
  }

  DateTime? _timetableDay;

  /// Opens the timetable at [day], wherever it was left, as a tap on the
  /// lesson on Today does.
  void openTimetableDay(DateTime day) {
    _timetableDay = DateTime(day.year, day.month, day.day);
    _tabIndex = 1;
    notifyListeners();
  }

  /// The day the timetable was asked to open at, once: the timetable takes
  /// it as it draws.
  DateTime? takeTimetableDay() {
    final day = _timetableDay;
    _timetableDay = null;
    return day;
  }

  /// Data this old opens with a sync when the user switches to its profile
  /// and automatic sync is on.
  static const switchSyncAfter = Duration(minutes: 20);

  /// Opens the profile [profileId] at once with its saved data and its own
  /// settings. A sync of the profile left behind goes on and saves its data.
  Future<void> switchProfile(String profileId) async {
    if (!_together && activeProfile?.id == profileId) return;
    _leaveTogether();
    _snapshot = await _repository.switchProfile(profileId);
    await _loadProfileSettings();
    _profiles = _repository.profiles;
    _syncNews = null;
    _forgetSentMessages();
    _error = null;
    _seeNews(profileId);
    notifyListeners();
    _updateHomeWidget();
    unawaited(_updateReminders());
    final age = DateTime.now().difference(snapshot.lastSync);
    if (_autoSyncOnOpen && age >= switchSyncAfter) unawaited(sync());
  }

  void _seeNews(String profileId) {
    if (!_profileNews.contains(profileId)) return;
    _profileNews = {..._profileNews}..remove(profileId);
    unawaited(_repository.setProfileNews(profileId, false));
  }

  /// Reads the profiles and their news again, as the background check may
  /// have changed them while the app was away.
  Future<void> refreshProfiles() async {
    if (isDemo) return;
    final profiles = await _repository.loadProfiles(reload: true);
    final news = await _repository.loadProfileNews(reload: true);
    _profiles = profiles;
    // What is on screen is seen: the open profile, or every one together.
    final shown = _together
        ? {for (final profile in togetherProfiles) profile.id}
        : {?activeProfile?.id};
    _profileNews = {...news}..removeAll(shown);
    for (final id in shown.intersection(news)) {
      unawaited(_repository.setProfileNews(id, false));
    }
    notifyListeners();
  }

  /// The students of the phone's Librus logins that have no profile yet.
  Future<List<LinkedSynergiaAccount>> availableStudents() async => [
    for (final student in await _repository.availableStudents())
      if (!student.selected) student,
  ];

  /// Adds a profile for [student] of a login the phone has, opens it and
  /// syncs it. Returns the new profile, or null when it could not be added.
  Future<SchoolProfile?> addStudent(LinkedSynergiaAccount student) async {
    if (_signingIn) return null;
    _signingIn = true;
    _error = null;
    notifyListeners();
    try {
      final added = await _addAndOpen([student], student.account);
      return added.isEmpty ? null : added.first;
    } on Object catch (error, stack) {
      _error = _failed(error, stack, 'add student');
      return null;
    } finally {
      _signingIn = false;
      _profiles = _repository.profiles;
      notifyListeners();
    }
  }

  /// Signs in to a Librus account and adds its students as profiles. When
  /// it has several new ones, [choose] picks them, offered as
  /// [defaultStudentChoice] checks them; null or none adds nothing. Without
  /// [choose], the student's own account is added. The first added profile
  /// opens and syncs; the others sync after it.
  Future<bool> loginLibrus({
    required String username,
    required String password,
    Future<List<LinkedSynergiaAccount>?> Function(
      List<LinkedSynergiaAccount> students,
    )?
    choose,
  }) async {
    if (_signingIn || _markingMessagesRead) return false;
    _signingIn = true;
    _signInStage = SignInStage.checking;
    _error = null;
    notifyListeners();
    try {
      final found = await _repository.signIn(
        username: username,
        password: password,
      );
      if (found.students.isEmpty) {
        throw const LibrusException(LibrusErrorCode.noSynergiaAccount);
      }
      final fresh = [
        for (final student in found.students)
          if (!student.selected) student,
      ];
      List<LinkedSynergiaAccount> chosen;
      if (fresh.isEmpty) {
        chosen = const [];
      } else if (choose != null && fresh.length > 1) {
        _signInStage = SignInStage.choosing;
        notifyListeners();
        chosen = await choose(fresh) ?? const [];
        if (chosen.isEmpty) {
          await _repository.discardLogin(found.account);
          return false;
        }
      } else {
        final defaults = defaultStudentChoice(fresh);
        chosen = [
          fresh.firstWhere(
            (student) => defaults.contains(student.login) && !student.parent,
            orElse: () => fresh.first,
          ),
        ];
      }
      _signInStage = SignInStage.loading;
      notifyListeners();
      final added = await _addAndOpen(chosen, found.account);
      unawaited(_syncInTurn(added.skip(1).toList()));
      unawaited(configureBackground());
      unawaited(requestNotificationPermissionIfEnabled());
      return true;
    } on Object catch (error, stack) {
      _error = _failed(error, stack, 'sign-in');
      return false;
    } finally {
      _signingIn = false;
      _signInStage = null;
      _profiles = _repository.profiles;
      notifyListeners();
    }
  }

  /// What signing in is doing, while it runs.
  SignInStage? get signInStage => _signInStage;

  /// Adds profiles for [students] of the login [account] and opens the
  /// first, synced while the user waits. Signing in again to a login whose
  /// students are all here opens the first of them. If that sync fails,
  /// nothing is added and the profile open before stays open, as a failed
  /// sign-in always left the app.
  Future<List<SchoolProfile>> _addAndOpen(
    List<LinkedSynergiaAccount> students,
    String account,
  ) async {
    final before = activeProfile?.id;
    final added = await _repository.addProfiles(students);
    final first = added.isNotEmpty
        ? added.first
        : _repository.profiles.firstWhere(
            (profile) => profile.account == account,
          );
    try {
      await _repository.switchProfile(first.id);
      final synced = await _repository.syncProfile(first.id);
      _leaveTogether();
      _snapshot = synced;
    } on Object {
      for (final profile in added) {
        await _repository.removeProfile(profile.id);
      }
      await _repository.discardLogin(account);
      if (before != null && _repository.activeProfile?.id != before) {
        await _repository.switchProfile(before);
      }
      rethrow;
    }
    await _loadProfileSettings();
    _syncNews = null;
    _forgetSentMessages();
    _profiles = _repository.profiles;
    _seeNews(first.id);
    await _recordNotifications();
    _updateHomeWidget();
    return added;
  }

  /// Syncs newly added profiles one after another, so their names, schools
  /// and data are ready before the user opens them.
  Future<void> _syncInTurn(List<SchoolProfile> added) async {
    for (final profile in added) {
      try {
        final result = await _repository.syncProfile(profile.id);
        await _notify(result, profile);
      } on Object {
        // Synced again when the user opens it.
      }
      _profiles = _repository.profiles;
      notifyListeners();
    }
  }

  /// Removes the profile [profileId] and its data from the phone. Librus
  /// keeps everything. The last one leaves the app signed out.
  Future<void> removeProfile(String profileId) async {
    await notifications?.cancelParentSchedules(profileOf(profileId));
    final open = activeProfile?.id == profileId;
    final remaining = await _repository.removeProfile(profileId);
    _profiles = _repository.profiles;
    _profileNews = {..._profileNews}..remove(profileId);
    final wasTogether = _together;
    if (_together && canBeTogether) {
      _parts = {..._parts}..remove(profileId);
      _mergeParts();
      await _loadProfileSettings();
    } else if (wasTogether || open || _profiles.isEmpty) {
      // Fewer than two left together: the open profile shows alone.
      _leaveTogether();
      _snapshot = remaining;
      await _loadProfileSettings();
      _syncNews = null;
      _forgetSentMessages();
      _error = null;
      if (_profiles.isEmpty) _tabIndex = 0;
    }
    notifyListeners();
    _updateHomeWidget();
    unawaited(configureBackground());
    unawaited(_updateReminders());
  }

  Future<void> renameProfile(String profileId, String? label) async {
    await _repository.renameProfile(profileId, label);
    _profiles = _repository.profiles;
    notifyListeners();
  }

  Future<void> setProfileColor(String profileId, int color) async {
    await _repository.setProfileColor(profileId, color);
    _profiles = _repository.profiles;
    notifyListeners();
  }

  Future<void> setProfileNotify(String profileId, bool notify) async {
    if (!notify) {
      await notifications?.cancelParentSchedules(profileOf(profileId));
    }
    await _repository.setProfileNotify(profileId, notify);
    _profiles = _repository.profiles;
    notifyListeners();
    await configureBackground();
    await _updateReminders();
  }

  /// Puts the profile [profileId] in the view together, or takes it out.
  /// With fewer than two left in it, the view shows the open profile alone.
  Future<void> setProfileTogether(String profileId, bool together) async {
    await _repository.setProfileTogether(profileId, together);
    _profiles = _repository.profiles;
    if (_together && !canBeTogether) {
      _leaveTogether();
      _snapshot = await _repository.load();
      await _loadProfileSettings();
      _syncNews = null;
      _forgetSentMessages();
      _error = null;
    } else if (_together) {
      if (together && !_parts.containsKey(profileId)) {
        _parts = {
          ..._parts,
          profileId: await _repository.loadProfileSnapshot(profileId),
        };
      } else if (!together) {
        _parts = {..._parts}..remove(profileId);
      }
      _mergeParts();
      await _loadProfileSettings();
    }
    notifyListeners();
    // A widget may show every profile together, whichever view is open.
    _updateHomeWidget();
  }

  /// Syncs the open profile. Switching profiles meanwhile leaves the sync
  /// to finish and save its data, without touching the screen.
  Future<void> sync() async {
    if (_together) return _syncTogether();
    final key = _syncKey;
    if (_syncingProfiles.contains(key) || _signingIn || _markingMessagesRead) {
      return;
    }
    _syncingProfiles.add(key);
    _error = null;
    notifyListeners();
    final profile = activeProfile;
    try {
      final before = snapshot;
      final result = await _repository.sync(snapshot);
      if (_syncKey != key) {
        await _notify(result, profile);
        return;
      }
      final sameProfile = result.profile.id == snapshot.profile.id;
      // A Sent folder loaded or a message sent while this sync ran stays.
      _snapshot = sameProfile
          ? result.copyWith(sentMessages: snapshot.sentMessages)
          : result;
      // Nothing is news on the first sync or for another account.
      final news = sameProfile && before.lastSync.millisecondsSinceEpoch != 0
          ? SyncNews.between(before, snapshot)
          : null;
      _syncNews = news == null || news.isEmpty ? null : news;
      await _recordNotifications();
      _updateHomeWidget();
    } on Object catch (error, stack) {
      if (_syncKey == key) _error = _failed(error, stack, 'sync');
    } finally {
      _syncingProfiles.remove(key);
      _profiles = _repository.profiles;
      notifyListeners();
    }
  }

  /// Syncs every profile in the view together, one after another, as a
  /// Librus login two of them share renews its session once at a time. A
  /// profile that fails leaves the others' data, and the error names it.
  Future<void> _syncTogether() async {
    if (_syncingProfiles.contains(togetherId) ||
        _signingIn ||
        _markingMessagesRead) {
      return;
    }
    _syncingProfiles.add(togetherId);
    _error = null;
    _errorSource = null;
    notifyListeners();
    final before = snapshot;
    (SchoolProfile, Object, StackTrace)? failed;
    try {
      for (final profile in togetherProfiles) {
        _syncingProfiles.add(profile.id);
        try {
          final result = await _repository.syncProfile(profile.id);
          // A Sent folder loaded or a message sent meanwhile stays.
          _changePart(
            profile.id,
            (data) => result.copyWith(sentMessages: data.sentMessages),
          );
          await _notify(result, profile);
        } on Object catch (error, stack) {
          failed ??= (profile, error, stack);
        } finally {
          _syncingProfiles.remove(profile.id);
        }
      }
      if (!_together) return;
      final news = before.lastSync.millisecondsSinceEpoch != 0
          ? SyncNews.between(before, snapshot)
          : null;
      _syncNews = news == null || news.isEmpty ? null : news;
      if (failed case (final profile, final error, final stack)) {
        _error = _failed(error, stack, 'sync');
        _errorSource = profile.id;
      }
      unawaited(_updateReminders());
      _updateHomeWidget();
    } finally {
      _syncingProfiles.remove(togetherId);
      _profiles = _repository.profiles;
      notifyListeners();
    }
  }

  /// Signs out of every profile: their data and logins leave the phone.
  Future<void> logout() async {
    for (final profile in profiles) {
      await notifications?.cancelParentSchedules(profile);
    }
    _leaveTogether();
    _snapshot = await _repository.logout();
    _profiles = const [];
    _profileNews = const {};
    await _loadProfileSettings();
    _syncNews = null;
    _forgetSentMessages();
    _error = null;
    _tabIndex = 0;
    notifyListeners();
    _updateHomeWidget();
    unawaited(configureBackground());
    // Signed out, the reminders of the old account are cancelled.
    unawaited(_updateReminders());
  }
}

bool isNewerVersion(String candidate, String current) {
  List<int> parts(String value) {
    final clean = value
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp(r'[-+]'))
        .first;
    return clean
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  final candidateParts = parts(candidate);
  final currentParts = parts(current);
  final length = candidateParts.length > currentParts.length
      ? candidateParts.length
      : currentParts.length;
  for (var index = 0; index < length; index++) {
    final next = index < candidateParts.length ? candidateParts[index] : 0;
    final installed = index < currentParts.length ? currentParts[index] : 0;
    if (next != installed) return next > installed;
  }
  return false;
}
