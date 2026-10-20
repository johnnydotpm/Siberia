import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'domain/models.dart';
import 'l10n/app_localizations.dart';
import 'test_reminders.dart';

enum SchoolNotificationCategory {
  grades,
  messages,
  announcements,
  notices,
  attendance,
  events,
  homework,
  timetable;

  int get tabIndex => switch (this) {
    grades => 2,
    messages => 5,
    announcements => 7,
    notices => 8,
    attendance => 6,
    events => 3,
    homework => 4,
    timetable => 1,
  };
}

/// A change to a lesson the timetable notifications can be limited to.
enum TimetableChange {
  substitution,
  cancelled,
  moved;

  /// What happened to [lesson], or null when it takes place as planned.
  /// A moved lesson is also cancelled where it was, so it counts as moved.
  static TimetableChange? of(Lesson lesson) => lesson.movedTo != null
      ? moved
      : lesson.cancelled
      ? cancelled
      : lesson.substitution
      ? substitution
      : null;

  /// The translation key of its name.
  String get label => switch (this) {
    substitution => 'substitution',
    cancelled => 'lessonCancelled',
    moved => 'lessonMoved',
  };
}

class SchoolNotificationSettings {
  const SchoolNotificationSettings({
    this.enabled = true,
    this.categories = const {},
    this.reminders = const TestReminderSettings(),
    this.attendanceKinds = const {...AttendanceKind.values},
    this.timetableChanges = const {...TimetableChange.values},
  });

  final bool enabled;
  final Map<SchoolNotificationCategory, bool> categories;
  final TestReminderSettings reminders;

  /// The attendance entries that notify, for example only absences.
  final Set<AttendanceKind> attendanceKinds;

  /// The lesson changes that notify.
  final Set<TimetableChange> timetableChanges;

  /// A category with nothing chosen inside it is as good as off, so the
  /// background check does not fetch it.
  bool allows(SchoolNotificationCategory category) =>
      enabled &&
      (categories[category] ?? true) &&
      switch (category) {
        SchoolNotificationCategory.attendance => attendanceKinds.isNotEmpty,
        SchoolNotificationCategory.timetable => timetableChanges.isNotEmpty,
        _ => true,
      };

  bool get hasEnabledCategory =>
      enabled && SchoolNotificationCategory.values.any(allows);

  bool get remindersOn => enabled && reminders.any;

  /// Whether anything needs the background check: new data to report, or
  /// tests to keep the reminders up to date for.
  bool get needsBackgroundCheck => hasEnabledCategory || remindersOn;

  SchoolNotificationSettings copyWith({
    bool? enabled,
    SchoolNotificationCategory? category,
    bool? categoryEnabled,
    TestReminderSettings? reminders,
    Set<AttendanceKind>? attendanceKinds,
    Set<TimetableChange>? timetableChanges,
  }) => SchoolNotificationSettings(
    enabled: enabled ?? this.enabled,
    categories: category == null
        ? categories
        : {...categories, category: categoryEnabled ?? true},
    reminders: reminders ?? this.reminders,
    attendanceKinds: attendanceKinds ?? this.attendanceKinds,
    timetableChanges: timetableChanges ?? this.timetableChanges,
  );
}

abstract class SchoolNotificationPresenter {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
  });
  Future<SchoolNotificationCategory?> launchCategory();
  void onTap(void Function(SchoolNotificationCategory) callback);

  /// Replaces every scheduled reminder with [reminders]; an empty list
  /// cancels them all.
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  });
}

