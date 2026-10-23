import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_items.dart';
import 'glass_material.dart';
import 'glass_motion.dart';
import 'glass_plate.dart';

/// The tab bar, drawn by Flutter to the sizes of iOS 26's: a floating glass
/// capsule whose selection turns into a lens under the finger and can be
/// dragged across the tabs.
///
/// The widget is as tall as the bar and the room around it, down to the
/// bottom of the screen, so it belongs at the very bottom with the page
/// content extending behind it.
class RenderedGlassTabBar extends StatefulWidget {
  const RenderedGlassTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<GlassTab> tabs;

  /// Null when the current page does not belong to any tab.
  final int? selectedIndex;

  /// Called with the tab that was chosen. A tap on the open tab reports it
  /// again.
  final ValueChanged<int> onSelected;

  /// Height of the capsule on iOS 26, and its distance from the screen's
  /// sides.
  static const double capsuleHeight = 62;
  static const double margin = 21;

  /// Room above the capsule, which the lens grows into while it is held.
  static const double headroom = 16;

  /// How far the capsule floats above the bottom of the screen. On an iPhone
  /// it is as far as from the sides, a little into the home indicator's
  /// area, and the same goes for Android's gesture handle. A bar of system
  /// buttons is taller than that, so the capsule stays clear of it.
  static double bottomGap(double inset) => inset > 34 ? inset + 8 : margin;

  @override
  State<RenderedGlassTabBar> createState() => _RenderedGlassTabBarState();
}

class _RenderedGlassTabBarState extends State<RenderedGlassTabBar> {
  /// What iOS 26 keeps between the capsule's ends and its first and last tab.
  static const double _inset = 9;

  /// How far the selection reaches past its tab on either side, and what it
  /// keeps from the capsule's top and bottom.
  static const double _reach = 4.75;
  static const double _pillInset = 4;

  /// How far above the capsule's middle iOS 26 centres a tab's symbol and
  /// label.
  static const double _rise = 5 / 6;

  /// How much the lens outgrows the resting selection while it is held.
  static const _growth = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  /// How much larger the lens shows what is under it.
  static const double _magnification = 1.15;

  /// Whether a finger is on the bar, and whether it has begun to drag.
  bool _down = false;
  bool _dragging = false;

  /// Whether the tap in progress began on the tab that was already open.
  bool _retap = false;

  /// Where the lens is headed: -1 is the leftmost tab and 1 the rightmost.
  double _align = 0;

  /// Raised whenever the lens has to appear somewhere instead of travelling
  /// there.
  int _epoch = 0;

  /// The capsule's width, known once it has been laid out.
  double _width = 0;

  int get _count => widget.tabs.length;

  /// The place of tab [index] among the slots, counted from the left, and
  /// the other way round.
  int _slotOf(int index) => Directionality.of(context) == TextDirection.rtl
      ? _count - 1 - index
      : index;

  double _alignOf(int slot) => _count < 2 ? 0 : slot / (_count - 1) * 2 - 1;

  /// Where the lens rests: on the open tab.
  double get _restingAlign => _alignOf(_slotOf(widget.selectedIndex ?? 0));

  double get _slotWidth => (_width - _inset * 2) / _count;

  int _slotAt(double dx) =>
      ((dx - _inset) / _slotWidth).floor().clamp(0, _count - 1);

  /// Where the lens goes with the finger at [dx]. Past the first and last
  /// tab it follows only part of the way, like a rubber band.
  double _alignAt(double dx) {
    final travel = _slotWidth * (_count - 1);
    if (travel <= 0) return 0;
    var along = (dx.clamp(0.0, _width) - _inset - _slotWidth / 2) / travel;
    if (along < 0) along = -math.min(-along * 0.4, 0.3);
    if (along > 1) along = 1 + math.min((along - 1) * 0.4, 0.3);
    return along * 2 - 1;
  }

