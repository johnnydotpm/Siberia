import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/home_widget.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/theme/wallpaper_colors.dart';

import 'support/profile_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final onAndroid = TargetPlatformVariant.only(TargetPlatform.android);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WallpaperColors.ask = () async => {'seed': 0xFF4A7C45};
  });

  tearDown(() => WallpaperColors.ask = () async => null);

  Future<(AppController, _Bridge)> start(AppDesign design) async {
    final bridge = _Bridge();
    final repository = _Repository();
    await repository.saveDesign(design);
    final controller = AppController(
      repository,
      updatesEnabled: false,
      homeWidget: bridge,
    );
    await controller.bootstrap();
    // As main() does before the first frame.
    await controller.refreshWallpaperColors();
    return (controller, bridge);
  }

  testWidgets('widgets not set up take the wallpaper colours with the app', (
    tester,
  ) async {
    final (controller, bridge) = await start(AppDesign.expressive);
    expect(controller.widgetDefaultTheme, HomeWidgetTheme.system);
    // Told once the colours are known, never first in the brand colour.
    expect(bridge.defaults, [HomeWidgetTheme.system]);

    await controller.setUseWallpaperColors(false);
    expect(bridge.defaults.last, HomeWidgetTheme.brand);
    await controller.setUseWallpaperColors(true);
    expect(bridge.defaults.last, HomeWidgetTheme.system);

    // The same again is not sent again.
    await controller.refreshWallpaperColors();
    expect(bridge.defaults, hasLength(3));
  }, variant: onAndroid);

  testWidgets('other designs keep the brand colour', (tester) async {
    final (controller, bridge) = await start(AppDesign.classic);
    expect(bridge.defaults, [HomeWidgetTheme.brand]);
    await controller.setDesign(AppDesign.expressive);
    expect(bridge.defaults.last, HomeWidgetTheme.system);
  }, variant: onAndroid);

  testWidgets('without wallpaper colours the brand colour stays', (
    tester,
  ) async {
    WallpaperColors.ask = () async => null;
    final (controller, bridge) = await start(AppDesign.expressive);
    expect(controller.widgetDefaultTheme, HomeWidgetTheme.brand);
    expect(bridge.defaults, [HomeWidgetTheme.brand]);
  }, variant: onAndroid);

  test('a widget not set up gets the default theme Android stored', () {
    final config = HomeWidgetConfig.fromJson({'theme': 'system'});
    expect(config.theme, HomeWidgetTheme.system);
    expect(config.showRoom, const HomeWidgetConfig().showRoom);
  });
}

class _Bridge extends HomeWidgetBridge {
  final defaults = <HomeWidgetTheme>[];

  @override
  Future<void> setDefaultTheme(HomeWidgetTheme theme) async =>
      defaults.add(theme);

  @override
  Future<void> update(
    String payload, {
    Map<String, String> profiles = const {},
  }) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<PlacedHomeWidget>> placedWidgets() async => const [];
}

class _Repository extends AppRepository {
  @override
  Future<AppSnapshot> load() async => studentSnapshot('s1', 'a');

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}
