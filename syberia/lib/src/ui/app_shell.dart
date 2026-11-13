import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/rendering.dart'
    show
        BoxParentData,
        OpacityLayer,
        RenderAbstractViewport,
        RenderObjectVisitor,
        RenderProxyBox,
        RenderShiftedBox;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_build_info.dart';
import '../data/app_repository.dart';
import '../data/diary_plugin.dart';
import '../debug/diagnostics.dart';
import '../domain/calendar_days.dart';
import '../domain/excuse.dart';
import '../domain/grade_calculator.dart';
import '../domain/librus_error.dart';
import '../domain/models.dart';
import '../domain/profiles.dart';
import '../domain/parent.dart';
import '../domain/sync_news.dart';
import '../domain/together.dart' show localId, togetherId;
import '../home_widget.dart';
import '../network_vpn.dart';
import '../l10n/app_localizations.dart';
import '../school_notifications.dart';
import '../state/app_controller.dart';
import '../test_reminders.dart';
import '../theme/app_theme.dart';
import '../theme/expressive_tokens.dart';
import 'brand/brand_mark.dart';
import 'brand/brand_wordmark.dart';
import 'brand_logo.dart';
import 'expressive/expressive.dart';
import 'glass/glass_items.dart';
import 'glass/glass_modals.dart';
import 'glass/glass_platform.dart';
import 'glass/glass_shell.dart';
import 'glass/glass_toolbar.dart';
import 'home_widget_settings.dart';
import 'linked_text.dart';
import 'profile_avatar.dart';
import 'screen_transitions.dart';
import 'subject_colors.dart';

