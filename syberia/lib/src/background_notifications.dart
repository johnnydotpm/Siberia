import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'data/app_repository.dart';
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
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
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
      if (!settings.hasEnabledCategory) return true;
      await notifications.initialize();
      final snapshot = await repository.fetchBackgroundSnapshot();
      if (snapshot != null) await notifications.processSnapshot(snapshot);
      return true;
    } on Object {
      // Network and authentication failures must not generate false alerts.
      return true;
    }
  });
}
