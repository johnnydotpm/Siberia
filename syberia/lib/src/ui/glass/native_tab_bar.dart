import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'glass_items.dart';
import 'glass_platform.dart';
import 'native_view_link.dart';

/// The system tab bar, hosted as a platform view.
///
/// On iOS 26 UIKit draws it as a floating Liquid Glass capsule and owns the
/// selection lens. The widget is as tall as the bar wants to be, including the
/// bottom safe area, so it belongs at the very bottom of the screen with the
/// page content extending behind it.
class NativeGlassTabBar extends StatefulWidget {
  const NativeGlassTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<GlassTab> tabs;

  /// Null when the current page does not belong to any tab.
  final int? selectedIndex;

  final ValueChanged<int> onSelected;

  @override
  State<NativeGlassTabBar> createState() => _NativeGlassTabBarState();
}

class _NativeGlassTabBarState extends State<NativeGlassTabBar> {
  static final _gestures = <Factory<OneSequenceGestureRecognizer>>{
    // UIKit must see every touch at once, or the selection lens cannot be
    // dragged.
    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
  };

  late final _link = NativeViewLink('siberia/glass_tab_bar', onCall: _onCall);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _link.update(_params());
  }

  @override
  void didUpdateWidget(NativeGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _link.update(_params());
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Map<String, Object?> _params() {
    final theme = Theme.of(context);
    return {
      'items': [
        for (final tab in widget.tabs)
          {
            'label': tab.label,
            'symbol': tab.symbol.name,
            'selectedSymbol': tab.selectedSymbol.name,
            'badge': tab.badge > 0 ? badgeText(tab.badge) : '',
          },
      ],
      'selected': widget.selectedIndex,
      'tint': theme.colorScheme.primary.toARGB32(),
      'dark': theme.brightness == Brightness.dark,
    };
  }

  Future<void> _onCall(MethodCall call) async {
    final arguments = call.arguments;
    switch (call.method) {
      case 'select':
        if (arguments is int) widget.onSelected(arguments);
      case 'metrics':
        if (arguments is! Map || !mounted) return;
        final height = arguments['height'];
        final headroom = arguments['headroom'];
        if (height is! num || headroom is! num) return;
        // The reported height includes the safe area, which Flutter already
        // knows. Only the bar's own height is worth remembering.
        final content =
            height - headroom - MediaQuery.viewPaddingOf(context).bottom;
        if (content <= 0) return;
        GlassPlatform.metrics.value = GlassPlatform.metrics.value.copyWith(
          tabBarHeight: content.toDouble(),
          tabBarHeadroom: headroom.toDouble(),
        );
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<GlassMetrics>(
    valueListenable: GlassPlatform.metrics,
    builder: (context, metrics, child) => SizedBox(
      height:
          metrics.tabBarHeadroom +
          metrics.tabBarHeight +
          MediaQuery.viewPaddingOf(context).bottom,
      // The headroom only makes room for the selection lens; touches there
      // belong to the page behind the bar.
      child: _TopPassThrough(extent: metrics.tabBarHeadroom, child: child),
    ),
    child: UiKitView(
      viewType: _link.viewType,
      creationParams: _link.params,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _link.attach,
      gestureRecognizers: _gestures,
    ),
  );
}

/// Leaves the top [extent] of its child out of hit testing, so touches there
/// reach whatever is painted underneath.
class _TopPassThrough extends SingleChildRenderObjectWidget {
  const _TopPassThrough({required this.extent, super.child});

  final double extent;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTopPassThrough(extent);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTopPassThrough renderObject,
  ) {
    renderObject.extent = extent;
  }
}

class _RenderTopPassThrough extends RenderProxyBox {
  _RenderTopPassThrough(this.extent);

  double extent;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      position.dy >= extent && super.hitTest(result, position: position);
}
