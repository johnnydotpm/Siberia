import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_items.dart';
import 'glass_platform.dart';
import 'native_bar_buttons.dart';
import 'native_glass_surface.dart';
import 'native_tab_bar.dart';
import 'rendered_bar_buttons.dart';
import 'rendered_glass_surface.dart';
import 'rendered_tab_bar.dart';

/// Marks a page that lives inside the glass chrome.
///
/// Such a page scrolls behind the floating bars, so it pads its content with
/// the insets from [MediaQuery]. When [largeTitle] is set, the page opens with
/// that title and lets it scroll away under the top bar.
class GlassPageScope extends InheritedWidget {
  const GlassPageScope({
    required this.largeTitle,
    required this.barActions,
    required super.child,
    super.key,
  });

  final String? largeTitle;

  /// Whether a top bar carries the page's actions. Where there is no top bar,
  /// the page has to show them itself.
  final bool barActions;

  static GlassPageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassPageScope>();

  @override
  bool updateShouldNotify(GlassPageScope oldWidget) =>
      oldWidget.largeTitle != largeTitle || oldWidget.barActions != barActions;
}

/// The large title that opens a page, as in system apps.
class GlassLargeTitle extends StatelessWidget {
  const GlassLargeTitle(this.text, {super.key});

  final String text;

  /// Where system apps start a large title, measured from the screen's edge.
  static const double margin = 16;

  /// How far a page scrolls before the title is fully under the top bar.
  static const double extent = 52;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.37,
          height: 41 / 34,
        ),
      ),
    ),
  );
}

/// A rounded glass panel that holds Flutter content: a compact sheet, a
/// dialog or the side menu.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.radius,
    required this.child,
    this.reveal,
    super.key,
  });

  final double radius;
  final Widget child;

  /// Runs from 0 to 1 while the panel appears, where Flutter draws the glass
  /// and has to bring it up itself. UIKit's glass follows the route's own
  /// fade.
  final Animation<double>? reveal;

  @override
  Widget build(BuildContext context) {
    final content = Material(type: MaterialType.transparency, child: child);
    if (GlassPlatform.backend == GlassBackend.rendered) {
      return RenderedGlassSurface(
        radius: radius,
        reveal: reveal,
        child: content,
      );
    }
    return NativeGlassSurface(
      radius: radius,
      // A veil of the surface colour keeps the glass light under dark text
      // and dark under light text, whatever happens to be behind it.
      tint: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
      child: content,
    );
  }
}

/// The phone layout of the glass design: pages scroll behind a floating tab
/// bar and glass buttons, and the title behaves the way it does in system
/// apps. On iOS 26 the bars are UIKit's own; elsewhere Flutter draws them to
/// the same sizes.
class GlassShell extends StatefulWidget {
  const GlassShell({
    required this.pageIndex,
    required this.title,
    required this.largeTitle,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    required this.menuLabel,
    required this.actions,
    required this.drawer,
    required this.body,
    super.key,
  });

  /// Identifies the visible page, so its scroll position can be remembered.
  final int pageIndex;

  final String title;

  /// Whether the visible page opens with a large title that scrolls away
  /// under the bar. A page without one keeps its own header pinned below the
  /// bar, and the bar shows the title all the time.
  final bool largeTitle;

  final List<GlassTab> tabs;

  /// Null when the visible page does not belong to any tab.
  final int? selectedTab;

  final ValueChanged<int> onTabSelected;

  /// Read by VoiceOver for the button that opens [drawer].
  final String menuLabel;

  /// Buttons on the trailing side of the top bar, in reading order.
  final List<GlassBarButton> actions;

  final Widget drawer;
  final Widget body;

  @override
  State<GlassShell> createState() => _GlassShellState();
}

class _GlassShellState extends State<GlassShell> {
  /// Scrolling this far brings the edge effect under the bar in completely.
  static const double _edgeDistance = 12;

  final _scaffold = GlobalKey<ScaffoldState>();

  /// How far each page has been scrolled. The top bar follows the visible one.
  final _offsets = <int, double>{};

  /// Where each page's list lives, to scroll it back to the top.
  final _lists = <int, BuildContext>{};

  /// How strongly content under the top bar is blurred and faded, 0 to 1.
  final _edge = ValueNotifier<double>(0);

  /// How visible the bar's own title is while the large one scrolls away.
  final _barTitle = ValueNotifier<double>(0);

