import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/home_widget.dart';
import 'package:syberia/src/l10n/app_localizations.dart';
import 'package:syberia/src/state/app_controller.dart';

final _now = DateTime(2026, 10, 16, 9);

Lesson _lesson(
  String id,
  DateTime start, {
  bool cancelled = false,
  bool substitution = false,
}) => Lesson(
  id: id,
  subject: 'Subject $id',
  teacher: 'Teacher',
  room: '214',
  start: start,
  end: start.add(const Duration(minutes: 45)),
  cancelled: cancelled,
  substitution: substitution,
);

AppSnapshot _snapshot(
  List<Lesson> lessons, {
  String provider = 'Librus Synergia',
}) => AppSnapshot(
  profile: StudentProfile(
    id: 'test',
    name: 'Test',
    school: 'School',
    provider: provider,
  ),
  lessons: lessons,
  grades: const [],
  events: const [],
  messages: const [],
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: _now,
);

Map<String, dynamic> _decode(String payload) =>
    jsonDecode(payload) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('payload keeps today and upcoming lessons in order', () {
    final payload = _decode(
      buildHomeWidgetPayload(
        _snapshot([
          _lesson('later', _now.add(const Duration(hours: 2))),
          _lesson('yesterday', _now.subtract(const Duration(days: 1))),
          _lesson('earlier', _now.subtract(const Duration(hours: 2))),
          _lesson('ongoing', _now.subtract(const Duration(minutes: 10))),
          _lesson(
            'cancelled',
            _now.add(const Duration(hours: 1)),
            cancelled: true,
          ),
          _lesson(
            'substitute',
            _now.add(const Duration(hours: 1)),
            substitution: true,
          ),
          _lesson('far', _now.add(const Duration(days: 15))),
        ]),
        _now,
        const AppLocalizations(Locale('en')),
      ),
    );
    final lessons = (payload['lessons'] as List).cast<Map<String, dynamic>>();
    // Today's earlier lessons stay, so the widget can show breaks and the
    // day's progress.
    expect(lessons.map((lesson) => lesson['subject']), [
      'Subject earlier',
      'Subject ongoing',
      'Subject substitute',
      'Subject later',
    ]);
    expect(lessons[2]['substitution'], isTrue);
    expect(lessons[1]['room'], '214');
    expect(
      lessons[1]['start'],
      _now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
    );
    expect(payload['v'], 1);
    expect(payload['generatedAt'], _now.millisecondsSinceEpoch);
  });

  test('payload is capped and its labels follow the language', () {
    final many = [
      for (var i = 0; i < 100; i++)
        _lesson('$i', _now.add(Duration(hours: i + 1))),
    ];
    final english = _decode(
      buildHomeWidgetPayload(
        _snapshot(many),
        _now,
        const AppLocalizations(Locale('en')),
      ),
    );
    expect((english['lessons'] as List).length, homeWidgetMaxLessons);
    expect(english['locale'], 'en');
    expect(english['labels'], {
      'now': 'Now',
      'next': 'Next lesson',
      'break': 'Break',
      'tomorrow': 'Tomorrow',
      'substitution': 'Substitution',
      'startsIn': 'in %s',
      'endsIn': 'ends in %s',
      'lessonsFew': '%d lessons',
      'lessonsMany': '%d lessons',
      'noLessons': 'No more lessons',
      'openApp': 'Open SiberiaGB to load your timetable',
    });
    final russian = _decode(
      buildHomeWidgetPayload(
        _snapshot(const []),
        _now,
        const AppLocalizations(Locale('ru')),
      ),
    );
    expect(russian['locale'], 'ru');
    expect((russian['labels'] as Map)['next'], 'Следующий урок');
    expect((russian['labels'] as Map)['tomorrow'], 'Завтра');
    expect((russian['labels'] as Map)['lessonsFew'], '%d урока');
    expect(russian['lessons'], isEmpty);
  });

  test('payload uses the short subject names', () {
    final payload = _decode(
      buildHomeWidgetPayload(
        _snapshot([
          _lesson('long', _now.add(const Duration(hours: 1))),
          _lesson('plain', _now.add(const Duration(hours: 2))),
        ]),
        _now,
        const AppLocalizations(Locale('en')),
        shortNames: const {'Subject long': 'Long', 'Subject plain': '  '},
      ),
    );
    expect((payload['lessons'] as List).map((lesson) => lesson['subject']), [
      'Long',
      'Subject plain',
    ]);
  });

  test('widget settings survive a round trip and fall back to defaults', () {
    const config = HomeWidgetConfig(
      theme: HomeWidgetTheme.light,
      showTeacher: true,
      showCountdown: false,
      mergeDoubleLessons: false,
    );
    expect(HomeWidgetConfig.fromJson(config.toJson()), config);
    expect(
      HomeWidgetConfig.fromJson(const {'theme': 'neon', 'showRoom': 'yes'}),
      const HomeWidgetConfig(),
    );
  });

  test(
    'the controller refreshes the widget and clears it when signed out',
    () async {
      final widget = _RecordingBridge();
      // The controller looks at the real clock, so the lesson must be ahead
      // of it rather than of the fixed date the other tests use.
      final repository = _Repository(
        _snapshot([
          _lesson('first', DateTime.now().add(const Duration(days: 1))),
        ]),
      );
      final controller = AppController(
        repository,
        updatesEnabled: false,
        homeWidget: widget,
      );
      await controller.bootstrap();
      expect(widget.payloads, hasLength(1));
      expect(_decode(widget.payloads.single)['lessons'], isNotEmpty);

      await controller.sync();
      expect(widget.payloads, hasLength(2));

      await controller.setLocale(const Locale('pl'));
      expect(
        (_decode(widget.payloads.last)['labels'] as Map)['next'],
        'Następna lekcja',
      );

      repository.data = _snapshot(const [], provider: '');
      await controller.sync();
      expect(widget.clears, 1);
    },
  );

  test('without native widget code the bridge does nothing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await const HomeWidgetBridge().update('{}');
    await const HomeWidgetBridge().clear();
    expect(await const HomeWidgetBridge().placedWidgets(), isEmpty);
    expect(await const HomeWidgetBridge().configuringWidgetId(), isNull);
    expect(await const HomeWidgetBridge().status(), isNull);
  });

  testWidgets('Settings warn on iOS when the widget cannot get any data', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
    final controller = AppController(
      _Repository(_snapshot(const [])),
      updatesEnabled: false,
      homeWidget: _RecordingBridge(shared: false),
    );
    await controller.bootstrap();
    controller.selectTab(9);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    final widgets = find.byKey(const ValueKey('settings-home-widgets'));
    await tester.scrollUntilVisible(widgets, 300);
    expect(find.textContaining('App Group'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('widget settings and short names are edited in Settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
    final bridge = _RecordingBridge();
    final controller = AppController(
      _Repository(
        _snapshot([
          _lesson('long', DateTime.now().add(const Duration(hours: 1))),
        ]),
      ),
      updatesEnabled: false,
      homeWidget: bridge,
    );
    await controller.bootstrap();
    controller.selectTab(9);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    final widgets = find.byKey(const ValueKey('settings-home-widgets'));
    await tester.scrollUntilVisible(widgets, 300);
    await tester.ensureVisible(widgets);
    await tester.pumpAndSettle();
    await tester.tap(widgets);
    await tester.pumpAndSettle();
    // With a single widget on the home screen its settings open directly.
    await tester.tap(find.byKey(const ValueKey('widget-theme-light')));
    await tester.tap(
      find.byKey(const ValueKey('widget-option-widgetShowTeacher')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('widget-settings-save')));
    await tester.pumpAndSettle();
    expect(
      bridge.saved[7],
      const HomeWidgetConfig(theme: HomeWidgetTheme.light, showTeacher: true),
    );

    // Short names are listed above the widgets.
    final shortNames = find.byKey(const ValueKey('settings-short-names'));
    await tester.scrollUntilVisible(shortNames, -300);
    final centred = Scrollable.ensureVisible(
      tester.element(shortNames),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await centred;
    await tester.tap(shortNames);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('short-name-Subject long')),
      'Long',
    );
    await tester.pump(const Duration(seconds: 1));
    expect(controller.subjectShortNames, {'Subject long': 'Long'});
    final lessons = _decode(bridge.payloads.last)['lessons'] as List;
    expect((lessons.first as Map)['subject'], 'Long');
    expect(tester.takeException(), isNull);
  });
}

class _RecordingBridge extends HomeWidgetBridge {
  _RecordingBridge({this.shared = true});

  final bool shared;
  final payloads = <String>[];
  var clears = 0;

  @override
  Future<void> update(
    String payload, {
    Map<String, String> profiles = const {},
  }) async => payloads.add(payload);

  @override
  Future<void> clear() async => clears++;

  final saved = <int, HomeWidgetConfig>{};

  @override
  Future<List<PlacedHomeWidget>> placedWidgets() async => const [
    PlacedHomeWidget(id: 7),
  ];

  @override
  Future<HomeWidgetConfig> loadConfig(int id) async =>
      saved[id] ?? const HomeWidgetConfig();

  @override
  Future<void> saveConfig(int id, HomeWidgetConfig config) async =>
      saved[id] = config;

  @override
  Future<bool> dynamicColorsSupported() async => true;

  @override
  Future<HomeWidgetStatus?> status() async => HomeWidgetStatus(shared: shared);
}

class _Repository extends AppRepository {
  _Repository(this.data);
  AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<AppSnapshot> sync(AppSnapshot current) async => data;

  // The real one would reach Librus; the Today look-ahead asks for weeks.
  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}
