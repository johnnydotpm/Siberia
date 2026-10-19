import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/ui/brand_logo.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_items.dart';
import 'package:syberia/src/ui/glass/glass_plate.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';
import 'package:syberia/src/ui/glass/native_tab_bar.dart';
import 'package:syberia/src/ui/glass/rendered_glass_surface.dart';
import 'package:syberia/src/ui/glass/rendered_tab_bar.dart';

const _tabBar = 'siberia/glass_tab_bar';
const _barButtons = 'siberia/glass_bar_buttons';
const _surface = 'siberia/glass_surface';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final onIos = TargetPlatformVariant.only(TargetPlatform.iOS);
  final onAndroid = TargetPlatformVariant.only(TargetPlatform.android);

  /// The views UIKit was asked to create, by identifier.
  final created = <int, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    created.clear();
    GlassPlatform.debugSetBackend(GlassBackend.uikit);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map;
        created[arguments['id'] as int] = arguments['viewType'] as String;
      }
      return null;
    });
  });

  tearDown(() {
    GlassPlatform.debugSetBackend(GlassBackend.none);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  /// Delivers a call from UIKit to the newest view of [viewType].
  Future<void> fromNative(
    String viewType,
    String method, [
    Object? arguments,
  ]) async {
    final id = created.entries
        .lastWhere((entry) => entry.value == viewType)
        .key;
    await messenger.handlePlatformMessage(
      '$viewType/$id',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
  }

  /// Gives the test view an iPhone's notch and home indicator.
  void useIphoneInsets(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
  }

  /// Gives the test view an Android phone's status bar and, at the bottom,
  /// its gesture handle or a taller bar of system buttons.
  void useAndroidInsets(WidgetTester tester, {double bottom = 24}) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: 40, bottom: bottom);
    tester.view.viewPadding = FakeViewPadding(top: 40, bottom: bottom);
    addTearDown(tester.view.reset);
  }

  /// A tab's label in the bar that Flutter draws.
  Finder tabLabel(String text) => find
      .descendant(
        of: find.byType(RenderedGlassTabBar),
        matching: find.text(text),
      )
      .first;

  /// A button of the top bar that Flutter draws.
  Finder barButton(String id) => find.byKey(ValueKey('glass-bar-button-$id'));

  Future<AppController> pumpApp(WidgetTester tester, {int messages = 1}) async {
    final controller = AppController(
      _Repository(_snapshot(messages)),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('the glass design hosts the bars in UIKit', (tester) async {
    useIphoneInsets(tester);
    final controller = await pumpApp(tester);

    expect(created.values, containsAll([_barButtons, _tabBar]));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);

    // The page opens with a large title below the bar's own row.
    final largeTitle = tester.getRect(find.text('Today').first);
    expect(largeTitle.top, greaterThanOrEqualTo(59 + 44));
    expect(largeTitle.left, 16);

    // The buttons report the bar UIKit gives them, and the page follows.
    await fromNative(_barButtons, 'metrics', {
      'height': 126.0,
      'inset': 36.0,
      'center': 22.0,
    });
    await tester.pumpAndSettle();
    expect(GlassPlatform.metrics.value.navigationBarHeight, 54);
    expect(
      tester.getRect(find.text('Today').first).top,
      greaterThanOrEqualTo(59 + 54),
    );

    // The bar's own title lines up with the buttons, not with the bar.
    await fromNative(_tabBar, 'select', 1);
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('Timetable')).dy, 59 + 22);

    await fromNative(_tabBar, 'select', 2);
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 2);

    // The bar reports its real size, including the bottom safe area.
    await fromNative(_tabBar, 'metrics', {'height': 110.0, 'headroom': 16.0});
    await tester.pumpAndSettle();
    expect(GlassPlatform.metrics.value.tabBarHeight, 60);
    expect(tester.getSize(find.byType(NativeGlassTabBar)).height, 110);
  }, variant: onIos);

  testWidgets('glass bar buttons open the menu and the account sheet', (
    tester,
  ) async {
    useIphoneInsets(tester);
    await pumpApp(tester);

    await fromNative(_barButtons, 'tap', 'menu');
    await tester.pumpAndSettle();
    expect(find.text('SiberiaGB'), findsOneWidget);
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.byType(AppLogo), findsNothing);
    expect(created.values, contains(_surface));

    tester.state<ScaffoldState>(find.byType(Scaffold)).closeDrawer();
    await tester.pumpAndSettle();
    int surfaces() => created.values.where((type) => type == _surface).length;
    final menuSurfaces = surfaces();

    await fromNative(_barButtons, 'tap', 'account');
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    // A compact sheet is a glass panel of its own.
    expect(surfaces(), menuSurfaces + 1);
  }, variant: onIos);

  testWidgets('the compose button moves into the glass top bar', (
    tester,
  ) async {
    useIphoneInsets(tester);
    final controller = await pumpApp(tester);

    controller.selectTab(5);
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsNothing);
    expect(find.text('Test message'), findsOneWidget);

    await fromNative(_barButtons, 'tap', 'compose');
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsOneWidget);
  }, variant: onIos);

  testWidgets('tapping the open tab again scrolls its page to the top', (
    tester,
  ) async {
    useIphoneInsets(tester);
    final controller = await pumpApp(tester, messages: 20);

    await fromNative(_tabBar, 'select', 3);
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 5);

    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(list).position;
    expect(position.pixels, greaterThan(0));

    await fromNative(_tabBar, 'select', 3);
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(controller.tabIndex, 5);
  }, variant: onIos);

  testWidgets('the design can be switched back to classic in settings', (
    tester,
  ) async {
    useIphoneInsets(tester);
    final controller = await pumpApp(tester);

    controller.selectTab(9);
    await tester.pumpAndSettle();
    final classic = find.byKey(const ValueKey('settings-design-classic'));
    await tester.scrollUntilVisible(
      classic,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Glass'), findsOneWidget);
    await tester.tap(classic);
    await tester.pumpAndSettle();

    expect(controller.design, AppDesign.classic);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  }, variant: onIos);

  testWidgets('without platform support the design is classic and fixed', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.none);
    final controller = await pumpApp(tester);

    expect(controller.design, AppDesign.glass);
    expect(created, isEmpty);
    expect(find.byType(NavigationBar), findsOneWidget);

    controller.selectTab(9);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Librus account'), 200);
    expect(find.text('Design'), findsNothing);
  }, variant: onIos);

  testWidgets('where the system has no glass, Flutter draws the bars', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    useAndroidInsets(tester);
    final controller = await pumpApp(tester);

    expect(created, isEmpty);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);

    // The page opens with a large title below a bar as tall as iOS 26's.
    final largeTitle = tester.getRect(find.text('Today').first);
    expect(largeTitle.top, greaterThanOrEqualTo(40 + 54));
    expect(largeTitle.left, 16);

    // The buttons have the sizes and places iOS 26 gives them: a lone button
    // is a circle, and two that share a capsule sit 56 points apart.
    expect(
      tester.getRect(barButton('menu')),
      // The glass that carries the button is laid out a hair off whole
      // points.
      rectMoreOrLessEquals(const Rect.fromLTWH(16, 40, 44, 44), epsilon: 0.01),
    );
    double symbol(String id) => tester
        .getCenter(
          find.descendant(of: barButton(id), matching: find.byType(Icon)),
        )
        .dx;
    expect(symbol('sync'), moreOrLessEquals(402 - 16 - 24 - 56, epsilon: 0.01));
    expect(symbol('account'), moreOrLessEquals(402 - 16 - 24, epsilon: 0.01));

    // The capsule is 62 points tall and floats 21 points from the sides and
    // the bottom edge, as on an iPhone. Its tabs sit 85.5 points apart, 9
    // from the capsule's ends.
    expect(
      tester.getRect(
        find
            .descendant(
              of: find.byType(RenderedGlassTabBar),
              matching: find.byType(GlassPlate),
            )
            .first,
      ),
      rectMoreOrLessEquals(
        const Rect.fromLTWH(21, 874 - 21 - 62, 360, 62),
        epsilon: 0.01,
      ),
    );
    double tab(String label) => tester.getCenter(tabLabel(label)).dx;
    expect(tab('Today'), moreOrLessEquals(21 + 9 + 85.5 / 2, epsilon: 0.01));
    expect(
      tab('Timetable') - tab('Today'),
      moreOrLessEquals(85.5, epsilon: 0.01),
    );
    expect(
      tab('Messages'),
      moreOrLessEquals(402 - 21 - 9 - 85.5 / 2, epsilon: 0.01),
    );

    await tester.tap(tabLabel('Timetable'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 1);

    // The bar's own title lines up with the buttons.
    final barTitle = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == 'Timetable' &&
          widget.style?.fontSize == 17,
    );
    expect(
      tester.getCenter(barTitle).dy,
      moreOrLessEquals(40 + 22, epsilon: 0.01),
    );
  }, variant: onAndroid);

  testWidgets('the drawn tab bar stays clear of a bar of system buttons', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    useAndroidInsets(tester, bottom: 48);
    await pumpApp(tester);

    expect(
      tester.getSize(find.byType(RenderedGlassTabBar)).height,
      16 + 62 + 48 + 8,
    );
  }, variant: onAndroid);

  testWidgets('the composer keeps its button above a bar of system buttons', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    useAndroidInsets(tester, bottom: 48);
    final controller = await pumpApp(tester);
    controller.selectTab(5);
    await tester.pumpAndSettle();
    await tester.tap(barButton('compose'));
    await tester.pumpAndSettle();

    final send = find.ancestor(
      of: find.text('Send'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(tester.getRect(send).bottom, lessThanOrEqualTo(874 - 48 - 16));
  }, variant: onAndroid);

  testWidgets('over a gesture handle the composer reaches down as on iOS', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    useAndroidInsets(tester);
    final controller = await pumpApp(tester);
    controller.selectTab(5);
    await tester.pumpAndSettle();
    await tester.tap(barButton('compose'));
    await tester.pumpAndSettle();

    final send = find.ancestor(
      of: find.text('Send'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(tester.getRect(send).bottom, moreOrLessEquals(874 - 16));
  }, variant: onAndroid);

  testWidgets('drawn bar buttons open the menu, sheets and the composer', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    useAndroidInsets(tester);
    final controller = await pumpApp(tester);

    await tester.tap(barButton('menu'));
    await tester.pumpAndSettle();
    expect(find.text('SiberiaGB'), findsOneWidget);
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.byType(AppLogo), findsNothing);
    expect(find.byType(RenderedGlassSurface), findsOneWidget);

    tester.state<ScaffoldState>(find.byType(Scaffold)).closeDrawer();
    await tester.pumpAndSettle();
    expect(find.byType(RenderedGlassSurface), findsNothing);

    await tester.tap(barButton('account'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    // A compact sheet is a glass panel of its own.
    expect(find.byType(RenderedGlassSurface), findsOneWidget);
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();

    // The compose button belongs to the messages page only.
    expect(barButton('compose'), findsNothing);
    controller.selectTab(5);
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsNothing);
    await tester.tap(barButton('compose'));
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsOneWidget);
  }, variant: onAndroid);

  testWidgets('a dialog on drawn glass appears without a fade', (tester) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    useAndroidInsets(tester);
    final controller = await pumpApp(tester);

    controller.selectTab(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_month_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Glass under a fading layer would have nothing behind it to bend.
    final panel = find.byType(RenderedGlassSurface);
    expect(panel, findsOneWidget);
    expect(
      find.ancestor(of: panel, matching: find.byType(FadeTransition)),
      findsNothing,
    );

    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  }, variant: onAndroid);

  testWidgets('the lens of the drawn tab bar can be dragged to another tab', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    useAndroidInsets(tester);
    final controller = await pumpApp(tester);
    expect(controller.tabIndex, 0);

    // From the first tab to a little short of the third one's middle.
    await tester.drag(
      tabLabel('Today'),
      const Offset(160, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 2);

    // A page outside the tabs leaves the bar without a selection, and a tap
    // brings one back.
    controller.selectTab(9);
    await tester.pumpAndSettle();
    await tester.tap(tabLabel('Messages'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 5);
  }, variant: onAndroid);

  testWidgets('a tap on the open drawn tab scrolls up, a drag does not', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    useAndroidInsets(tester);
    final controller = await pumpApp(tester, messages: 20);

    await tester.tap(tabLabel('Messages'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 5);

    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(list).position;
    final scrolled = position.pixels;
    expect(scrolled, greaterThan(0));

    // The lens is let go where it was picked up: nothing was tapped.
    await tester.drag(
      tabLabel('Messages'),
      const Offset(-30, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(controller.tabIndex, 5);
    expect(position.pixels, scrolled);

    await tester.tap(tabLabel('Messages'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(controller.tabIndex, 5);
  }, variant: onAndroid);

  testWidgets('the drawn glass design looks and moves like the iPhone app', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    useAndroidInsets(tester);
    final controller = await pumpApp(tester);
    ThemeData theme() => Theme.of(tester.element(find.byType(Scaffold).first));

    expect(theme().platform, TargetPlatform.iOS);
    expect(theme().textTheme.bodyMedium?.fontFamily, 'Inter');

    // The classic design keeps Android's own conventions.
    await controller.setDesign(AppDesign.classic);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(theme().platform, TargetPlatform.android);
    expect(theme().textTheme.bodyMedium?.fontFamily, isNot('Inter'));
  }, variant: onAndroid);

  testWidgets('touches just above the tab bar reach the page behind it', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: NativeGlassTabBar(
                tabs: const [GlassTab(label: 'One', symbol: GlassSymbol.house)],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(NativeGlassTabBar));

    // The strip that only makes room for the selection lens.
    await tester.tapAt(bar.topCenter + const Offset(0, 6));
    expect(taps, 1);

    // The bar itself belongs to UIKit.
    await tester.tapAt(bar.center);
    expect(taps, 1);
  }, variant: onIos);
}

AppSnapshot _snapshot(int messages) {
  final now = DateTime.now();
  return AppSnapshot(
    profile: const StudentProfile(
      id: '1',
      name: 'Uczeń testowy',
      school: 'School',
      provider: 'Librus Synergia',
    ),
    lessons: const [],
    grades: const [],
    events: const [],
    messages: [
      for (var index = 0; index < messages; index++)
        SchoolMessage(
          id: 'm$index',
          sender: 'Nauczyciel A',
          subject: index == 0 ? 'Test message' : 'Message $index',
          preview: 'Preview',
          receivedAt: now,
          unread: index == 0,
        ),
    ],
    attendance: const [],
    announcements: const [],
    notices: const [],
    lastSync: now,
  );
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];

  @override
  Future<List<MessageRecipient>> fetchMessageRecipients() async => const [];
}
