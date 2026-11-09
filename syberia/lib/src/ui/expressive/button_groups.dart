import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_symbols.dart';
import '../../theme/expressive_tokens.dart';

/// The height of small buttons, of their groups and of the split button
/// (ButtonSmallTokens, ConnectedButtonGroupSmallTokens).
const _height = 40.0;
const _full = Radius.circular(_height / 2);
final _shapeSpring = SpringCurve(Springs.fastSpatial);

/// One choice of a [ConnectedButtonGroup].
typedef GroupOption<T> = ({T value, String label, IconData? icon, Key? key});

/// Material 3 Expressive's connected button group, where one of a few
/// choices is picked: a day, a period, a theme.
///
/// The buttons stand 2 points apart, rounded fully on the outside and 8
/// inside; a pressed one rounds its inside to 4 and the chosen one becomes
/// fully round, each change on a fast spatial spring. The chosen one is
/// filled with the primary colour, the others with the surface container.
class ConnectedButtonGroup<T> extends StatelessWidget {
  const ConnectedButtonGroup({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<GroupOption<T>> options;
  final T? selected;

  /// Null leaves the group disabled.
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) => _GroupRow(
    children: [
      for (final (index, option) in options.indexed)
        _GroupButton(
          key: option.key,
          label: Text(option.label),
          icon: option.icon == null ? null : Icon(option.icon),
          selected: option.value == selected,
          first: index == 0,
          last: index == options.length - 1,
          onTap: onSelected == null
              ? null
              : () {
                  if (option.value == selected) return;
                  HapticFeedback.selectionClick();
                  onSelected!(option.value);
                },
        ),
    ],
  );
}

/// A connected button group made of [ButtonSegment]s, for the places a
/// [SegmentedButton] picks one value (or none, with
/// [emptySelectionAllowed]) in the other designs.
class SegmentedGroup<T> extends StatelessWidget {
  const SegmentedGroup({
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.emptySelectionAllowed = false,
    super.key,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final bool emptySelectionAllowed;

  @override
  Widget build(BuildContext context) => _GroupRow(
    children: [
      for (final (index, segment) in segments.indexed)
        _GroupButton(
          label: segment.label ?? const SizedBox.shrink(),
          icon: segment.icon,
          tooltip: segment.tooltip,
          selected: selected.contains(segment.value),
          first: index == 0,
          last: index == segments.length - 1,
          onTap: onSelectionChanged == null || !segment.enabled
              ? null
              : () {
                  final chosen = selected.contains(segment.value);
                  if (chosen && !emptySelectionAllowed) return;
                  HapticFeedback.selectionClick();
                  onSelectionChanged!(chosen ? <T>{} : {segment.value});
                },
        ),
    ],
  );
}

/// The buttons of a group 2 points apart: sharing the width when it is
/// bounded, each as wide as it needs where it is not.
class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fill = constraints.hasBoundedWidth;
      return Row(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(width: Space.connected),
            if (fill) Expanded(child: child) else child,
          ],
        ],
      );
    },
  );
}

class _GroupButton extends StatefulWidget {
  const _GroupButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.first,
    required this.last,
    required this.onTap,
    this.tooltip,
    super.key,
  });

  final Widget label;
  final Widget? icon;
  final String? tooltip;
  final bool selected;
  final bool first;
  final bool last;
  final VoidCallback? onTap;

  @override
  State<_GroupButton> createState() => _GroupButtonState();
}

