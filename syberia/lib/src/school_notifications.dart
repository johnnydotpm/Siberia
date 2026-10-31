import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'domain/models.dart';
import 'domain/profiles.dart';
import 'homework_done.dart';
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

/// What a tap on a notification opens: a part of the app, in the profile
/// the notification is about when it names one.
@immutable
class NotificationTarget {
  const NotificationTarget(this.category, {this.profileId});

  final SchoolNotificationCategory category;
  final String? profileId;

  /// `grades`, or `grades|` and the profile's id.
  String get payload =>
      profileId == null ? category.name : '${category.name}|$profileId';

  static NotificationTarget? parse(String? payload) {
    if (payload == null) return null;
    final split = payload.indexOf('|');
    final name = split < 0 ? payload : payload.substring(0, split);
    final profile = split < 0 ? null : payload.substring(split + 1);
    for (final category in SchoolNotificationCategory.values) {
      if (category.name == name) {
        return NotificationTarget(
          category,
          profileId: profile == null || profile.isEmpty ? null : profile,
        );
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationTarget &&
      other.category == category &&
      other.profileId == profileId;

  @override
  int get hashCode => Object.hash(category, profileId);
}

/// The number of a notification of [category] about the profile in [slot]:
/// each profile has ten, and the first profile keeps the numbers 1 to 8 it
/// had before profiles. Reminders start at 1000.
int notificationId(SchoolNotificationCategory category, {int slot = 0}) =>
    1 + slot * 10 + category.index;

/// The name in front of [profile]'s notifications: with more than one of
/// [profiles] on the phone, or on a parent's profile, whose child it names.
String? notificationName(SchoolProfile profile, List<SchoolProfile> profiles) =>
    profiles.length > 1 || profile.usedBy == ProfileRole.parent
    ? profile.displayName
    : null;

/// The id of the evening summary of the profile in [slot], after the
/// categories' own.
int digestNotificationId({int slot = 0}) => 9 + slot * 10;

/// One profile's data for the test reminders. [name] goes in front of the
/// titles when the phone has more than one profile.
class ReminderSource {
  const ReminderSource(this.snapshot, {this.profile, this.name});

  final AppSnapshot snapshot;
  final SchoolProfile? profile;
  final String? name;
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
    this.quietHours = false,
    this.quietFromMinutes = 21 * 60,
    this.quietToMinutes = 7 * 60,
    this.digest = false,
    this.digestMinutes = 19 * 60,
  });

  /// What a parent hears of: grades, absences and lateness, notes,
  /// messages, announcements, events and lessons that do not take place; no
  /// homework and no test reminders, and nothing loud at night.
  static const parentDefaults = SchoolNotificationSettings(
    categories: {SchoolNotificationCategory.homework: false},
    reminders: TestReminderSettings(evening: false),
    attendanceKinds: {AttendanceKind.absent, AttendanceKind.late},
    timetableChanges: {TimetableChange.cancelled, TimetableChange.moved},
    quietHours: true,
  );

  /// Whether notifications come without sound between [quietFromMinutes]
  /// and [quietToMinutes], minutes after midnight.
  final bool quietHours;
  final int quietFromMinutes;
  final int quietToMinutes;

  /// Whether the news of a day comes as one summary per profile at
  /// [digestMinutes] instead of a notification each.
  final bool digest;
  final int digestMinutes;

  /// Whether a notification at [now] comes without sound. The hours may
  /// run past midnight, as from 21:00 to 7:00.
  bool isQuiet(DateTime now) {
    if (!quietHours || quietFromMinutes == quietToMinutes) return false;
    final minutes = now.hour * 60 + now.minute;
    return quietFromMinutes < quietToMinutes
        ? minutes >= quietFromMinutes && minutes < quietToMinutes
        : minutes >= quietFromMinutes || minutes < quietToMinutes;
  }

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

  /// Whether every kind of notification is on and the reminders are as they
  /// come: "all" in the setup.
  bool get everything =>
      enabled &&
      SchoolNotificationCategory.values.every(
        (category) => categories[category] ?? true,
      ) &&
      attendanceKinds.length == AttendanceKind.values.length &&
      timetableChanges.length == TimetableChange.values.length &&
      reminders == const TestReminderSettings();

  /// "All" in the setup: [everything] for a student, and the
  /// [parentDefaults] for a [parent].
  bool isAllFor({required bool parent}) {
    if (!parent) return everything;
    const all = parentDefaults;
    return enabled &&
        SchoolNotificationCategory.values.every(
          (category) =>
              (categories[category] ?? true) ==
              (all.categories[category] ?? true),
        ) &&
        setEquals(attendanceKinds, all.attendanceKinds) &&
        setEquals(timetableChanges, all.timetableChanges) &&
        reminders == all.reminders;
  }

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
    bool? quietHours,
    int? quietFromMinutes,
    int? quietToMinutes,
    bool? digest,
    int? digestMinutes,
  }) => SchoolNotificationSettings(
    enabled: enabled ?? this.enabled,
    categories: category == null
        ? categories
        : {...categories, category: categoryEnabled ?? true},
    reminders: reminders ?? this.reminders,
    attendanceKinds: attendanceKinds ?? this.attendanceKinds,
    timetableChanges: timetableChanges ?? this.timetableChanges,
    quietHours: quietHours ?? this.quietHours,
    quietFromMinutes: quietFromMinutes ?? this.quietFromMinutes,
    quietToMinutes: quietToMinutes ?? this.quietToMinutes,
    digest: digest ?? this.digest,
    digestMinutes: digestMinutes ?? this.digestMinutes,
  );
}

