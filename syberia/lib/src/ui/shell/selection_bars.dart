part of '../app_shell.dart';

/// What the Messages page has picked, for the shell to show in its bars
/// while messages are being picked: the count up top with a way out, the
/// actions in place of the tabs.
@immutable
class _Selection {
  const _Selection({
    required this.count,
    required this.total,
    required this.readable,
    required this.canRead,
    required this.busy,
    required this.onClose,
    required this.onSelectAll,
    required this.onRead,
    required this.onDelete,
  });

  final int count;

  /// How many could be picked: every message on screen.
  final int total;

  /// Whether the folder can mark messages read at all; the Sent one cannot.
  final bool readable;

  /// Whether any picked message is still unread.
  final bool canRead;

  /// An action is under way.
  final bool busy;

  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  bool get all => total > 0 && count == total;
  VoidCallback? get read =>
      readable && canRead && !busy && count > 0 ? onRead : null;
  VoidCallback? get delete => !busy && count > 0 ? onDelete : null;
  VoidCallback? get selectAll => busy || total == 0 ? null : onSelectAll;

  @override
  bool operator ==(Object other) =>
      other is _Selection &&
      other.count == count &&
      other.total == total &&
      other.readable == readable &&
      other.canRead == canRead &&
      other.busy == busy &&
      other.onClose == onClose &&
      other.onSelectAll == onSelectAll &&
      other.onRead == onRead &&
      other.onDelete == onDelete;

  @override
  int get hashCode => Object.hash(
    count,
    total,
    readable,
    canRead,
    busy,
    onClose,
    onSelectAll,
    onRead,
    onDelete,
  );
}

/// What is picked, as the shell holds it for its bars. A page may hand
/// it over after the shell is gone, which [disposed] tells it.
class _SelectionBars extends ValueNotifier<_Selection?> {
  _SelectionBars() : super(null);

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// Where the Messages page hands what it has picked to the shell. Where
/// the shell has no bars to show it in, on a wide screen, [hosted] is false
/// and the page shows it itself.
class _SelectionScope extends InheritedWidget {
  const _SelectionScope({
    required this.selection,
    required this.hosted,
    required super.child,
  });

  final _SelectionBars selection;
  final bool hosted;

  static _SelectionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SelectionScope>();

  @override
  bool updateShouldNotify(_SelectionScope oldWidget) =>
      oldWidget.selection != selection || oldWidget.hosted != hosted;
}

/// "3 wybrane", or a call to pick some while none is.
String _selectionTitle(BuildContext context, int count) => count == 0
    ? context.tr('messagesPickNone')
    : _plural(context, count, 'messagesPicked');

/// The label of the button that picks everything, or nothing once all is.
String _selectAllLabel(BuildContext context, _Selection selection) =>
    context.tr(selection.all ? 'messagesSelectNone' : 'messagesSelectAllShort');

IconData _selectAllIcon(_Selection selection) =>
    selection.all ? Icons.remove_done_rounded : Icons.checklist_rounded;

/// The tint a picked row, and the bar about it, stand out in. Black stays
/// black around them, so they take the accent instead of a lighter grey.
Color _pickedTint(ThemeData theme) {
  final colors = theme.colorScheme;
  if (theme.scaffoldBackgroundColor == Colors.black) {
    return Color.alphaBlend(
      colors.primary.withValues(alpha: 0.16),
      Colors.black,
    );
  }
  return colors.secondaryContainer;
}

/// The count of picked messages, changing in place as more are picked.
class _PickedCount extends StatelessWidget {
  const _PickedCount(this.count, {required this.style});

  final int count;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: _motion(context, const Duration(milliseconds: 180)),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    layoutBuilder: (current, previous) => Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [...previous, ?current],
    ),
    child: Text(
      _selectionTitle(context, count),
      key: ValueKey(count),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(fontFeatures: _tabular),
    ),
  );
}

