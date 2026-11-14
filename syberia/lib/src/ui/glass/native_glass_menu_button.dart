import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_modals.dart';
import 'native_view_link.dart';

/// A clear UIKit button over a title that Flutter draws, which opens
/// UIKit's own menu of [items]: on iOS 26 the system brings it out of the
/// title on Liquid Glass, with its liquid motion, and folds it back in.
///
/// A tap that stays put reaches the button; a drag still scrolls the page.
class NativeGlassMenuButton<T> extends StatefulWidget {
  const NativeGlassMenuButton({
    required this.label,
    required this.items,
    required this.onPicked,
    super.key,
  });

  /// What VoiceOver reads for the title.
  final String label;
  final List<GlassMenuItem<T>> items;
  final ValueChanged<T> onPicked;

  @override
  State<NativeGlassMenuButton<T>> createState() =>
      _NativeGlassMenuButtonState<T>();
}

class _NativeGlassMenuButtonState<T> extends State<NativeGlassMenuButton<T>> {
  late final _link = NativeViewLink(
    'siberia/glass_menu_button',
    onCall: _onCall,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _link.update(_params());
  }

  @override
  void didUpdateWidget(NativeGlassMenuButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _link.update(_params());
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Map<String, Object?> _params() => {
    'label': widget.label,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'items': [
      for (final (index, item) in widget.items.indexed)
        {'id': '$index', 'title': item.label, 'selected': item.selected},
    ],
  };

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'pick') return;
    final index = int.tryParse('${call.arguments}');
    if (index == null || index < 0 || index >= widget.items.length) return;
    widget.onPicked(widget.items[index].value);
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: _link.viewType,
    creationParams: _link.params,
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: _link.attach,
  );
}