abstract class SchoolNotificationPresenter {
  Future<void> initialize();
  Future<bool> requestPermission();

  /// Shows a notification of [category]. [id] replaces an earlier one with
  /// the same number; [target] is what a tap opens; [channelName] names the
  /// category in the system settings. Each falls back to the category. A
  /// [silent] one comes without sound or vibration.
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
    int? id,
    NotificationTarget? target,
    String? channelName,
    bool silent = false,
  });

  /// What the notification that opened the app points to, if one did.
  Future<NotificationTarget?> launchTarget();
  void onTap(void Function(NotificationTarget target) callback);

  /// Replaces every scheduled reminder with [reminders]; an empty list
  /// cancels them all.
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  });

  /// The reminders the phone holds, as "title: body", for the debug menu.
  Future<List<String>> scheduledReminders();
}

class FlutterSchoolNotificationPresenter
    implements SchoolNotificationPresenter {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  void Function(NotificationTarget)? _tapCallback;
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
          final target = NotificationTarget.parse(response.payload);
          if (target != null) _tapCallback?.call(target);
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
    int? id,
    NotificationTarget? target,
    String? channelName,
    bool silent = false,
  }) async {
    if (!_ready) return;
    final channel = channelName ?? title;
    await _plugin.show(
      id: id ?? notificationId(category),
      title: title,
      body: body,
      payload: (target ?? NotificationTarget(category)).payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'siberiagb_${category.name}',
          channel,
          channelDescription: 'SiberiaGB: $channel',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          silent: silent,
        ),
        iOS: DarwinNotificationDetails(presentSound: !silent),
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
        payload: NotificationTarget(
          SchoolNotificationCategory.events,
          profileId: reminder.profileId,
        ).payload,
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
  Future<List<String>> scheduledReminders() async {
    if (!_ready || !_canSchedule) return const [];
    return [
      for (final pending in await _plugin.pendingNotificationRequests())
        if (pending.id >= _firstReminderId &&
            pending.id < _firstReminderId + maxTestReminders)
          '${pending.title ?? ''}: ${pending.body ?? ''}',
    ];
  }

  @override
  Future<NotificationTarget?> launchTarget() async {
    if (!_ready) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return NotificationTarget.parse(details?.notificationResponse?.payload);
    } on Object {
      return null;
    }
  }

  @override
  void onTap(void Function(NotificationTarget) callback) {
    _tapCallback = callback;
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
  Future<NotificationTarget?> launchTarget() => _presenter.launchTarget();
  void onTap(void Function(NotificationTarget) callback) =>
      _presenter.onTap(callback);

  /// Notification ids from here on are the debug menu's samples.
  static const _firstSampleId = 900;

  /// A sample of [category]'s notification, in that category's channel, for
  /// the debug menu; it replaces the category's previous sample.
  Future<void> showSample(SchoolNotificationCategory category) async {
    final title = (await _translations()).text('notification_${category.name}');
    await _presenter.show(
      category: category,
      title: title,
      body: 'A test notification from the debug menu.',
      id: _firstSampleId + category.index,
      target: NotificationTarget(category),
      channelName: title,
    );
  }

  /// The test reminders the phone holds now.
  Future<List<String>> scheduledReminders() => _presenter.scheduledReminders();

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
      quietHours: preferences.getBool('${_settingsPrefix}quiet_hours') ?? false,
      quietFromMinutes: minutes('quiet_from_minutes') ?? 21 * 60,
      quietToMinutes: minutes('quiet_to_minutes') ?? 7 * 60,
      digest: preferences.getBool('${_settingsPrefix}digest') ?? false,
      digestMinutes: minutes('digest_minutes') ?? 19 * 60,
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
    await preferences.setBool(
      '${_settingsPrefix}quiet_hours',
      settings.quietHours,
    );
    await preferences.setInt(
      '${_settingsPrefix}quiet_from_minutes',
      settings.quietFromMinutes,
    );
    await preferences.setInt(
      '${_settingsPrefix}quiet_to_minutes',
      settings.quietToMinutes,
    );
    await preferences.setBool('${_settingsPrefix}digest', settings.digest);
    await preferences.setInt(
      '${_settingsPrefix}digest_minutes',
      settings.digestMinutes,
    );
  }

  /// Schedules the reminders for the tests in [snapshot] with the saved
  /// settings, replacing the ones scheduled before. Signed out, or with
  /// reminders off, none are left.
  Future<void> updateReminders(AppSnapshot snapshot, {DateTime? now}) =>
      updateAllReminders([ReminderSource(snapshot)], now: now);

  /// Schedules the reminders for the tests of every profile in [sources]
  /// as one list, the soonest first, replacing the ones scheduled before.
  /// Updates run one after another, so an older list can never land last.
  Future<void> updateAllReminders(
    List<ReminderSource> sources, {
    DateTime? now,
  }) {
    final next = _reminderUpdates.then((_) => _updateReminders(sources, now));
    _reminderUpdates = next.catchError((Object _) {});
    return next;
  }

  Future<void> _updateReminders(
    List<ReminderSource> sources,
    DateTime? now,
  ) async {
    final settings = await loadSettings();
    final translations = await _translations();
    final preferences = await _preferences;
    final reminders = <TestReminder>[];
    for (final source in sources) {
      final snapshot = source.snapshot;
      final signedIn =
          snapshot.profile.provider == 'Librus Synergia' &&
          snapshot.lastSync.millisecondsSinceEpoch != 0;
      if (!signedIn || !settings.remindersOn) continue;
      final profile = source.profile;
      // Homework the student marked as done is not reminded of.
      final done = HomeworkDoneStore.read(
        preferences,
        key: profile == null
            ? HomeworkDoneStore.key
            : HomeworkDoneStore.keyFor(profile.id),
      );
      final name = source.name;
      for (final reminder in buildTestReminders(
        snapshot.events.where(
          (event) =>
              event.kind != EventKind.homework || !done.containsKey(event.id),
        ),
        settings.reminders,
        now ?? DateTime.now(),
        translations,
      )) {
        reminders.add(
          TestReminder(
            at: reminder.at,
            title: name == null ? reminder.title : '$name · ${reminder.title}',
            body: reminder.body,
            profileId: profile?.id,
          ),
        );
      }
    }
    reminders.sort((a, b) => a.at.compareTo(b.at));
    try {
      await _presenter.scheduleReminders(
        reminders.take(maxTestReminders).toList(growable: false),
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

  /// Notifies of what is new in [snapshot] since the last one of its
  /// profile. [profile] keeps the profile's notifications and what it has
  /// seen apart from the others'; [name] goes in front of the titles when
  /// the phone has more than one profile. True when something new came that
  /// the settings want to hear of.
  ///
  /// A [quiet] profile, with notifications off, only marks what it saw.
  Future<bool> processSnapshot(
    AppSnapshot snapshot, {
    SchoolProfile? profile,
    String? name,
    bool quiet = false,
    DateTime? now,
  }) async {
    if (snapshot.profile.provider != 'Librus Synergia' ||
        snapshot.lastSync.millisecondsSinceEpoch == 0) {
      return false;
    }
    final preferences = await _preferences;
    await preferences.reload();
    final settings = await loadSettings();
    // Before profiles, what was seen was kept by the student's id; it moves
    // to the profile's own key.
    final studentKey = '$_seenPrefix${snapshot.profile.id}';
    final seenKey = profile == null ? studentKey : '$_seenPrefix${profile.id}';
    final translations = await _translations();
    final current = _candidates(snapshot, translations);
    final previous = _readSeen(
      preferences.getString(seenKey) ?? preferences.getString(studentKey),
    );
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
    if (seenKey != studentKey) await preferences.remove(studentKey);
    if (quiet) return false;
    final at = now ?? DateTime.now();
    final silent = settings.isQuiet(at);
    // Summed up in the evening instead, when the user wants it so.
    final summary = settings.digest && profile != null
        ? _readDigest(preferences, profile.id)
        : null;
    var found = false;
    for (final category in SchoolNotificationCategory.values) {
      final items = [
        for (final item in newItems[category]!)
          if (item.wanted?.call(settings) ?? true) item,
      ];
      if (!settings.allows(category) || items.isEmpty) continue;
      found = true;
      if (summary != null) {
        summary[category.name] = (summary[category.name] ?? 0) + items.length;
        continue;
      }
      final title = translations.text('notification_${category.name}');
      final body = items.length == 1
          ? items.single.body
          : translations.plural(items.length, 'newEntries');
      try {
        await _presenter.show(
          category: category,
          title: name == null ? title : '$name · $title',
          body: body,
          id: notificationId(category, slot: profile?.slot ?? 0),
          target: NotificationTarget(category, profileId: profile?.id),
          channelName: title,
          silent: silent,
        );
      } on Object {
        // Notification delivery is best effort; synchronization still succeeds.
      }
    }
    if (summary != null && summary.isNotEmpty) {
      await preferences.setString(
        '$_digestPrefix${profile!.id}',
        jsonEncode({'day': _day(at), 'counts': summary}),
      );
    }
    return found;
  }

  static const _digestPrefix = 'school_notifications_digest_v1_';

  static String _day(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';

  /// The counts of the day's news kept for the summary of [profileId]; a
  /// summary of an earlier day not delivered yet goes on.
  Map<String, int> _readDigest(
    SharedPreferences preferences,
    String profileId,
  ) {
    final raw = preferences.getString('$_digestPrefix$profileId');
    if (raw == null) return {};
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final MapEntry(:key, :value)
            in (data['counts'] as Map<String, dynamic>).entries)
          if (value is int) key: value,
      };
    } on Object {
      return {};
    }
  }

  /// Shows the evening summary of each of [profiles] whose time has come:
  /// once [SchoolNotificationSettings.digestMinutes] passed on its day, on
  /// any later day, or at once when summaries were turned off meanwhile.
  /// [name] goes in front of the title, as in the other notifications.
  Future<void> deliverDigests(
    Iterable<SchoolProfile> profiles, {
    String? Function(SchoolProfile profile)? name,
    DateTime? now,
  }) async {
    final preferences = await _preferences;
    await preferences.reload();
    final settings = await loadSettings();
    final at = now ?? DateTime.now();
    final minutes = at.hour * 60 + at.minute;
    AppLocalizations? translations;
    for (final profile in profiles) {
      final key = '$_digestPrefix${profile.id}';
      final raw = preferences.getString(key);
      if (raw == null) continue;
      Map<String, dynamic> data;
      try {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } on Object {
        await preferences.remove(key);
        continue;
      }
      final due =
          !settings.digest ||
          data['day'] != _day(at) ||
          minutes >= settings.digestMinutes;
      if (!due) continue;
      await preferences.remove(key);
      final counts = data['counts'];
      if (counts is! Map) continue;
      translations ??= await _translations();
      final parts = [
        for (final category in SchoolNotificationCategory.values)
          if (counts[category.name] case final int count when count > 0)
            (
              category,
              '${translations.text('notification_${category.name}')} $count',
            ),
      ];
      if (parts.isEmpty) continue;
      final title = translations.text('digestTitle');
      final who = name?.call(profile);
      try {
        await _presenter.show(
          category: parts.first.$1,
          title: who == null ? title : '$who · $title',
          body: parts.map((part) => part.$2).join(' · '),
          id: digestNotificationId(slot: profile.slot),
          target: NotificationTarget(parts.first.$1, profileId: profile.id),
          channelName: title,
          silent: settings.isQuiet(at),
        );
      } on Object {
        // Best effort, as the other notifications.
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
          record.subject.isEmpty
              ? record.type
              : '${record.subject}: ${record.type}',
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