/// The classic top bar while messages are picked: a tinted capsule with a
/// way out, the count and a button that picks them all.
class _ClassicSelectionBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ClassicSelectionBar(this.selection);

  final _Selection selection;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSecondaryContainer;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          theme.appBarTheme.systemOverlayStyle ??
          (theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Material(
              color: _pickedTint(theme),
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('messages-selection-close'),
                    tooltip: context.tr('messagesEndSelection'),
                    color: foreground,
                    onPressed: selection.onClose,
                    icon: const AppIcon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _PickedCount(
                      selection.count,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('messages-select-all'),
                    style: TextButton.styleFrom(foregroundColor: foreground),
                    onPressed: selection.selectAll,
                    icon: AppIcon(_selectAllIcon(selection), size: 20),
                    label: Text(_selectAllLabel(context, selection)),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Expressive top bar while messages are picked: a tonal way out and a
/// tonal button that picks them all; the count is the page's large title,
/// and the bar's once that has scrolled away.
AppBar _expressiveSelectionBar(
  BuildContext context,
  _Selection selection, {
  required Widget title,
}) => AppBar(
  leading: Padding(
    padding: const EdgeInsetsDirectional.only(start: 8),
    child: Center(
      child: IconButton.filledTonal(
        key: const ValueKey('messages-selection-close'),
        tooltip: context.tr('messagesEndSelection'),
        onPressed: selection.onClose,
        icon: const AppIcon(Icons.close_rounded),
      ),
    ),
  ),
  title: title,
  actions: [
    FilledButton.tonalIcon(
      key: const ValueKey('messages-select-all'),
      onPressed: selection.selectAll,
      icon: AppIcon(_selectAllIcon(selection), size: 20),
      label: Text(_selectAllLabel(context, selection)),
    ),
    const SizedBox(width: 12),
  ],
);

/// The actions on the picked messages in place of the classic tabs, each
/// drawn as a destination of the bar it stands in for.
class _ClassicSelectionActions extends StatelessWidget {
  const _ClassicSelectionActions(this.selection);

  final _Selection selection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bar = NavigationBarTheme.of(context);
    return Material(
      color: bar.backgroundColor ?? colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bar.height ?? 80),
          child: Row(
            children: [
              if (selection.readable)
                Expanded(
                  child: _ActionDestination(
                    key: const ValueKey('messages-mark-selected-read'),
                    icon: Icons.mark_email_read_rounded,
                    label: context.tr('messagesReadShort'),
                    color: colors.primary,
                    labelColor: colors.onSurface,
                    tint:
                        bar.indicatorColor ??
                        colors.primary.withValues(alpha: 0.14),
                    onPressed: selection.read,
                  ),
                ),
              Expanded(
                child: _ActionDestination(
                  key: const ValueKey('messages-delete-selected'),
                  icon: Icons.delete_outline_rounded,
                  label: context.tr('messagesDelete'),
                  color: colors.error,
                  labelColor: colors.error,
                  tint: colors.error.withValues(alpha: 0.12),
                  onPressed: selection.delete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionDestination extends StatelessWidget {
  const _ActionDestination({
    required this.icon,
    required this.label,
    required this.color,
    required this.labelColor,
    required this.tint,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color labelColor;
  final Color tint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.38,
          duration: _motion(context, const Duration(milliseconds: 150)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 32,
                  decoration: ShapeDecoration(
                    color: tint,
                    shape: const StadiumBorder(),
                  ),
                  child: AppIcon(icon, color: color),
                ),
                const SizedBox(height: 4),
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Material 3 Expressive's floating toolbar with the actions on the picked
/// messages, in the vibrant primary container, floating where the
/// navigation bar was.
class _ExpressiveSelectionToolbar extends StatelessWidget {
  const _ExpressiveSelectionToolbar(this.selection);

  final _Selection selection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget action({
      required Key key,
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback? onPressed,
    }) => TextButton.icon(
      key: key,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: color.withValues(alpha: 0.38),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 20, 0),
        textStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed();
            },
      icon: AppIcon(icon, size: 22),
      label: Text(label),
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Material(
        color: colors.primaryContainer,
        shape: const StadiumBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selection.readable) ...[
                action(
                  key: const ValueKey('messages-mark-selected-read'),
                  icon: Icons.mark_email_read_rounded,
                  label: context.tr('messagesReadShort'),
                  color: colors.onPrimaryContainer,
                  onPressed: selection.read,
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: colors.onPrimaryContainer.withValues(alpha: 0.22),
                ),
              ],
              action(
                key: const ValueKey('messages-delete-selected'),
                icon: Icons.delete_outline_rounded,
                label: context.tr('messagesDelete'),
                color: colors.error,
                onPressed: selection.delete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The actions on the picked messages in place of the glass tab bar: the
/// toolbar iOS shows while you select.
GlassToolbar _glassSelectionActions(
  BuildContext context,
  _Selection selection,
) => GlassToolbar(
  key: const ValueKey('glass-selection-actions'),
  actions: [
    if (selection.readable)
      GlassAction(
        id: 'messages-mark-selected-read',
        label: context.tr('messagesReadShort'),
        onPressed: selection.read,
      ),
    GlassAction(
      id: 'messages-delete-selected',
      label: context.tr('messagesDelete'),
      destructive: true,
      onPressed: selection.delete,
    ),
  ],
);