class FlutterSchoolNotificationPresenter
    implements SchoolNotificationPresenter {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  void Function(SchoolNotificationCategory)? _tapCallback;
  bool _ready = false;

  @override
  Future<void> initialize() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
          windows: WindowsInitializationSettings(
            appName: 'SiberiaGB',
            appUserModelId: 'SiberiaGB.Client',
            guid: 'db2c9659-91a2-462b-963b-ad063137c698',
          ),
          web: WebInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final category = _categoryFromPayload(response.payload);
          if (category != null) _tapCallback?.call(category);
        },
      );
      _ready = true;
    } on Object {
      // Notifications must not prevent the rest of the app from opening.
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (kIsWeb) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  WebFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: category.index + 1,
      title: title,
      body: body,
      payload: category.name,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'siberiagb_${category.name}',
          title,
          channelDescription: 'SiberiaGB: $title',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  /// Reminders take the notification ids from here on.
  static const _firstReminderId = 1000;

  /// Exact alarms until the system refuses them; then inexact ones, which
  /// may come late.
  bool _exactAlarms = true;

  /// Scheduled notifications work on phones; elsewhere there are none.
  bool get _canSchedule =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  }) async {
    if (!_ready || !_canSchedule) return;
    try {
      for (final pending in await _plugin.pendingNotificationRequests()) {
        if (pending.id >= _firstReminderId &&
            pending.id < _firstReminderId + maxTestReminders) {
          await _plugin.cancel(id: pending.id);
        }
      }
    } on Object {
      // A reminder that could not be cancelled is replaced below, by id.
    }
    for (final (index, reminder) in reminders.take(maxTestReminders).indexed) {
      Future<void> schedule() => _plugin.zonedSchedule(
        id: _firstReminderId + index,
        // A point in time, so no time zone database is needed: the local
        // time was turned into it when the reminder was made.
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
        title: reminder.title,
        body: reminder.body,
        payload: SchoolNotificationCategory.events.name,
        androidScheduleMode: _exactAlarms
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'siberiagb_test_reminders',
            channelName,
            channelDescription: 'SiberiaGB: $channelName',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(reminder.body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
      try {
        try {
          await schedule();
        } on PlatformException catch (error) {
          if (!_exactAlarms || error.code != 'exact_alarms_not_permitted') {
            rethrow;
          }
          _exactAlarms = false;
          await schedule();
        }
      } on Object {
        // One reminder that cannot be scheduled leaves the others.
      }
    }
  }

  @override
  Future<SchoolNotificationCategory?> launchCategory() async {
    if (!_ready) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return _categoryFromPayload(details?.notificationResponse?.payload);
    } on Object {
      return null;
    }
  }

  @override
  void onTap(void Function(SchoolNotificationCategory) callback) {
    _tapCallback = callback;
  }

  SchoolNotificationCategory? _categoryFromPayload(String? payload) {
    for (final category in SchoolNotificationCategory.values) {
      if (category.name == payload) return category;
    }
    return null;
  }
}