class _GroupButtonState extends State<_GroupButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onTap != null;
    final inner = Radius.circular(
      _pressed
          ? Corners.extraSmall
          : widget.selected
          ? _height / 2
          : Corners.small,
    );
    final radius = BorderRadiusDirectional.horizontal(
      start: widget.first ? _full : inner,
      end: widget.last ? _full : inner,
    );
    final (container, content) = !enabled
        ? (
            colors.onSurface.withValues(alpha: StateLayer.disabledContainer),
            colors.onSurface.withValues(alpha: StateLayer.disabledContent),
          )
        : widget.selected
        ? (colors.primary, colors.onPrimary)
        : (colors.surfaceContainer, colors.onSurfaceVariant);
    Widget button = Semantics(
      button: true,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      child: SpringShapeButton(
        shape: RoundedRectangleBorder(borderRadius: radius),
        color: container,
        onTap: widget.onTap,
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        child: _ButtonContent(
          label: widget.label,
          icon: widget.icon,
          color: content,
          padding: const EdgeInsets.symmetric(horizontal: Space.medium),
        ),
      ),
    );
    if (widget.tooltip case final tooltip?) {
      button = Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

/// Material 3 Expressive's split button: an action, and next to it a button
/// that opens its menu.
///
/// The two halves stand 2 points apart, rounded fully on the outside and 4
/// inside, 12 while pressed (SplitButtonSmallTokens). While the menu is open
/// the menu half becomes fully round and its chevron turns over.
class SplitButton extends StatefulWidget {
  const SplitButton({
    required this.label,
    required this.onPressed,
    required this.onMenu,
    required this.menuTooltip,
    this.icon,
    this.menuOpen = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VoidCallback? onMenu;
  final String menuTooltip;
  final bool menuOpen;

  @override
  State<SplitButton> createState() => _SplitButtonState();
}

class _SplitButtonState extends State<SplitButton> {
  bool _leadingPressed = false;
  bool _trailingPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Radius inner(bool pressed) =>
        Radius.circular(pressed ? Corners.medium : Corners.extraSmall);
    (Color, Color) look(bool enabled) => enabled
        ? (colors.primary, colors.onPrimary)
        : (
            colors.onSurface.withValues(alpha: StateLayer.disabledContainer),
            colors.onSurface.withValues(alpha: StateLayer.disabledContent),
          );
    final (leadingFill, leadingContent) = look(widget.onPressed != null);
    final (trailingFill, trailingContent) = look(widget.onMenu != null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          child: SpringShapeButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadiusDirectional.horizontal(
                start: _full,
                end: inner(_leadingPressed),
              ),
            ),
            color: leadingFill,
            onTap: widget.onPressed,
            onHighlightChanged: (pressed) =>
                setState(() => _leadingPressed = pressed),
            child: _ButtonContent(
              label: Text(widget.label),
              icon: widget.icon == null ? null : Icon(widget.icon),
              color: leadingContent,
              padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
            ),
          ),
        ),
        const SizedBox(width: Space.connected),
        Tooltip(
          message: widget.menuTooltip,
          child: Semantics(
            button: true,
            expanded: widget.menuOpen,
            child: SpringShapeButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusDirectional.horizontal(
                  start: widget.menuOpen ? _full : inner(_trailingPressed),
                  end: _full,
                ),
              ),
              color: trailingFill,
              onTap: widget.onMenu,
              onHighlightChanged: (pressed) =>
                  setState(() => _trailingPressed = pressed),
              child: SizedBox(
                width: 48,
                height: _height,
                child: AnimatedRotation(
                  turns: widget.menuOpen ? 0.5 : 0,
                  duration: _springTime(context, _shapeSpring),
                  curve: _shapeSpring,
                  child: Icon(
                    AppSymbols.expandMore,
                    size: 22,
                    color: trailingContent,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small button's label, with its icon (20, 8 before the label).
class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.color,
    required this.padding,
  });

  final Widget label;
  final Widget? icon;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    // 40 tall, taller only when large text needs it.
    constraints: const BoxConstraints(minHeight: _height),
    child: Padding(
      padding: padding,
      child: IconTheme.merge(
        data: IconThemeData(size: 20, color: color),
        child: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon case final icon?) ...[
                icon,
                const SizedBox(width: Space.small),
              ],
              Flexible(child: label),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A button drawn in [shape] and [color], its ink clipped to the shape, that
/// moves to a new shape or colour on a fast spatial spring; at once when the
/// phone asks for less motion.
class SpringShapeButton extends StatelessWidget {
  const SpringShapeButton({
    required this.shape,
    required this.color,
    required this.child,
    this.onTap,
    this.onHighlightChanged,
    super.key,
  });

  final ShapeBorder shape;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHighlightChanged;

  @override
  Widget build(BuildContext context) => _SpringShape(
    shape: shape,
    color: color,
    onTap: onTap,
    onHighlightChanged: onHighlightChanged,
    duration: _springTime(context, _shapeSpring),
    child: child,
  );
}

/// [spring]'s time, or none when the phone asks for less motion.
Duration _springTime(BuildContext context, SpringCurve spring) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false
    ? Duration.zero
    : spring.duration;

class _SpringShape extends ImplicitlyAnimatedWidget {
  _SpringShape({
    required this.shape,
    required this.color,
    required this.child,
    required super.duration,
    this.onTap,
    this.onHighlightChanged,
  }) : super(curve: _shapeSpring);

  final ShapeBorder shape;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHighlightChanged;

  @override
  AnimatedWidgetBaseState<_SpringShape> createState() => _SpringShapeState();
}

class _SpringShapeState extends AnimatedWidgetBaseState<_SpringShape> {
  ShapeBorderTween? _shape;
  ColorTween? _color;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _shape = visitor(
      _shape,
      widget.shape,
      (value) => ShapeBorderTween(begin: value as ShapeBorder),
    ) as ShapeBorderTween?;
    _color = visitor(
      _color,
      widget.color,
      (value) => ColorTween(begin: value as Color),
    ) as ColorTween?;
  }

  @override
  Widget build(BuildContext context) {
    final shape = _shape!.evaluate(animation)!;
    return Material(
      color: _color!.evaluate(animation),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      // This widget animates the shape and colour itself.
      animationDuration: Duration.zero,
      child: InkWell(
        customBorder: shape,
        onTap: widget.onTap,
        onHighlightChanged: widget.onHighlightChanged,
        child: widget.child,
      ),
    );
  }
}
