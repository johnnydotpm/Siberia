import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_build_info.dart';
import '../domain/grade_calculator.dart';
import '../domain/librus_error.dart';
import '../domain/models.dart';
import '../domain/sync_news.dart';
import '../home_widget.dart';
import '../l10n/app_localizations.dart';
import '../school_notifications.dart';
import '../state/app_controller.dart';
import '../test_reminders.dart';
import 'brand_logo.dart';
import 'glass/glass_items.dart';
import 'glass/glass_modals.dart';
import 'glass/glass_platform.dart';
import 'glass/glass_shell.dart';
import 'home_widget_settings.dart';
import 'subject_colors.dart';

part 'shell/common.dart';
part 'shell/today.dart';
part 'shell/timetable.dart';
part 'shell/timetable_views.dart';
part 'shell/grades.dart';
part 'shell/grade_calculator_sheet.dart';
part 'shell/events_homework.dart';
part 'shell/messages.dart';
part 'shell/message_compose.dart';
part 'shell/attendance.dart';
part 'shell/announcements_notices.dart';
part 'shell/settings.dart';
part 'shell/settings_previews.dart';
part 'shell/notification_settings.dart';
part 'shell/account.dart';
part 'shell/free_days.dart';
part 'shell/motion.dart';
part 'shell/sync_news.dart';

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
  (bool, bool)? _pagesLayout;
  List<Lesson>? _colorLessons;
  Set<String> _colorSubjects = const {};
  SubjectColors _colors = SubjectColors.empty;

  /// The vertical list last scrolled on each page, to take back to the top.
  final _lists = <int, BuildContext>{};

  /// The page whose tab was tapped while open, for the page to act on.
  final _reselected = _Reselect();

  AppController get controller => widget.controller;

  @override
  void dispose() {
    _reselected.dispose();
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
    listenable: controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        if (!controller.isDemo &&
            controller.snapshot.profile.provider != 'Librus Synergia') {
          _pages.clear();
          return _LoginRequired(controller: controller);
        }
        final wide = constraints.maxWidth >= 900;
        // In the glass design the bars, compact sheets and menus are glass:
        // UIKit's own on iOS 26, drawn by Flutter elsewhere.
        final glass = GlassStyle.of(context);
        Widget wrap(int index, Widget page) => glass
            ? GlassPageScope(
                // The timetable keeps its day strip under the bar, so it has
                // no title that could scroll away.
                largeTitle: index == 1 ? null : _title(context, index),
                barActions: !wide,
                child: page,
              )
            : page;
        // Pages kept from another layout would have the wrong wrapper.
        if (_pagesLayout != (glass, wide)) {
          _pagesLayout = (glass, wide);
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
          names: controller.subjectShortNames,
          colors: _subjectColors(),
          child: _FreeDaysScope(
            days: controller.snapshot.freeDays,
            child: _ControllerScope(
              controller: controller,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: IndexedStack(index: current, children: pages),
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
        const bottomTabs = [0, 1, 2, 5];
        final selected = bottomTabs.indexOf(controller.tabIndex);
        if (glass) {
          return GlassShell(
            pageIndex: controller.tabIndex,
            title: _title(context, controller.tabIndex),
            largeTitle: controller.tabIndex != 1,
            tabs: [
              GlassTab(
                label: context.tr('today'),
                symbol: GlassSymbol.house,
                selectedSymbol: GlassSymbol.houseFill,
              ),
              GlassTab(
                label: context.tr('timetable'),
                symbol: GlassSymbol.calendar,
              ),
              GlassTab(
                label: context.tr('grades'),
                symbol: GlassSymbol.graduationCap,
                selectedSymbol: GlassSymbol.graduationCapFill,
              ),
              GlassTab(
                label: context.tr('messages'),
                symbol: GlassSymbol.envelope,
                selectedSymbol: GlassSymbol.envelopeFill,
                badge: controller.snapshot.unreadMessages,
              ),
            ],
            selectedTab: selected < 0 ? null : selected,
            onTabSelected: (index) => controller.selectTab(bottomTabs[index]),
            onTabReselected: (index) =>
                _reselect(bottomTabs[index], glass: true),
            menuLabel: MaterialLocalizations.of(context).openAppDrawerTooltip,
            actions: [
              if (controller.tabIndex == 5)
                GlassBarButton(
                  id: 'compose',
                  symbol: GlassSymbol.compose,
                  label: context.tr('newMessage'),
                  prominent: true,
                  separated: true,
                  onPressed: () => _showComposeMessage(context, controller),
                ),
              GlassBarButton(
                id: 'sync',
                symbol: GlassSymbol.sync,
                label: context.tr('sync'),
                loading: controller.syncing,
                onPressed: controller.syncing ? null : controller.sync,
              ),
              GlassBarButton(
                id: 'account',
                symbol: GlassSymbol.account,
                label: context.tr('account'),
                onPressed: () => _showAccount(context, controller),
              ),
            ],
            drawer: _SideNavigation(controller: controller, glass: true),
            body: body,
          );
        }
        return Scaffold(
          drawer: Drawer(
            child: SafeArea(child: _SideNavigation(controller: controller)),
          ),
          appBar: AppBar(
            title: Text(_title(context, controller.tabIndex)),
            actions: [
              if (controller.syncing)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                onPressed: controller.syncing ? null : controller.sync,
                icon: const Icon(Icons.sync_rounded),
                tooltip: context.tr('sync'),
              ),
              IconButton(
                onPressed: () => _showAccount(context, controller),
                icon: const CircleAvatar(
                  radius: 15,
                  child: Icon(Icons.person_rounded, size: 18),
                ),
              ),
            ],
          ),
          body: body,
          // A page opened from the menu has no tab, so none looks selected.
          // NavigationBar always selects one, so the first is drawn plain.
          bottomNavigationBar: NavigationBarTheme(
            data: selected >= 0
                ? NavigationBarTheme.of(context)
                : NavigationBarTheme.of(context).copyWith(
                    indicatorColor: Colors.transparent,
                    iconTheme: WidgetStatePropertyAll(
                      IconThemeData(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
            child: NavigationBar(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (index) {
                final page = bottomTabs[index];
                if (page == controller.tabIndex) {
                  _reselect(page, glass: false);
                } else {
                  controller.selectTab(page);
                }
              },
              destinations: [
                _destination(
                  Icons.home_outlined,
                  selected < 0 ? Icons.home_outlined : Icons.home_rounded,
                  context.tr('today'),
                ),
                _destination(
                  Icons.calendar_view_week_outlined,
                  Icons.calendar_view_week_rounded,
                  context.tr('timetable'),
                ),
                _destination(
                  Icons.school_outlined,
                  Icons.school_rounded,
                  context.tr('grades'),
                ),
                _destination(
                  Icons.mail_outline_rounded,
                  Icons.mail_rounded,
                  context.tr('messages'),
                  badge: controller.snapshot.unreadMessages,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

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
    label: Text('$badge'),
    child: Icon(data),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 16, 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: BrandWordmark(fontSize: 24),
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
                      leading: Icon(entry.$1),
                      title: Text(context.tr(entry.$2)),
                      trailing:
                          index == 5 && controller.snapshot.unreadMessages > 0
                          ? Badge(
                              label: Text(
                                '${controller.snapshot.unreadMessages}',
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
                leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                title: Text(
                  controller.snapshot.profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  controller.snapshot.profile.school,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _showAccount(context, controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
