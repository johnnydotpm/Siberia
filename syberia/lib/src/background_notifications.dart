import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'data/app_repository.dart';
import 'data/librus/librus_client.dart';
import 'domain/profiles.dart';
import 'school_notifications.dart';

const _taskId = 'siberiagb_librus_notification_check';

Future<void> initializeBackgroundNotifications() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }
  await Workmanager().initialize(schoolNotificationCallbackDispatcher);
}

Future<void> configureBackgroundNotifications(bool enabled) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  if (!enabled) {
    await Workmanager().cancelByUniqueName(_taskId);
    return;
  }
  await Workmanager().registerPeriodicTask(
    _taskId,
    _taskId,
    frequency: const Duration(minutes: 30),
    // Updating the existing task also brings it the battery rule.
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
  );
}

@pragma('vm:entry-point')
void schoolNotificationCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != _taskId && task != Workmanager.iOSBackgroundTask) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      final repository = AppRepository();
      if (!await repository.loadAutoSyncOnOpen()) return true;
      final notifications = SchoolNotificationService(
        FlutterSchoolNotificationPresenter(),
      );
      final settings = await notifications.loadSettings();
      if (!settings.needsBackgroundCheck) return true;
      await notifications.initialize();
      await checkProfilesInBackground(repository, notifications, settings);
      return true;
    } on Object {
      // Network and authentication failures must not generate false alerts.
      return true;
    }
  });
}

/// Fetches every profile with notifications on and notifies of what is new
/// in each. News of a profile other than the open one puts a dot on it.
/// The test reminders of all profiles are scheduled again after a fetch.
@visibleForTesting
Future<void> checkProfilesInBackground(
  AppRepository repository,
  SchoolNotificationService notifications,
  SchoolNotificationSettings settings,
) async {
  final checked = await repository.fetchBackgroundSnapshots(
    parts: backgroundParts(settings),
  );
  if (checked.isEmpty) return;
  final profiles = await repository.loadProfiles();
  final open = repository.activeProfile;
  String? name(SchoolProfile profile) =>
      profiles.length > 1 ? profile.displayName : null;
  for (final (profile, snapshot) in checked) {
    final news = await notifications.processSnapshot(
      snapshot,
      profile: profile,
      name: name(profile),
    );
    if (news && profile.id != open?.id) {
      await repository.setProfileNews(profile.id, true);
    }
  }
  await notifications.updateAllReminders([
    for (final (profile, snapshot) in await repository.notifyingSnapshots())
      ReminderSource(snapshot, profile: profile, name: name(profile)),
  ]);
}

/// What the background check downloads: only what a notification or the
/// test reminders are on for.
@visibleForTesting
Set<LibrusPart> backgroundParts(SchoolNotificationSettings settings) => {
  if (settings.allows(SchoolNotificationCategory.grades)) LibrusPart.grades,
  if (settings.allows(SchoolNotificationCategory.messages)) LibrusPart.messages,
  if (settings.allows(SchoolNotificationCategory.announcements))
    LibrusPart.announcements,
  if (settings.allows(SchoolNotificationCategory.notices)) LibrusPart.notices,
  if (settings.allows(SchoolNotificationCategory.attendance))
    LibrusPart.attendance,
  // Events and homework arrive in one list, so they come together. The
  // reminders need them to know about new tests.
  if (settings.allows(SchoolNotificationCategory.events) ||
      settings.allows(SchoolNotificationCategory.homework) ||
      settings.remindersOn) ...[
    LibrusPart.events,
    LibrusPart.homework,
  ],
  if (settings.allows(SchoolNotificationCategory.timetable))
    LibrusPart.timetable,
};
