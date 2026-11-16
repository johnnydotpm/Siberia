import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_material.dart';
import 'package:syberia/src/ui/glass/glass_plate.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';
import 'package:syberia/src/ui/glass/glass_segmented.dart';
import 'package:syberia/src/ui/glass/glass_toast.dart';

/// The glass design's own controls: the word over the tab bar, the
/// segmented control and the switch, UIKit's on iOS 26 and drawn alike
/// elsewhere.

final _now = DateTime.now();
final _tomorrow = DateTime(_now.year, _now.month, _now.day + 1);

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}

AppSnapshot _snapshot() => AppSnapshot(
  profile: const StudentProfile(
    id: 'test',
    name: 'Test',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: const [],
  grades: const [],
  events: [
    SchoolEvent(
      id: 'hw1',
      title: 'Zadania 1-5',
      subject: 'Matematyka',
      date: _tomorrow,
      kind: EventKind.homework,
    ),
  ],
  messages: const [],
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: _now,
);

Future<AppController> _app(
  WidgetTester tester, {
  int tab = 0,
  String design = 'glass',
}) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': design,
    'onboarding_done_v1': true,
  });
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(
    _Repository(_snapshot()),
    updatesEnabled: false,
  );
  await controller.bootstrap();
  controller.selectTab(tab);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