  int get _nearestSlot =>
      ((_align + 1) / 2 * (_count - 1)).round().clamp(0, _count - 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dragging) _align = _restingAlign;
  }

  @override
  void didUpdateWidget(RenderedGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex &&
        oldWidget.tabs.length == widget.tabs.length) {
      return;
    }
    // A selection that shows up where there was none has nowhere to travel
    // from, unless the finger has just put the lens there.
    if (oldWidget.selectedIndex == null && !_down) _epoch++;
    if (!_dragging) _align = _restingAlign;
  }

  void _choose(int slot) {
    final index = _slotOf(slot);
    if (index == widget.selectedIndex) return;
    HapticFeedback.selectionClick();
    widget.onSelected(index);
  }

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _down = true;
      if (widget.selectedIndex == null) {
        // With no tab open, the lens comes up under the finger.
        _align = _alignAt(event.localPosition.dx);
        _epoch++;
      }
    });
  }

  /// The finger is gone, unless it has taken the lens along: then the drag
  /// says when it ends.
  void _release() {
    if (!_dragging) setState(() => _down = false);
  }

  void _onTapDown(TapDownDetails details) {
    final slot = _slotAt(details.localPosition.dx);
    _retap = _slotOf(slot) == widget.selectedIndex;
    _choose(slot);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _down = false);
    final open = widget.selectedIndex;
    // A finished tap on the tab that was open all along.
    if (_retap && open != null) widget.onSelected(open);
  }

  void _onDrag(Offset position) {
    setState(() {
      _dragging = true;
      _align = _alignAt(position.dx);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    var slot = _nearestSlot;
    // A flick carries the lens one tab further than where it was let go.
    final speed = _width <= 0
        ? 0.0
        : details.velocity.pixelsPerSecond.dx / _width;
    if (speed > 0.5 && slot < _count - 1) slot++;
    if (speed < -0.5 && slot > 0) slot--;
    _settle(slot);
  }

  void _onDragCancel() {
    if (_dragging) {
      _settle(_nearestSlot);
    } else {
      setState(() {
        _down = false;
        _align = _restingAlign;
      });
    }
  }

  /// Lets the lens go on [slot].
  void _settle(int slot) {
    setState(() {
      _dragging = false;
      _down = false;
      _align = _alignOf(slot);
    });
    _choose(slot);
    // The app may not open the tab. The lens then returns to the open one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dragging || _align == _restingAlign) return;
      setState(() => _align = _restingAlign);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gap = RenderedGlassTabBar.bottomGap(
      MediaQuery.viewPaddingOf(context).bottom,
    );
    // Like UIKit's, the labels keep their size whatever the text size
    // setting: the capsule has no room for larger ones.
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          RenderedGlassTabBar.margin,
          RenderedGlassTabBar.headroom,
          RenderedGlassTabBar.margin,
          gap,
        ),
        child: SizedBox(
          height: RenderedGlassTabBar.capsuleHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _width = constraints.maxWidth;
              return _interactive(context);
            },
          ),
        ),
      ),
    );
  }

  /// The capsule with everything that moves under the finger.
  Widget _interactive(BuildContext context) {
    final open = widget.selectedIndex != null;
    final resting = _restingAlign;
    return GlassSpring(
      // The whole capsule swells a little while it is touched.
      target: _down ? 1 : 0,
      spring: GlassSprings.press,
      builder: (context, press, _, child) =>
          Transform.scale(scale: 1 + 0.04 * press, child: child),
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Each tab describes itself to screen readers.
          excludeFromSemantics: true,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _release,
          onHorizontalDragStart: (details) => _onDrag(details.localPosition),
          onHorizontalDragUpdate: (details) => _onDrag(details.localPosition),
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _onDragCancel,
          child: GlassSpring(
            target: _align,
            spring: _dragging ? GlassSprings.follow : GlassSprings.settle,
            jump: _epoch,
            builder: (context, align, velocity, _) => GlassSpring(
              // The selection is a lens while it is held and while it is on
              // its way to the open tab. At rest it is a plain shade.
              target:
                  _down || _dragging || (open && (align - resting).abs() > 0.05)
                  ? 1
                  : 0,
              spring: GlassSprings.press,
              builder: (context, lens, _, _) => _bar(
                context,
                align: align,
                velocity: velocity,
                lens: lens.clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context, {
    required double align,
    required double velocity,
    required double lens,
  }) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final open = widget.selectedIndex != null;
    final tabWidth = _slotWidth;
    final width = tabWidth + _reach * 2;
    final left =
        _inset +
        tabWidth / 2 +
        (align + 1) / 2 * tabWidth * (_count - 1) -
        width / 2;
    // The selection at rest, and what it has grown to as a lens.
    final grown = (_growth * lens).inflateRect(
      Rect.fromLTWH(
        left,
        _pillInset,
        width,
        RenderedGlassTabBar.capsuleHeight - _pillInset * 2,
      ),
    );
    final squash = _squash(velocity);
    // The tabs inside the selection are drawn in the accent colour, and a
    // little larger while it is a lens; outside it, plainly. Without a lens
    // or an open tab there is no inside.
    final selecting = open || lens > 0.01;

    Widget tabs({required bool selected}) => Padding(
      padding: const EdgeInsets.fromLTRB(_inset, 0, _inset, _rise * 2),
      child: Row(
        // Slots are counted from the left whatever the reading direction.
        textDirection: TextDirection.ltr,
        children: [
          for (var slot = 0; slot < _count; slot++)
            Expanded(
              child: _Tab(
                tab: widget.tabs[_slotOf(slot)],
                open: _slotOf(slot) == widget.selectedIndex,
                selected: selected,
                scale: selected ? lerpDouble(1, _magnification, lens)! : 1,
                color: selected
                    ? theme.colorScheme.primary
                    : GlassMaterial.label(theme.brightness),
                onTap: () {
                  final index = _slotOf(slot);
                  if (index == widget.selectedIndex) {
                    widget.onSelected(index);
                  } else {
                    _choose(slot);
                  }
                },
              ),
            ),
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GlassPlate(
            look: GlassMaterial.chrome(theme.brightness),
            shape: const StadiumBorder(),
          ),
        ),
        Positioned.fill(
          child: selecting
              ? ClipPath(
                  // No layer of its own, which Impeller would make on every
                  // frame: tabs need no smoother edge than the clip gives.
                  clipBehavior: Clip.antiAlias,
                  clipper: _AroundSelection(grown, squash),
                  child: tabs(selected: false),
                )
              : tabs(selected: false),
        ),
        if (selecting)
          Positioned.fromRect(
            rect: grown,
            child: Transform(
              alignment: Alignment.center,
              transform: squash,
              child: _Selection(
                lens: lens,
                // The shade iOS 26 lays under the open tab.
                shade: open
                    ? (dark ? Colors.white : Colors.black).withValues(
                        alpha: dark ? 0.14 : 0.07,
                      )
                    : Colors.transparent,
                look: GlassMaterial.lens(theme.brightness),
                // The same tabs once more, each where it is in the capsule.
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -grown.left,
                      top: -grown.top,
                      width: _width,
                      height: RenderedGlassTabBar.capsuleHeight,
                      child: tabs(selected: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The squash the lens takes on while it moves fast: narrower along its
  /// way and a little taller.
  static Matrix4 _squash(double velocity) {
    final amount = (velocity.abs() / 10).clamp(0.0, 1.0) * 0.35;
    return Matrix4.diagonal3Values(1 - amount * 0.5, 1 + amount * 0.3, 1);
  }
}

/// The selection of the tab bar: a plain shade under the open tab that turns
/// into a piece of glass as [lens] goes from 0 to 1. [child] is what shows
/// in it, cut to its outline.
class _Selection extends StatelessWidget {
  const _Selection({
    required this.lens,
    required this.shade,
    required this.look,
    required this.child,
  });

  final double lens;
  final Color shade;
  final GlassLook look;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The shade is gone soon after the glass starts to show.
    final resting = (1 - lens / 0.15).clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (resting > 0)
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: shade.withValues(alpha: shade.a * resting),
            ),
          ),
        // Before it is a lens, the glass is only this outline.
        GlassPlate(
          look: look.faded(lens),
          shape: const StadiumBorder(),
          child: child,
        ),
      ],
    );
  }
}

/// One tab: its symbol over its label.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.open,
    required this.selected,
    required this.scale,
    required this.color,
    required this.onTap,
  });

  final GlassTab tab;

  /// Whether this is the tab of the visible page.
  final bool open;

  /// Whether this is the copy drawn inside the selection.
  final bool selected;

  final double scale;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Transform.scale(
      scale: scale,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(
              color: color,
              size: 28,
              // Tab symbols are a little lighter than the bar's.
              shadows: GlassSymbol.heavier(color, by: 0.14),
            ),
            child: _TabIcon(
              selected ? tab.selectedSymbol : tab.symbol,
              badge: tab.badge,
            ),
          ),
          const SizedBox(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            // A label too long for its tab shrinks instead of being cut.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab.label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  letterSpacing: 0.12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // The copy in the selection is the same tab once more.
    if (selected) return ExcludeSemantics(child: content);
    return Semantics(
      container: true,
      button: true,
      selected: open,
      label: tab.label,
      value: tab.badge > 0 ? '${tab.badge}' : null,
      onTap: onTap,
      child: ExcludeSemantics(child: content),
    );
  }
}

/// A tab's symbol with its badge, where iOS puts it: at the symbol's upper
/// right, growing to the right with the number.
class _TabIcon extends StatelessWidget {
  const _TabIcon(this.symbol, {required this.badge});

  final GlassSymbol symbol;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final glyph = Transform.scale(
      scaleX: symbol.mirrored ? -symbol.scale : symbol.scale,
      scaleY: symbol.scale,
      child: Icon(symbol.icon),
    );
    if (badge <= 0) return glyph;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        glyph,
        Positioned(
          left: 26,
          top: -4,
          child: Container(
            height: 20,
            constraints: const BoxConstraints(minWidth: 20),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              // The system red of iOS 26.
              color: dark ? const Color(0xFFFF4245) : const Color(0xFFFF383C),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Everything but the selection, which has its own copy of the tabs.
class _AroundSelection extends CustomClipper<Path> {
  const _AroundSelection(this.region, this.squash);

  final Rect region;
  final Matrix4 squash;

  @override
  Path getClip(Size size) {
    final center = region.center;
    final squashed = Matrix4.translationValues(center.dx, center.dy, 0)
      ..multiply(squash)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    final outline =
        (Path()..addRRect(
              RRect.fromRectAndRadius(
                region,
                Radius.circular(region.shortestSide / 2),
              ),
            ))
            .transform(squashed.storage);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(outline, Offset.zero);
  }

  @override
  bool shouldReclip(_AroundSelection oldClipper) =>
      oldClipper.region != region || oldClipper.squash != squash;
}
