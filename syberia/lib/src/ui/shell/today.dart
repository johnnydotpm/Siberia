part of '../app_shell.dart';

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
        lessons.any((lesson) => !lesson.cancelled && lesson.end.isAfter(now)) ||
        _lastLookAheadDay == today) {
      return;
    }
    _lookingAhead = true;
    _lastLookAheadDay = today;
    // Calendar days, not 24-hour steps: across a clock change a Duration
    // would land on the Sunday before and fetch the week that just ended.
    var monday = DateTime(
      today.year,
      today.month,
      today.day + 8 - today.weekday,
    );
    try {
      for (var attempt = 0; attempt < 4; attempt++) {
        await widget.controller.fetchTimetableWeek(monday);
        if (!mounted ||
            widget.controller.snapshot.lessons.any(
              (lesson) => !lesson.cancelled && lesson.end.isAfter(now),
            )) {
          break;
        }
        monday = DateTime(monday.year, monday.month, monday.day + 7);
      }
    } on Object {
      // The existing timetable stays visible while a later week is unavailable.
    } finally {
      _lookingAhead = false;
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
        padding: const EdgeInsets.all(_Space.page),
        children: [
          if (controller.updateAvailable) ...[
            _UpdateBanner(controller),
            const SizedBox(height: _Space.card),
          ],
          Text(
            _capitalize(DateFormat.MMMMEEEEd(locale).format(now)),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (controller.snapshot.lastSync.millisecondsSinceEpoch != 0)
            _LastSync(controller, now: now),
          const SizedBox(height: _Space.card),
          if (controller.error != null) ...[
            _InfoCard(
              icon: Icons.error_outline_rounded,
              text: context.trError(controller.error!),
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: _Space.card),
          ],
          for (final (index, block) in blocks.indexed) ...[
            if (index > 0) const SizedBox(height: _Space.section),
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
        const SizedBox(height: _Space.heading),
        child,
      ],
    );
    Widget spaced(Iterable<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const SizedBox(height: _Space.item),
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
      case TodayBlock.freeDays:
        final next = _nextFreeDays(data.freeDays, now);
        if (next == null) return null;
        return KeyedSubtree(
          key: const ValueKey('today-free-days'),
          child: _FreeDayCard(next, now: now),
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
                      !item.date.isBefore(today) &&
                      // Done is off the list of what is to do.
                      !controller.isHomeworkDone(item),
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
          spaced(
            unread
                .take(2)
                .map(
                  (item) => _MessageTile(
                    controller,
                    item,
                    style: MessageListStyle.cards,
                    now: now,
                  ),
                ),
          ),
          key: const ValueKey('today-messages'),
        );
    }
  }
}

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

/// What is on now and what comes next, or when lessons start again.
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
      return _InfoCard(
        key: const ValueKey('today-now-card'),
        icon: Icons.free_breakfast_rounded,
        text: context.tr('todayNoUpcoming'),
        color: theme.colorScheme.onSurfaceVariant,
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
      // The big subject below is that day's first lesson, not today's.
      when =
          '$dayName, ${_shortDate(context, day)} · '
          '${context.tr('todayFirstLesson')}';
    }

    // The line at the bottom: what follows.
    String? footer;
    if (current != null) {
      final next = laterToday.firstOrNull;
      footer = next == null
          ? context.tr('todayLastLesson')
          : '${context.tr('todayNext')} · ${_time(next.lesson.start)} '
                '${_SubjectScope.of(context, next.lesson.subject)}'
                '${next.lesson.room.isEmpty ? '' : ' · ${_room(context, next.lesson.room)}'}';
    } else if (!sameDay) {
      final thatDay = upcoming.where(
        (block) => _sameDay(block.lesson.start, lesson.start),
      );
      footer = context.trArgs('todayDayLessons', {
        'lessons': _lessonCount(
          context,
          thatDay.fold(0, (sum, block) => sum + block.count),
        ),
        'time': _time(thatDay.last.lesson.end),
      });
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
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.selectTab(1),
        child: Padding(
          padding: const EdgeInsets.all(_Space.inset),
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
                    // All the room the time leaves: beside a Spacer it
                    // got only half of it, and "Next lesson" broke in two.
                    Expanded(
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
                    if (current != null) const Spacer(),
                    const SizedBox(width: 8),
                    Text(
                      when,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontFeatures: _tabular,
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
                        fontFeatures: _tabular,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    // One width for all, growing with the text so long words stay whole.
    final width = MediaQuery.textScalerOf(context).scale(84).clamp(84.0, 120.0);
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        // Every grade as tall as the tallest, so the dates line up.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final grade in grades)
                InkWell(
                  key: ValueKey('recent-grade-${grade.id}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showGradeDetails(context, grade),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          // All of them are recent: a "new" dot says nothing.
                          _GradeChip(
                            grade,
                            settings: settings,
                            size: 44,
                            showNew: false,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _SubjectScope.of(context, grade.subject),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 2),
                          Text(
                            _gradeWhen(context, grade.date, now),
                            key: ValueKey('recent-grade-when-${grade.id}'),
                            maxLines: 1,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today", "Yesterday", the weekday within a week, then the date.
String _gradeWhen(BuildContext context, DateTime date, DateTime now) {
  final days = _daysBetween(date, now);
  if (days <= 0) return context.tr('messagesToday');
  if (days == 1) return context.tr('messagesYesterday');
  if (days < 7) return _shortWeekday(context, date);
  return _shortDate(context, date);
}

/// "Updated at 17:05" under the date; a tap syncs again.
class _LastSync extends StatelessWidget {
  const _LastSync(this.controller, {required this.now});
  final AppController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final last = controller.snapshot.lastSync;
    final text = controller.syncing
        ? context.tr('todayUpdating')
        : _sameDay(last, now)
        ? context.trArgs('todayUpdatedAt', {'time': _time(last)})
        : context.trArgs('todayUpdatedOn', {
            'date': '${_shortDate(context, last)}, ${_time(last)}',
          });
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        key: const ValueKey('today-last-sync'),
        borderRadius: BorderRadius.circular(8),
        onTap: controller.syncing ? null : controller.sync,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          // The rows' own 16 makes the sheet's 20.
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('todayScreen'),
                        style: _sheetTitleStyle(context),
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
              // Scrolls only when the sheet does not fit, as in landscape.
              Flexible(
                child: ReorderableListView(
                  shrinkWrap: true,
                  // Not always scrollable: while the rows fit, a drag on
                  // them still moves the sheet.
                  primary: false,
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
                        trailing: Switch.adaptive(
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
  TodayBlock.freeDays => 'freeDays',
  TodayBlock.summary => 'todayBlockSummary',
  TodayBlock.grades => 'todayRecentGrades',
  TodayBlock.homework => 'homework',
  TodayBlock.events => 'todayExams',
  TodayBlock.messages => 'todayUnreadMessages',
};

IconData _todayBlockIcon(TodayBlock block) => switch (block) {
  TodayBlock.currentLesson => Icons.schedule_rounded,
  TodayBlock.freeDays => Icons.beach_access_rounded,
  TodayBlock.summary => Icons.dashboard_rounded,
  TodayBlock.grades => Icons.school_rounded,
  TodayBlock.homework => Icons.assignment_rounded,
  TodayBlock.events => Icons.event_note_rounded,
  TodayBlock.messages => Icons.mail_rounded,
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
    // The card's corner less its padding, so the two curves follow.
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
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