  @override
  void didUpdateWidget(GlassShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex != widget.pageIndex) {
      _follow(_offsets[widget.pageIndex] ?? 0);
    }
  }

  @override
  void dispose() {
    _edge.dispose();
    _barTitle.dispose();
    super.dispose();
  }

  void _follow(double pixels) {
    _edge.value = (pixels / _edgeDistance).clamp(0.0, 1.0);
    _barTitle.value =
        ((pixels - GlassLargeTitle.extent / 2) / (GlassLargeTitle.extent / 4))
            .clamp(0.0, 1.0);
  }

  bool _onScroll(ScrollNotification notification) {
    // Only the page's own vertical list moves the title, not a list nested in
    // it or a horizontal strip.
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      final pixels = math.max(0.0, notification.metrics.pixels);
      _offsets[widget.pageIndex] = pixels;
      final list = notification.context;
      if (list != null) _lists[widget.pageIndex] = list;
      _follow(pixels);
    }
    return false;
  }

  /// Tapping the tab that is already open returns its page to the top, as in
  /// system apps.
  void _onTabSelected(int index) {
    if (index != widget.selectedTab) {
      widget.onTabSelected(index);
      return;
    }
    final list = _lists[widget.pageIndex];
    if (list == null || !list.mounted) return;
    Scrollable.maybeOf(list)?.position.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final leading = [
      GlassBarButton(
        id: 'menu',
        symbol: GlassSymbol.menu,
        label: widget.menuLabel,
        onPressed: () => _scaffold.currentState?.openDrawer(),
      ),
    ];
    final theme = Theme.of(context);
    return Theme(
      // A message floats above the tab bar. Spanning the screen, it would
      // look cut off by the bar that floats below it.
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      child: ValueListenableBuilder<GlassMetrics>(
        valueListenable: GlassPlatform.metrics,
        builder: (context, metrics, _) => Scaffold(
          key: _scaffold,
          extendBody: true,
          extendBodyBehindAppBar: true,
          drawerScrimColor: Colors.black.withValues(alpha: 0.2),
          drawer: _GlassDrawer(child: widget.drawer),
          appBar: _TopBar(
            height: metrics.navigationBarHeight,
            buttonsCenter: metrics.navigationBarCenter,
            room: metrics.navigationBarRoom,
            title: widget.title,
            largeTitle: widget.largeTitle,
            edge: _edge,
            barTitle: _barTitle,
            leading: leading,
            trailing: widget.actions,
          ),
          body: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.body,
          ),
          bottomNavigationBar: _BottomBar(
            tabs: widget.tabs,
            selectedIndex: widget.selectedTab,
            onSelected: _onTabSelected,
          ),
        ),
      ),
    );
  }
}

/// The floating top bar: glass buttons over a title drawn by Flutter.
///
/// Everything else Flutter paints here sits below the buttons. Where they are
/// a platform view, no extra layer has to be composited above it.
class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.height,
    required this.buttonsCenter,
    required this.room,
    required this.title,
    required this.largeTitle,
    required this.edge,
    required this.barTitle,
    required this.leading,
    required this.trailing,
  });

  /// The least distance between the buttons and the title.
  static const double _titleGap = 8;

  /// Height of the bar, as UIKit lays it out.
  final double height;

  /// The middle of the buttons, measured from the top of the bar. UIKit does
  /// not centre them in the bar, and the title has to line up with them.
  final double buttonsCenter;

  /// Room the buttons' view needs above and below the bar.
  final double room;

  final String title;
  final bool largeTitle;
  final ValueListenable<double> edge;
  final ValueListenable<double> barTitle;
  final List<GlassBarButton> leading;
  final List<GlassBarButton> trailing;

  @override
  Size get preferredSize => Size.fromHeight(height);

  /// The width [buttons] take on one side of the bar, up to where the title
  /// may begin.
  static double _reserved(List<GlassBarButton> buttons) {
    if (buttons.isEmpty) return GlassBarButton.edgeGap;
    final groups = GlassBarButton.groups(buttons);
    return GlassBarButton.edgeGap +
        groups.fold(
          0.0,
          (width, group) => width + GlassBarButton.groupWidth(group.length),
        ) +
        (groups.length - 1) * GlassBarButton.groupGap +
        _titleGap;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    // Like UIKit's, the bar title grows only a little with the text size
    // setting: the row it sits in has a fixed height.
    final titleText = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The same as under the classic top bar. On Android it also keeps the
      // status bar clear, so the page shows through behind the clock.
      value:
          theme.appBarTheme.systemOverlayStyle ??
          (theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // A page without a large title pins its own header below the bar,
          // so nothing ever slides under it.
          if (largeTitle)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: top + height + _ScrollEdge.tail,
              child: _ScrollEdge(solidExtent: top + height, strength: edge),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: top,
            height: buttonsCenter * 2,
            child: IgnorePointer(
              child: CustomSingleChildLayout(
                delegate: _TitleLayout(
                  leading: _reserved(leading),
                  trailing: _reserved(trailing),
                  textDirection: Directionality.of(context),
                ),
                child: largeTitle
                    // The large title in the page is the heading until it has
                    // scrolled away; this one only takes its place visually.
                    ? ExcludeSemantics(
                        child: ValueListenableBuilder<double>(
                          valueListenable: barTitle,
                          builder: (context, value, child) =>
                              Opacity(opacity: value, child: child),
                          child: titleText,
                        ),
                      )
                    : Semantics(header: true, child: titleText),
              ),
            ),
          ),
          if (GlassPlatform.backend == GlassBackend.rendered)
            // Flutter's own buttons paint their shadows past their bounds, so
            // they need no more room than the row UIKit puts its buttons in.
            Positioned(
              left: 0,
              right: 0,
              top: top,
              height: buttonsCenter * 2,
              child: RenderedGlassBarButtons(
                leading: leading,
                trailing: trailing,
              ),
            )
          else
            // The view is taller than the row: glass buttons cast a wide
            // shadow that would otherwise end in a line at the view's edge.
            Positioned(
              left: 0,
              right: 0,
              top: top - room,
              height: height + room * 2,
              child: NativeGlassBarButtons(
                leading: leading,
                trailing: trailing,
              ),
            ),
        ],
      ),
    );
  }
}

