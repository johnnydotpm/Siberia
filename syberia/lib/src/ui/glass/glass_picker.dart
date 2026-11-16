import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'glass_modals.dart';
import 'glass_platform.dart';
import 'native_glass_menu_button.dart';

/// A choice among a few as iOS draws a pop-up button: a row with [label],
/// the choice and its two chevrons at the end. Its menu is UIKit's own on
/// iOS 26, which the system brings out of the row on Liquid Glass, and the
/// glass menu elsewhere, which pours out from under the chevrons.
class GlassPickerRow<T> extends StatefulWidget {
  const GlassPickerRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;

  /// Each choice and what it reads.
  final List<(T, String)> options;

  /// Null leaves the row disabled.
  final ValueChanged<T>? onChanged;

  @override
  State<GlassPickerRow<T>> createState() => _GlassPickerRowState<T>();
}

class _GlassPickerRowState<T> extends State<GlassPickerRow<T>> {
  final _chevron = GlobalKey();

  /// The choices for a menu, by their place: a choice may itself be null.
  List<GlassMenuItem<int>> get _items => [
    for (final (index, (value, label)) in widget.options.indexed)
      GlassMenuItem(
        key: ValueKey('picker-option-$index'),
        value: index,
        label: label,
        selected: value == widget.value,
      ),
  ];

  void _pick(int index) {
    final value = widget.options[index].$1;
    if (value != widget.value) widget.onChanged?.call(value);
  }

  Future<void> _open() async {
    final row = context.findRenderObject()! as RenderBox;
    final chevron = _chevron.currentContext?.findRenderObject() as RenderBox?;
    final anchor = row.localToGlobal(Offset.zero) & row.size;
    final picked = await showGlassMenu<int>(
      context: context,
      anchor: anchor,
      origin: chevron == null
          ? anchor.centerRight
          : chevron.localToGlobal(chevron.size.center(Offset.zero)),
      items: _items,
    );
    if (picked != null && mounted) _pick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final change = widget.onChanged;
    final colors = Theme.of(context).colorScheme;
    final chosen = widget.options
        .where((option) => option.$1 == widget.value)
        .map((option) => option.$2)
        .firstOrNull;
    final native = GlassPlatform.backend == GlassBackend.uikit;
    final row = ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: change != null,
      title: Text(widget.label),
      onTap: change == null || native ? null : _open,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              chosen ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.primary, fontSize: 16),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_up_chevron_down,
            key: _chevron,
            size: 14,
            color: colors.primary,
          ),
        ],
      ),
    );
    if (!native || change == null) return row;
    // On iOS 26 a tap on the row reaches UIKit's own button over it.
    return Stack(
      children: [
        ExcludeSemantics(child: row),
        Positioned.fill(
          child: NativeGlassMenuButton<int>(
            label: '${widget.label}: ${chosen ?? ''}',
            items: _items,
            onPicked: _pick,
          ),
        ),
      ],
    );
  }
}