part 'shell/common.dart';
part 'shell/today.dart';
part 'shell/timetable.dart';
part 'shell/timetable_views.dart';
part 'shell/grades.dart';
part 'shell/grade_calculator_sheet.dart';
part 'shell/events_homework.dart';
part 'shell/messages.dart';
part 'shell/message_page.dart';
part 'shell/message_compose.dart';
part 'shell/attendance.dart';
part 'shell/announcements_notices.dart';
part 'shell/settings.dart';
part 'shell/settings_previews.dart';
part 'shell/notification_settings.dart';
part 'shell/account.dart';
part 'shell/parent.dart';
part 'shell/onboarding.dart';
part 'shell/onboarding_intro.dart';
part 'shell/onboarding_motion.dart';
part 'shell/onboarding_sign_in.dart';
part 'shell/onboarding_finale.dart';
part 'shell/free_days.dart';
part 'shell/motion.dart';
part 'shell/sync_news.dart';
part 'shell/debug_menu.dart';
part 'shell/together.dart';
part 'shell/excuse.dart';
part 'shell/selection_bars.dart';
part 'shell/month_calendar.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});
  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _pageCount = 10;

  /// The last widget built for each page that has been open. Handing a
  /// hidden page the same widget again lets Flutter skip it, so a change in
  /// the app rebuilds only the page on screen. Pages not opened yet are not
  /// built at all.
  final _pages = <int, Widget>{};
  (bool, bool, bool)? _pagesLayout;
  List<Lesson>? _colorLessons;
  Set<String> _colorSubjects = const {};
  SubjectColors _colors = SubjectColors.empty;

  /// The vertical list last scrolled on each page, to take back to the top.
  final _lists = <int, BuildContext>{};

  /// In the Expressive design: whether each page has scrolled its large
  /// title away, so the top bar shows it. [_titleScroll] ticks on a change.
  final _titleAway = <int, bool>{};
  final _titleScroll = ValueNotifier(0);

  /// The page whose tab was tapped while open, for the page to act on.
  final _reselected = _Reselect();

  /// What the Messages page has picked, shown in the bars while it picks.
  final _selection = _SelectionBars();

  /// The folder of messages open; the glass bar is titled after it.
  final _messagesFolder = ValueNotifier(_MessageFolder.inbox);

  /// Everything the shell is drawn from.
  late final _changes = Listenable.merge([
    widget.controller,
    _selection,
    _messagesFolder,
  ]);

  AppController get controller => widget.controller;

  @override
  void dispose() {
    _reselected.dispose();
    _titleScroll.dispose();
    _selection.dispose();
    _messagesFolder.dispose();
    super.dispose();
  }

  /// The open tab tapped again: its page back to the top, as in system
  /// apps; the timetable back to today.
  void _reselect(int page, {required bool glass}) {
    _reselected.fire(page);
    // The glass shell scrolls its own pages.
    if (glass) return;
    final list = _lists[page];
    if (list == null || !list.mounted) return;
    final position = Scrollable.maybeOf(list)?.position;
    if (position == null) return;
    if (_reduceMotion(context)) {
      position.jumpTo(0);
    } else {
      position.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _onScroll(ScrollNotification notification) {
    // The page's own list, not one nested in it or a horizontal strip.
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.context != null) {
      _lists[controller.tabIndex] = notification.context!;
      final away = notification.metrics.pixels > ExpressiveLargeTitle.extent;
      if (_titleAway[controller.tabIndex] != away) {
        _titleAway[controller.tabIndex] = away;
        _titleScroll.value++;
      }
    }
    return false;
  }

  Widget _page(int index) => switch (index) {
    0 => _Today(controller),
    1 => _Timetable(controller, reselected: _reselected),
    2 => _Grades(controller),
    3 => _Events(controller),
    4 => _Homework(controller),
    5 => _Messages(controller),
    6 => _Attendance(controller),
    7 => _Announcements(controller),
    8 => _Notices(controller),
    _ => _Settings(controller),
  };

  /// Subject colours change only when the set of subjects does, so pages
  /// that use them are not rebuilt by every sync.
  SubjectColors _subjectColors() {
    final lessons = controller.snapshot.lessons;
    if (identical(lessons, _colorLessons)) return _colors;
    _colorLessons = lessons;
    final subjects = {for (final lesson in lessons) lesson.subject};
    if (!setEquals(subjects, _colorSubjects)) {
      _colorSubjects = subjects;
      _colors = SubjectColors.assign(subjects);
    }
    return _colors;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        // The first setup comes before anything else; the demo, started
        // from its logo, leaves it for the time being.
        if (!controller.onboardingDone && !controller.isDemo) {
          _pages.clear();
          return _Onboarding(controller: controller);
        }
        if (!controller.isDemo && !controller.snapshot.profile.connected) {
          _pages.clear();
          return _LoginRequired(controller: controller);
        }
        final wide = constraints.maxWidth >= 900;
        // In the glass design the bars, compact sheets and menus are glass:
        // UIKit's own on iOS 26, drawn by Flutter elsewhere.
        final glass = GlassStyle.of(context);
        final expressive = ExpressiveStyle.of(context);
        // While messages are picked, the bars are about them: the count up
        // top with a way out, the actions in place of the tabs. A wide
        // screen has no such bars, and the page shows them itself.
        final picking = !wide && controller.tabIndex == _messagesTab
            ? _selection.value
            : null;
        String titleOf(int index) => index != _messagesTab
            ? _title(context, index)
            : picking != null
            ? _selectionTitle(context, picking.count)
            // In glass the bar is titled after the folder, as in Mail.
            : _folderName(context, _messagesFolder.value);
        Widget wrap(int index, Widget page) => glass
            ? GlassPageScope(
                // The timetable keeps its day strip under the bar, so it has
                // no title that could scroll away.
                largeTitle: index == 1 ? null : titleOf(index),
                barActions: !wide,
                child: page,
              )
            : expressive
            ? ExpressivePageScope(
                largeTitle: index == 1 ? null : _title(context, index),
                child: page,
              )
            : page;
        // Pages kept from another layout would have the wrong wrapper.
        if (_pagesLayout != (glass, wide, expressive)) {
          _pagesLayout = (glass, wide, expressive);
          _pages.clear();
        }
        final current = controller.tabIndex;
        final pages = [
          for (var index = 0; index < _pageCount; index++)
            index == current
                ? _pages[index] = wrap(index, _page(index))
                : _pages[index] ?? const SizedBox.shrink(),
        ];
        final body = _SubjectScope(
          studentTools: controller.canUseStudentTools,
          names: controller.subjectShortNames,
          colors: _subjectColors(),
          child: _FreeDaysScope(
            days: controller.snapshot.freeDays,
            child: _ControllerScope(
              controller: controller,
              child: _SelectionScope(
                selection: _selection,
                hosted: !wide,
                folder: _messagesFolder,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      // Pages fade through one another, as Material's
                      // navigation bar asks; glass switches at once, as
                      // iOS does.
                      child: _TabSwitch(
                        index: current,
                        animate: !glass,
                        children: pages,
                      ),
                    ),
                    // Under the top bar, over the page.
                    Positioned(
                      top: 0,
                      left: _Space.page,
                      right: _Space.page,
                      child: Builder(
                        builder: (context) => Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.paddingOf(context).top + 8,
                          ),
                          child: Center(child: _SyncNewsBanner(controller)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: glass
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: GlassPanel(
                            radius: 28,
                            child: _SideNavigation(
                              controller: controller,
                              permanent: true,
                              glass: true,
                            ),
                          ),
                        )
                      : _SideNavigation(
                          controller: controller,
                          permanent: true,
                        ),
                ),
                if (!glass) const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        final bottomTabs = controller.bottomTabs;
        final selected = bottomTabs.indexOf(controller.tabIndex);
        if (glass) {
          return GlassShell(
            pageIndex: controller.tabIndex,
            title: titleOf(controller.tabIndex),
            largeTitle: controller.tabIndex != 1,
            tabs: [
              for (final tab in bottomTabs)
                GlassTab(
                  label: context.tr(_tabLooks[tab].label),
                  symbol: _tabLooks[tab].symbol,
                  selectedSymbol: _tabLooks[tab].selectedSymbol,
                  badge: tab == 5 ? controller.snapshot.unreadMessages : 0,
                ),
            ],
            selectedTab: selected < 0 ? null : selected,
            onTabSelected: (index) => controller.selectTab(bottomTabs[index]),
            onTabReselected: (index) =>
                _reselect(bottomTabs[index], glass: true),
            menuLabel: MaterialLocalizations.of(context).openAppDrawerTooltip,
            leading: picking == null
                ? null
                : [
                    GlassBarButton(
                      id: 'selection-close',
                      symbol: GlassSymbol.close,
                      label: context.tr('messagesEndSelection'),
                      onPressed: picking.onClose,
                    ),
                  ],
            actionBar: picking == null
                ? null
                : _glassSelectionActions(context, picking),
            actions: picking != null
                ? [
                    GlassBarButton(
                      id: 'selection-all',
                      symbol: GlassSymbol.selectAll,
                      label: _selectAllLabel(context, picking),
                      onPressed: picking.selectAll,
                    ),
                  ]
                : [
                    if (controller.tabIndex == 5)
                      GlassBarButton(
                        id: 'compose',
                        symbol: GlassSymbol.compose,
                        label: context.tr('newMessage'),
                        prominent: true,
                        separated: true,
                        onPressed: () =>
                            _showComposeMessage(context, controller),
                      ),
                    GlassBarButton(
                      id: 'sync',
                      symbol: GlassSymbol.sync,
                      label: context.tr('sync'),
                      loading: controller.syncing,
                      onPressed: controller.syncing ? null : controller.sync,
                    ),
                    _profileBarButton(context, controller),
                  ],
            drawer: _SideNavigation(controller: controller, glass: true),
            body: body,
          );
        }
        void selectBottomTab(int index) {
          HapticFeedback.selectionClick();
          final page = bottomTabs[index];
          if (page == controller.tabIndex) {
            _reselect(page, glass: false);
          } else {
            controller.selectTab(page);
          }
        }

        return Scaffold(
          drawer: Drawer(
            child: SafeArea(child: _SideNavigation(controller: controller)),
          ),
          // The bars fade from one to the next: a page's to another's,
          // and to the picking ones.
          appBar: _SwitchedBar(
            picking == null
                ? AppBar(
                    // A bar of its own for each page: one scrolled under does
                    // not leave the next page's bar filled.
                    key: ValueKey('app-bar-${controller.tabIndex}'),
                    // In the Expressive design the page opens with its own large
                    // title; the bar shows it once that has scrolled away.
                    title: expressive && controller.tabIndex != 1
                        ? ValueListenableBuilder(
                            valueListenable: _titleScroll,
                            builder: (context, _, child) => AnimatedOpacity(
                              opacity: _titleAway[controller.tabIndex] ?? false
                                  ? 1
                                  : 0,
                              duration: const Duration(milliseconds: 150),
                              child: child,
                            ),
                            child: Text(_title(context, controller.tabIndex)),
                          )
                        : Text(_title(context, controller.tabIndex)),
                    actions: [
                      // Writing is the messages' own action, in the bar as in
                      // glass. Expressive keeps it beside the page's title.
                      if (!expressive && controller.tabIndex == _messagesTab)
                        IconButton(
                          key: const ValueKey('messages-compose'),
                          onPressed: () =>
                              _showComposeMessage(context, controller),
                          icon: const AppIcon(Icons.edit_rounded),
                          tooltip: context.tr('newMessage'),
                        ),
                      // One sign of a sync: the button turns into its spinner.
                      IconButton(
                        key: const ValueKey('sync-button'),
                        onPressed: controller.syncing ? null : controller.sync,
                        icon: controller.syncing
                            ? expressive
                                  // Expressive's own: shapes that morph as they turn.
                                  ? const SizedBox.square(
                                      dimension: 28,
                                      child: FittedBox(
                                        child: LoadingIndicator(),
                                      ),
                                    )
                                  : const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                            : const AppIcon(Icons.sync_rounded),
                        tooltip: context.tr('sync'),
                      ),
                      IconButton(
                        key: const ValueKey('profile-button'),
                        tooltip: context.tr('profiles'),
                        onPressed: () => _showProfiles(context, controller),
                        icon: _OpenProfileSign(
                          controller,
                          radius: 15,
                          news: controller.otherProfilesHaveNews,
                        ),
                      ),
                    ],
                  )
                : expressive
                ? KeyedSubtree(
                    key: const ValueKey('selection-bar'),
                    child: _expressiveSelectionBar(
                      context,
                      picking,
                      title: ValueListenableBuilder(
                        valueListenable: _titleScroll,
                        builder: (context, _, child) => AnimatedOpacity(
                          opacity: _titleAway[controller.tabIndex] ?? false
                              ? 1
                              : 0,
                          duration: const Duration(milliseconds: 150),
                          child: child,
                        ),
                        child: Text(titleOf(controller.tabIndex)),
                      ),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('selection-bar'),
                    child: _ClassicSelectionBar(picking),
                  ),
          ),
          body: body,
          // Expressive's bar slides away under its floating actions; the
          // classic one gives way to the actions in its place.
          bottomNavigationBar: _SwitchedBottom(
            collapse: expressive,
            child: picking != null
                ? expressive
                      ? const SizedBox.shrink(key: ValueKey('no-bar'))
                      : KeyedSubtree(
                          key: const ValueKey('selection-actions'),
                          child: _ClassicSelectionActions(picking),
                        )
                : controller.design == AppDesign.expressive
                ? ExpressiveNavigationBar(
                    key: const ValueKey('navigation-bar'),
                    selectedIndex: selected,
                    onSelected: selectBottomTab,
                    destinations: [
                      for (final tab in bottomTabs)
                        (
                          icon: _tabLooks[tab].icon,
                          label: context.tr(_tabLooks[tab].label),
                          badge: tab == 5
                              ? controller.snapshot.unreadMessages
                              : 0,
                          badgeText: badgeText(
                            tab == 5 ? controller.snapshot.unreadMessages : 0,
                          ),
                        ),
                    ],
                  )
                // A page opened from the menu has no tab, so none looks
                // selected. NavigationBar always selects one, so the first is
                // drawn plain.
                : NavigationBarTheme(
                    key: const ValueKey('navigation-bar'),
                    data: selected >= 0
                        ? NavigationBarTheme.of(context)
                        : NavigationBarTheme.of(context).copyWith(
                            indicatorColor: Colors.transparent,
                            iconTheme: WidgetStatePropertyAll(
                              IconThemeData(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                    child: NavigationBar(
                      selectedIndex: selected < 0 ? 0 : selected,
                      onDestinationSelected: selectBottomTab,
                      destinations: [
                        for (final tab in bottomTabs)
                          _destination(
                            _tabLooks[tab].icon,
                            // Off the bar, Today stands selected only for show.
                            tab == 0 && selected < 0
                                ? _tabLooks[tab].icon
                                : _tabLooks[tab].selectedIcon,
                            context.tr(_tabLooks[tab].label),
                            badge: tab == 5
                                ? controller.snapshot.unreadMessages
                                : 0,
                          ),
                      ],
                    ),
                  ),
          ),
          // Expressive's actions float where its navigation bar was.
          floatingActionButton: picking != null && expressive
              ? _ExpressiveSelectionToolbar(picking)
              : null,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    ),
  );
}

/// How each page shows on the bottom bar: its name, Material icons for the
/// classic bar and symbols for the glass one.
const List<
  ({
    String label,
    IconData icon,
    IconData selectedIcon,
    GlassSymbol symbol,
    GlassSymbol? selectedSymbol,
  })
>
_tabLooks = [
  (
    label: 'today',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    symbol: GlassSymbol.house,
    selectedSymbol: GlassSymbol.houseFill,
  ),
  (
    label: 'timetable',
    icon: Icons.calendar_view_week_outlined,
    selectedIcon: Icons.calendar_view_week_rounded,
    symbol: GlassSymbol.calendar,
    selectedSymbol: null,
  ),
  (
    label: 'grades',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
    symbol: GlassSymbol.graduationCap,
    selectedSymbol: GlassSymbol.graduationCapFill,
  ),
  (
    label: 'calendar',
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note_rounded,
    symbol: GlassSymbol.list,
    selectedSymbol: GlassSymbol.listFill,
  ),
  (
    label: 'homework',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment_rounded,
    symbol: GlassSymbol.book,
    selectedSymbol: GlassSymbol.bookFill,
  ),
  (
    label: 'messages',
    icon: Icons.mail_outline_rounded,
    selectedIcon: Icons.mail_rounded,
    symbol: GlassSymbol.envelope,
    selectedSymbol: GlassSymbol.envelopeFill,
  ),
  (
    label: 'attendance',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check_rounded,
    symbol: GlassSymbol.checkmark,
    selectedSymbol: GlassSymbol.checkmarkFill,
  ),
  (
    label: 'announcements',
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign_rounded,
    symbol: GlassSymbol.megaphone,
    selectedSymbol: GlassSymbol.megaphoneFill,
  ),
  (
    label: 'notices',
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
    symbol: GlassSymbol.textBubble,
    selectedSymbol: GlassSymbol.textBubbleFill,
  ),
];

/// Tells a page that its tab was tapped while it was open.
class _Reselect extends ChangeNotifier {
  int? page;

  void fire(int value) {
    page = value;
    notifyListeners();
  }
}

NavigationDestination _destination(
  IconData icon,
  IconData selected,
  String label, {
  int badge = 0,
}) {
  // The count stays on the selected tab too, as in the glass bar and the
  // side navigation.
  Widget badged(IconData data) => Badge(
    isLabelVisible: badge > 0,
    label: Text(
      badgeText(badge),
      style: const TextStyle(fontFeatures: _tabular),
    ),
    child: AppIcon(data),
  );
  return NavigationDestination(
    icon: badged(icon),
    selectedIcon: badged(selected),
    label: label,
  );
}

String _title(BuildContext context, int index) => context.tr(
  const [
    'today',
    'timetable',
    'grades',
    'calendar',
    'homework',
    'messages',
    'attendance',
    'announcements',
    'notices',
    'settings',
  ][index],
);

/// Keep a menu that fits stationary, even when inherited scroll physics
/// allow dragging short lists. Overflowing menus retain platform scrolling.
class _MenuScrollPhysics extends ScrollPhysics {
  const _MenuScrollPhysics({super.parent});

  @override
  _MenuScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _MenuScrollPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      position.maxScrollExtent > position.minScrollExtent &&
      super.shouldAcceptUserOffset(position);
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.controller,
    this.permanent = false,
    this.glass = false,
  });
  final AppController controller;
  final bool permanent;

  /// Whether the menu sits on a glass panel, which must stay visible.
  final bool glass;
  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String)>[
      (Icons.home_rounded, 'today'),
      (Icons.calendar_view_week_rounded, 'timetable'),
      (Icons.school_rounded, 'grades'),
      (Icons.event_note_rounded, 'calendar'),
      (Icons.assignment_rounded, 'homework'),
      (Icons.mail_rounded, 'messages'),
      (Icons.fact_check_rounded, 'attendance'),
      (Icons.campaign_rounded, 'announcements'),
      (Icons.chat_bubble_rounded, 'notices'),
      (Icons.settings_rounded, 'settings'),
    ];
    return SizedBox(
      width: permanent ? 268 : null,
      child: Material(
        color: glass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DebugMenuGesture(
              controller: controller,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(22, 22, 16, 20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: BrandWordmark(fontSize: 24),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                // Scrolls only when the entries do not fit, as on a short
                // screen or with large text.
                primary: false,
                physics: const _MenuScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    child: ListTile(
                      selected: controller.tabIndex == index,
                      leading: AppIcon(entry.$1),
                      title: Text(context.tr(entry.$2)),
                      trailing:
                          index == 5 && controller.snapshot.unreadMessages > 0
                          ? Badge(
                              label: Text(
                                badgeText(controller.snapshot.unreadMessages),
                                style: const TextStyle(fontFeatures: _tabular),
                              ),
                            )
                          : null,
                      onTap: () {
                        controller.selectTab(index);
                        if (!permanent) Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: ListTile(
                key: const ValueKey('drawer-profile'),
                leading: _OpenProfileSign(
                  controller,
                  news: controller.otherProfilesHaveNews,
                ),
                title: Text(
                  _openProfileName(context, controller),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _openProfileDetail(context, controller),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  // The sheet outlives the menu, so it opens from the
                  // navigator's context.
                  final navigator = Navigator.of(context);
                  if (!permanent) navigator.pop();
                  _showProfiles(navigator.context, controller);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