class SchoolNotificationService {
  SchoolNotificationService(
    this._presenter, {
    Future<SharedPreferences>? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance();

  static const _settingsPrefix = 'school_notifications_v1_';
  static const _seenPrefix = 'school_notifications_seen_v1_';

  final SchoolNotificationPresenter _presenter;
  final Future<SharedPreferences> _preferences;
  Future<void> _reminderUpdates = Future.value();

  Future<void> initialize() => _presenter.initialize();
  Future<bool> requestPermission() => _presenter.requestPermission();
  Future<SchoolNotificationCategory?> launchCategory() =>
      _presenter.launchCategory();
  void onTap(void Function(SchoolNotificationCategory) callback) =>
      _presenter.onTap(callback);

  Future<SchoolNotificationSettings> loadSettings() async {
    final preferences = await _preferences;
    await preferences.reload();
    const defaults = TestReminderSettings();
    int? minutes(String key) {
      final value = preferences.getInt('$_settingsPrefix$key');
      return value != null && value >= 0 && value < 24 * 60 ? value : null;
    }

    return SchoolNotificationSettings(
      enabled: preferences.getBool('${_settingsPrefix}enabled') ?? true,
      categories: {
        for (final category in SchoolNotificationCategory.values)
          category:
              preferences.getBool('$_settingsPrefix${category.name}') ?? true,
      },
      reminders: TestReminderSettings(
        evening:
            preferences.getBool('${_settingsPrefix}reminder_evening') ??
            defaults.evening,
        morning:
            preferences.getBool('${_settingsPrefix}reminder_morning') ??
            defaults.morning,
        eveningMinutes:
            minutes('reminder_evening_minutes') ?? defaults.eveningMinutes,
        morningMinutes:
            minutes('reminder_morning_minutes') ?? defaults.morningMinutes,
        homework:
            preferences.getBool('${_settingsPrefix}reminder_homework') ??
            defaults.homework,
      ),
      attendanceKinds: _chosen(
        preferences.getStringList('${_settingsPrefix}attendance_kinds'),
        AttendanceKind.values,
      ),
      timetableChanges: _chosen(
        preferences.getStringList('${_settingsPrefix}timetable_changes'),
        TimetableChange.values,
      ),
    );
  }

  /// The saved choice, or all of [values] when nothing was saved yet.
  static Set<T> _chosen<T extends Enum>(List<String>? names, List<T> values) =>
      names == null
      ? values.toSet()
      : {
          for (final value in values)
            if (names.contains(value.name)) value,
        };

  Future<void> saveSettings(SchoolNotificationSettings settings) async {
    final preferences = await _preferences;
    await preferences.setBool('${_settingsPrefix}enabled', settings.enabled);
    for (final category in SchoolNotificationCategory.values) {
      await preferences.setBool(
        '$_settingsPrefix${category.name}',
        settings.categories[category] ?? true,
      );
    }
    final reminders = settings.reminders;
    await preferences.setBool(
      '${_settingsPrefix}reminder_evening',
      reminders.evening,
    );
    await preferences.setBool(
      '${_settingsPrefix}reminder_morning',
      reminders.morning,
    );
    await preferences.setInt(
      '${_settingsPrefix}reminder_evening_minutes',
      reminders.eveningMinutes,
    );
    await preferences.setInt(
      '${_settingsPrefix}reminder_morning_minutes',
      reminders.morningMinutes,
    );
    await preferences.setBool(
      '${_settingsPrefix}reminder_homework',
      reminders.homework,
    );
    await preferences.setStringList('${_settingsPrefix}attendance_kinds', [
      for (final kind in settings.attendanceKinds) kind.name,
    ]);
    await preferences.setStringList('${_settingsPrefix}timetable_changes', [
      for (final change in settings.timetableChanges) change.name,
    ]);
  }

  /// Schedules the reminders for the tests in [snapshot] with the saved
  /// settings, replacing the ones scheduled before. Signed out, or with
  /// reminders off, none are left. Updates run one after another, so an
  /// older list can never land last.
  Future<void> updateReminders(AppSnapshot snapshot, {DateTime? now}) {
    final next = _reminderUpdates.then((_) => _updateReminders(snapshot, now));
    _reminderUpdates = next.catchError((Object _) {});
    return next;
  }

  Future<void> _updateReminders(AppSnapshot snapshot, DateTime? now) async {
    final settings = await loadSettings();
    final translations = await _translations();
    final signedIn =
        snapshot.profile.provider == 'Librus Synergia' &&
        snapshot.lastSync.millisecondsSinceEpoch != 0;
    final reminders = signedIn && settings.remindersOn
        ? buildTestReminders(
            snapshot.events,
            settings.reminders,
            now ?? DateTime.now(),
            translations,
          )
        : const <TestReminder>[];
    try {
      await _presenter.scheduleReminders(
        reminders,
        channelName: translations.text('reminders'),
      );
    } on Object {
      // Reminders are best effort, like every notification.
    }
  }

  Future<AppLocalizations> _translations() async {
    final preferences = await _preferences;
    final language =
        preferences.getString('app_locale_v1') ??
        PlatformDispatcher.instance.locale.languageCode;
    return AppLocalizations(Locale(language));
  }

  Future<void> processSnapshot(AppSnapshot snapshot) async {
    if (snapshot.profile.provider != 'Librus Synergia' ||
        snapshot.lastSync.millisecondsSinceEpoch == 0) {
      return;
    }
    final preferences = await _preferences;
    await preferences.reload();
    final settings = await loadSettings();
    final seenKey = '$_seenPrefix${snapshot.profile.id}';
    final translations = await _translations();
    final current = _candidates(snapshot, translations);
    final previous = _readSeen(preferences.getString(seenKey));
    final firstSnapshot = previous == null;
    final updated = <String, List<String>>{};
    final newItems = <SchoolNotificationCategory, List<_Candidate>>{};

    for (final category in SchoolNotificationCategory.values) {
      final existing = previous?[category.name] ?? const <String>[];
      final oldKeys = existing.toSet();
      final items = current[category] ?? const <_Candidate>[];
      newItems[category] = firstSnapshot
          ? const <_Candidate>[]
          : items.where((item) => !oldKeys.contains(item.key)).toList();
      updated[category.name] = {
        ...items.map((item) => item.key),
        ...existing,
      }.take(1000).toList();
    }

    // Muted items are still marked as seen, so enabling a category, or a
    // kind inside it, never replays its entire history.
    await preferences.setString(seenKey, jsonEncode(updated));
    for (final category in SchoolNotificationCategory.values) {
      final items = [
        for (final item in newItems[category]!)
          if (item.wanted?.call(settings) ?? true) item,
      ];
      if (!settings.allows(category) || items.isEmpty) continue;
      final title = translations.text('notification_${category.name}');
      final body = items.length == 1
          ? items.single.body
          : translations
                .text('notificationMultiple')
                .replaceAll('{count}', '${items.length}');
      try {
        await _presenter.show(category: category, title: title, body: body);
      } on Object {
        // Notification delivery is best effort; synchronization still succeeds.
      }
    }
  }

  Map<String, List<String>>? _readSeen(String? raw) {
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in data.entries)
          entry.key: (entry.value as List).whereType<String>().toList(),
      };
    } on Object {
      return null;
    }
  }

  Map<SchoolNotificationCategory, List<_Candidate>> _candidates(
    AppSnapshot snapshot,
    AppLocalizations translations,
  ) => {
    SchoolNotificationCategory.grades: [
      for (final grade in snapshot.grades)
        _Candidate(
          '${grade.id}|${grade.value}',
          '${grade.subject}: ${grade.value}',
        ),
    ],
    SchoolNotificationCategory.messages: [
      for (final message in snapshot.messages)
        _Candidate(message.id, '${message.sender}: ${message.subject}'),
    ],
    SchoolNotificationCategory.announcements: [
      for (final announcement in snapshot.announcements)
        _Candidate(announcement.id, announcement.title),
    ],
    SchoolNotificationCategory.notices: [
      for (final notice in snapshot.notices)
        _Candidate(notice.id, '${notice.teacher}: ${notice.category}'),
    ],
    SchoolNotificationCategory.attendance: [
      for (final record in snapshot.attendance)
        _Candidate(
          '${record.id}|${record.kind.name}',
          '${record.subject}: ${record.type}',
          wanted: (settings) => settings.attendanceKinds.contains(record.kind),
        ),
    ],
    SchoolNotificationCategory.events: [
      for (final event in snapshot.events)
        if (event.kind != EventKind.homework) _Candidate(event.id, event.title),
    ],
    SchoolNotificationCategory.homework: [
      for (final event in snapshot.events)
        if (event.kind == EventKind.homework) _Candidate(event.id, event.title),
    ],
    SchoolNotificationCategory.timetable: [
      for (final lesson in snapshot.lessons)
        if (TimetableChange.of(lesson) case final change?)
          _Candidate(
            '${lesson.id}|${lesson.subject}|${lesson.teacher}|${lesson.room}|${lesson.cancelled}|${lesson.movedTo}',
            // "Matematyka, 21.10: Odwołana lekcja"
            '${lesson.subject}, ${_dayMonth(lesson.start)}: '
                '${translations.text(change.label)}',
            wanted: (settings) => settings.timetableChanges.contains(change),
          ),
    ],
  };

  static String _dayMonth(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}';
}

class _Candidate {
  const _Candidate(this.key, this.body, {this.wanted});
  final String key;
  final String body;

  /// Whether the settings want a notification for it; null means always.
  final bool Function(SchoolNotificationSettings settings)? wanted;
}
