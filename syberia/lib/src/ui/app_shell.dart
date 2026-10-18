import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_build_info.dart';
import '../domain/librus_error.dart';
import '../domain/models.dart';
import '../home_widget.dart';
import '../l10n/app_localizations.dart';
import '../school_notifications.dart';
import '../state/app_controller.dart';
import 'brand_logo.dart';
import 'glass/glass_items.dart';
import 'glass/glass_modals.dart';
import 'glass/glass_platform.dart';
import 'glass/glass_shell.dart';
import 'home_widget_settings.dart';
import 'subject_colors.dart';

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

  AppController get controller => widget.controller;

  Widget _page(int index) => switch (index) {
    0 => _Today(controller),
    1 => _Timetable(controller),
    2 => _Grades(controller),
    3 => _Events(controller),
    4 => _Homework(controller),
    5 => _Messages(controller),
    6 => _Attendance(controller),
    7 => _Announcements(controller.snapshot),
    8 => _Notices(controller.snapshot),
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
        if (controller.snapshot.profile.provider != 'Librus Synergia') {
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
          child: IndexedStack(index: current, children: pages),
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
              onDestinationSelected: (index) =>
                  controller.selectTab(bottomTabs[index]),
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

NavigationDestination _destination(
  IconData icon,
  IconData selected,
  String label, {
  int badge = 0,
}) => NavigationDestination(
  icon: Badge(
    isLabelVisible: badge > 0,
    label: Text('$badge'),
    child: Icon(icon),
  ),
  selectedIcon: Icon(selected),
  label: label,
);

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

class _Today extends StatefulWidget {
  const _Today(this.controller);
  final AppController controller;

  @override
  State<_Today> createState() => _TodayState();
}

class _TodayState extends State<_Today> {
  Timer? _clock;
  bool _lookingAhead = false;
  bool _waitingForSync = false;
  DateTime? _lastLookAheadDay;
  DateTime _day = _dateOf(DateTime.now());

  static DateTime _dateOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    // The page itself only changes with the date; the lesson card keeps its
    // own minute clock, so the rest of the page is not redrawn meanwhile.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final day = _dateOf(DateTime.now());
      if (day != _day) setState(() => _day = day);
      _loadNextWeekIfNeeded();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNextWeekIfNeeded();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _clock?.cancel();
    super.dispose();
  }

  /// Looks ahead once the sync that held it back is over.
  void _onControllerChanged() {
    if (_waitingForSync && !widget.controller.syncing && mounted) {
      _waitingForSync = false;
      _loadNextWeekIfNeeded();
    }
  }

  Future<void> _loadNextWeekIfNeeded() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lessons = widget.controller.snapshot.lessons;
    // A sync under way would replace the week fetched here with older data.
    if (widget.controller.syncing) {
      _waitingForSync = true;
      return;
    }
    if (_lookingAhead ||
        !widget.controller.autoSyncOnOpen ||
        lessons.isEmpty ||
        lessons.any((lesson) => !lesson.cancelled && lesson.end.isAfter(now)) ||
        _lastLookAheadDay == today) {
      return;
    }
    _lookingAhead = true;
    _lastLookAheadDay = today;
    var monday = today.add(Duration(days: 8 - today.weekday));
    try {
      for (var attempt = 0; attempt < 4; attempt++) {
        await widget.controller.fetchTimetableWeek(monday);
        if (!mounted ||
            widget.controller.snapshot.lessons.any(
              (lesson) => !lesson.cancelled && lesson.end.isAfter(now),
            )) {
          break;
        }
        monday = monday.add(const Duration(days: 7));
      }
    } on Object {
      // The existing timetable stays visible while a later week is unavailable.
    } finally {
      _lookingAhead = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final blocks = <Widget>[
      for (final block in controller.todayLayout.visible)
        ?_todayBlock(context, block, now),
    ];
    return _Refresh(
      controller: controller,
      child: _PageList(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.updateAvailable) ...[
            _UpdateBanner(controller),
            const SizedBox(height: 14),
          ],
          Text(
            _capitalize(DateFormat.MMMMEEEEd(locale).format(now)),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          if (controller.error != null)
            _InfoCard(
              icon: Icons.error_outline,
              text: context.trError(controller.error!),
              color: Theme.of(context).colorScheme.error,
            ),
          for (final (index, block) in blocks.indexed) ...[
            if (index > 0) const SizedBox(height: 22),
            block,
          ],
        ],
      ),
    );
  }

  /// One block of the Today screen, or null when it has nothing to show.
  Widget? _todayBlock(BuildContext context, TodayBlock block, DateTime now) {
    final controller = widget.controller;
    final data = controller.snapshot;
    final today = DateTime(now.year, now.month, now.day);
    Widget section(String title, int tab, Widget child, {Key? key}) => Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(title, onAll: () => controller.selectTab(tab)),
        const SizedBox(height: 8),
        child,
      ],
    );
    Widget spaced(Iterable<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          item,
        ],
      ],
    );
    switch (block) {
      case TodayBlock.currentLesson:
        return KeyedSubtree(
          key: const ValueKey('today-current-lesson'),
          child: _MinuteClock(
            builder: (context, now) =>
                _NowCard(controller: controller, now: now),
          ),
        );
      case TodayBlock.summary:
        return _Summary(controller);
      case TodayBlock.grades:
        final recent = data.grades.take(6).toList(growable: false);
        if (recent.isEmpty) return null;
        return section(
          context.tr('todayRecentGrades'),
          2,
          _RecentGrades(recent, settings: controller.gradeAverage),
          key: const ValueKey('today-recent-grades'),
        );
      case TodayBlock.homework:
        final homework =
            data.events
                .where(
                  (item) =>
                      item.kind == EventKind.homework &&
                      !item.date.isBefore(today),
                )
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        if (homework.isEmpty) return null;
        return section(
          context.tr('homework'),
          4,
          spaced(homework.take(3).map((item) => _HomeworkCard(item, now: now))),
          key: const ValueKey('today-homework'),
        );
      case TodayBlock.events:
        final events =
            data.events
                .where(
                  (item) =>
                      item.kind != EventKind.homework &&
                      !item.date.isBefore(today),
                )
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        if (events.isEmpty) return null;
        return section(
          context.tr('todayExams'),
          3,
          spaced(events.take(3).map(_EventTile.new)),
          key: const ValueKey('today-events'),
        );
      case TodayBlock.messages:
        final unread = data.messages.where((item) => item.unread).toList()
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
        if (unread.isEmpty) return null;
        return section(
          context.tr('todayUnreadMessages'),
          5,
          Column(
            children: [
              for (final item in unread.take(2))
                _MessageTile(
                  controller,
                  item,
                  style: MessageListStyle.cards,
                  now: now,
                ),
            ],
          ),
          key: const ValueKey('today-messages'),
        );
    }
  }
}