/// A glass page with a button that says [text] when pressed.
Future<BuildContext> _page(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext page;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => GlassStyle(enabled: true, child: child!),
      home: Builder(
        builder: (context) {
          page = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
  return page;
}

/// A segmented control of three choices on a page, holding its choice.
Future<List<String?>> _segmented(
  WidgetTester tester, {
  String? initial = 'a',
  bool emptyAllowed = false,
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picks = <String?>[];
  var selected = initial;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: StatefulBuilder(
              builder: (context, setState) => GlassSegmentedControl<String>(
                key: const ValueKey('control'),
                segments: const [
                  GlassSegment('a', 'One'),
                  GlassSegment('b', 'Two'),
                  GlassSegment('c', 'Three'),
                ],
                selected: selected,
                emptyAllowed: emptyAllowed,
                onChanged: (value) => setState(() {
                  picks.add(value);
                  selected = value;
                }),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picks;
}

/// The selection's glass, and how far it is a lens.
Finder get _thumbGlass => find.descendant(
  of: find.byKey(const ValueKey('control')),
  matching: find.byType(GlassPlate),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => GlassPlatform.debugSetBackend(GlassBackend.rendered));
  tearDown(() => GlassPlatform.debugSetBackend(GlassBackend.none));

  group('the word over the tab bar', () {
    testWidgets('comes up on clear glass on a spring, over the tab bar, and '
        'goes after a while', (tester) async {
      final page = await _page(tester);
      var gone = false;
      showGlassToast(Overlay.of(page), text: 'Saved').then((_) => gone = true);
      final word = find.text('Saved');
      final tops = <double>[];
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (word.evaluate().isNotEmpty) tops.add(tester.getRect(word).top);
      }
      final rest = tester.getRect(word).top;
      // From below, into its place.
      expect(tops.first, greaterThan(rest + 10));
      expect(tops.reduce(math.min), closeTo(rest, 1.5));
      // On the bars' clearer glass, over the tab bar.
      final plate = find.ancestor(of: word, matching: find.byType(GlassPlate));
      expect(
        tester.widget<GlassPlate>(plate).look,
        same(GlassMaterial.menu(Brightness.light)),
      );
      final bottom = tester.getRect(plate).bottom;
      expect(
        bottom,
        closeTo(860 - GlassPlatform.metrics.value.tabBarHeight - 14, 1),
      );
      // A while later it goes by itself, sinking.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(word).top, greaterThan(rest));
      await tester.pumpAndSettle();
      expect(word, findsNothing);
      expect(gone, isTrue);
    });

    testWidgets('its button acts and sends it off; a new word takes the '
        'last one\'s place; a swipe down sends it off', (tester) async {
      final page = await _page(tester);
      var undone = false;
      showGlassToast(
        Overlay.of(page),
        text: 'Marked',
        actionLabel: 'Undo',
        onAction: () => undone = true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, isTrue);
      expect(find.text('Marked'), findsNothing);

      showGlassToast(Overlay.of(page), text: 'First');
      await tester.pump(const Duration(milliseconds: 100));
      showGlassToast(Overlay.of(page), text: 'Second');
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      await tester.drag(find.text('Second'), const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('in the glass design the app says things on glass, not in a '
        'snack bar', (tester) async {
      final controller = await _app(tester, tab: 4);
      await tester.tap(find.byKey(const ValueKey('homework-done-hw1')));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      final word = find.text('Marked as done');
      expect(word, findsOneWidget);
      expect(
        find.ancestor(of: word, matching: find.byType(GlassPlate)),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(controller.snapshot.events, isNotEmpty);
      expect(find.text('Marked as done'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  });

  group('the segmented control', () {
    testWidgets('a tap picks a choice; the selection travels to it as a '
        'lens on a spring and settles as a platter', (tester) async {
      final picks = await _segmented(tester);
      double lens() => tester.widget<GlassPlate>(_thumbGlass).look.visibility;
      double left() => tester.getRect(_thumbGlass).left;
      expect(lens(), 0);
      final start = left();
      await tester.tap(find.text('Three'));
      await tester.pump();
      expect(picks, ['c']);
      final lenses = <double>[];
      final lefts = <double>[];
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        lenses.add(lens());
        lefts.add(left());
      }
      await tester.pumpAndSettle();
      // On its way it is glass, and it moves, not jumps.
      expect(lenses.reduce(math.max), greaterThan(0.5));
      expect(lefts.first, lessThan(left() - 20));
      expect(lefts.first, greaterThan(start));
      // At rest it is a platter again, under the choice.
      expect(lens(), 0);
      expect(
        tester.getCenter(_thumbGlass).dx,
        closeTo(tester.getCenter(find.text('Three')).dx, 2),
      );
    });

    testWidgets('the selection can be dragged to another choice', (
      tester,
    ) async {
      final picks = await _segmented(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('One')),
      );
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      // Under the finger it is a lens.
      expect(
        tester.widget<GlassPlate>(_thumbGlass).look.visibility,
        greaterThan(0.3),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(picks, ['b']);
    });

    testWidgets('where none may be chosen, tapping the choice lets it go', (
      tester,
    ) async {
      final picks = await _segmented(tester, emptyAllowed: true);
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(picks, [null]);
      expect(_thumbGlass, findsNothing);
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(picks, [null, 'b']);
    });

    testWidgets('on iOS 26 it is UIKit\'s own, whose choice comes back', (
      tester,
    ) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final views = <String, Map<Object?, Object?>>{};
      final ids = <String, int>{};
      GlassPlatform.debugSetBackend(GlassBackend.uikit);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          final type = arguments['viewType'] as String;
          ids[type] = arguments['id'] as int;
          final params = arguments['params'];
          if (params is Uint8List) {
            views[type] = const StandardMessageCodec().decodeMessage(
              ByteData.sublistView(params),
            ) as Map<Object?, Object?>;
          }
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      final picks = await _segmented(tester);
      const type = 'siberia/glass_segmented';
      expect(ids[type], isNotNull);
      expect(views[type]?['labels'], ['One', 'Two', 'Three']);
      expect(views[type]?['selected'], 0);
      Future<void> say(String method, Object? arguments) =>
          messenger.handlePlatformMessage(
            '$type/${ids[type]}',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            (_) {},
          );
      await say('select', 2);
      await tester.pump();
      expect(picks, ['c']);
      // UIKit's height for its control is the height it gets.
      await say('metrics', {'height': 40.0});
      await tester.pump();
      expect(tester.getSize(find.byKey(const ValueKey('control'))).height, 40);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('in the glass design the app\'s segmented controls are '
        'these', (tester) async {
      final controller = await _app(tester, tab: 4);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('homework-filter')),
          matching: find.byType(GlassSegmentedControl<bool>),
        ),
        findsOneWidget,
      );
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  });
}
