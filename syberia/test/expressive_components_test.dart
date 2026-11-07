import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/theme/app_symbols.dart';
import 'package:syberia/src/theme/app_theme.dart';
import 'package:syberia/src/theme/expressive_tokens.dart';
import 'package:syberia/src/theme/wallpaper_colors.dart';
import 'package:syberia/src/ui/expressive/expressive.dart';

import 'support/profile_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child, {bool still = false}) => MaterialApp(
    theme: AppTheme.expressive(Brightness.light, latinFont: false),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  group('spring curve', () {
    test('a spatial spring overshoots and comes to rest at the end', () {
      final curve = SpringCurve(Springs.fastSpatial);
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      final values = [for (var t = 0.0; t <= 1; t += 0.01) curve.transform(t)];
      expect(values.reduce((a, b) => a > b ? a : b), greaterThan(1));
      expect(curve.duration, lessThan(const Duration(seconds: 1)));
      expect(curve.duration, greaterThan(const Duration(milliseconds: 100)));
    });

    test('an effects spring never overshoots', () {
      final curve = SpringCurve(Springs.defaultEffects);
      for (var t = 0.0; t <= 1; t += 0.01) {
        expect(curve.transform(t), lessThanOrEqualTo(1.0001));
      }
    });
  });

  group('shapes', () {
    test('fill the rectangle they are given', () {
      const rect = Rect.fromLTWH(10, 20, 100, 100);
      for (final shape in [
        ExpressiveShapes.cookie9,
        ExpressiveShapes.softBurst,
        ExpressiveShapes.sunny,
        ExpressiveShapes.circle,
      ]) {
        // Centred, as long as the box on their longer side.
        final bounds = shape.getOuterPath(rect).getBounds();
        expect(bounds.center.dx, moreOrLessEquals(60, epsilon: 0.5));
        expect(bounds.center.dy, moreOrLessEquals(70, epsilon: 0.5));
        expect(bounds.longestSide, moreOrLessEquals(100, epsilon: 0.5));
        expect(rect.inflate(0.5).contains(bounds.topLeft), isTrue);
        expect(rect.inflate(0.5).contains(bounds.bottomRight), isTrue);
      }
    });

    test('morph into each other when lerped', () {
      const rect = Rect.fromLTWH(0, 0, 100, 100);
      final halfway = ShapeBorder.lerp(
        ExpressiveShapes.cookie9,
        ExpressiveShapes.circle,
        0.5,
      )!;
      expect(halfway, isNot(isA<MaterialShapeBorder>()));
      final bounds = halfway.getOuterPath(rect).getBounds();
      expect(bounds.width, moreOrLessEquals(100, epsilon: 2));
      // The same pair builds its morph once.
      expect(
        ShapeBorder.lerp(
          ExpressiveShapes.cookie9,
          ExpressiveShapes.circle,
          1,
        )!.getOuterPath(rect).getBounds().width,
        moreOrLessEquals(100, epsilon: 1),
      );
    });

    test('keep room to turn in', () {
      final scale = rotationSafeScale(LoadingIndicator.polygons);
      expect(scale, greaterThan(0.5));
      expect(scale, lessThanOrEqualTo(1));
    });
  });

  group('loading indicator', () {
    test('morphs every 650 ms and turns a quarter each time', () {
      final start = loadingIndicatorFrame(Duration.zero);
      expect(start.morph, 0);
      expect(start.progress, 0);
      expect(start.degrees, 90);

      // Halfway through the first spring the shape is between two.
      final moving = loadingIndicatorFrame(const Duration(milliseconds: 100));
      expect(moving.morph, 0);
      expect(moving.progress, greaterThan(0));

      // Settled: the next shape waits a quarter further turned.
      final settled = loadingIndicatorFrame(const Duration(milliseconds: 640));
      expect(settled.morph, 1);
      expect(settled.progress, 0);

      final next = loadingIndicatorFrame(const Duration(milliseconds: 650));
      expect(next.morph, 1);
      expect(next.degrees, moreOrLessEquals(180 + 650 / 4666 * 360));

      // Seven morphs bring back the first shape.
      expect(
        loadingIndicatorFrame(const Duration(milliseconds: 650 * 7)).morph,
        0,
      );
    });

    test('turns without jumps', () {
      var previous = loadingIndicatorFrame(Duration.zero).degrees;
      for (var ms = 4; ms < 3000; ms += 4) {
        final degrees = loadingIndicatorFrame(Duration(milliseconds: ms))
            .degrees;
        final step = (degrees - previous + 540) % 360 - 180;
        expect(step.abs(), lessThan(12), reason: 'at $ms ms');
        previous = degrees;
      }
    });

    testWidgets('is 48 points, contained on the primary container', (
      tester,
    ) async {
      await tester.pumpWidget(app(const LoadingIndicator(contained: true)));
      await tester.pump(const Duration(milliseconds: 300));
      final box = find.byType(LoadingIndicator);
      expect(tester.getSize(box), const Size.square(48));
      final container = tester.widget<DecoratedBox>(
        find.descendant(of: box, matching: find.byType(DecoratedBox)),
      );
      final colors = AppTheme.expressive(Brightness.light).colorScheme;
      expect(
        (container.decoration as ShapeDecoration).color,
        colors.primaryContainer,
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('stands still with animations off', (tester) async {
      await tester.pumpWidget(app(const LoadingIndicator(), still: true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('wavy progress', () {
    testWidgets('says its value and draws wave, track and dot', (tester) async {
      await tester.pumpWidget(
        app(
          const SizedBox(width: 300, child: WavyProgressIndicator(value: 0.62)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final semantics = tester.getSemantics(find.byType(WavyProgressIndicator));
      expect(semantics.value, '62%');
      final paint = find.descendant(
        of: find.byType(WavyProgressIndicator),
        matching: find.byType(CustomPaint),
      );
      expect(
        paint,
        paints
          ..path(strokeWidth: 4)
          ..line(strokeWidth: 4)
          ..circle(radius: 2),
      );
      final rect = tester.getRect(paint);
      expect(rect.height, 10);
      // The wave travels.
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('flattens near the end and then stops moving', (tester) async {
      Widget bar(double value) =>
          app(SizedBox(width: 300, child: WavyProgressIndicator(value: value)));
      await tester.pumpWidget(bar(0.5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(bar(0.97));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('has no wave at the start', (tester) async {
      await tester.pumpWidget(
        app(
          const SizedBox(width: 300, child: WavyProgressIndicator(value: 0.05)),
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    test('flattens below 10 % and from 95 %', () {
      expect(WavyProgressIndicator.amplitudeFor(0.1), 0);
      expect(WavyProgressIndicator.amplitudeFor(0.11), 1);
      expect(WavyProgressIndicator.amplitudeFor(0.94), 1);
      expect(WavyProgressIndicator.amplitudeFor(0.95), 0);
    });
  });

  group('connected button group', () {
    Widget group(String selected, ValueChanged<String>? onSelected) => app(
      SizedBox(
        width: 360,
        child: ConnectedButtonGroup<String>(
          selected: selected,
          onSelected: onSelected,
          options: [
            for (final value in const ['a', 'b', 'c'])
              (value: value, label: value.toUpperCase(), icon: null, key: null),
          ],
        ),
      ),
    );

    BorderRadiusGeometry radius(WidgetTester tester, String label) {
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );
      return (material.shape! as RoundedRectangleBorder).borderRadius;
    }

    testWidgets('picks one and rounds it fully', (tester) async {
      String? picked;
      await tester.pumpWidget(group('a', (value) => picked = value));
      await tester.pumpAndSettle();
      expect(
        radius(tester, 'A'),
        const BorderRadiusDirectional.horizontal(
          start: Radius.circular(20),
          end: Radius.circular(20),
        ),
      );
      expect(
        radius(tester, 'B'),
        const BorderRadiusDirectional.horizontal(
          start: Radius.circular(Corners.small),
          end: Radius.circular(Corners.small),
        ),
      );
      expect(
        radius(tester, 'C'),
        const BorderRadiusDirectional.horizontal(
          start: Radius.circular(Corners.small),
          end: Radius.circular(20),
        ),
      );
      expect(
        tester.getSize(find.byType(ConnectedButtonGroup<String>)).height,
        40,
      );

      await tester.tap(find.text('B'));
      expect(picked, 'b');
      picked = null;
      await tester.tap(find.text('A'));
      expect(picked, isNull);

      final semantics = tester.getSemantics(find.text('A'));
      expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    });

    testWidgets('a pressed button rounds its inside less', (tester) async {
      await tester.pumpWidget(group('a', (_) {}));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('B')),
      );
      await tester.pumpAndSettle();
      expect(
        radius(tester, 'B'),
        const BorderRadiusDirectional.horizontal(
          start: Radius.circular(Corners.extraSmall),
          end: Radius.circular(Corners.extraSmall),
        ),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('without a handler nothing can be picked', (tester) async {
      await tester.pumpWidget(group('a', null));
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text('B'))
            .flagsCollection
            .isEnabled
            .toBoolOrNull(),
        isFalse,
      );
    });
  });

  group('split button', () {
    testWidgets('acts, opens its menu and turns its chevron', (tester) async {
      var pressed = 0;
      var menus = 0;
      Widget button(bool open) => app(
        SplitButton(
          label: 'Ważona',
          menuTooltip: 'Average',
          menuOpen: open,
          onPressed: () => pressed++,
          onMenu: () => menus++,
        ),
      );
      await tester.pumpWidget(button(false));
      await tester.tap(find.text('Ważona'));
      await tester.tap(find.byIcon(AppSymbols.expandMore));
      expect((pressed, menus), (1, 1));
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0,
      );
      await tester.pumpWidget(button(true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0.5,
      );
      expect(tester.getSize(find.byType(SplitButton)).height, 40);
    });
  });

  group('navigation bar', () {
    Widget bar(int selected, ValueChanged<int> onSelected) => MaterialApp(
      theme: AppTheme.expressive(Brightness.light, latinFont: false),
      home: Scaffold(
        bottomNavigationBar: ExpressiveNavigationBar(
          selectedIndex: selected,
          onSelected: onSelected,
          destinations: const [
            (
              icon: Icons.home_outlined,
              label: 'Today',
              badge: 0,
              badgeText: '',
            ),
            (
              icon: Icons.school_outlined,
              label: 'Grades',
              badge: 0,
              badgeText: '',
            ),
            (
              icon: Icons.mail_outline_rounded,
              label: 'Mail',
              badge: 4,
              badgeText: '4',
            ),
          ],
        ),
      ),
    );

    testWidgets('fills the chosen icon and grows its pill', (tester) async {
      int? tapped;
      await tester.pumpWidget(bar(1, (index) => tapped = index));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ExpressiveNavigationBar)).height, 64);
      final grades = tester.widget<Icon>(find.byIcon(AppSymbols.school));
      final today = tester.widget<Icon>(find.byIcon(AppSymbols.home));
      expect(grades.fill, 1);
      expect(today.fill, 0);
      expect(find.text('4'), findsOneWidget);
      final colors = AppTheme.expressive(Brightness.light).colorScheme;
      final label = tester.widget<Text>(find.text('Grades'));
      expect(label.style!.color, colors.secondary);
      final pill = tester
          .widgetList<Container>(find.byType(Container))
          .where((container) => container.constraints?.maxWidth == 56);
      expect(pill, hasLength(1));

      await tester.tap(find.text('Mail'));
      expect(tapped, 2);
      expect(
        tester
            .getSemantics(find.byIcon(AppSymbols.school))
            .flagsCollection
            .isSelected
            .toBoolOrNull(),
        isTrue,
      );
    });

    testWidgets('may have no item chosen', (tester) async {
      await tester.pumpWidget(bar(-1, (_) {}));
      await tester.pumpAndSettle();
      expect(tester.widget<Icon>(find.byIcon(AppSymbols.home)).fill, 0);
      expect(tester.widget<Icon>(find.byIcon(AppSymbols.school)).fill, 0);
    });
  });

  test('a switch that is on has a check on its handle', () {
    final theme = AppTheme.expressive(Brightness.light);
    final icon = theme.switchTheme.thumbIcon!.resolve({WidgetState.selected});
    expect(icon?.icon, AppSymbols.check);
    expect(theme.switchTheme.thumbIcon!.resolve({}), isNull);
  });

  group('in the app', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      WallpaperColors.ask = () async => null;
    });

    testWidgets('the Expressive design has its own navigation bar', (
      tester,
    ) async {
      final repository = _Repository();
      await repository.saveDesign(AppDesign.expressive);
      final controller = AppController(repository, updatesEnabled: false);
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byType(ExpressiveNavigationBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(ExpressiveNavigationBar),
          matching: find.text('Grades'),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.tabIndex, 2);
    });

    testWidgets('the gallery shows every component', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.expressive(Brightness.light, latinFont: false),
          home: const ExpressiveGallery(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LoadingIndicator), findsNWidgets(2));
      expect(find.byType(ExpressiveNavigationBar), findsOneWidget);

      final list = find.byKey(const ValueKey('expressive-gallery'));
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('gallery-day-wt')),
        list,
        const Offset(0, -200),
      );
      await tester.tap(find.byKey(const ValueKey('gallery-day-wt')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .getSemantics(find.text('wt 3'))
            .flagsCollection
            .isSelected
            .toBoolOrNull(),
        isTrue,
      );

      await tester.dragUntilVisible(
        find.byKey(const ValueKey('gallery-morph')),
        list,
        const Offset(0, -200),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('gallery-morph')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('gallery-morph')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Halfway, the shape is a morph of two.
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const ValueKey('gallery-morph')),
          matching: find.byType(Container),
        ),
      );
      expect(
        (box.decoration! as ShapeDecoration).shape,
        isNot(isA<MaterialShapeBorder>()),
      );
      await tester.pump(const Duration(seconds: 1));
    });
  });
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