/// What is on now and what comes next, or when lessons start again.
/// Rebuilds [builder] at the start of every minute, which is as often as
/// lesson times and countdowns change.
class _MinuteClock extends StatefulWidget {
  const _MinuteClock({required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<_MinuteClock> createState() => _MinuteClockState();
}

class _MinuteClockState extends State<_MinuteClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

class _NowCard extends StatelessWidget {
  const _NowCard({required this.controller, required this.now});
  final AppController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = _lessonBlocks(
      controller.snapshot.lessons.where((lesson) => !lesson.cancelled),
    );
    final current = _currentBlock(blocks, now);
    final upcoming = blocks
        .where((block) => block.lesson.start.isAfter(now))
        .toList(growable: false);
    final laterToday = upcoming
        .where((block) => _sameDay(block.lesson.start, now))
        .toList(growable: false);
    final featured = current ?? upcoming.firstOrNull;
    if (featured == null) {
      return Card(
        key: const ValueKey('today-now-card'),
        child: ListTile(
          leading: const Icon(Icons.free_breakfast_outlined),
          title: Text(context.tr('todayNoUpcoming')),
        ),
      );
    }
    final lesson = featured.lesson;
    final palette = SubjectColors.colors(
      _SubjectScope.colorsOf(context).indexOf(lesson.subject),
      theme.brightness,
    );
    final foreground = palette.foreground;
    final muted = foreground.withValues(alpha: 0.78);
    final sameDay = _sameDay(lesson.start, now);
    final minutesTo = (lesson.start.difference(now).inSeconds / 60).ceil();

    // The label at the top and the time on its right.
    final String label;
    final String when;
    if (current != null) {
      label = context.tr('nowLesson');
      when = '${_time(lesson.start)}–${_time(lesson.end)}';
    } else if (sameDay) {
      label = context.tr('todayNextLesson');
      when = minutesTo <= 60
          ? context.trArgs('lessonStartsIn', {'minutes': '$minutesTo'})
          : context.trArgs('lessonStartsAt', {'time': _time(lesson.start)});
    } else {
      final hadToday = blocks.any((block) => _sameDay(block.lesson.start, now));
      label = context.tr(hadToday ? 'todayDone' : 'todayNoLessons');
      final day = DateTime(
        lesson.start.year,
        lesson.start.month,
        lesson.start.day,
      );
      final dayName = _daysBetween(now, day) == 1
          ? context.tr('widgetTomorrow')
          : _shortWeekday(context, day);
      when = '$dayName, ${DateFormat('dd.MM').format(day)}';
    }

    // The line at the bottom: what follows.
    String? footer;
    if (current != null) {
      final next = laterToday.firstOrNull;
      footer = next == null
          ? context.tr('todayLastLesson')
          : '${context.tr('todayNext')} · ${_time(next.lesson.start)} '
                '${_SubjectScope.of(context, next.lesson.subject)}'
                '${next.lesson.room.isEmpty ? '' : ' · s. ${next.lesson.room}'}';
    } else if (sameDay && laterToday.length > 1) {
      final more = laterToday
          .skip(1)
          .fold(0, (sum, block) => sum + block.count);
      footer = context.trArgs('todayMoreLessons', {
        'lessons': _lessonCount(context, more),
        'time': _time(laterToday.last.lesson.end),
      });
    }

    final duration = lesson.end.difference(lesson.start).inSeconds;
    final progress = current == null || duration <= 0
        ? 0.0
        : (now.difference(lesson.start).inSeconds / duration).clamp(0.0, 1.0);
    final minutesLeft = (lesson.end.difference(now).inSeconds / 60).ceil();
    return Material(
      key: const ValueKey('today-now-card'),
      color: palette.background,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.selectTab(1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (current != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: palette.background,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (sameDay || current != null) ...[
                    const Spacer(),
                    const SizedBox(width: 8),
                    Text(
                      when,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
              if (!sameDay && current == null) ...[
                const SizedBox(height: 2),
                Text(
                  when,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _SubjectScope.of(context, lesson.subject),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (lesson.substitution)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Icon(Icons.swap_horiz_rounded, color: foreground),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (current == null)
                    '${_time(lesson.start)}–${_time(lesson.end)}',
                  _blockDetails(context, featured),
                ].where((value) => value.isNotEmpty).join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (current != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          color: palette.accent,
                          backgroundColor: foreground.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.trArgs('lessonEndsIn', {
                        'minutes': '$minutesLeft',
                      }),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: foreground.withValues(alpha: 0.18)),
                const SizedBox(height: 12),
                Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The latest grades side by side, each with its subject.
class _RecentGrades extends StatelessWidget {
  const _RecentGrades(this.grades, {required this.settings});
  final List<Grade> grades;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final grade in grades)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showGradeDetails(context, grade),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 56, maxWidth: 96),
                  child: Column(
                    children: [
                      _GradeChip(grade, settings: settings, size: 44),
                      const SizedBox(height: 6),
                      Text(
                        _SubjectScope.of(context, grade.subject),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Future<void> _showTimetableSettings(
  BuildContext context,
  AppController controller,
) => showAppSheet<void>(
  context: context,
  compact: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('timetable-settings-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('timetableStyle'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<TimetableView>(
              key: const ValueKey('settings-timetable-style'),
              segments: [
                ButtonSegment(
                  value: TimetableView.timeline,
                  label: Text(context.tr('timetableStyleClassic')),
                  icon: const Icon(Icons.view_timeline_outlined),
                ),
                ButtonSegment(
                  value: TimetableView.list,
                  label: Text(context.tr('timetableStyleCompact')),
                  icon: const Icon(Icons.view_agenda_outlined),
                ),
              ],
              selected: {controller.timetableView},
              onSelectionChanged: (selection) =>
                  controller.setTimetableView(selection.first),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              key: const ValueKey('settings-merge-lessons'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('mergeTimetableLessons')),
              subtitle: Text(context.tr('mergeTimetableLessonsDescription')),
              value: controller.mergeTimetableLessons,
              onChanged: controller.setMergeTimetableLessons,
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('settings-show-breaks'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('showTimetableBreaks')),
              value: controller.showTimetableBreaks,
              onChanged: controller.setShowTimetableBreaks,
            ),
          ],
        ),
      ),
    ),
  ),
);

/// Which Today blocks show, and in what order.
Future<void> _showTodayLayoutSheet(
  BuildContext context,
  AppController controller,
) => showAppSheet<void>(
  context: context,
  compact: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final layout = controller.todayLayout;
      void update(List<({TodayBlock block, bool visible})> blocks) =>
          controller.setTodayLayout(TodayLayout(List.unmodifiable(blocks)));
      return SafeArea(
        child: Padding(
          key: const ValueKey('today-layout-sheet'),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('todayScreen'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: layout == TodayLayout.defaults
                          ? null
                          : () =>
                                controller.setTodayLayout(TodayLayout.defaults),
                      child: Text(context.tr('resetDefaults')),
                    ),
                  ],
                ),
              ),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) {
                  final blocks = [...layout.blocks];
                  blocks.insert(to, blocks.removeAt(from));
                  update(blocks);
                },
                children: [
                  for (final (index, entry) in layout.blocks.indexed)
                    ListTile(
                      key: ValueKey('today-block-${entry.block.name}'),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_indicator_rounded),
                      ),
                      title: Row(
                        children: [
                          Icon(_todayBlockIcon(entry.block), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr(_todayBlockLabel(entry.block)),
                            ),
                          ),
                        ],
                      ),
                      trailing: Switch(
                        value: entry.visible,
                        onChanged: (visible) {
                          final blocks = [...layout.blocks];
                          blocks[index] = (
                            block: entry.block,
                            visible: visible,
                          );
                          update(blocks);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ),
);

String _todayBlockLabel(TodayBlock block) => switch (block) {
  TodayBlock.currentLesson => 'todayCurrentLesson',
  TodayBlock.summary => 'todayBlockSummary',
  TodayBlock.grades => 'todayRecentGrades',
  TodayBlock.homework => 'homework',
  TodayBlock.events => 'todayExams',
  TodayBlock.messages => 'todayUnreadMessages',
};

IconData _todayBlockIcon(TodayBlock block) => switch (block) {
  TodayBlock.currentLesson => Icons.schedule_rounded,
  TodayBlock.summary => Icons.dashboard_outlined,
  TodayBlock.grades => Icons.school_outlined,
  TodayBlock.homework => Icons.assignment_outlined,
  TodayBlock.events => Icons.event_outlined,
  TodayBlock.messages => Icons.mail_outline_rounded,
};

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner(this.controller);
  final AppController controller;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              Icons.system_update_alt_rounded,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('updateAvailableTitle'),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  context.trArgs('updateAvailableText', {
                    'current': AppBuildInfo.version,
                    'latest': controller.latestVersion ?? '',
                  }),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.dismissUpdate,
            icon: const Icon(Icons.close_rounded),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary(this.controller);
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final data = controller.snapshot;
    final semester = _preferredSemester(data.grades);
    final average = controller.gradeAverage.average(
      data.grades.where((grade) => grade.semester == semester),
    );
    final present = data.attendance
        .where((item) => item.kind.countsAsPresence)
        .length;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _Metric(
                average == null ? '—' : _decimal(context, average),
                context.tr('averageGrade'),
                Icons.school_rounded,
                key: const ValueKey('summary-grades'),
                onTap: () => controller.selectTab(2),
              ),
            ),
            Expanded(
              child: _Metric(
                data.attendance.isEmpty
                    ? '—'
                    : _percent(context, present / data.attendance.length * 100),
                context.tr('attendanceRate'),
                Icons.fact_check_rounded,
                key: const ValueKey('summary-absences'),
                onTap: () => controller.selectTab(6),
              ),
            ),
            Expanded(
              child: _Metric(
                '${data.unreadMessages}',
                context.tr('messagesUnread'),
                Icons.mail_rounded,
                key: const ValueKey('summary-messages'),
                onTap: () => controller.selectTab(5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
    this.value,
    this.label,
    this.icon, {
    required this.onTap,
    super.key,
  });
  final String value, label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );
}

class _Timetable extends StatefulWidget {
  const _Timetable(this.controller);
  final AppController controller;
  @override
  State<_Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<_Timetable> {
  DateTime? selectedDay;
  bool loading = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTime _nearestDayWithLessons(
    DateTime requested,
    Iterable<DateTime> lessonDays,
  ) {
    final normalized = _day(requested);
    final candidates =
        lessonDays.map(_day).where((day) => !day.isBefore(normalized)).toList()
          ..sort();
    return candidates.isEmpty ? normalized : candidates.first;
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final lessonDays = widget.controller.snapshot.lessons
        .map((lesson) => _day(lesson.start))
        .toSet();
    final picked = await showAppDialog<DateTime>(
      context: context,
      builder: (context) => _TimetableCalendarDialog(
        initialDate: selectedDay ?? now,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year + 3, 12, 31),
        lessonDays: lessonDays,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedDay = _day(picked);
      loading = true;
    });
    try {
      var probe = picked;
      for (var attempt = 0; attempt < 4; attempt++) {
        final fetched = await widget.controller.fetchTimetableWeek(probe);
        final available = fetched
            .map((lesson) => _day(lesson.start))
            .where((day) => !day.isBefore(_day(picked)))
            .toList();
        if (available.isNotEmpty) break;
        probe = probe.add(const Duration(days: 7));
      }
      if (mounted) {
        final availableDays = widget.controller.snapshot.lessons.map(
          (lesson) => _day(lesson.start),
        );
        setState(() {
          selectedDay = _nearestDayWithLessons(picked, availableDays);
        });
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('timetableLoadFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _selectFromStrip(DateTime requested, Iterable<DateTime> lessonDays) {
    setState(() {
      selectedDay = _nearestDayWithLessons(requested, lessonDays);
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<Lesson>>{};
    for (final item in widget.controller.snapshot.lessons) {
      final day = DateTime(item.start.year, item.start.month, item.start.day);
      groups.putIfAbsent(day, () => []).add(item);
    }
    final now = DateTime.now();
    selectedDay ??= _nearestDayWithLessons(now, groups.keys);
    final anchor = selectedDay!;
    final monday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
    ).subtract(Duration(days: anchor.weekday - 1));
    final days = List.generate(5, (index) => monday.add(Duration(days: index)));
    final weekEnd = monday.add(const Duration(days: 7));
    for (final day in groups.keys.where(
      (day) =>
          day.weekday > 5 && !day.isBefore(monday) && day.isBefore(weekEnd),
    )) {
      if (!days.any((item) => _sameDay(item, day))) days.add(day);
    }
    final lessons = groups[selectedDay] ?? const <Lesson>[];
    final dayEvents = widget.controller.snapshot.events
        .where(
          (event) =>
              event.kind == EventKind.exam &&
              _sameDay(event.date, selectedDay!),
        )
        .toList(growable: false);
    final mergeLessons = widget.controller.mergeTimetableLessons;
    final showBreaks = widget.controller.showTimetableBreaks;
    final placed = _placeTests(
      _lessonBlocks(lessons, merge: mergeLessons),
      dayEvents,
    );
    final eventDays = {
      for (final event in widget.controller.snapshot.events) _day(event.date),
    };
    final today = _day(now);
    final view = widget.controller.timetableView;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final title = _capitalize(
      (selectedDay!.year == now.year
              ? DateFormat.MMMMEEEEd(locale)
              : DateFormat.yMMMMEEEEd(locale))
          .format(selectedDay!),
    );
    final insets = _chromeInsets(context);
    return Column(
      children: [
        SizedBox(height: insets.top),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: loading ? null : _pickDay,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calendar_month_rounded),
                tooltip: context.tr('chooseDate'),
              ),
              Expanded(
                child: Row(
                  children: [
                    for (final (index, day) in days.indexed) ...[
                      if (index > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _DayChip(
                          key: ValueKey(
                            'timetable-day-${DateFormat('yyyy-MM-dd').format(day)}',
                          ),
                          day: day,
                          selected: _sameDay(day, selectedDay!),
                          today: _sameDay(day, today),
                          hasLessons: groups.containsKey(day),
                          hasEvents: eventDays.contains(day),
                          onTap: () => _selectFromStrip(day, groups.keys),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Expanded(
          child: lessons.isEmpty
              ? ListView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + insets.bottom),
                  children: [
                    for (final event in dayEvents) ...[
                      _EventTile(event),
                      const SizedBox(height: 8),
                    ],
                    if (dayEvents.isEmpty) _Empty(context.tr('noData')),
                  ],
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(12, 4, 16, 24 + insets.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Entries that belong to no lesson of the day.
                      for (final event in placed.unplaced)
                        Padding(
                          key: ValueKey('timetable-day-event-${event.id}'),
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: _EventTile(event),
                        ),
                      _DayTests(
                        byLesson: placed.byLesson,
                        child: view == TimetableView.timeline
                            ? _TimetableTimeline(
                                lessons,
                                mergeLessons: mergeLessons,
                                showBreaks: showBreaks,
                              )
                            : _TimetableList(
                                lessons,
                                mergeLessons: mergeLessons,
                                showBreaks: showBreaks,
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// The tests of the day in the timetable, by the lesson they are written in.
class _DayTests extends InheritedWidget {
  const _DayTests({required this.byLesson, required super.child});

  final Map<String, List<SchoolEvent>> byLesson;

  static List<SchoolEvent> of(BuildContext context, _LessonBlock block) =>
      context
          .dependOnInheritedWidgetOfExactType<_DayTests>()
          ?.byLesson[block.lesson.id] ??
      const [];

  @override
  bool updateShouldNotify(_DayTests oldWidget) =>
      oldWidget.byLesson != byLesson;
}

/// Puts each test of a day on its lesson: the lesson with its number and
/// subject, else the first lesson of its subject, else the lesson with its
/// number. Entries that fit no lesson, like a school trip, come back apart.
({Map<String, List<SchoolEvent>> byLesson, List<SchoolEvent> unplaced})
_placeTests(List<_LessonBlock> blocks, Iterable<SchoolEvent> tests) {
  String normal(String value) => value.trim().toLowerCase();
  final byLesson = <String, List<SchoolEvent>>{};
  final unplaced = <SchoolEvent>[];
  for (final test in tests) {
    bool sameNumber(_LessonBlock block) =>
        test.lessonNumber != null &&
        block.lessons.any((lesson) => lesson.lessonNumber == test.lessonNumber);
    bool sameSubject(_LessonBlock block) =>
        normal(block.lesson.subject) == normal(test.subject);
    final block =
        blocks
            .where((block) => sameNumber(block) && sameSubject(block))
            .firstOrNull ??
        blocks.where(sameSubject).firstOrNull ??
        blocks.where(sameNumber).firstOrNull;
    if (block == null) {
      unplaced.add(test);
    } else {
      byLesson.putIfAbsent(block.lesson.id, () => []).add(test);
    }
  }
  return (byLesson: byLesson, unplaced: unplaced);
}

/// "Kartkówka" on a lesson card; "+1" when there is more than one test.
class _TestPill extends StatelessWidget {
  const _TestPill(this.tests);
  final List<SchoolEvent> tests;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final first = tests.first;
    final label = [
      first.typeLabel.isNotEmpty ? first.typeLabel : context.tr('lessonTest'),
      if (tests.length > 1) '+${tests.length - 1}',
    ].join(' ');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Container(
        key: ValueKey('timetable-test-${first.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_rounded, size: 13, color: colors.onErrorContainer),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onErrorContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lesson as the timetable shows it: a double lesson is one block.
class _LessonBlock {
  const _LessonBlock(this.lesson, this.lessons);

  /// The first lesson, ending when the last one ends.
  final Lesson lesson;
  final List<Lesson> lessons;

  int get count => lessons.length;

  /// "3." or "3–4." for a double lesson.
  String? get number {
    final first = lessons.first.lessonNumber;
    final last = lessons.last.lessonNumber;
    if (first == null) return null;
    return last == null || last == first ? '$first' : '$first–$last';
  }
}

/// Joins the same lesson in a row (same subject, teacher and room, at most a
/// short break apart) into one block.
List<_LessonBlock> _lessonBlocks(
  Iterable<Lesson> lessons, {
  bool merge = true,
}) {
  final sorted = [...lessons]..sort((a, b) => a.start.compareTo(b.start));
  final groups = <List<Lesson>>[];
  for (final lesson in sorted) {
    final last = groups.isEmpty ? null : groups.last.last;
    if (merge &&
        last != null &&
        !last.cancelled &&
        !lesson.cancelled &&
        last.subject == lesson.subject &&
        last.teacher == lesson.teacher &&
        last.room == lesson.room &&
        _sameDay(last.start, lesson.start) &&
        !lesson.start.isBefore(last.end) &&
        lesson.start.difference(last.end).inMinutes <= 15) {
      groups.last.add(lesson);
    } else {
      groups.add([lesson]);
    }
  }
  return [
    for (final group in groups)
      _LessonBlock(group.first.copyWith(end: group.last.end), group),
  ];
}

/// "s. 207 · Teacher Alpha", or "2 lessons · s. 207 · …" for a double lesson.
String _blockDetails(BuildContext context, _LessonBlock block) {
  final lesson = block.lesson;
  return [
    if (block.count > 1) _lessonCount(context, block.count),
    if (lesson.room.isNotEmpty) 's. ${lesson.room}',
    lesson.teacher,
  ].where((value) => value.isNotEmpty).join(' · ');
}

String _lessonCount(BuildContext context, int count) {
  if (count == 1) return context.tr('lessonsOne').replaceAll('%d', '1');
  final few =
      (2 <= count % 10 && count % 10 <= 4) &&
      !(12 <= count % 100 && count % 100 <= 14);
  return context
      .tr(few ? 'widgetLessonsFew' : 'widgetLessonsMany')
      .replaceAll('%d', '$count');
}

String _time(DateTime value) => DateFormat('HH:mm').format(value);

/// The lesson block running at [now], if any.
_LessonBlock? _currentBlock(List<_LessonBlock> blocks, DateTime now) {
  for (final block in blocks) {
    if (!block.lesson.cancelled &&
        !now.isBefore(block.lesson.start) &&
        now.isBefore(block.lesson.end)) {
      return block;
    }
  }
  return null;
}

class _TimetableTimeline extends StatelessWidget {
  const _TimetableTimeline(
    this.lessons, {
    required this.mergeLessons,
    required this.showBreaks,
  });
  final bool mergeLessons;
  final bool showBreaks;

  static const _pixelsPerMinute = 1.75;
  static const _axisWidth = 62.0;

  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    final blocks = _lessonBlocks(lessons, merge: mergeLessons);
    final axisStart = blocks.first.lesson.start;
    final last = blocks
        .map((block) => block.lesson.end)
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final breakHeight = math.max(
      30.0,
      MediaQuery.textScalerOf(
                context,
              ).scale(Theme.of(context).textTheme.labelSmall?.fontSize ?? 11) *
              1.5 +
          8,
    );
    double offset(DateTime time) {
      var result = time.difference(axisStart).inSeconds / 60 * _pixelsPerMinute;
      if (showBreaks) {
        for (var index = 0; index < blocks.length - 1; index++) {
          final end = blocks[index].lesson.end;
          final start = blocks[index + 1].lesson.start;
          final gap = start.difference(end).inMilliseconds;
          if (gap <= 0 || !time.isAfter(end)) continue;
          final extra = math.max(
            0.0,
            breakHeight - gap / 60000 * _pixelsPerMinute,
          );
          result +=
              extra *
              (time.difference(end).inMilliseconds / gap).clamp(0.0, 1.0);
        }
      }
      return result;
    }

    final height = math.max(60.0, offset(last));
    final now = DateTime.now();
    final current = _currentBlock(blocks, now);
    final currentBreak = current == null ? _currentBreak(blocks, now) : null;
    final currentTop = (current != null || currentBreak != null)
        ? offset(now)
        : null;
    final colors = _SubjectScope.colorsOf(context)
        .forDay(blocks.map((block) => block.lesson.subject));
    // A little air keeps back-to-back lessons apart.
    double blockHeight(_LessonBlock block) =>
        math.max(34, offset(block.lesson.end) - offset(block.lesson.start) - 4);

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final block in blocks) ...[
            Positioned(
              top: offset(block.lesson.start),
              left: 0,
              width: _axisWidth - 8,
              height: blockHeight(block),
              child: _TimelineRail(block),
            ),
            Positioned(
              top: offset(block.lesson.start),
              left: _axisWidth,
              right: 0,
              height: blockHeight(block),
              child: _TimelineLessonCard(
                key: ValueKey('timeline-lesson-${block.lesson.id}'),
                block: block,
                hue: colors[block.lesson.subject] ?? 0,
                current: identical(block, current),
                now: now,
              ),
            ),
          ],
          for (var index = 0; index < blocks.length - 1; index++)
            if (showBreaks &&
                blocks[index + 1].lesson.start.isAfter(
                  blocks[index].lesson.end,
                ))
              Positioned(
                top: offset(blocks[index].lesson.end),
                height:
                    offset(blocks[index + 1].lesson.start) -
                    offset(blocks[index].lesson.end),
                left: _axisWidth,
                right: 0,
                child: Center(
                  child: _BreakLabel(
                    blocks[index + 1].lesson.start.difference(
                      blocks[index].lesson.end,
                    ),
                  ),
                ),
              ),
          if (currentTop != null && currentTop >= 0 && currentTop <= height)
            Positioned(
              key: ValueKey(
                current != null
                    ? 'timetable-current-time-${current.lesson.id}'
                    : 'timetable-current-time-break-${currentBreak!.before.lesson.id}-${currentBreak.after.lesson.id}',
              ),
              top: currentTop,
              left: 0,
              // During a lesson the line stops at its card, which shows the
              // progress itself, so the title stays readable.
              right: current != null ? null : 0,
              width: current != null ? _axisWidth + 4.5 : null,
              child: const _TimelineNowLine(),
            ),
        ],
      ),
    );
  }

  _TimetableBreak? _currentBreak(List<_LessonBlock> blocks, DateTime now) {
    final active = blocks.where((block) => !block.lesson.cancelled).toList();
    for (var index = 0; index < active.length - 1; index++) {
      final before = active[index];
      final after = active[index + 1];
      if (!now.isBefore(before.lesson.end) &&
          now.isBefore(after.lesson.start)) {
        return _TimetableBreak(before: before, after: after);
      }
    }
    return null;
  }
}

class _TimetableBreak {
  const _TimetableBreak({required this.before, required this.after});

  final _LessonBlock before;
  final _LessonBlock after;
}

/// The lesson number and its times, beside its card.
class _TimelineRail extends StatelessWidget {
  const _TimelineRail(this.block);
  final _LessonBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // A short lesson keeps only what fits: the number goes first, then
        // the end time.
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final number = constraints.maxHeight >= 58 * scale
            ? block.number
            : null;
        final showEnd = constraints.maxHeight >= 40 * scale;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.topStart,
          child: _railColumn(theme, number, showEnd),
        );
      },
    );
  }

  Widget _railColumn(ThemeData theme, String? number, bool showEnd) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (number != null)
          Container(
            margin: const EdgeInsets.only(top: 2, bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              number,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        Text(
          _time(block.lesson.start),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (showEnd)
          Text(
            _time(block.lesson.end),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _BreakLabel extends StatelessWidget {
  const _BreakLabel(this.length);
  final Duration length;

  @override
  Widget build(BuildContext context) => Text(
    context.trArgs('lessonBreak', {'minutes': '${length.inMinutes}'}),
    style: Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _TimelineNowLine extends StatelessWidget {
  const _TimelineNowLine();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: const Offset(0, -4.5),
      child: Row(
        children: [
          Expanded(child: Container(height: 2, color: colors.error)),
          Container(
            key: const ValueKey('timetable-now-dot'),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: colors.error,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineLessonCard extends StatelessWidget {
  const _TimelineLessonCard({
    super.key,
    required this.block,
    required this.hue,
    required this.current,
    required this.now,
  });

  final _LessonBlock block;
  final int hue;
  final bool current;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final lesson = block.lesson;
    final palette = SubjectColors.colors(hue, Theme.of(context).brightness);
    final foreground = palette.foreground;
    final duration = lesson.end.difference(lesson.start);
    final elapsed = current
        ? now.difference(lesson.start).inMinutes.clamp(0, duration.inMinutes)
        : 0;
    final tests = _DayTests.of(context, block);
    final details = _blockDetails(context, block);
    return Opacity(
      opacity: lesson.cancelled ? 0.55 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showLessonDetails(context, block),
        child: Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(12),
            border: current
                ? Border.all(color: palette.accent, width: 2)
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Measured, so a short card drops the details line before
              // anything overflows, whatever the font and text size.
              final scaler = MediaQuery.textScalerOf(context);
              double lineHeight(TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(text: 'Ag', style: style),
                  textDirection: Directionality.of(context),
                  textScaler: scaler,
                  maxLines: 1,
                )..layout();
                final height = painter.height;
                painter.dispose();
                return height;
              }

              final subjectStyle = TextStyle(
                color: foreground,
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w800,
                decoration: lesson.cancelled
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: foreground,
              );
              final detailsStyle = TextStyle(
                color: foreground.withValues(alpha: 0.78),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              );
              final progressStyle = TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              );
              final room = constraints.maxHeight;
              final subjectLine = lineHeight(subjectStyle);
              final detailsHeight = 2 + lineHeight(detailsStyle);
              final progressHeight = current
                  ? 3 + math.max(4, lineHeight(progressStyle) + 2)
                  : 0;
              final showDetails =
                  details.isNotEmpty &&
                  room >= subjectLine + detailsHeight + progressHeight;
              final reserved =
                  (showDetails ? detailsHeight : 0) + progressHeight;
              final subjectLines = room - reserved >= subjectLine * 2 ? 2 : 1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _SubjectScope.of(context, lesson.subject),
                          maxLines: subjectLines,
                          overflow: TextOverflow.ellipsis,
                          style: subjectStyle,
                        ),
                      ),
                      if (tests.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 6, top: 1),
                          child: _TestPill(tests),
                        ),
                      if (lesson.substitution)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            color: foreground,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  if (showDetails)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: detailsStyle,
                      ),
                    ),
                  if (current) ...[
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: duration.inMinutes == 0
                                  ? 0
                                  : elapsed / duration.inMinutes,
                              minHeight: 4,
                              color: palette.accent,
                              backgroundColor: foreground.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.trArgs('lessonProgress', {
                            'elapsed': '$elapsed',
                            'total': '${duration.inMinutes}',
                          }),
                          style: progressStyle,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            context.tr('nowLesson'),
                            style: TextStyle(
                              color: palette.background,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The day as a list: number, times, subject and room on equal rows.
class _TimetableList extends StatelessWidget {
  const _TimetableList(
    this.lessons, {
    required this.mergeLessons,
    required this.showBreaks,
  });
  final bool mergeLessons;
  final bool showBreaks;
  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    final blocks = _lessonBlocks(lessons, merge: mergeLessons);
    final now = DateTime.now();
    final current = _currentBlock(blocks, now);
    final colors = _SubjectScope.colorsOf(context)
        .forDay(blocks.map((block) => block.lesson.subject));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0)
            if (showBreaks &&
                blocks[index].lesson.start.isAfter(
                  blocks[index - 1].lesson.end,
                ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _BreakLabel(
                        blocks[index].lesson.start.difference(
                          blocks[index - 1].lesson.end,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              )
            else
              const SizedBox(height: 4),
          _TimetableRow(
            key: ValueKey('timetable-row-${blocks[index].lesson.id}'),
            block: blocks[index],
            hue: colors[blocks[index].lesson.subject] ?? 0,
            current: identical(blocks[index], current),
            now: now,
          ),
        ],
      ],
    );
  }
}

class _TimetableRow extends StatelessWidget {
  const _TimetableRow({
    super.key,
    required this.block,
    required this.hue,
    required this.current,
    required this.now,
  });

  final _LessonBlock block;
  final int hue;
  final bool current;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lesson = block.lesson;
    final palette = SubjectColors.colors(hue, theme.brightness);
    final tests = _DayTests.of(context, block);
    final details = _blockDetails(context, block);
    final muted = theme.colorScheme.onSurfaceVariant;
    final duration = lesson.end.difference(lesson.start).inMinutes;
    return Opacity(
      opacity: lesson.cancelled ? 0.55 : 1,
      child: Material(
        color: current
            ? palette.background.withValues(alpha: 0.6)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showLessonDetails(context, block),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      block.number ?? '',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _time(lesson.start),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _time(lesson.end),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 4,
                  height: 38,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _SubjectScope.of(context, lesson.subject),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          decoration: lesson.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (details.isNotEmpty)
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      if (current)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: duration == 0
                                  ? 0
                                  : now.difference(lesson.start).inMinutes /
                                        duration,
                              minHeight: 4,
                              color: palette.accent,
                              backgroundColor: palette.accent.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (tests.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _TestPill(tests),
                  ),
                if (lesson.substitution)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      size: 20,
                      color: theme.colorScheme.tertiary,
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

/// A weekday in the strip above the timetable.
class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.day,
    required this.selected,
    required this.today,
    required this.hasLessons,
    required this.hasEvents,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final bool hasLessons;
  final bool hasEvents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected
        ? colors.onPrimary
        : hasLessons
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide.none
              : BorderSide(
                  color: today ? colors.primary : colors.outlineVariant,
                  width: today ? 1.5 : 1,
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _shortWeekday(context, day),
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !hasEvents
                        ? Colors.transparent
                        : selected
                        ? colors.onPrimary
                        : colors.primary,
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

void _showLessonDetails(BuildContext context, _LessonBlock block) {
  final lesson = block.lesson;
  final tests = _DayTests.of(context, block);
  final screenWidth = MediaQuery.sizeOf(context).width;
  final details = [
    if (block.count > 1) _lessonCount(context, block.count),
    lesson.teacher,
    if (lesson.room.isNotEmpty) 's. ${lesson.room}',
  ].where((value) => value.isNotEmpty).join(' · ');
  showAppSheet<void>(
    context: context,
    compact: true,
    showDragHandle: true,
    constraints: BoxConstraints.tightFor(width: screenWidth),
    builder: (context) => SafeArea(
      child: SizedBox(
        key: const ValueKey('lesson-details-sheet'),
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.subject,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text('${_time(lesson.start)} – ${_time(lesson.end)}'),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(details),
              ],
              if (lesson.substitution) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded),
                    const SizedBox(width: 8),
                    Text(
                      lesson.cancelled
                          ? context.tr('lessonMoved')
                          : context.tr('substitution'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  lesson.movedTo != null
                      ? context.trArgs('movedTo', {
                          'date': _date(lesson.movedTo!),
                          'time': _time(lesson.movedTo!),
                        })
                      : context.trArgs('insteadOf', {
                          'details': [
                            lesson.originalSubject,
                            lesson.originalTeacher,
                            if (lesson.originalRoom.isNotEmpty)
                              's. ${lesson.originalRoom}',
                          ].where((value) => value.isNotEmpty).join(' · '),
                        }),
                ),
              ],
              for (final test in tests) ...[
                const SizedBox(height: 16),
                Row(
                  key: ValueKey('lesson-test-${test.id}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.quiz_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            test.typeLabel.isNotEmpty
                                ? test.typeLabel
                                : context.tr('lessonTest'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (test.title.isNotEmpty &&
                              test.title != test.typeLabel)
                            SelectableText(test.title),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _TimetableCalendarDialog extends StatefulWidget {
  const _TimetableCalendarDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.lessonDays,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<DateTime> lessonDays;

  @override
  State<_TimetableCalendarDialog> createState() =>
      _TimetableCalendarDialogState();
}

class _TimetableCalendarDialogState extends State<_TimetableCalendarDialog> {
  late DateTime month;

  @override
  void initState() {
    super.initState();
    month = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  bool _hasLessons(DateTime day) =>
      widget.lessonDays.contains(DateTime(day.year, day.month, day.day));

  bool _monthBefore(DateTime left, DateTime right) =>
      left.year < right.year ||
      (left.year == right.year && left.month < right.month);

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final first = DateTime(month.year, month.month);
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cellCount = ((leading + dayCount + 6) ~/ 7) * 7;
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    final narrowWeekdays = localizations.narrowWeekdays;
    final weekdayLabels = [...narrowWeekdays.skip(1), narrowWeekdays.first];

    return AppDialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('chooseDate'),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: localizations.closeButtonTooltip,
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _monthBefore(firstMonth, month)
                        ? () => setState(
                            () => month = DateTime(month.year, month.month - 1),
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      localizations.formatMonthYear(month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: _monthBefore(month, lastMonth)
                        ? () => setState(
                            () => month = DateTime(month.year, month.month + 1),
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              Row(
                children: weekdayLabels
                    .map(
                      (label) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: cellCount,
                itemBuilder: (context, index) {
                  final dayNumber = index - leading + 1;
                  if (dayNumber < 1 || dayNumber > dayCount) {
                    return const SizedBox.shrink();
                  }
                  final day = DateTime(month.year, month.month, dayNumber);
                  final enabled =
                      !day.isBefore(widget.firstDate) &&
                      !day.isAfter(widget.lastDate);
                  final selected = _sameDay(day, widget.initialDate);
                  final today = _sameDay(day, DateTime.now());
                  final hasLessons = _hasLessons(day);
                  final colors = Theme.of(context).colorScheme;
                  return InkWell(
                    key: ValueKey('timetable-day-${day.toIso8601String()}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: enabled ? () => Navigator.pop(context, day) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? colors.primaryContainer : null,
                        borderRadius: BorderRadius.circular(12),
                        border: today && !selected
                            ? Border.all(color: colors.outline)
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              color: enabled
                                  ? null
                                  : colors.onSurface.withAlpha(90),
                              fontWeight: selected || hasLessons
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          if (!hasLessons)
                            Icon(
                              Icons.close_rounded,
                              size: 27,
                              color: colors.outline.withAlpha(150),
                            )
                          else
                            Positioned(
                              bottom: 5,
                              child: Container(
                                key: ValueKey(
                                  'timetable-lessons-${day.toIso8601String()}',
                                ),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grades extends StatefulWidget {
  const _Grades(this.controller);
  final AppController controller;

  @override
  State<_Grades> createState() => _GradesState();
}

class _GradesState extends State<_Grades> {
  late int semester = _preferredSemester(widget.controller.snapshot.grades);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = controller.gradeAverage;
    final view = controller.gradesView;
    final grades = controller.snapshot.grades
        .where((grade) => grade.semester == semester)
        .toList(growable: false);
    // Grades come newest first, so subjects with recent grades lead.
    final groups = <String, List<Grade>>{};
    for (final item in grades) {
      groups.putIfAbsent(item.subject, () => []).add(item);
    }
    return _PageList(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 1, label: Text(context.tr('period1'))),
                  ButtonSegment(value: 2, label: Text(context.tr('period2'))),
                ],
                selected: {semester},
                onSelectionChanged: (selection) =>
                    setState(() => semester = selection.first),
              ),
            ),
            IconButton(
              key: const ValueKey('grades-view-toggle'),
              tooltip: context.tr(
                view == GradesView.compact
                    ? 'gradesViewCards'
                    : 'gradesViewCompact',
              ),
              onPressed: () => controller.setGradesView(
                view == GradesView.compact
                    ? GradesView.cards
                    : GradesView.compact,
              ),
              icon: Icon(
                view == GradesView.compact
                    ? Icons.view_agenda_outlined
                    : Icons.view_list_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GradesOverview(grades, settings),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          _Empty(context.tr('noData'))
        else
          for (final MapEntry(key: subject, value: items) in groups.entries)
            view == GradesView.compact
                ? _SubjectGradesRow(
                    subject: subject,
                    grades: items,
                    settings: settings,
                  )
                : _SubjectGradesTile(
                    subject: subject,
                    grades: items,
                    settings: settings,
                  ),
      ],
    );
  }
}

/// The semester under way: the second from February to August.
int _preferredSemester(List<Grade> grades) {
  final now = DateTime.now();
  final preferred = now.month >= 2 && now.month <= 8 ? 2 : 1;
  final available = grades.map((grade) => grade.semester).toSet();
  return available.contains(preferred) || available.isEmpty
      ? preferred
      : available.first;
}

/// Grades added in the last week count as new.
bool _isNewGrade(Grade grade, DateTime now) =>
    now.difference(grade.date) < const Duration(days: 7);

/// The semester average, how many grades and how they spread from 1 to 6.
class _GradesOverview extends StatelessWidget {
  const _GradesOverview(this.grades, this.settings);
  final List<Grade> grades;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = settings.average(grades);
    final now = DateTime.now();
    final fresh = grades.where((grade) => _isNewGrade(grade, now)).length;
    final buckets = <int, int>{};
    for (final grade in grades) {
      final value = settings.valueOf(grade.value);
      if (value == null) continue;
      final bucket = value.round().clamp(1, 6);
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    return Card(
      key: const ValueKey('grades-overview'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AveragePill(average, large: true),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('averageGrade'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          context.trArgs('gradesCount', {
                            'count': '${grades.length}',
                          }),
                          if (fresh > 0)
                            context.trArgs('gradesNew', {'count': '$fresh'}),
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (buckets.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var bucket = 1; bucket <= 6; bucket++)
                        if (buckets[bucket] != null)
                          Expanded(
                            flex: buckets[bucket]!,
                            child: ColoredBox(
                              color: SubjectColors.grade(
                                bucket.toDouble(),
                                theme.brightness,
                              ).accent,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (var bucket = 1; bucket <= 6; bucket++)
                    if (buckets[bucket] != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: SubjectColors.grade(
                                bucket.toDouble(),
                                theme.brightness,
                              ).accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$bucket',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            ' × ${buckets[bucket]}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An average in the colour of the grade it rounds to.
class _AveragePill extends StatelessWidget {
  const _AveragePill(this.average, {this.large = false});
  final double? average;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SubjectColors.grade(average, theme.brightness);
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(large ? 16 : 10),
      ),
      child: Text(
        average == null ? '—' : _decimal(context, average!),
        style: TextStyle(
          color: palette.foreground,
          fontSize: large ? 26 : 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// A grade in the colour of its value. A grade that replaced an earlier
/// one keeps Librus's brackets, and a new grade has a dot.
class _GradeChip extends StatelessWidget {
  const _GradeChip(this.grade, {required this.settings, this.size = 32});
  final Grade grade;
  final GradeAverageSettings settings;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SubjectColors.grade(
      settings.valueOf(grade.value),
      theme.brightness,
    );
    final chip = Container(
      key: ValueKey('grade-chip-${grade.id}'),
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: EdgeInsets.symmetric(horizontal: size * 0.16),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      // As wide as the grade, never wider.
      child: Center(
        widthFactor: 1,
        child: Text(
          grade.wasChanged ? '[${grade.value}]' : grade.value,
          maxLines: 1,
          style: TextStyle(
            color: palette.foreground,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    if (!_isNewGrade(grade, DateTime.now())) return chip;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        chip,
        PositionedDirectional(
          top: -2,
          end: -2,
          child: Container(
            key: ValueKey('grade-new-${grade.id}'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// A subject on one row: its grades in order and its average.
class _SubjectGradesRow extends StatelessWidget {
  const _SubjectGradesRow({
    required this.subject,
    required this.grades,
    required this.settings,
  });
  final String subject;
  final List<Grade> grades;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = SubjectColors.colors(
      _SubjectScope.colorsOf(context).indexOf(subject),
      theme.brightness,
    ).accent;
    final chronological = grades.reversed.toList(growable: false);
    return Card(
      key: ValueKey('grades-subject-$subject'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSubjectGrades(context, subject, grades, settings),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _SubjectScope.of(context, subject),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final grade in chronological)
                          _GradeChip(grade, settings: settings, size: 30),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AveragePill(settings.average(grades)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A subject as a card that opens to list its grades.
class _SubjectGradesTile extends StatelessWidget {
  const _SubjectGradesTile({
    required this.subject,
    required this.grades,
    required this.settings,
  });
  final String subject;
  final List<Grade> grades;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = SubjectColors.colors(
      _SubjectScope.colorsOf(context).indexOf(subject),
      theme.brightness,
    ).accent;
    final average = settings.average(grades);
    return Card(
      key: ValueKey('grades-subject-$subject'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _SubjectScope.of(context, subject),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _AveragePill(average),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final grade in grades.reversed)
                  _GradeChip(grade, settings: settings, size: 24),
              ],
            ),
          ),
          children: [
            for (final grade in grades) _GradeRow(grade, settings: settings),
          ],
        ),
      ),
    );
  }
}

/// One grade with what it was for, when and how much it weighs.
class _GradeRow extends StatelessWidget {
  const _GradeRow(this.grade, {required this.settings});
  final Grade grade;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () => _showGradeDetails(context, grade),
    leading: _GradeChip(grade, settings: settings, size: 42),
    title: Text(
      grade.category.isNotEmpty
          ? grade.category
          : (grade.description.isNotEmpty
                ? grade.description
                : context.tr('grade')),
    ),
    subtitle: Text(
      '${_date(grade.date)} · ${context.tr('weight').toLowerCase()} ${_decimal(context, grade.weight)}',
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}

Future<void> _showSubjectGrades(
  BuildContext context,
  String subject,
  List<Grade> grades,
  GradeAverageSettings settings,
) => showAppSheet<void>(
  context: context,
  compact: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        key: const ValueKey('subject-grades-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.tr('averageGrade')} · ${context.trArgs('gradesCount', {'count': '${grades.length}'})}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AveragePill(settings.average(grades), large: true),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final grade in grades)
                    _GradeRow(grade, settings: settings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);

String _decimal(BuildContext context, double value) => NumberFormat(
  '0.##',
  Localizations.localeOf(context).toLanguageTag(),
).format(value);

Future<void> _showGradeDetails(BuildContext context, Grade grade) =>
    showAppSheet<void>(
      context: context,
      compact: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final history = [grade, ...grade.previousGrades.reversed];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      context.tr('gradeDetails'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < history.length; index++) ...[
                    if (index > 0)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    _GradeHistoryCard(
                      key: ValueKey('grade-history-${history[index].id}'),
                      grade: history[index],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

class _GradeHistoryCard extends StatelessWidget {
  const _GradeHistoryCard({super.key, required this.grade});

  final Grade grade;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            grade.value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          _GradeDetailRow(context.tr('subject'), grade.subject),
          if (grade.category.isNotEmpty)
            _GradeDetailRow(context.tr('category'), grade.category),
          _GradeDetailRow(
            context.tr('description'),
            grade.description.isEmpty ? '—' : grade.description,
          ),
          _GradeDetailRow(context.tr('date'), _date(grade.date)),
          _GradeDetailRow(
            context.tr('weight'),
            _decimal(context, grade.weight),
          ),
        ],
      ),
    ),
  );
}

class _GradeDetailRow extends StatelessWidget {
  const _GradeDetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _Events extends StatefulWidget {
  const _Events(this.controller);
  final AppController controller;
  @override
  State<_Events> createState() => _EventsState();
}

class _EventsState extends State<_Events> {
  DateTime selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final events = widget.controller.snapshot.events;
    final selectedEvents = events.where(
      (item) => _sameDay(item.date, selected),
    );
    final today = DateTime.now();
    final upcoming = events
        .where(
          (item) =>
              !item.date.isBefore(DateTime(today.year, today.month, today.day)),
        )
        .take(8);
    return _PageList(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            child: PrimaryScrollController.none(
              child: CalendarDatePicker(
                initialDate: selected,
                firstDate: DateTime(today.year - 2),
                lastDate: DateTime(today.year + 3, 12, 31),
                onDateChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _Heading(context.tr('selectedDay')),
        const SizedBox(height: 8),
        if (selectedEvents.isEmpty)
          _Empty(context.tr('noData'))
        else
          ...selectedEvents.map(_EventTile.new),
        const SizedBox(height: 18),
        _Heading(context.tr('upcomingEvents')),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          _Empty(context.tr('noData'))
        else
          ...upcoming.map(_EventTile.new),
      ],
    );
  }
}

class _Homework extends StatefulWidget {
  const _Homework(this.controller);
  final AppController controller;
  @override
  State<_Homework> createState() => _HomeworkState();
}

class _HomeworkState extends State<_Homework> {
  final _search = TextEditingController();
  bool _past = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Upcoming work by when it is due: "Today", "Tomorrow", "This week",
  /// "Next week", "Later". Past work by month.
  String _section(DateTime due, DateTime today) {
    final days = _daysBetween(today, due);
    if (days < 0) {
      return _capitalize(
        DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag())
            .format(due),
      );
    }
    if (days == 0) return context.tr('messagesToday');
    if (days == 1) return context.tr('widgetTomorrow');
    final weeks = (days + today.weekday - 1) ~/ 7;
    if (weeks == 0) return context.tr('messagesThisWeek');
    if (weeks == 1) return context.tr('homeworkNextWeek');
    return context.tr('homeworkLater');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final all = widget.controller.snapshot.events
        .where((item) => item.kind == EventKind.homework)
        .toList();
    if (all.isEmpty) return _PageEmpty(context.tr('noData'));
    final upcoming = all.where((item) => !item.date.isBefore(today)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = all.where((item) => item.date.isBefore(today)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final query = _search.text.trim().toLowerCase();
    final shown = (_past ? past : upcoming)
        .where(
          (item) =>
              query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.subject.toLowerCase().contains(query) ||
              _SubjectScope.of(
                context,
                item.subject,
              ).toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query),
        )
        .toList();
    final colors = Theme.of(context).colorScheme;

    final rows = <Widget>[];
    String? lastSection;
    for (final item in shown) {
      final section = _section(item.date, today);
      if (section != lastSection) {
        rows.add(
          Padding(
            key: ValueKey('homework-section-$section'),
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
            child: Text(
              section,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
        lastSection = section;
      } else {
        rows.add(const SizedBox(height: 8));
      }
      rows.add(_HomeworkCard(item, now: now));
    }

    String counted(String key, int count) =>
        count == 0 ? context.tr(key) : '${context.tr(key)} ($count)';
    return _PageList(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          key: const ValueKey('homework-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.tr('homeworkSearch'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    tooltip: MaterialLocalizations.of(context)
                        .deleteButtonTooltip,
                    onPressed: () => setState(_search.clear),
                  ),
            filled: true,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          key: const ValueKey('homework-filter'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              label: Text(counted('homeworkUpcoming', upcoming.length)),
            ),
            ButtonSegment(
              value: true,
              label: Text(counted('homeworkPast', past.length)),
            ),
          ],
          selected: {_past},
          onSelectionChanged: (selection) =>
              setState(() => _past = selection.first),
        ),
        if (shown.isEmpty) _Empty(context.tr('noData')),
        ...rows,
      ],
    );
  }
}

/// Whole days from [from] to [to], unaffected by daylight saving.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The assignment itself. Librus falls back to the type ("Zadanie domowe")
/// when an assignment has neither topic nor text.
String _homeworkTitle(BuildContext context, SchoolEvent item) =>
    item.title.isEmpty || item.title == item.typeLabel
    ? context.tr('homeworkItem')
    : item.title;

/// More text than the title, if the assignment has any.
String _homeworkDetails(SchoolEvent item) =>
    item.description == item.title ? '' : item.description;

class _Messages extends StatefulWidget {
  const _Messages(this.controller);
  final AppController controller;

  @override
  State<_Messages> createState() => _MessagesState();
}

class _MessagesState extends State<_Messages> {
  final _search = TextEditingController();
  bool _unreadOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    try {
      await widget.controller.markAllMessagesRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('allMessagesRead'))));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('markAllReadFailed'))));
    }
  }

  /// "Today", "Yesterday", "This week", then the month.
  String _section(DateTime value, DateTime now) {
    final day = DateTime(value.year, value.month, value.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return context.tr('messagesToday');
    if (days == 1) return context.tr('messagesYesterday');
    if (days < 7 && day.weekday < today.weekday) {
      return context.tr('messagesThisWeek');
    }
    return _capitalize(
      DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag())
          .format(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final all = controller.snapshot.messages.toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final query = _search.text.trim().toLowerCase();
    final messages = all
        .where((item) => !_unreadOnly || item.unread)
        .where(
          (item) =>
              query.isEmpty ||
              item.subject.toLowerCase().contains(query) ||
              item.sender.toLowerCase().contains(query) ||
              item.preview.toLowerCase().contains(query),
        )
        .toList();
    final error = controller.snapshot.messagesError;
    final unreadCount = all.where((item) => item.unread).length;
    final style = controller.messageListStyle;
    final now = DateTime.now();
    final colors = Theme.of(context).colorScheme;

    final rows = <Widget>[];
    String? lastSection;
    for (final item in messages) {
      final section = _section(item.receivedAt, now);
      if (section != lastSection) {
        rows.add(
          Padding(
            key: ValueKey('messages-section-$section'),
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
            child: Text(
              section,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
        lastSection = section;
      }
      rows.add(_MessageTile(controller, item, style: style, now: now));
    }

    final tiles = <Widget>[
      TextField(
        key: const ValueKey('messages-search'),
        controller: _search,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.tr('messagesSearch'),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  tooltip: MaterialLocalizations.of(context)
                      .deleteButtonTooltip,
                  onPressed: () => setState(_search.clear),
                ),
          filled: true,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: SegmentedButton<bool>(
              key: const ValueKey('messages-filter'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(context.tr('messagesAll')),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    unreadCount == 0
                        ? context.tr('messagesUnread')
                        : '${context.tr('messagesUnread')} ($unreadCount)',
                  ),
                ),
              ],
              selected: {_unreadOnly},
              onSelectionChanged: (selection) =>
                  setState(() => _unreadOnly = selection.first),
            ),
          ),
          IconButton(
            key: const ValueKey('messages-mark-all-read'),
            tooltip: context.tr('markAllRead'),
            onPressed:
                unreadCount == 0 ||
                    controller.markingMessagesRead ||
                    controller.syncing
                ? null
                : _markAllRead,
            icon: controller.markingMessagesRead
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            key: const ValueKey('messages-style-toggle'),
            tooltip: context.tr(
              style == MessageListStyle.list
                  ? 'messagesViewCards'
                  : 'messagesViewList',
            ),
            onPressed: () => controller.setMessageListStyle(
              style == MessageListStyle.list
                  ? MessageListStyle.cards
                  : MessageListStyle.list,
            ),
            icon: Icon(
              style == MessageListStyle.list
                  ? Icons.view_agenda_outlined
                  : Icons.view_list_rounded,
            ),
          ),
        ],
      ),
      if (error != null)
        ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(context.trError(error)),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: MaterialLocalizations.of(context)
                .refreshIndicatorSemanticLabel,
            onPressed: controller.syncing ? null : controller.sync,
          ),
        ),
      if (messages.isEmpty && error == null) _Empty(context.tr('noData')),
      ...rows,
    ];
    final scope = GlassPageScope.maybeOf(context);
    // Under a glass top bar the compose button lives in the bar.
    if (scope != null && scope.barActions) {
      return _PageList(padding: const EdgeInsets.all(12), children: tiles);
    }
    final insets = _chromeInsets(context);
    final title = scope?.largeTitle;
    return Column(
      children: [
        SizedBox(height: insets.top),
        if (title != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GlassLargeTitle.margin,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: GlassLargeTitle(title),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showComposeMessage(context, controller),
              icon: const Icon(Icons.edit_rounded),
              label: Text(context.tr('newMessage')),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + insets.bottom),
            children: tiles,
          ),
        ),
      ],
    );
  }
}

/// "12:30" today, the weekday this week, the date before that.
String _messageTime(BuildContext context, DateTime value, DateTime now) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final day = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  // Today and yesterday have their own sections, so the time says more.
  if (days <= 1) return DateFormat('HH:mm').format(value);
  if (days < 7) return _shortWeekday(context, value);
  if (value.year == now.year) return DateFormat('dd.MM', locale).format(value);
  return DateFormat('dd.MM.yyyy', locale).format(value);
}

class _MessageTile extends StatelessWidget {
  const _MessageTile(
    this.controller,
    this.item, {
    required this.style,
    required this.now,
  });
  final AppController controller;
  final SchoolMessage item;
  final MessageListStyle style;
  final DateTime now;

  Future<bool> _markRead(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.tr('markAllReadFailed');
    try {
      await controller.markMessageRead(item);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
    // The row stays; it just turns read.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unread = item.unread;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: style == MessageListStyle.list ? 8 : 12,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SenderAvatar(item.sender),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.sender.isEmpty ? '—' : item.sender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.hasAttachments)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.attach_file_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _messageTime(context, item.receivedAt, now),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: unread
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: unread
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        key: ValueKey('message-unread-${item.id}'),
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(left: 8, top: 6),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (item.preview.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.preview.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final tile = style == MessageListStyle.cards
        ? Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showMessageDetail(context, controller, item),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: unread ? colors.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: content,
              ),
            ),
          )
        : Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showMessageDetail(context, controller, item),
                child: content,
              ),
              const Divider(height: 1, indent: 60),
            ],
          );
    if (!unread) return tile;
    return Dismissible(
      key: ValueKey('message-${item.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) => _markRead(context),
      background: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              context.tr('messageMarkRead'),
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: tile,
    );
  }
}

/// The sender's initials on a calm colour of their own.
class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar(this.sender, {this.radius = 20});
  final String sender;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final words = sender
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    final initials = words.isEmpty
        ? '?'
        : words
              .take(2)
              .map((word) => word.characters.first.toUpperCase())
              .join();
    final palette = SubjectColors.colors(
      SubjectColors.stableHash(sender) % SubjectColors.hueCount,
      Theme.of(context).brightness,
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.background,
      foregroundColor: palette.foreground,
      child: Text(
        initials,
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w800),
      ),
    );
  }
}

Future<void> _showMessageDetail(
  BuildContext context,
  AppController controller,
  SchoolMessage message,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) =>
      _MessageDetailSheet(controller: controller, message: message),
);

class _MessageDetailSheet extends StatefulWidget {
  const _MessageDetailSheet({required this.controller, required this.message});
  final AppController controller;
  final SchoolMessage message;

  @override
  State<_MessageDetailSheet> createState() => _MessageDetailSheetState();
}

class _MessageDetailSheetState extends State<_MessageDetailSheet> {
  late Future<SchoolMessageContent> content;
  String? openingAttachment;

  @override
  void initState() {
    super.initState();
    content = widget.controller.fetchMessageContent(widget.message);
  }

  void retry() {
    setState(() {
      content = widget.controller.fetchMessageContent(widget.message);
    });
  }

  Future<void> openAttachment(MessageAttachment attachment) async {
    setState(() => openingAttachment = attachment.id);
    try {
      final url = await widget.controller.fetchMessageAttachmentUrl(
        messageId: widget.message.id,
        attachmentId: attachment.id,
      );
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Unable to open attachment URL');
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('attachmentOpenFailed'))),
      );
    } finally {
      if (mounted) setState(() => openingAttachment = null);
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.92,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('messages'),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<SchoolMessageContent>(
            future: content,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: _RecipientError(
                    message: snapshot.error == null
                        ? context.tr('messageLoadFailed')
                        : context.trError(AppError.from(snapshot.error!)),
                    onRetry: retry,
                  ),
                );
              }
              final message = snapshot.data!;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + _systemButtonsRoom(context),
                ),
                children: [
                  Text(
                    message.subject,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          message.sender.isEmpty
                              ? '?'
                              : message.sender.characters.first.toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.sender,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              DateFormat('dd.MM.yyyy, HH:mm')
                                  .format(message.receivedAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  SelectableText(
                    message.body,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(height: 1.45),
                  ),
                  if (message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      context.tr('attachments'),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...message.attachments.map(
                      (attachment) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.attach_file_rounded),
                          title: Text(attachment.name),
                          trailing: openingAttachment == attachment.id
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.open_in_new_rounded),
                          enabled: openingAttachment == null,
                          onTap: openingAttachment == null
                              ? () => openAttachment(attachment)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// The room a bar of system buttons takes at the bottom of the screen. It
/// lies over the app and takes the touches there, so a sheet that reaches
/// the bottom keeps its last control above it. An iPhone's home indicator
/// and Android's gesture handle are in the way of nothing and count as no
/// room at all. While the keyboard is up, the bar is under it.
double _systemButtonsRoom(BuildContext context) {
  final inset = MediaQuery.paddingOf(context).bottom;
  return inset > 34 ? inset : 0;
}

Future<void> _showComposeMessage(
  BuildContext context,
  AppController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _ComposeMessageSheet(controller),
);

class _ComposeMessageSheet extends StatefulWidget {
  const _ComposeMessageSheet(this.controller);
  final AppController controller;

  @override
  State<_ComposeMessageSheet> createState() => _ComposeMessageSheetState();
}

class _ComposeMessageSheetState extends State<_ComposeMessageSheet> {
  final subjectController = TextEditingController();
  final bodyController = TextEditingController();
  final selectedRecipients = <MessageRecipient>[];
  TextEditingController? recipientSearchController;
  late Future<List<MessageRecipient>> recipients;
  bool sending = false;
  String? validationError;

  @override
  void initState() {
    super.initState();
    recipients = widget.controller.fetchMessageRecipients();
  }

  @override
  void dispose() {
    subjectController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  void retryRecipients() {
    setState(() {
      validationError = null;
      recipients = widget.controller.fetchMessageRecipients();
    });
  }

  Future<void> send() async {
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();
    final error = switch ((selectedRecipients.isEmpty, subject, body)) {
      (true, _, _) => context.tr('requiredRecipients'),
      (_, '', _) => context.tr('requiredSubject'),
      (_, _, '') => context.tr('requiredBody'),
      _ => null,
    };
    if (error != null) {
      setState(() => validationError = error);
      return;
    }
    setState(() {
      sending = true;
      validationError = null;
    });
    try {
      await widget.controller.sendMessage(
        recipientIds: selectedRecipients.map((item) => item.id).toList(),
        subject: subject,
        body: body,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('messageSent'))),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        validationError = error.toString().trim().isEmpty
            ? context.tr('messageSendFailed')
            : error.toString();
      });
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('newMessage'),
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: sending ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<List<MessageRecipient>>(
                    future: recipients,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return _RecipientError(
                          message: context.trError(
                            AppError.from(snapshot.error!),
                          ),
                          onRetry: retryRecipients,
                        );
                      }
                      final items = snapshot.data ?? const [];
                      if (items.isEmpty) {
                        return _RecipientError(
                          message: context.tr('noRecipients'),
                          onRetry: retryRecipients,
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (selectedRecipients.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: selectedRecipients
                                  .map(
                                    (recipient) => InputChip(
                                      label: Text(recipient.name),
                                      onDeleted: sending
                                          ? null
                                          : () => setState(
                                              () => selectedRecipients.remove(
                                                recipient,
                                              ),
                                            ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Autocomplete<MessageRecipient>(
                            displayStringForOption: (item) => item.name,
                            optionsBuilder: (value) {
                              final query = value.text.trim().toLowerCase();
                              return items.where(
                                (item) =>
                                    !selectedRecipients.any(
                                      (selected) => selected.id == item.id,
                                    ) &&
                                    (query.isEmpty ||
                                        item.name.toLowerCase().contains(
                                          query,
                                        ) ||
                                        item.group.toLowerCase().contains(
                                          query,
                                        )),
                              );
                            },
                            onSelected: (item) {
                              setState(() => selectedRecipients.add(item));
                              recipientSearchController?.clear();
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, onSubmit) {
                                  recipientSearchController = controller;
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: !sending,
                                    decoration: InputDecoration(
                                      labelText: context.tr('recipient'),
                                      hintText: context.tr('searchRecipient'),
                                      prefixIcon: const Icon(
                                        Icons.person_search_rounded,
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                  );
                                },
                            optionsViewBuilder:
                                (context, onSelected, options) => Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 8,
                                    borderRadius: BorderRadius.circular(12),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 280,
                                        maxWidth: 520,
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (context, index) {
                                          final item = options.elementAt(index);
                                          return ListTile(
                                            title: Text(item.name),
                                            subtitle: item.group.isEmpty
                                                ? null
                                                : Text(item.group),
                                            onTap: () => onSelected(item),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectController,
                    enabled: !sending,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: context.tr('subject'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bodyController,
                    enabled: !sending,
                    minLines: 7,
                    maxLines: 14,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: context.tr('messageBody'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      validationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + _systemButtonsRoom(context),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: sending ? null : send,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(context.tr(sending ? 'sending' : 'send')),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecipientError extends StatelessWidget {
  const _RecipientError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    ),
  );
}

enum _AttendancePeriod { first, second, year }

class _Attendance extends StatefulWidget {
  const _Attendance(this.controller);
  final AppController controller;
  @override
  State<_Attendance> createState() => _AttendanceState();
}

class _AttendanceState extends State<_Attendance> {
  _AttendancePeriod period = _AttendancePeriod.year;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final records = widget.controller.snapshot.attendance
        .where(
          (item) => switch (period) {
            _AttendancePeriod.first => item.semester == 1,
            _AttendancePeriod.second => item.semester == 2,
            _AttendancePeriod.year => true,
          },
        )
        .toList();
    final counts = {
      for (final kind in AttendanceKind.values)
        kind: records.where((item) => item.kind == kind).length,
    };
    final selected = selectedDay == null
        ? const <AttendanceRecord>[]
        : records.where((item) => _sameDay(item.date, selectedDay!)).toList();
    return _PageList(
      padding: const EdgeInsets.all(12),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_AttendancePeriod>(
            selected: {period},
            onSelectionChanged: (value) => setState(() => period = value.first),
            segments: [
              ButtonSegment(
                value: _AttendancePeriod.first,
                label: Text(context.tr('period1')),
              ),
              ButtonSegment(
                value: _AttendancePeriod.second,
                label: Text(context.tr('period2')),
              ),
              ButtonSegment(
                value: _AttendancePeriod.year,
                label: Text(context.tr('schoolYear')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AttendanceChart(
          counts: counts,
          style: widget.controller.attendanceChartStyle,
        ),
        const SizedBox(height: 16),
        _AttendanceCalendar(
          records: records,
          month: month,
          selectedDay: selectedDay,
          onMonthChanged: (value) => setState(() => month = value),
          onDaySelected: (value) => setState(() => selectedDay = value),
        ),
        if (selectedDay != null) ...[
          const SizedBox(height: 18),
          _Heading('${context.tr('selectedDay')}: ${_date(selectedDay!)}'),
          const SizedBox(height: 8),
          if (selected.isEmpty)
            _Empty(context.tr('noData'))
          else
            ...selected.map(_AttendanceTile.new),
        ],
        const SizedBox(height: 18),
        ...records.map(_AttendanceTile.new),
      ],
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  const _AttendanceChart({required this.counts, required this.style});
  final Map<AttendanceKind, int> counts;
  final AttendanceChartStyle style;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, value) => sum + value);
    final present = counts.entries
        .where((entry) => entry.key.countsAsPresence)
        .fold(0, (sum, entry) => sum + entry.value);
    final entries = AttendanceKind.values
        .map(
          (kind) => (
            kind: kind,
            count: counts[kind] ?? 0,
            color: _attendanceColor(kind),
            label: context.tr(_attendanceLabel(kind)),
          ),
        )
        .toList(growable: false);
    final visibleEntries = entries
        .where((entry) => entry.count > 0)
        .toList(growable: false);
    final percentage = total == 0 ? 0.0 : present / total * 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('attendanceChart'),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${context.tr('attendanceRate')}: ${_percent(context, percentage)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _AttendanceGraphic(
              entries: visibleEntries,
              style: style,
              percentage: percentage,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: entries
                  .map(
                    (entry) => _Legend(
                      color: entry.color,
                      label: entry.label,
                      value: entry.count,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceGraphic extends StatelessWidget {
  const _AttendanceGraphic({
    required this.entries,
    required this.style,
    required this.percentage,
  });
  final List<({AttendanceKind kind, int count, Color color, String label})>
  entries;
  final AttendanceChartStyle style;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    if (style == AttendanceChartStyle.bar) {
      return SizedBox(
        key: const ValueKey('attendance-flat-chart'),
        width: double.infinity,
        height: 24,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: entries.isEmpty
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: entries
                      .map(
                        (entry) => Expanded(
                          flex: entry.count,
                          child: ColoredBox(color: entry.color),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
      );
    }
    final ring = style == AttendanceChartStyle.ring;
    return Center(
      child: SizedBox.square(
        dimension: 178,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(178),
              painter: _AttendancePiePainter(
                segments: entries
                    .map((entry) => (count: entry.count, color: entry.color))
                    .toList(growable: false),
                ring: ring,
                emptyColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
            ),
            if (ring)
              Text(
                _percent(context, percentage),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttendancePiePainter extends CustomPainter {
  const _AttendancePiePainter({
    required this.segments,
    required this.ring,
    required this.emptyColor,
  });
  final List<({int count, Color color})> segments;
  final bool ring;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<int>(0, (sum, item) => sum + item.count);
    final strokeWidth = size.shortestSide * 0.18;
    final inset = ring ? strokeWidth / 2 : 0.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(inset);
    if (total == 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2,
        !ring,
        Paint()
          ..color = emptyColor
          ..style = ring ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = strokeWidth,
      );
      return;
    }
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = math.pi * 2 * segment.count / total;
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        !ring,
        Paint()
          ..color = segment.color
          ..style = ring ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _AttendancePiePainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.ring != ring ||
      oldDelegate.emptyColor != emptyColor;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.value});
  final Color color;
  final String label;
  final int? value;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Text(value == null ? label : '$label: $value'),
    ],
  );
}

class _AttendanceCalendar extends StatelessWidget {
  const _AttendanceCalendar({
    required this.records,
    required this.month,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });
  final List<AttendanceRecord> records;
  final DateTime month;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = leading + count;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = {
      for (var day = 1; day <= count; day++)
        day: _attendanceDay(
          records
              .where(
                (item) =>
                    _sameDay(item.date, DateTime(month.year, month.month, day)),
              )
              .toList(),
        ),
    };
    final shown = days.values.nonNulls.map((day) => day.label).toSet();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () =>
                      onMonthChanged(DateTime(month.year, month.month - 1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _capitalize(DateFormat.yMMMM(locale).format(month)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      onMonthChanged(DateTime(month.year, month.month + 1)),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // 1 January 2024 was a Monday.
                  for (var weekday = 0; weekday < 7; weekday++)
                    Expanded(
                      child: Text(
                        _shortWeekday(context, DateTime(2024, 1, 1 + weekday)),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: ((cells + 6) ~/ 7) * 7,
              itemBuilder: (context, index) {
                final dayNumber = index - leading + 1;
                if (dayNumber < 1 || dayNumber > count) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(month.year, month.month, dayNumber);
                final color = days[dayNumber]?.color;
                final active =
                    selectedDay != null && _sameDay(selectedDay!, date);
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onDaySelected(date),
                  child: Container(
                    key: ValueKey('attendance-day-${date.toIso8601String()}'),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      border: active
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontWeight: color == null
                            ? FontWeight.w400
                            : FontWeight.w800,
                        color: color == null
                            ? null
                            : ThemeData.estimateBrightnessForColor(color) ==
                                  Brightness.light
                            ? const Color(0xFF101416)
                            : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (shown.isNotEmpty)
              Padding(
                key: const ValueKey('attendance-calendar-legend'),
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final day in _attendanceDayKinds)
                      if (shown.contains(day.label))
                        _Legend(color: day.color, label: context.tr(day.label)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile(this.item);
  final AttendanceRecord item;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: _attendanceColor(item.kind).withAlpha(55),
        child: Text(item.symbol),
      ),
      title: Text(item.type),
      subtitle: Text(
        [
          if (item.subject.isNotEmpty) item.subject,
          if (item.lessonNumber > 0)
            context.trArgs('lessonNumber', {'number': '${item.lessonNumber}'}),
        ].join(' · '),
      ),
      trailing: Text(_date(item.date)),
    ),
  );
}

String _attendanceLabel(AttendanceKind kind) => switch (kind) {
  AttendanceKind.present => 'present',
  AttendanceKind.absent => 'absent',
  AttendanceKind.absentExcused => 'absentExcused',
  AttendanceKind.late => 'late',
  AttendanceKind.lateExcused => 'lateExcused',
  AttendanceKind.released => 'released',
  AttendanceKind.other => 'otherAttendance',
};

Color _attendanceColor(AttendanceKind kind) => switch (kind) {
  AttendanceKind.present => const Color(0xFF43C66C),
  AttendanceKind.absent => const Color(0xFFF45B69),
  AttendanceKind.absentExcused => const Color(0xFFAB7BE8),
  AttendanceKind.late => const Color(0xFFFFD166),
  AttendanceKind.lateExcused => const Color(0xFF2DD4BF),
  AttendanceKind.released => const Color(0xFF5BA9F4),
  AttendanceKind.other => const Color(0xFFA4ACBA),
};

typedef _AttendanceDay = ({Color color, String label});

const _partlyAbsent = (color: Color(0xFFF28C28), label: 'partlyAbsent');

/// Everything a calendar day can show, in the order of its legend.
final _attendanceDayKinds = <_AttendanceDay>[
  for (final kind in AttendanceKind.values) ...[
    (color: _attendanceColor(kind), label: _attendanceLabel(kind)),
    if (kind == AttendanceKind.absent) _partlyAbsent,
  ],
];

/// The colour of a calendar day: the most serious record of the day, or
/// "partly absent" when the student missed only some of the lessons.
_AttendanceDay? _attendanceDay(List<AttendanceRecord> records) {
  if (records.isEmpty) return null;
  final hasPresence = records.any(
    (record) => record.kind == AttendanceKind.present,
  );
  final hasAbsence = records.any(
    (record) =>
        record.kind == AttendanceKind.absent ||
        record.kind == AttendanceKind.absentExcused,
  );
  if (hasPresence && hasAbsence) return _partlyAbsent;
  final kind = _dominantAttendanceKind(records);
  return (color: _attendanceColor(kind), label: _attendanceLabel(kind));
}

AttendanceKind _dominantAttendanceKind(List<AttendanceRecord> records) {
  const priority = [
    AttendanceKind.absent,
    AttendanceKind.absentExcused,
    AttendanceKind.late,
    AttendanceKind.lateExcused,
    AttendanceKind.released,
    AttendanceKind.other,
    AttendanceKind.present,
  ];
  return priority.firstWhere(
    (kind) => records.any((record) => record.kind == kind),
  );
}

class _Announcements extends StatelessWidget {
  const _Announcements(this.data);
  final AppSnapshot data;
  @override
  Widget build(BuildContext context) => data.announcements.isEmpty
      ? _PageEmpty(context.tr('noData'))
      : _PageList(
          padding: const EdgeInsets.all(12),
          children: data.announcements
              .map(
                (item) => Card(
                  child: ExpansionTile(
                    leading: Icon(
                      item.read
                          ? Icons.campaign_outlined
                          : Icons.campaign_rounded,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.read
                            ? FontWeight.w500
                            : FontWeight.w800,
                      ),
                    ),
                    subtitle: Text('${item.author} · ${_date(item.createdAt)}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(item.content),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
}

class _Notices extends StatelessWidget {
  const _Notices(this.data);
  final AppSnapshot data;
  @override
  Widget build(BuildContext context) => data.notices.isEmpty
      ? _PageEmpty(context.tr('noData'))
      : _PageList(
          padding: const EdgeInsets.all(12),
          children: data.notices.map((item) {
            final color = switch (item.tone) {
              NoticeTone.positive => Colors.green,
              NoticeTone.neutral => Colors.blueGrey,
              NoticeTone.negative => Colors.red,
            };
            final icon = switch (item.tone) {
              NoticeTone.positive => Icons.thumb_up_alt_rounded,
              NoticeTone.neutral => Icons.chat_bubble_rounded,
              NoticeTone.negative => Icons.report_rounded,
            };
            final toneLabel = context.tr(switch (item.tone) {
              NoticeTone.positive => 'noticePositive',
              NoticeTone.neutral => 'noticeNeutral',
              NoticeTone.negative => 'noticeNegative',
            });
            return Card(
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                title: Text(
                  toneLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(item.teacher),
                trailing: Text(_date(item.date)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.category.isNotEmpty) ...[
                            Text(
                              item.category,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: color),
                            ),
                            const SizedBox(height: 6),
                          ],
                          SelectableText(item.text),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
}

/// Short subject names the student chose, for the lesson tiles below.
/// Short subject names and subject colours, for the lesson views below.
class _SubjectScope extends InheritedWidget {
  const _SubjectScope({
    required this.names,
    required this.colors,
    required super.child,
  });

  final Map<String, String> names;
  final SubjectColors colors;

  /// The short name for [subject], or the subject itself.
  static String of(BuildContext context, String subject) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SubjectScope>();
    return scope == null ? subject : displaySubject(subject, scope.names);
  }

  static SubjectColors colorsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SubjectScope>()?.colors ??
      SubjectColors.empty;

  @override
  bool updateShouldNotify(_SubjectScope oldWidget) =>
      names != oldWidget.names || colors != oldWidget.colors;
}

const _repositoryUrl = 'https://github.com/johnnydotpm/Siberia';

Future<void> _openLink(BuildContext context, String link) async {
  final opened = await launchUrl(
    Uri.parse(link),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(link)));
  }
}

class _Settings extends StatelessWidget {
  const _Settings(this.controller);
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final bridge = controller.homeWidget ?? const HomeWidgetBridge();
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final settings = controller.gradeAverage;
    final notifications = controller.notificationSettings;
    final enabledCategories = SchoolNotificationCategory.values
        .where(notifications.allows)
        .length;
    return _PageList(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsProfile(controller),
        _SettingsSection(
          title: context.tr('settingsAppearance'),
          children: [
            _PreviewChoice<AppColorMode>(
              title: context.tr('colorMode'),
              icon: Icons.brightness_6_outlined,
              selected: controller.colorMode,
              onSelected: controller.setColorMode,
              options: [
                for (final mode in AppColorMode.values)
                  (
                    value: mode,
                    label: context.tr('colorMode_${mode.name}'),
                    key: ValueKey('settings-theme-${mode.name}'),
                    preview: _ThemePreview(mode),
                  ),
              ],
            ),
            // Where the platform cannot draw glass there is nothing to choose.
            if (GlassPlatform.supported)
              _PreviewChoice<AppDesign>(
                title: context.tr('design'),
                icon: Icons.auto_awesome_outlined,
                selected: controller.design,
                onSelected: controller.setDesign,
                options: [
                  for (final design in AppDesign.values)
                    (
                      value: design,
                      label: context.tr('design_${design.name}'),
                      key: ValueKey('settings-design-${design.name}'),
                      preview: _DesignPreview(design),
                    ),
                ],
              ),
            ListTile(
              key: const ValueKey('settings-language'),
              leading: const _SettingsIcon(Icons.language_rounded),
              title: Text(context.tr('language')),
              subtitle: Text(_languageName(context, controller.locale)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showLanguageSheet(context, controller),
            ),
          ],
        ),
        _SettingsSection(
          title: context.tr('settingsSyncNotifications'),
          children: [
            SwitchListTile.adaptive(
              secondary: const _SettingsIcon(Icons.sync_rounded),
              title: Text(context.tr('autoSyncOnOpen')),
              subtitle: Text(context.tr('autoSyncOnOpenDescription')),
              value: controller.autoSyncOnOpen,
              onChanged: controller.setAutoSyncOnOpen,
            ),
            ListTile(
              key: const ValueKey('settings-notifications'),
              leading: const _SettingsIcon(Icons.notifications_active_outlined),
              title: Text(context.tr('notifications')),
              subtitle: Text(
                notifications.enabled
                    ? context.trArgs('notificationsOn', {
                        'enabled': '$enabledCategories',
                        'total': '${SchoolNotificationCategory.values.length}',
                      })
                    : context.tr('notificationsOff'),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showNotificationSettings(context, controller),
            ),
          ],
        ),
        _SettingsSection(
          title: context.tr('settingsScreens'),
          children: [
            ListTile(
              key: const ValueKey('settings-today-screen'),
              leading: const _SettingsIcon(Icons.dashboard_customize_outlined),
              title: Text(context.tr('todayCustomizeSettings')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showTodayLayoutSheet(context, controller),
            ),
            ListTile(
              key: const ValueKey('settings-timetable'),
              leading: const _SettingsIcon(Icons.calendar_view_week_outlined),
              title: Text(context.tr('timetable')),
              subtitle: Text(context.tr('timetableStyle')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showTimetableSettings(context, controller),
            ),
            ListTile(
              key: const ValueKey('settings-short-names'),
              leading: const _SettingsIcon(Icons.short_text_rounded),
              title: Text(context.tr('shortSubjectNames')),
              subtitle: Text(context.tr('shortSubjectNamesDescription')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showAppSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => SubjectShortNamesSheet(controller: controller),
              ),
            ),
            _PreviewChoice<AttendanceChartStyle>(
              title: context.tr('attendanceChartStyle'),
              icon: Icons.donut_large_rounded,
              selected: controller.attendanceChartStyle,
              onSelected: controller.setAttendanceChartStyle,
              options: [
                for (final style in AttendanceChartStyle.values)
                  (
                    value: style,
                    label: context.tr('chartStyle_${style.name}'),
                    key: ValueKey('settings-chart-${style.name}'),
                    preview: _ChartPreview(style),
                  ),
              ],
            ),
          ],
        ),
        _SettingsSection(
          title: context.tr('grades'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (sign, key, value) in [
                    ('+', 'grade-plus', settings.plus),
                    ('-', 'grade-minus', settings.minus),
                  ]) ...[
                    if (sign == '-') const SizedBox(height: 16),
                    Row(
                      children: [
                        _SettingsIcon(
                          sign == '+'
                              ? Icons.add_rounded
                              : Icons.remove_rounded,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '${context.tr(sign == '+' ? 'gradePlusValue' : 'gradeMinusValue')} · 3$sign',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<double>(
                        key: ValueKey(key),
                        showSelectedIcon: false,
                        segments: [
                          for (final modifier
                              in GradeAverageSettings.modifierOptions)
                            ButtonSegment(
                              value: modifier,
                              label: Text(
                                _decimal(
                                  context,
                                  sign == '+' ? 3 + modifier : 3 - modifier,
                                ),
                              ),
                            ),
                        ],
                        selected: {value},
                        onSelectionChanged: (selection) =>
                            controller.setGradeAverageSettings(
                              sign == '+'
                                  ? settings.copyWith(plus: selection.first)
                                  : settings.copyWith(minus: selection.first),
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('grade-weighted'),
              secondary: const _SettingsIcon(Icons.balance_rounded),
              title: Text(context.tr('weightedAverage')),
              subtitle: Text(context.tr('weightedAverageDescription')),
              value: settings.weighted,
              onChanged: (value) => controller.setGradeAverageSettings(
                settings.copyWith(weighted: value),
              ),
            ),
            _AveragePreview(controller),
          ],
        ),
        if (bridge.configurableInApp || ios)
          _SettingsSection(
            title: context.tr('homeWidgets'),
            children: [_HomeWidgetsRow(bridge)],
          ),
        _SettingsSection(
          title: context.tr('settingsAbout'),
          children: [
            ListTile(
              leading: const _SettingsIcon(Icons.info_outline_rounded),
              title: Text('SiberiaGB ${AppBuildInfo.version}'),
              subtitle: Text(
                '${context.tr('buildCommit')}: ${AppBuildInfo.shortCommit}',
              ),
            ),
            _CheckUpdatesRow(controller),
            ListTile(
              key: const ValueKey('settings-whats-new'),
              leading: const _SettingsIcon(Icons.new_releases_outlined),
              title: Text(context.tr('whatsNew')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => _openLink(context, '$_repositoryUrl/releases'),
            ),
            ListTile(
              key: const ValueKey('settings-source'),
              leading: const _SettingsIcon(Icons.code_rounded),
              title: Text(context.tr('sourceCode')),
              subtitle: const Text('github.com/johnnydotpm/Siberia'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => _openLink(context, _repositoryUrl),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            key: const ValueKey('settings-reset'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _confirmResetSettings(context, controller),
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(context.tr('resetSettings')),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A titled group of settings in one card.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0) const Divider(height: 1, indent: 16),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The icon at the start of a settings row.
class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
    );
  }
}

/// The signed-in student, when the data was last synced, and a sync button.
class _SettingsProfile extends StatelessWidget {
  const _SettingsProfile(this.controller);
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final profile = controller.snapshot.profile;
    return Card(
      key: const ValueKey('settings-profile'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showAccount(context, controller),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            children: [
              _SenderAvatar(profile.name, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('account'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                      ),
                    ),
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (profile.school.isNotEmpty)
                      Text(
                        profile.school,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.cloud_done_outlined, size: 15, color: muted),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _syncedAgo(context, controller.snapshot.lastSync),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (controller.syncing)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  key: const ValueKey('settings-sync'),
                  tooltip: context.tr('sync'),
                  onPressed: controller.sync,
                  icon: const Icon(Icons.sync_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Synced just now", "5 min ago", "2 h ago", or the date.
String _syncedAgo(BuildContext context, DateTime lastSync) {
  final elapsed = DateTime.now().difference(lastSync);
  if (elapsed.inMinutes < 1) return context.tr('syncedJustNow');
  if (elapsed.inHours < 1) {
    return context.trArgs('syncedMinutesAgo', {
      'minutes': '${elapsed.inMinutes}',
    });
  }
  if (elapsed.inHours < 24) {
    return context.trArgs('syncedHoursAgo', {'hours': '${elapsed.inHours}'});
  }
  return context.trArgs('syncedAt', {
    'date': DateFormat('dd.MM.yyyy HH:mm').format(lastSync),
  });
}

/// A setting chosen from a few picture cards.
class _PreviewChoice<T> extends StatelessWidget {
  const _PreviewChoice({
    required this.title,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final String title;
  final IconData icon;
  final List<({T value, String label, Key key, Widget preview})> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SettingsIcon(icon),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final option in options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Semantics(
                      selected: option.value == selected,
                      button: true,
                      child: InkWell(
                        key: option.key,
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onSelected(option.value),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: 64,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: option.value == selected
                                        ? colors.primary
                                        : colors.outlineVariant,
                                    width: option.value == selected ? 2.5 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: SizedBox.expand(child: option.preview),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                option.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: option.value == selected
                                      ? colors.primary
                                      : colors.onSurface,
                                  fontWeight: option.value == selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tiny screen in the given colours: a title, and a card with two lines.
Widget _miniScreen({
  required Color background,
  required Color card,
  required Color line,
  required Color accent,
}) => ColoredBox(
  color: background,
  child: Padding(
    padding: const EdgeInsets.all(6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 6,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 4, color: line),
                const SizedBox(height: 3),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: Container(height: 4, color: line),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);

class _ThemePreview extends StatelessWidget {
  const _ThemePreview(this.mode);
  final AppColorMode mode;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final light = _miniScreen(
      background: const Color(0xFFF2F4F5),
      card: Colors.white,
      line: const Color(0xFFCBD2D6),
      accent: accent,
    );
    final dark = _miniScreen(
      background: const Color(0xFF151A1D),
      card: const Color(0xFF232A2E),
      line: const Color(0xFF414B51),
      accent: accent,
    );
    return switch (mode) {
      AppColorMode.light => light,
      AppColorMode.dark => dark,
      AppColorMode.amoled => _miniScreen(
        background: Colors.black,
        card: const Color(0xFF0E1012),
        line: const Color(0xFF2C3236),
        accent: accent,
      ),
      AppColorMode.system => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: light),
          Expanded(child: dark),
        ],
      ),
    };
  }
}

class _DesignPreview extends StatelessWidget {
  const _DesignPreview(this.design);
  final AppDesign design;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final glass = design == AppDesign.glass;
    Widget bar({required bool top}) => Container(
      height: 10,
      margin: glass
          ? EdgeInsets.fromLTRB(top ? 4 : 10, 4, top ? 4 : 10, 4)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: glass
            ? Colors.white.withValues(alpha: 0.42)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(glass ? 6 : 0),
        border: glass
            ? Border.all(color: Colors.white.withValues(alpha: 0.6))
            : null,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? null : colors.surface,
        gradient: glass
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primaryContainer, colors.tertiaryContainer],
              )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [bar(top: true), bar(top: false)],
      ),
    );
  }
}

class _ChartPreview extends StatelessWidget {
  const _ChartPreview(this.style);
  final AttendanceChartStyle style;

  static final _segments = [
    (count: 6, color: _attendanceColor(AttendanceKind.present)),
    (count: 2, color: _attendanceColor(AttendanceKind.absent)),
    (count: 1, color: _attendanceColor(AttendanceKind.absentExcused)),
    (count: 1, color: _attendanceColor(AttendanceKind.late)),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Center(
        child: style == AttendanceChartStyle.bar
            ? ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  width: 52,
                  height: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final segment in _segments)
                        Expanded(
                          flex: segment.count,
                          child: ColoredBox(color: segment.color),
                        ),
                    ],
                  ),
                ),
              )
            : CustomPaint(
                size: const Size.square(42),
                painter: _AttendancePiePainter(
                  segments: _segments,
                  ring: style == AttendanceChartStyle.ring,
                  emptyColor: colors.surfaceContainerHighest,
                ),
              ),
      ),
    );
  }
}

const _languageCodes = ['pl', 'en', 'ru', 'de', 'uk'];

String _languageName(BuildContext context, Locale? locale) =>
    switch (locale?.languageCode) {
      null => context.tr('systemLanguage'),
      'pl' => context.tr('polish'),
      'en' => context.tr('english'),
      'ru' => context.tr('russian'),
      'de' => context.tr('german'),
      'uk' => context.tr('ukrainian'),
      final code => code,
    };

Future<void> _showLanguageSheet(
  BuildContext context,
  AppController controller,
) => showAppSheet<void>(
  context: context,
  compact: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: Padding(
      key: const ValueKey('language-sheet'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final code in [null, ..._languageCodes])
            ListTile(
              key: ValueKey('language-${code ?? 'system'}'),
              title: Text(
                _languageName(sheetContext, code == null ? null : Locale(code)),
              ),
              trailing: controller.locale?.languageCode == code
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                controller.setLocale(code == null ? null : Locale(code));
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    ),
  ),
);

IconData _notificationIcon(SchoolNotificationCategory category) =>
    switch (category) {
      SchoolNotificationCategory.grades => Icons.school_outlined,
      SchoolNotificationCategory.messages => Icons.mail_outline_rounded,
      SchoolNotificationCategory.announcements => Icons.campaign_outlined,
      SchoolNotificationCategory.notices => Icons.thumbs_up_down_outlined,
      SchoolNotificationCategory.attendance => Icons.fact_check_outlined,
      SchoolNotificationCategory.events => Icons.event_outlined,
      SchoolNotificationCategory.homework => Icons.assignment_outlined,
      SchoolNotificationCategory.timetable => Icons.calendar_view_week_outlined,
    };

Future<void> _showNotificationSettings(
  BuildContext context,
  AppController controller,
) {
  void denied(bool granted) {
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('notificationPermissionDenied'))),
      );
    }
  }

  return showAppSheet<void>(
    context: context,
    compact: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: controller,
      builder: (sheetContext, _) {
        final settings = controller.notificationSettings;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
            ),
            child: SingleChildScrollView(
              key: const ValueKey('notification-settings-sheet'),
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey('notifications-master'),
                    secondary: const _SettingsIcon(
                      Icons.notifications_active_outlined,
                    ),
                    title: Text(
                      sheetContext.tr('notifications'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(sheetContext.tr('notificationsDescription')),
                    value: settings.enabled,
                    onChanged: (value) async =>
                        denied(await controller.setNotificationsEnabled(value)),
                  ),
                  const Divider(height: 1),
                  for (final category in SchoolNotificationCategory.values)
                    SwitchListTile.adaptive(
                      key: ValueKey('notification-${category.name}'),
                      secondary: Icon(_notificationIcon(category)),
                      title: Text(
                        sheetContext.tr('notification_${category.name}'),
                      ),
                      value: settings.categories[category] ?? true,
                      onChanged: settings.enabled
                          ? (value) async => denied(
                              await controller.setNotificationCategoryEnabled(
                                category,
                                value,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// The student's average with the chosen settings, or a sample before there
/// are grades, so a change shows what it does.
class _AveragePreview extends StatelessWidget {
  const _AveragePreview(this.controller);
  final AppController controller;

  static final _sample = [
    for (final (value, weight) in const [('4+', 2.0), ('3-', 1.0), ('5', 3.0)])
      Grade(
        id: 'sample-$value',
        subject: '',
        value: value,
        description: '',
        date: DateTime(2000),
        weight: weight,
        semester: 1,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = controller.gradeAverage;
    final grades = controller.snapshot.grades;
    final semester = _preferredSemester(grades);
    final own = settings.average(
      grades.where((grade) => grade.semester == semester),
    );
    return ListTile(
      key: const ValueKey('settings-average-preview'),
      leading: const _SettingsIcon(Icons.calculate_outlined),
      title: Text(context.tr('averagePreview')),
      subtitle: Text(
        own != null
            ? context.tr('averagePreviewOwn')
            : context.trArgs('averageExample', {
                'grades': _sample.map((grade) => grade.value).join(', '),
              }),
      ),
      trailing: _AveragePill(own ?? settings.average(_sample)),
    );
  }
}

class _HomeWidgetsRow extends StatefulWidget {
  const _HomeWidgetsRow(this.bridge);
  final HomeWidgetBridge bridge;

  @override
  State<_HomeWidgetsRow> createState() => _HomeWidgetsRowState();
}

class _HomeWidgetsRowState extends State<_HomeWidgetsRow> {
  late final Future<HomeWidgetStatus?> _status = widget.bridge.status();

  @override
  Widget build(BuildContext context) {
    final android = widget.bridge.configurableInApp;
    return ListTile(
      key: const ValueKey('settings-home-widgets'),
      leading: const _SettingsIcon(Icons.widgets_outlined),
      title: Text(context.tr('homeWidgets')),
      subtitle: android
          ? Text(context.tr('homeWidgetsDescription'))
          : FutureBuilder(
              future: _status,
              builder: (context, snapshot) {
                // A signer that dropped the app group leaves the widget
                // without data; say so instead of the hint.
                final status = snapshot.data;
                if (status != null && !status.shared) {
                  return Text(
                    context.tr('homeWidgetsIosNoGroup'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                return Text(context.tr('homeWidgetsIosHint'));
              },
            ),
      trailing: android ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: android
          ? () => showAppSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (_) => HomeWidgetsSheet(bridge: widget.bridge),
            )
          : null,
    );
  }
}

class _CheckUpdatesRow extends StatefulWidget {
  const _CheckUpdatesRow(this.controller);
  final AppController controller;

  @override
  State<_CheckUpdatesRow> createState() => _CheckUpdatesRowState();
}

class _CheckUpdatesRowState extends State<_CheckUpdatesRow> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final latest = await widget.controller.checkForUpdateNow();
    if (!mounted) return;
    setState(() => _checking = false);
    final messenger = ScaffoldMessenger.of(context);
    if (latest == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('updateCheckFailed'))),
      );
    } else if (isNewerVersion(latest, AppBuildInfo.version)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.trArgs('updateAvailableShort', {'version': latest}),
          ),
          action: SnackBarAction(
            label: context.tr('openRelease'),
            onPressed: () =>
                _openLink(context, '$_repositoryUrl/releases/latest'),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('updateLatest'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('settings-check-updates'),
    leading: const _SettingsIcon(Icons.system_update_outlined),
    title: Text(context.tr('checkUpdates')),
    trailing: _checking
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.chevron_right_rounded),
    onTap: _checking ? null : _check,
  );
}

Future<void> _confirmResetSettings(
  BuildContext context,
  AppController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.tr('resetSettings')),
      content: Text(dialogContext.tr('resetSettingsConfirm')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            MaterialLocalizations.of(dialogContext).cancelButtonLabel,
          ),
        ),
        FilledButton(
          key: const ValueKey('settings-reset-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(dialogContext.tr('resetDefaults')),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await controller.resetSettings();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(context.tr('resetSettingsDone'))));
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.item);
  final SchoolEvent item;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (item.kind == EventKind.homework) return _HomeworkCard(item, now: now);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final days = _daysBetween(now, item.date);
    final soon = days == 0 || days == 1;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final when = switch (days) {
      0 => context.tr('messagesToday'),
      1 => context.tr('widgetTomorrow'),
      _ =>
        '${_shortWeekday(context, item.date)}, '
            '${DateFormat(item.date.year == now.year ? 'dd.MM' : 'dd.MM.yyyy', locale).format(item.date)}',
    };
    final exam = item.kind == EventKind.exam;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: exam
                    ? colors.tertiaryContainer
                    : colors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                exam ? Icons.quiz_rounded : Icons.event_rounded,
                size: 22,
                color: exam
                    ? colors.onTertiaryContainer
                    : colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.typeLabel.isNotEmpty || item.subject.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          if (item.typeLabel.isNotEmpty) item.typeLabel,
                          if (item.subject.isNotEmpty)
                            _SubjectScope.of(context, item.subject),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              when,
              style: theme.textTheme.labelMedium?.copyWith(
                color: soon ? colors.error : colors.onSurfaceVariant,
                fontWeight: soon ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One assignment: subject, due date, the task and the start of its text.
class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard(this.item, {required this.now});
  final SchoolEvent item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = SubjectColors.colors(
      _SubjectScope.colorsOf(context).indexOf(item.subject),
      theme.brightness,
    );
    final details = _homeworkDetails(item);
    final days = _daysBetween(now, item.date);
    // Due today or tomorrow: the one to do first.
    final soon = days == 0 || days == 1;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final due =
        '${_shortWeekday(context, item.date)}, '
        '${DateFormat(item.date.year == now.year ? 'dd.MM' : 'dd.MM.yyyy', locale).format(item.date)}';
    return Card(
      key: ValueKey('homework-${item.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showHomeworkDetails(context, item),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: palette.accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.subject.isEmpty
                          ? context.tr('homeworkItem')
                          : _SubjectScope.of(context, item.subject),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: palette.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.event_rounded,
                    size: 14,
                    color: soon ? colors.error : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    due,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: soon ? colors.error : colors.onSurfaceVariant,
                      fontWeight: soon ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _homeworkTitle(context, item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _showHomeworkDetails(BuildContext context, SchoolEvent item) {
  final theme = Theme.of(context);
  final palette = SubjectColors.colors(
    _SubjectScope.colorsOf(context).indexOf(item.subject),
    theme.brightness,
  );
  final locale = Localizations.localeOf(context).toLanguageTag();
  final due = _capitalize(
    (item.date.year == DateTime.now().year
            ? DateFormat.MMMMEEEEd(locale)
            : DateFormat.yMMMMEEEEd(locale))
        .format(item.date),
  );
  final details = _homeworkDetails(item);
  final screen = MediaQuery.sizeOf(context);
  showAppSheet<void>(
    context: context,
    compact: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: screen.width,
      maxHeight: screen.height * 0.85,
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('homework-details-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.subject.isNotEmpty)
                Text(
                  item.subject,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 6),
              SelectableText(
                _homeworkTitle(context, item),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.tr('homeworkDue')}: $due',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(details, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.onAll});
  final String text;
  final VoidCallback? onAll;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      if (onAll != null)
        TextButton(onPressed: onAll, child: Text(context.tr('all'))),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color)),
    ),
  );
}

class _Refresh extends StatelessWidget {
  const _Refresh({required this.controller, required this.child});
  final AppController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
    onRefresh: controller.sync,
    // Under a glass top bar the indicator would otherwise appear behind it.
    edgeOffset: _chromeInsets(context).top,
    child: child,
  );
}

/// The space the floating glass bars take from a page. Outside the glass
/// chrome the bars are not floating, and there is nothing to make room for.
EdgeInsets _chromeInsets(BuildContext context) =>
    GlassPageScope.maybeOf(context) == null
    ? EdgeInsets.zero
    : MediaQuery.paddingOf(context);

/// A page's own list. Inside the glass chrome it starts below the top bar,
/// ends above the tab bar and opens with the page's large title.
class _PageList extends StatelessWidget {
  const _PageList({required this.padding, required this.children});
  final EdgeInsets padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scope = GlassPageScope.maybeOf(context);
    if (scope == null) return ListView(padding: padding, children: children);
    final insets = MediaQuery.paddingOf(context);
    final title = scope.largeTitle;
    return ListView(
      padding: padding.copyWith(
        // The title brings its own spacing below the bar.
        top: (title == null ? padding.top : 0) + insets.top,
        bottom: padding.bottom + insets.bottom,
      ),
      children: [
        if (title != null)
          Padding(
            // Titles keep the system margin whatever the page's own padding.
            padding: EdgeInsets.symmetric(
              horizontal: math.max(0.0, GlassLargeTitle.margin - padding.left),
            ),
            child: GlassLargeTitle(title),
          ),
        ...children,
      ],
    );
  }
}

/// A page with nothing to list. Inside the glass chrome the large title stays
/// in place above the placeholder.
class _PageEmpty extends StatelessWidget {
  const _PageEmpty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scope = GlassPageScope.maybeOf(context);
    if (scope == null) return _Empty(text);
    final insets = MediaQuery.paddingOf(context);
    final title = scope.largeTitle;
    return Padding(
      padding: EdgeInsets.only(top: insets.top, bottom: insets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GlassLargeTitle.margin,
              ),
              child: GlassLargeTitle(title),
            ),
          Expanded(child: _Empty(text)),
        ],
      ),
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                const AppLogo(),
                const SizedBox(height: 24),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BrandWordmark(fontSize: 34),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('loginRequiredTitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('loginRequiredText'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      builder: (_) => _Login(controller),
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Text(context.tr('connect')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showAccount(BuildContext context, AppController controller) =>
    showAppSheet<void>(
      context: context,
      compact: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          24 + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              controller.snapshot.profile.name,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(controller.snapshot.profile.school),
            const SizedBox(height: 20),
            if (controller.snapshot.profile.provider == 'Librus Synergia')
              OutlinedButton.icon(
                onPressed: controller.syncing
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        showAppSheet<void>(
                          context: context,
                          useSafeArea: true,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => _LinkedSynergiaAccounts(controller),
                        );
                      },
                icon: const Icon(Icons.switch_account_outlined),
                label: Text(context.tr('synergiaAccounts')),
              ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                if (controller.snapshot.profile.provider == 'Librus Synergia') {
                  controller.logout();
                } else {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    builder: (_) => _Login(controller),
                  );
                }
              },
              icon: Icon(
                controller.snapshot.profile.provider == 'Librus Synergia'
                    ? Icons.logout_rounded
                    : Icons.login_rounded,
              ),
              label: Text(
                context.tr(
                  controller.snapshot.profile.provider == 'Librus Synergia'
                      ? 'logout'
                      : 'connect',
                ),
              ),
            ),
          ],
        ),
      ),
    );

class _LinkedSynergiaAccounts extends StatefulWidget {
  const _LinkedSynergiaAccounts(this.controller);
  final AppController controller;
  @override
  State<_LinkedSynergiaAccounts> createState() =>
      _LinkedSynergiaAccountsState();
}

class _LinkedSynergiaAccountsState extends State<_LinkedSynergiaAccounts> {
  late Future<List<LinkedSynergiaAccount>> accounts = widget.controller
      .fetchSynergiaAccounts();
  bool selecting = false;
  AppError? selectionError;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: FutureBuilder<List<LinkedSynergiaAccount>>(
      future: accounts,
      builder: (context, result) => ListView(
        shrinkWrap: true,
        children: [
          Text(
            context.tr('synergiaAccounts'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (result.connectionState != ConnectionState.done || selecting)
            const LinearProgressIndicator(),
          if (result.hasError)
            ListTile(
              title: Text(context.trError(AppError.from(result.error!))),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() {
                  accounts = widget.controller.fetchSynergiaAccounts();
                }),
              ),
            ),
          if (selectionError != null) Text(context.trError(selectionError!)),
          for (final account in result.data ?? <LinkedSynergiaAccount>[])
            ListTile(
              title: Text(account.name.isEmpty ? account.login : account.name),
              subtitle: account.name.isEmpty ? null : Text(account.login),
              trailing: account.selected ? const Icon(Icons.check) : null,
              enabled: !selecting,
              onTap: () async {
                setState(() {
                  selecting = true;
                  selectionError = null;
                });
                final ok = await widget.controller.selectSynergiaAccount(
                  account.login,
                );
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    selecting = false;
                    selectionError = widget.controller.error;
                  });
                }
              },
            ),
        ],
      ),
    ),
  );
}

class _Login extends StatefulWidget {
  const _Login(this.controller);
  final AppController controller;
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    final ok = await widget.controller.loginLibrus(
      username: email.text,
      password: password.text,
    );
    if (mounted && ok) {
      Navigator.pop(context);
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      24 +
          MediaQuery.viewInsetsOf(context).bottom +
          _systemButtonsRoom(context),
    ),
    child: Form(
      key: form,
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            context.tr('account'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(context.tr('loginHelp')),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.vpn_lock_outlined,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('vpnWarning'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: context.tr('email'),
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              border: const OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? context.tr('requiredEmail')
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: obscure,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => submit(),
            decoration: InputDecoration(
              labelText: context.tr('password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => value == null || value.isEmpty
                ? context.tr('requiredPassword')
                : null,
          ),
          if (widget.controller.error != null) ...[
            const SizedBox(height: 12),
            Text(
              context.trError(widget.controller.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => FilledButton(
              onPressed: widget.controller.syncing ? null : submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: widget.controller.syncing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('login')),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _date(DateTime value) => DateFormat('dd.MM.yyyy').format(value);
String _percent(BuildContext context, double value) =>
    NumberFormat.decimalPercentPattern(
      locale: Localizations.localeOf(context).toLanguageTag(),
      decimalDigits: 1,
    ).format(value / 100);
String _shortWeekday(BuildContext context, DateTime value) => _capitalize(
  DateFormat.E(Localizations.localeOf(context).toLanguageTag())
      .format(value)
      .replaceAll('.', ''),
);
String _capitalize(String value) => value.isEmpty
    ? value
    : '${value.characters.first.toUpperCase()}${value.substring(value.characters.first.length)}';
