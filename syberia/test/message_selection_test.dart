import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/theme/wallpaper_colors.dart';
import 'package:syberia/src/ui/expressive/expressive.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';
import 'package:syberia/src/ui/glass/glass_toolbar.dart';
import 'package:syberia/src/ui/glass/rendered_tab_bar.dart';

import 'support/profile_fakes.dart';

/// Picking messages turns the bars to it in every design: the count up top
/// with a way out, the actions in place of the tabs, and back again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WallpaperColors.ask = () async => null;
  });
  tearDown(() => GlassPlatform.debugSetBackend(GlassBackend.none));

  Future<AppController> open(WidgetTester tester, AppDesign design) async {
    final repository = _Repository();
    await repository.saveDesign(design);
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    controller.selectTab(5);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  testWidgets('classic: a tinted bar up top, the actions where the tabs were', (
    tester,
  ) async {
    await open(tester, AppDesign.classic);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(key('messages-select'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(key('messages-selection-close'), findsOneWidget);
    expect(find.text('Select messages'), findsOneWidget);
    expect(key('messages-select'), findsNothing);

    // An avatar and a long press pick; picking everything offers none.
    await tester.tap(key('message-select-m1'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.ensureVisible(find.text('Szkolna liga szachowa'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Szkolna liga szachowa'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(key('messages-select-all'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);

    await tester.tap(key('messages-delete-selected'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 3 messages?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Back leaves the picking before it leaves the page.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(key('messages-selection-close'), findsNothing);
    expect(key('messages-select'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Expressive: the count as the title, a floating toolbar', (
    tester,
  ) async {
    await open(tester, AppDesign.expressive);
    expect(find.byType(ExpressiveNavigationBar), findsOneWidget);
    await tester.longPress(find.text('Wyjście do opery'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpressiveNavigationBar), findsNothing);
    // The page's large title, and the bar's once that has scrolled away.
    expect(find.text('1 selected', findRichText: true), findsWidgets);
    expect(key('messages-mark-selected-read'), findsOneWidget);
    expect(key('messages-delete-selected'), findsOneWidget);
    await tester.tap(key('messages-delete-selected'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 message?'), findsOneWidget);
    expect(key('messages-confirm-delete'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(key('messages-selection-close'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpressiveNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Liquid Glass: glass buttons up top, an action bar for tabs', (
    tester,
  ) async {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    await open(tester, AppDesign.glass);
    expect(find.byType(RenderedGlassTabBar), findsOneWidget);
    await tester.tap(key('messages-select'));
    await tester.pumpAndSettle();
    expect(find.byType(RenderedGlassTabBar), findsNothing);
    expect(find.byType(GlassToolbar), findsOneWidget);
    expect(key('glass-bar-button-menu'), findsNothing);
    expect(key('glass-bar-button-compose'), findsNothing);

    await tester.tap(key('glass-bar-button-selection-all'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsWidgets);
    await tester.tap(key('messages-delete-selected'));
    await tester.pumpAndSettle();
    // A sheet from below, as on an iPhone.
    expect(find.text('Delete 3 messages?'), findsOneWidget);
    await tester.tap(key('messages-cancel-delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 3 messages?'), findsNothing);

    await tester.tap(key('glass-bar-button-selection-close'));
    await tester.pumpAndSettle();
    expect(find.byType(RenderedGlassTabBar), findsOneWidget);
    expect(key('glass-bar-button-compose'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide screen shows the picking in the page', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester, AppDesign.classic);
    await tester.tap(key('messages-select'));
    await tester.pumpAndSettle();
    expect(key('messages-selection-close'), findsOneWidget);
    await tester.tap(key('message-select-m2'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(key('messages-selection-close'));
    await tester.pumpAndSettle();
    expect(key('messages-select'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Sent folder offers deleting only', (tester) async {
    await open(tester, AppDesign.classic);
    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Pytanie o wycieczkę'));
    await tester.pumpAndSettle();
    expect(key('messages-mark-selected-read'), findsNothing);
    expect(key('messages-delete-selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Repository extends AppRepository {
  @override
  Future<AppSnapshot> load() async {
    final now = DateTime.now();
    final base = studentSnapshot('s1', 'a');
    SchoolMessage message(String id, String sender, String subject, int days) =>
        SchoolMessage(
          id: id,
          sender: sender,
          subject: subject,
          preview: 'Treść wiadomości',
          receivedAt: now.subtract(Duration(days: days)),
          unread: days == 0,
        );
    return AppSnapshot(
      profile: base.profile,
      lessons: const [],
      grades: const [],
      events: const [],
      messages: [
        message('m1', 'Wychowawca klasy', 'Wyjście do opery', 0),
        message('m2', 'Dyrekcja szkoły', 'Obchody 11 listopada', 2),
        message('m3', 'Nauczyciel Testowy', 'Szkolna liga szachowa', 3),
      ],
      sentMessages: [
        SchoolMessage(
          id: 's1',
          sender: '',
          subject: 'Pytanie o wycieczkę',
          preview: '',
          receivedAt: now.subtract(const Duration(days: 1)),
          unread: false,
          sent: true,
          recipients: const ['Wychowawca klasy'],
        ),
      ],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
  }

  @override
  Future<List<SchoolMessage>> fetchSentMessages({String? profileId}) async =>
      (await load()).sentMessages;
}
