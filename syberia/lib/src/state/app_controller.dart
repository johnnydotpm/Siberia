import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import '../app_build_info.dart';
import '../data/app_repository.dart';
import '../domain/librus_error.dart';
import '../domain/models.dart';
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
  bool _syncing = false;
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
  Timer? _homeWidgetDebounce;
  SchoolNotificationSettings _notificationSettings =
      const SchoolNotificationSettings();
  bool _autoSyncOnOpen = true;

  AppSnapshot get snapshot => _snapshot!;
  bool get syncing => _syncing;
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
    _gradeAverage = await _repository.loadGradeAverageSettings();
    _subjectShortNames = await _repository.loadSubjectShortNames();
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
            snapshot.profile.provider == 'Librus Synergia',
      );
    } on Object {
      // The manual sync button remains usable if scheduling is unavailable.
    }
  }

  void _updateHomeWidget() {
    final widget = homeWidget;
    if (widget == null) return;
    if (snapshot.profile.provider != 'Librus Synergia') {
      unawaited(widget.clear());
      return;
    }
    final l10n = AppLocalizations(
      _locale ?? PlatformDispatcher.instance.locale,
    );
    unawaited(
      widget.update(
        buildHomeWidgetPayload(
          snapshot,
          DateTime.now(),
          l10n,
          shortNames: _subjectShortNames,
        ),
      ),
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
    try {
      await notifications?.processSnapshot(snapshot);
    } on Object {
      // Notifications cannot turn a successful Librus sync into an error.
    }
    // Scheduling takes a round trip per reminder, so it never holds the app
    // opening or a sync.
    unawaited(_updateReminders());
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

  Future<void> _updateReminders() async {
    try {
      await notifications?.updateReminders(snapshot);
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
    if (snapshot.profile.provider != 'Librus Synergia') return;
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
    if (_markingMessagesRead || _syncing) return;
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
      final selectedDate = DateTime(day.year, day.month, day.day);
      final weekStart = selectedDate.subtract(
        Duration(days: selectedDate.weekday - 1),
      );
      final weekEnd = weekStart.add(const Duration(days: 7));
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

  Future<List<LinkedSynergiaAccount>> fetchSynergiaAccounts() =>
      _repository.fetchSynergiaAccounts();

  Future<bool> selectSynergiaAccount(String login) async {
    if (_syncing || _markingMessagesRead) return false;
    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      _snapshot = await _repository.selectSynergiaAccount(login);
      _forgetSentMessages();
      await _recordNotifications();
      _updateHomeWidget();
      return true;
    } on Object catch (error) {
      _error = AppError.from(error);
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    if (_syncing || _markingMessagesRead) return;
    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.sync(snapshot);
      // A Sent folder loaded or a message sent while this sync ran stays.
      _snapshot = result.profile.id == snapshot.profile.id
          ? result.copyWith(sentMessages: snapshot.sentMessages)
          : result;
      await _recordNotifications();
      _updateHomeWidget();
    } on Object catch (error) {
      _error = AppError.from(error);
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<bool> loginLibrus({
    required String username,
    required String password,
  }) async {
    if (_syncing || _markingMessagesRead) return false;
    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      _snapshot = await _repository.loginLibrus(
        username: username,
        password: password,
      );
      _forgetSentMessages();
      await _recordNotifications();
      _updateHomeWidget();
      unawaited(configureBackground());
      unawaited(requestNotificationPermissionIfEnabled());
      return true;
    } on Object catch (error) {
      _error = AppError.from(error);
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _snapshot = await _repository.logout();
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
