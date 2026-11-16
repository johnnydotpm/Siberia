import 'package:flutter/material.dart';

import 'glass_platform.dart';
import 'glass_shell.dart';

/// One more choice for the menu over selected text, besides copying and
/// the rest: what it reads and what it does.
@immutable
class GlassTextMenuItem {
  const GlassTextMenuItem(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

/// The menu over selected text.
///
/// In the glass design it is iOS's own edit menu where the system can show
/// it, on Liquid Glass on iOS 26, with [extra] choices first: that is over
/// text that can be edited, as iOS shows it only for a field it is typing
/// into. Elsewhere its buttons sit on a capsule of glass. The other designs
/// keep the platform's toolbar as Flutter draws it.
Widget glassTextMenu(
  BuildContext context,
  EditableTextState state, {
  List<GlassTextMenuItem> extra = const [],
}) {
  void run(VoidCallback onPressed) {
    ContextMenuController.removeAny();
    onPressed();
  }

  final buttons = [
    for (final item in extra)
      ContextMenuButtonItem(
        label: item.label,
        onPressed: () => run(item.onPressed),
      ),
    ...state.contextMenuButtonItems,
  ];
  if (!GlassStyle.of(context)) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: buttons,
    );
  }
  if (SystemContextMenu.isSupportedByField(state)) {
    return SystemContextMenu.editableText(
      editableTextState: state,
      items: [
        for (final item in extra)
          IOSSystemContextMenuItemCustom(
            title: item.label,
            onPressed: () => run(item.onPressed),
          ),
        ...SystemContextMenu.getDefaultItems(state),
      ],
    );
  }
  return _glassToolbar(context, state.contextMenuAnchors, buttons);
}

/// The menu over text selected in a selection area, as a message's: on a
/// capsule of glass in the glass design, on every platform, as iOS's own
/// edit menu is only to be had for text that can be edited; the platform's
/// toolbar as Flutter draws it in the other designs. [extra] choices first.
Widget glassSelectionMenu(
  BuildContext context,
  SelectableRegionState region, {
  List<GlassTextMenuItem> extra = const [],
}) {
  final buttons = [
    for (final item in extra)
      ContextMenuButtonItem(
        label: item.label,
        onPressed: () {
          ContextMenuController.removeAny();
          item.onPressed();
        },
      ),
    ...region.contextMenuButtonItems,
  ];
  if (!GlassStyle.of(context)) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: region.contextMenuAnchors,
      buttonItems: buttons,
    );
  }
  return _glassToolbar(context, region.contextMenuAnchors, buttons);
}

/// [buttons] in a toolbar over the selection, on a capsule of glass.
Widget _glassToolbar(
  BuildContext context,
  TextSelectionToolbarAnchors anchors,
  List<ContextMenuButtonItem> buttons,
) => TextSelectionToolbar(
  anchorAbove: anchors.primaryAnchor,
  anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
  toolbarBuilder: (context, child) => GlassPanel(
    key: const ValueKey('glass-text-menu'),
    radius: 20,
    clear: true,
    child: child,
  ),
  children: [
    for (final (index, button) in buttons.indexed)
      TextSelectionToolbarTextButton(
        padding: TextSelectionToolbarTextButton.getPadding(
          index,
          buttons.length,
        ),
        onPressed: button.onPressed,
        // The toolbar's buttons set a style of no typeface: the app's own,
        // as the edit menu's words are in the system's.
        child: Text(
          AdaptiveTextSelectionToolbar.getButtonLabel(context, button),
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            fontSize: 15,
            letterSpacing: -0.24,
          ),
        ),
      ),
  ],
);