/// What iOS shows where content slides under a bar: it blurs and fades into
/// the background, more strongly the closer it gets to the screen's edge.
class _ScrollEdge extends StatelessWidget {
  const _ScrollEdge({required this.solidExtent, required this.strength});

  /// How far below [solidExtent] the effect takes to fade out.
  static const double tail = 36;

  /// The blur at full strength. A backdrop blur cannot fade by itself, so
  /// the tail is cut into bands, each a little sharper than the one above.
  /// They are thin enough for the steps between them not to show.
  static const double _blur = 14;
  static const int _bands = 9;

  /// How much of the background colour covers the blurred content.
  static const double _veil = 0.7;

  /// The height, from the top, where the effect is at full strength.
  final double solidExtent;

  /// 0 while the page rests at its top, 1 once content is under the bar.
  final ValueListenable<double> strength;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: strength,
        builder: (context, value, _) {
          if (value <= 0) return const SizedBox.shrink();
          const step = tail / _bands;
          final extent = solidExtent + tail;
          return BackdropGroup(
            child: Stack(
              children: [
                _band(0, solidExtent, _blur * value),
                for (var index = 0; index < _bands; index++)
                  _band(
                    solidExtent + index * step,
                    step,
                    // Eases out, so the blur lets go of the content gently.
                    _blur *
                        value *
                        math.pow(1 - (index + 0.5) / _bands, 1.5).toDouble(),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          background.withValues(alpha: _veil * value),
                          background.withValues(alpha: _veil * value),
                          background.withValues(alpha: _veil * value * 0.4),
                          background.withValues(alpha: 0),
                        ],
                        stops: [
                          0,
                          solidExtent / extent,
                          (solidExtent + tail * 0.45) / extent,
                          1,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _band(double top, double height, double sigma) => Positioned(
    left: 0,
    right: 0,
    top: top,
    height: height,
    child: ClipRect(
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

/// Centres the title on the screen, like UIKit, and moves it aside only when
/// the buttons leave no room there.
class _TitleLayout extends SingleChildLayoutDelegate {
  _TitleLayout({
    required this.leading,
    required this.trailing,
    required this.textDirection,
  });

  final double leading;
  final double trailing;
  final TextDirection textDirection;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(0.0, constraints.maxWidth - leading - trailing),
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final (left, right) = switch (textDirection) {
      TextDirection.ltr => (leading, trailing),
      TextDirection.rtl => (trailing, leading),
    };
    final centred = (size.width - childSize.width) / 2;
    final farthest = math.max(left, size.width - right - childSize.width);
    return Offset(
      centred.clamp(left, farthest),
      (size.height - childSize.height) / 2,
    );
  }

  @override
  bool shouldRelayout(_TitleLayout oldDelegate) =>
      oldDelegate.leading != leading ||
      oldDelegate.trailing != trailing ||
      oldDelegate.textDirection != textDirection;
}

/// The tab bar over a soft fade, so its labels stay readable and the page
/// does not show through below the bar.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GlassTab> tabs;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    background.withValues(alpha: 0),
                    background.withValues(alpha: 0.5),
                    background.withValues(alpha: 0.92),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        if (GlassPlatform.backend == GlassBackend.rendered)
          RenderedGlassTabBar(
            tabs: tabs,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
          )
        else
          NativeGlassTabBar(
            tabs: tabs,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

/// The side menu as a floating glass panel.
class _GlassDrawer extends StatelessWidget {
  const _GlassDrawer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Drawer(
    width: math.min(320.0, MediaQuery.sizeOf(context).width - 64),
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    // The glass rounds its own corners. A rounded Material shape would clip
    // the platform view and flatten the material.
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.none,
    child: SafeArea(
      minimum: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      child: GlassPanel(radius: 32, child: child),
    ),
  );
}
