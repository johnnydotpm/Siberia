import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/ui/glass/glass_plate.dart';
import 'package:syberia/src/ui/glass/glass_platform.dart';
import 'package:syberia/src/ui/glass/rendered_tab_bar.dart';

/// Opens the demo school, in [design].
Future<AppController> _demo(WidgetTester tester, String design) async {
  SharedPreferences.setMockInitialValues({
    'app_design_v1': design,
    'app_locale_v1': 'en',
  });
  if (design == 'glass') {
    GlassPlatform.debugSetBackend(GlassBackend.rendered);
    addTearDown(() => GlassPlatform.debugSetBackend(GlassBackend.none));
  }
  tester.view.physicalSize = const Size(400, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AppController(AppRepository(), updatesEnabled: false);
  addTearDown(controller.dispose);
  await controller.bootstrap();
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  controller.startDemo();
  await tester.pumpAndSettle();
  return controller;
}

/// The painters of the custom paints under [of], by their type's name.
List<String> _painters(WidgetTester tester, Finder of) {
  final names = <String>[];
  void visit(RenderObject object) {
    if (object is RenderCustomPaint) {
      for (final painter in [object.painter, object.foregroundPainter]) {
        if (painter != null) names.add('${painter.runtimeType}');
      }
    }
    object.visitChildren(visit);
  }

  visit(tester.renderObject(of));
  return names;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rims and shadows are drawn once and kept', (tester) async {
    final controller = await _demo(tester, 'glass');
    // The bars' glass was drawn into images as it first showed.
    final baked = debugGlassImagesBaked;
    expect(baked, greaterThan(0));
    // Everything painted again: the same images, none drawn anew.
    void repaint(RenderObject object) {
      object
        ..markNeedsPaint()
        ..visitChildren(repaint);
    }

    repaint(tester.binding.renderViews.first);
    await tester.pump();
    expect(debugGlassImagesBaked, baked);
    expect(controller.isDemo, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a selection at rest casts no shadow of nothing', (tester) async {
    await _demo(tester, 'glass');
    // The bar's own shadow, and none for the selection, faded to nothing.
    expect(
      _painters(
        tester,
        find.byType(RenderedGlassTabBar),
      ).where((name) => name == '_ShadowPainter'),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rows at rest take no layers of their own', (tester) async {
    final controller = await _demo(tester, 'classic');
    // Today's blocks and cards come and go smoothly, but sit as plain paint.
    expect(_opacityOwners(tester, '_AnimatedColumn'), isEmpty);
    // A homework done steps back: that one is see-through, so a layer.
    controller.selectTab(4);
    await tester.pumpAndSettle();
    expect(_opacityOwners(tester, '_LightOpacity'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('homework-done-demo-event-0')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('homework-done-toggle')));
    await tester.pumpAndSettle();
    expect(_opacityOwners(tester, '_LightOpacity'), hasLength(1));
    expect(_opacityOwners(tester, '_AnimatedColumn'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// The widgets that hold a layer to fade, where [within] is among them or
/// their ancestors.
List<String> _opacityOwners(WidgetTester tester, String within) {
  final owners = <String>[];
  void visit(RenderObject object) {
    if (object.debugLayer is OpacityLayer) {
      final chain = object.debugCreator.toString();
      if (chain.contains(within)) owners.add(chain.split(' ← ').first);
    }
    object.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
  return owners;
}
