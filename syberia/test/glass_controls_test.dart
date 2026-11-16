import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_material.dart';
import 'package:syberia/src/ui/glass/glass_plate.dart';
import 'package:syberia/src/ui/glass/glass_picker.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';
import 'package:syberia/src/ui/glass/glass_segmented.dart';
import 'package:syberia/src/ui/glass/glass_switch.dart';
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
  double height = 860,
}) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': design,
    'onboarding_done_v1': true,
  });
  tester.view.physicalSize = Size(400, height);
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

/// A switch on a page, holding its value unless [keep].
Future<List<bool>> _switch(
  WidgetTester tester, {
  bool initial = false,
  bool keep = false,
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final flips = <bool>[];
  var value = initial;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => GlassSwitch(
              key: const ValueKey('switch'),
              value: value,
              onChanged: (next) => setState(() {
                flips.add(next);
                if (!keep) value = next;
              }),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return flips;
}

Finder get _knobGlass => find.descendant(
  of: find.byKey(const ValueKey('switch')),
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
      // Its button in the app's typeface, as the word beside it.
      String? family(String text) => tester
          .renderObject<RenderParagraph>(find.text(text))
          .text
          .style
          ?.fontFamily;
      expect(family('Undo'), isNotNull);
      expect(family('Undo'), family('Marked as done'));
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

  group('the switch', () {
    testWidgets('a tap flips it; the knob slides over on a spring and the '
        'track takes on its colour', (tester) async {
      final flips = await _switch(tester);
      final control = tester.getRect(find.byKey(const ValueKey('switch')));
      expect(control.size, GlassSwitch.size);
      final start = tester.getRect(_knobGlass).left;
      await tester.tap(find.byKey(const ValueKey('switch')));
      await tester.pump();
      expect(flips, [true]);
      final lefts = <double>[];
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        lefts.add(tester.getRect(_knobGlass).left);
      }
      await tester.pumpAndSettle();
      final end = tester.getRect(_knobGlass).left;
      expect(end, greaterThan(start + 15));
      // It travels, not jumps.
      expect(lefts.first, lessThan(end - 2));
      expect(tester.getRect(_knobGlass).right, closeTo(control.right - 2, 1));
    });

    testWidgets('held, the knob swells into a lens of glass; dragged across, '
        'it flips the switch', (tester) async {
      final flips = await _switch(tester);
      final rest = tester.getRect(_knobGlass);
      final gesture = await tester.startGesture(tester.getCenter(_knobGlass));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<GlassPlate>(_knobGlass).look.visibility,
        greaterThan(0.5),
      );
      expect(tester.getRect(_knobGlass).width, greaterThan(rest.width + 4));
      await gesture.moveBy(const Offset(12, 0));
      await gesture.moveBy(const Offset(12, 0));
      await gesture.moveBy(const Offset(12, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(flips, [true]);
      // At rest the glass is gone and the knob is white again.
      expect(tester.widget<GlassPlate>(_knobGlass).look.visibility, 0);
    });

    testWidgets('on iOS 26 it is UIKit\'s own: its flip comes back, and '
        'where the app keeps the value UIKit\'s switch is set back', (
      tester,
    ) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      int? id;
      Map<Object?, Object?>? created;
      GlassPlatform.debugSetBackend(GlassBackend.uikit);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          if (arguments['viewType'] == 'siberia/glass_switch') {
            id = arguments['id'] as int;
            final params = arguments['params'];
            if (params is Uint8List) {
              created = const StandardMessageCodec().decodeMessage(
                ByteData.sublistView(params),
              ) as Map<Object?, Object?>;
            }
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
      final flips = await _switch(tester, keep: true);
      expect(id, isNotNull);
      expect(created?['value'], isFalse);
      final updates = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(
        MethodChannel('siberia/glass_switch/$id'),
        (call) async {
          if (call.method == 'update') {
            updates.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        },
      );
      await messenger.handlePlatformMessage(
        'siberia/glass_switch/$id',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('changed', true),
        ),
        (_) {},
      );
      await tester.pump();
      await tester.pump();
      expect(flips, [true]);
      // The app kept off: UIKit's switch is told off again.
      expect(updates, isNotEmpty);
      expect(updates.last['value'], isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('in the glass design a row with a switch flips it when '
        'tapped, and the switches are these', (tester) async {
      final controller = await _app(tester, tab: 9, height: 3000);
      expect(find.byType(Switch), findsNothing);
      final row = find.byKey(const ValueKey('grade-weighted'));
      final glassSwitch = find.descendant(
        of: row,
        matching: find.byType(GlassSwitch),
      );
      expect(glassSwitch, findsOneWidget);
      final before = tester.widget<GlassSwitch>(glassSwitch).value;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.widget<GlassSwitch>(glassSwitch).value, !before);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  });

  group('picking a time', () {
    Future<AppController> openReminders(WidgetTester tester) async {
      final controller = await _app(tester, tab: 9, height: 3000);
      await tester.tap(find.byKey(const ValueKey('settings-notifications')));
      await tester.pumpAndSettle();
      final morning = find.byKey(const ValueKey('reminder-morning'));
      await tester.ensureVisible(morning);
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('in the glass design it is iOS\'s wheels on a sheet of '
        'glass, with Cancel and Done', (tester) async {
      final controller = await openReminders(tester);
      expect(find.text('7:00 AM · change time'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminder-morning')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      final wheels = find.byKey(const ValueKey('time-wheels'));
      expect(wheels, findsOneWidget);
      expect(
        find.ancestor(of: wheels, matching: find.byType(GlassPlate)),
        findsOneWidget,
      );
      // An hour on: the hour wheel turned by one row.
      final hour = find.descendant(of: wheels, matching: find.text('07')).first;
      await tester.drag(hour, const Offset(0, -32), touchSlopY: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('time-done')));
      await tester.pumpAndSettle();
      expect(find.text('8:00 AM · change time'), findsOneWidget);
      // Cancel keeps the time.
      await tester.tap(find.byKey(const ValueKey('reminder-morning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('time-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('8:00 AM · change time'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets('on iOS 26 UIKit asks, in a sheet of its own', (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      GlassPlatform.debugSetBackend(GlassBackend.uikit);
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async => null,
      );
      final asked = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(const MethodChannel('siberia/glass'), (
        call,
      ) async {
        if (call.method == 'pickTime') {
          asked.add(call.arguments as Map<Object?, Object?>);
          return 6 * 60 + 30;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('siberia/glass'),
          null,
        );
      });
      final controller = await openReminders(tester);
      await tester.tap(find.byKey(const ValueKey('reminder-morning')));
      await tester.pumpAndSettle();
      expect(asked, hasLength(1));
      expect(asked.single['minutes'], 7 * 60);
      expect(asked.single['done'], 'Done');
      expect(find.byKey(const ValueKey('time-wheels')), findsNothing);
      expect(find.text('6:30 AM · change time'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  });

  group('the pop-up row', () {
    Future<List<String?>> row(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final picks = <String?>[];
      String? value = 'b';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => GlassStyle(enabled: true, child: child!),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (context, setState) => GlassPickerRow<String?>(
                  key: const ValueKey('row'),
                  label: 'Role',
                  value: value,
                  options: const [
                    (null, 'Auto'),
                    ('a', 'Student'),
                    ('b', 'Parent'),
                  ],
                  onChanged: (next) => setState(() {
                    picks.add(next);
                    value = next;
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return picks;
    }

    testWidgets('shows the choice and opens a glass menu from its chevrons, '
        'where null is a choice too', (tester) async {
      final picks = await row(tester);
      expect(find.text('Parent'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('row')));
      await tester.pumpAndSettle();
      final menu = find.ancestor(
        of: find.byKey(const ValueKey('picker-option-0')),
        matching: find.byType(GlassPlate),
      );
      expect(menu, findsOneWidget);
      // At the row's end, where its chevrons are.
      expect(tester.getRect(menu).right, greaterThan(300));
      await tester.tap(find.byKey(const ValueKey('picker-option-0')));
      await tester.pumpAndSettle();
      expect(picks, [null]);
      expect(find.text('Auto'), findsOneWidget);
    });

    testWidgets('on iOS 26 UIKit\'s own menu lies over it', (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final ids = <String, int>{};
      GlassPlatform.debugSetBackend(GlassBackend.uikit);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          ids[arguments['viewType'] as String] = arguments['id'] as int;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      final picks = await row(tester);
      final id = ids['siberia/glass_menu_button'];
      expect(id, isNotNull);
      await messenger.handlePlatformMessage(
        'siberia/glass_menu_button/$id',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('pick', '1'),
        ),
        (_) {},
      );
      await tester.pump();
      expect(picks, ['a']);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
