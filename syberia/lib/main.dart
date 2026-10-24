import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'src/background_notifications.dart';
import 'src/data/app_repository.dart';
import 'src/frame_rate.dart';
import 'src/home_widget.dart';
import 'src/school_notifications.dart';
import 'src/state/app_controller.dart';
import 'src/startup.dart';
import 'src/ui/home_widget_settings.dart';
import 'src/ui/glass/glass_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    FrameRateBooster().start();
  }
  final repository = AppRepository();
  runApp(
    StartupApp(
      initialize: () => _initializeApplication(repository),
      preferences: repository,
    ),
  );
}

/// Opens on the saved data. Steps that do not depend on each other run
/// together, and the Librus sync starts afterwards, without holding the app.
Future<AppController> _initializeApplication(AppRepository repository) async {
  final notifications = SchoolNotificationService(
    FlutterSchoolNotificationPresenter(),
  );
  final controller = AppController(
    repository,
    notifications: notifications,
    backgroundScheduling: configureBackgroundNotifications,
    homeWidget: const HomeWidgetBridge(),
  );
  notifications.onTap(
    (target) => unawaited(controller.openNotification(target)),
  );
  try {
    await Future.wait([
      if (defaultTargetPlatform == TargetPlatform.android)
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
      _initializeBackground(),
      GlassPlatform.ensureInitialized(),
      // The snapshot may raise notifications, so the plugin comes first.
      notifications.initialize().then((_) => controller.bootstrap()),
    ]);
    final launchTarget = await notifications.launchTarget();
    if (launchTarget != null) await controller.openNotification(launchTarget);
  } on Object {
    controller.dispose();
    rethrow;
  }
  unawaited(controller.startAutoSync());
  unawaited(controller.configureBackground());
  if (!kIsWeb) {
    unawaited(controller.requestNotificationPermissionIfEnabled());
  }
  return controller;
}

Future<void> _initializeBackground() async {
  try {
    await initializeBackgroundNotifications();
  } on Object {
    // The app still supports manual synchronization on unsupported devices.
  }
}

/// Runs the setup screen the launcher opens for a newly placed Android
/// widget, in its own activity (see WidgetConfigActivity.kt).
@pragma('vm:entry-point')
Future<void> widgetConfigMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const bridge = HomeWidgetBridge();
  final repository = AppRepository();
  final languageCode = await repository.loadLocale();
  final colorMode = await repository.loadColorMode();
  final profiles = await repository.loadProfiles();
  final defaultProfile = await repository.loadWidgetProfile();
  final widgetId = await bridge.configuringWidgetId();
  if (widgetId == null) {
    await bridge.finishConfiguring();
    return;
  }
  runApp(
    HomeWidgetConfigApp(
      bridge: bridge,
      widgetId: widgetId,
      locale: languageCode == null ? null : Locale(languageCode),
      colorMode: colorMode,
      profiles: profiles,
      defaultProfileId: defaultProfile,
    ),
  );
}
