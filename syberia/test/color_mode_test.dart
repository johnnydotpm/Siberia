import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'}),
  );

  testWidgets(
    'defaults to the phone theme, supports overrides and persists AMOLED',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final repository = AppRepository();
      final controller = AppController(repository, updatesEnabled: false);
      await controller.bootstrap();
      expect(controller.colorMode, AppColorMode.system);
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();

      ThemeData currentTheme() =>
          Theme.of(tester.element(find.byType(Scaffold).first));
      expect(currentTheme().brightness, Brightness.dark);

      await controller.setColorMode(AppColorMode.light);
      await tester.pumpAndSettle();
      expect(currentTheme().brightness, Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await controller.setColorMode(AppColorMode.dark);
      await tester.pumpAndSettle();
      expect(currentTheme().brightness, Brightness.dark);
      expect(currentTheme().scaffoldBackgroundColor, isNot(Colors.black));

      await controller.setColorMode(AppColorMode.amoled);
      await tester.pumpAndSettle();
      expect(currentTheme().brightness, Brightness.dark);
      expect(currentTheme().scaffoldBackgroundColor, Colors.black);
      expect(currentTheme().colorScheme.surface, Colors.black);
      expect(currentTheme().colorScheme.surfaceContainerHigh, Colors.black);
      expect(currentTheme().cardTheme.color, Colors.black);
      expect(currentTheme().navigationBarTheme.backgroundColor, Colors.black);
      final restored = AppController(AppRepository(), updatesEnabled: false);
      await restored.bootstrap();
      expect(restored.colorMode, AppColorMode.amoled);

      await controller.setColorMode(AppColorMode.system);
      await tester.pumpAndSettle();
      expect(currentTheme().brightness, Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(currentTheme().brightness, Brightness.dark);
    },
  );

  testWidgets(
    'settings expose all four modes and apply a selection immediately',
    (tester) async {
      final repository = _SignedInRepository();
      final controller = AppController(repository, updatesEnabled: false);
      await controller.bootstrap();
      controller.selectTab(9);
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      final amoled = find.byKey(const ValueKey('settings-theme-amoled'));
      await tester.scrollUntilVisible(amoled, 300);
      expect(find.text('Phone theme'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      await tester.tap(amoled);
      await tester.pumpAndSettle();
      expect(controller.colorMode, AppColorMode.amoled);
      expect(await repository.loadColorMode(), AppColorMode.amoled);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SignedInRepository extends AppRepository {
  @override
  Future<AppSnapshot> load() async => AppSnapshot(
    profile: const StudentProfile(
      id: 'test',
      name: 'Test',
      school: 'School',
      provider: 'Librus Synergia',
    ),
    lessons: const [],
    grades: const [],
    events: const [],
    messages: const [],
    attendance: const [],
    announcements: const [],
    notices: const [],
    lastSync: DateTime.now(),
  );
}
