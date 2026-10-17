import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_items.dart';
import 'glass_platform.dart';
import 'native_view_link.dart';

/// The buttons of a navigation bar, hosted as a platform view.
///
/// On iOS 26 UIKit gives them Liquid Glass backgrounds and merges neighbours
/// into one capsule, as in system apps. The bar has no background of its own,
/// and the title is left for Flutter to draw.
class NativeGlassBarButtons extends StatefulWidget {
  const NativeGlassBarButtons({
    required this.leading,
    required this.trailing,
    super.key,
  });

  /// Buttons on the leading and trailing side, in reading order.
  final List<GlassBarButton> leading;
  final List<GlassBarButton> trailing;

  @override
  State<NativeGlassBarButtons> createState() => _NativeGlassBarButtonsState();
}

class _NativeGlassBarButtonsState extends State<NativeGlassBarButtons> {
  static final _gestures = <Factory<OneSequenceGestureRecognizer>>{
    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
  };

  late final _link = NativeViewLink(
    'siberia/glass_bar_buttons',
    onCall: _onCall,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _link.update(_params());
  }

  @override
  void didUpdateWidget(NativeGlassBarButtons oldWidget) {
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
      'leading': widget.leading.map(_encode).toList(growable: false),
      'trailing': widget.trailing.map(_encode).toList(growable: false),
      'tint': theme.colorScheme.primary.toARGB32(),
      'dark': theme.brightness == Brightness.dark,
    };
  }

  static Map<String, Object?> _encode(GlassBarButton button) => {
    'id': button.id,
    'symbol': button.symbol.name,
    'label': button.label,
    'enabled': button.onPressed != null,
    'loading': button.loading,
    'prominent': button.prominent,
    'separated': button.separated,
  };

  Future<void> _onCall(MethodCall call) async {
    final arguments = call.arguments;
    switch (call.method) {
      case 'tap':
        for (final button in [...widget.leading, ...widget.trailing]) {
          if (button.id == arguments) {
            button.onPressed?.call();
            return;
          }
        }
      case 'metrics':
        if (arguments is! Map) return;
        final height = arguments['height'];
        final inset = arguments['inset'];
        if (height is! num || inset is! num) return;
        final content = height - inset * 2;
        if (content <= 0) return;
        final center = arguments['center'];
        GlassPlatform.metrics.value = GlassPlatform.metrics.value.copyWith(
          navigationBarHeight: content.toDouble(),
          navigationBarRoom: inset.toDouble(),
          navigationBarCenter: center is num && center > 0
              ? center.toDouble()
              : null,
        );
    }
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: _link.viewType,
    creationParams: _link.params,
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: _link.attach,
    gestureRecognizers: _gestures,
  );
}
