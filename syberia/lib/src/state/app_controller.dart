import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import '../app_build_info.dart';
import '../data/app_repository.dart';
import '../domain/librus_error.dart';
import '../domain/models.dart';
import '../domain/profiles.dart';
import '../domain/sync_news.dart';
import '../home_widget.dart';
import '../home_widget.dart' as home_widget show displaySubject;
import '../l10n/app_localizations.dart';
import '../school_notifications.dart';
import '../test_reminders.dart';

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

  AppSnapshot get snapshot => _snapshot!;
  bool get isDemo => _snapshot?.profile.provider == 'Demo';

  /// The login screen's hidden gesture enters a disposable local session.
  void startDemo() {
    if (syncing ||
        _markingMessagesRead ||
        snapshot.profile.provider != 'Signed out') {
      return;
    }
    _snapshot = _repository.enterDemo();
    _doneHomework = const {};
    _forgetSentMessages();
    _error = null;
    _tabIndex = 0;
    notifyListeners();
    _updateHomeWidget();
  }

  /// Whether the open profile is syncing, or an account is being added.
  /// Another profile's sync goes on unseen.
  bool get syncing => _signingIn || _syncingProfiles.contains(_syncKey);

  String get _syncKey => _repository.activeProfile?.id ?? '';

  /// The profiles on the phone, in the order they were added.
  List<SchoolProfile> get profiles => _profiles;

  /// The open profile; null when signed out, in demo mode, or for data from
  /// a repository without profiles.
  SchoolProfile? get activeProfile => _repository.activeProfile;

  /// Whether the profile [profileId] has news the user has not seen.
  bool profileHasNews(String profileId) => _profileNews.contains(profileId);

  /// Whether a profile other than the open one has news.
  bool get otherProfilesHaveNews =>
      _profileNews.any((id) => id != activeProfile?.id);

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
  Map<String, String> get subjectShortNames => _subjectShortNames;
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
  bool isHomeworkDone(SchoolEvent item) => _doneHomework.containsKey(item.id);

  /// The name to show for [subject]: the student's short name if they set one.
  String displaySubject(String subject) =>
      home_widget.displaySubject(subject, _subjectShortNames);
  SchoolNotificationSettings get notificationSettings => _notificationSettings;
  bool get autoSyncOnOpen => _autoSyncOnOpen;

  /// Loads settings and the saved snapshot. It never waits on the network;
  /// [startAutoSync] refreshes the data once the app is on screen.
  Future<void> bootstrap() async {
    await _loadPreferences();
    _snapshot = await _repository.load();
    _profiles = _repository.profiles;
    _profileNews = await _repository.loadProfileNews();
    _widgetProfileId = await _repository.loadWidgetProfile();
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
      _notificationSettings = await notifications!.loadSettings();
    }
  }

  /// The settings each profile keeps for itself.
  Future<void> _loadProfileSettings() async {
    _gradeAverage = await _repository.loadGradeAverageSettings();
    _subjectShortNames = await _repository.loadSubjectShortNames();
    _doneHomework = await _repository.loadDoneHomework();
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
        profile.id == open.id
        ? buildHomeWidgetPayload(
            snapshot,
            now,
            l10n,
            shortNames: _subjectShortNames,
          )
        : buildHomeWidgetPayload(
            await _repository.loadProfileSnapshot(profile.id),
            now,
            l10n,
            shortNames: await _repository.loadSubjectShortNamesOf(profile.id),
          );
    final shown = _profiles.firstWhere(
      (profile) => profile.id == widgetProfileId,
      orElse: () => open,
    );
    await widget.update(
      await lessonsOf(shown),
      profiles: widget.configurableInApp
          ? {
              for (final profile in _profiles)
                profile.id: await lessonsOf(profile),
            }
          : const {},
    );
  }

  Future<void> setSubjectShortName(String subject, String shortName) async {
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

  @override
  void dispose() {
    _homeWidgetDebounce?.cancel();
    super.dispose();
  }

  Future<void> _recordNotifications() async {
    await _notify(snapshot, activeProfile);
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
      profile != null && _profiles.length > 1 ? profile.displayName : null;

  /// Opens what a tapped notification is about: its profile, then its page.
  Future<void> openNotification(NotificationTarget target) async {
    final profileId = target.profileId;
    if (profileId != null &&
        profileId != activeProfile?.id &&
        _profiles.any((profile) => profile.id == profileId)) {
      await switchProfile(profileId);
    }
    selectTab(target.category.tabIndex);
  }

  Future<bool> requestNotificationPermissionIfEnabled() async {
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
    _notificationSettings = _notificationSettings.copyWith(enabled: enabled);
    notifyListeners();
    await notifications?.saveSettings(_notificationSettings);
    await configureBackground();
    await _updateReminders();
    return enabled ? requestNotificationPermissionIfEnabled() : null;
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
              profile.id == open.id
                  ? snapshot
                  : await _repository.loadProfileSnapshot(profile.id),
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

  Future<List<MessageRecipient>> fetchMessageRecipients() async {
    _error = null;
    try {
      return await _repository.fetchMessageRecipients();
    } on Object catch (error) {
      _error = AppError.from(error);
      notifyListeners();
      rethrow;
    }
  }

  /// Sends a message; it shows in the Sent folder at once.
  Future<void> sendMessage({
    required List<MessageRecipient> recipients,
    required String subject,
    required String body,
  }) async {
    _error = null;
    final profileId = snapshot.profile.id;
    try {
      final message = await _repository.sendMessage(
        recipients: recipients,
        subject: subject,
        body: body,
      );
      if (snapshot.profile.id == profileId) {
        _snapshot = snapshot.withSent(message);
        notifyListeners();
      }
    } on Object catch (error) {
      _error = AppError.from(error);
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
      final sent = await _repository.fetchSentMessages();
      if (snapshot.profile.id == profileId) {
        _snapshot = snapshot.copyWith(sentMessages: sent);
        _sentMessagesLoadedAt = DateTime.now();
      }
    } on Object catch (error) {
      if (snapshot.profile.id == profileId) {
        _sentMessagesError = AppError.from(error);
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
    final profileId = snapshot.profile.id;
    try {
      final content = await _repository.fetchMessageContent(message);
      if (snapshot.profile.id == profileId) {
        _snapshot = snapshot.withOpened(message, content);
        notifyListeners();
      }
      return content;
    } on Object catch (error) {
      _error = AppError.from(error);
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
  }) => _repository.fetchMessageAttachmentUrl(
    messageId: messageId,
    attachmentId: attachmentId,
  );

  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async {
    _error = null;
    try {
      final lessons = await _repository.fetchTimetableWeek(day);
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
      final merged =
          snapshot.lessons
              .where(
                (lesson) =>
                    lesson.start.isBefore(weekStart) ||
                    !lesson.start.isBefore(weekEnd),
              )
              .followedBy(lessons)
              .toList(growable: false)
            ..sort((a, b) => a.start.compareTo(b.start));
      _snapshot = snapshot.copyWith(lessons: merged);
      notifyListeners();
      _updateHomeWidget();
      return lessons;
    } on Object catch (error) {
      _error = AppError.from(error);
      notifyListeners();
      rethrow;
    }
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
    if (isHomeworkDone(item) == done) return;
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

  Future<void> setGradeAverageSettings(GradeAverageSettings settings) async {
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

  /// Data this old opens with a sync when the user switches to its profile
  /// and automatic sync is on.
  static const switchSyncAfter = Duration(minutes: 20);

  /// Opens the profile [profileId] at once with its saved data and its own
  /// settings. A sync of the profile left behind goes on and saves its data.
  Future<void> switchProfile(String profileId) async {
    if (isDemo || activeProfile?.id == profileId) return;
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
    final open = activeProfile?.id;
    _profiles = profiles;
    _profileNews = open == null || !news.contains(open)
        ? news
        : ({...news}..remove(open));
    if (open != null && news.contains(open)) {
      unawaited(_repository.setProfileNews(open, false));
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
    } on Object catch (error) {
      _error = AppError.from(error);
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
      final added = await _addAndOpen(chosen, found.account);
      unawaited(_syncInTurn(added.skip(1).toList()));
      unawaited(configureBackground());
      unawaited(requestNotificationPermissionIfEnabled());
      return true;
    } on Object catch (error) {
      _error = AppError.from(error);
      return false;
    } finally {
      _signingIn = false;
      _profiles = _repository.profiles;
      notifyListeners();
    }
  }

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
    final open = activeProfile?.id == profileId;
    final remaining = await _repository.removeProfile(profileId);
    _profiles = _repository.profiles;
    _profileNews = {..._profileNews}..remove(profileId);
    if (open || _profiles.isEmpty) {
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
    await _repository.setProfileNotify(profileId, notify);
    _profiles = _repository.profiles;
    notifyListeners();
    await configureBackground();
    await _updateReminders();
  }

  /// Syncs the open profile. Switching profiles meanwhile leaves the sync
  /// to finish and save its data, without touching the screen.
  Future<void> sync() async {
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
    } on Object catch (error) {
      if (_syncKey == key) _error = AppError.from(error);
    } finally {
      _syncingProfiles.remove(key);
      _profiles = _repository.profiles;
      notifyListeners();
    }
  }

  /// Signs out of every profile: their data and logins leave the phone.
  Future<void> logout() async {
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
