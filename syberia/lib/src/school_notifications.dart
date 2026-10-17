import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/models.dart';
import 'l10n/app_localizations.dart';

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

class SchoolNotificationSettings {
  const SchoolNotificationSettings({
    this.enabled = true,
    this.categories = const {},
  });

  final bool enabled;
  final Map<SchoolNotificationCategory, bool> categories;

  bool allows(SchoolNotificationCategory category) =>
      enabled && (categories[category] ?? true);

  bool get hasEnabledCategory =>
      enabled && SchoolNotificationCategory.values.any(allows);

  SchoolNotificationSettings copyWith({
    bool? enabled,
    SchoolNotificationCategory? category,
    bool? categoryEnabled,
  }) => SchoolNotificationSettings(
    enabled: enabled ?? this.enabled,
    categories: category == null
        ? categories
        : {...categories, category: categoryEnabled ?? true},
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

  Future<void> initialize() => _presenter.initialize();
  Future<bool> requestPermission() => _presenter.requestPermission();
  Future<SchoolNotificationCategory?> launchCategory() =>
      _presenter.launchCategory();
  void onTap(void Function(SchoolNotificationCategory) callback) =>
      _presenter.onTap(callback);

  Future<SchoolNotificationSettings> loadSettings() async {
    final preferences = await _preferences;
    await preferences.reload();
    return SchoolNotificationSettings(
      enabled: preferences.getBool('${_settingsPrefix}enabled') ?? true,
      categories: {
        for (final category in SchoolNotificationCategory.values)
          category:
              preferences.getBool('$_settingsPrefix${category.name}') ?? true,
      },
    );
  }

  Future<void> saveSettings(SchoolNotificationSettings settings) async {
    final preferences = await _preferences;
    await preferences.setBool('${_settingsPrefix}enabled', settings.enabled);
    for (final category in SchoolNotificationCategory.values) {
      await preferences.setBool(
        '$_settingsPrefix${category.name}',
        settings.categories[category] ?? true,
      );
    }
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
    final current = _candidates(snapshot);
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

    // Muted items are still marked as seen, so enabling a category never
    // replays its entire history.
    await preferences.setString(seenKey, jsonEncode(updated));
    final language =
        preferences.getString('app_locale_v1') ??
        PlatformDispatcher.instance.locale.languageCode;
    final translations = AppLocalizations(Locale(language));
    for (final category in SchoolNotificationCategory.values) {
      final items = newItems[category]!;
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
        if (lesson.substitution || lesson.cancelled || lesson.movedTo != null)
          _Candidate(
            '${lesson.id}|${lesson.subject}|${lesson.teacher}|${lesson.room}|${lesson.cancelled}|${lesson.movedTo}',
            lesson.subject,
          ),
    ],
  };
}

class _Candidate {
  const _Candidate(this.key, this.body);
  final String key;
  final String body;
}
