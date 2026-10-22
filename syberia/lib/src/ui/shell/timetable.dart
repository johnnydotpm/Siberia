part of '../app_shell.dart';

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
        padding: const EdgeInsets.fromLTRB(_Space.sheet, 0, _Space.sheet, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('timetableStyle'),
              style: _sheetTitleStyle(context),
            ),
            const SizedBox(height: 12),
            SegmentedButton<TimetableView>(
              key: const ValueKey('settings-timetable-style'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: TimetableView.timeline,
                  label: Text(context.tr('timetableStyleClassic')),
                  icon: const Icon(Icons.view_timeline_rounded),
                ),
                ButtonSegment(
                  value: TimetableView.list,
                  label: Text(context.tr('timetableStyleCompact')),
                  icon: const Icon(Icons.view_agenda_rounded),
                ),
              ],
              selected: {controller.timetableView},
              onSelectionChanged: (selection) {
                HapticFeedback.selectionClick();
                controller.setTimetableView(selection.first);
              },
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

  /// The pages are days, counted from [_anchor] at page [_anchorPage]:
  /// weekdays, and weekend days with lessons, as in the strip.
  static const _anchorPage = 100000;
  DateTime _anchor = DateTime(2000);
  Set<DateTime> _weekendDays = const {};
  PageController? _pages;

  /// Changes with the anchor, for pages counted afresh.
  int _generation = 0;

  /// While the pages move to a day picked in the strip, the days they pass
  /// are not picked on the way.
  bool _moving = false;

  /// Which way the last change of week went: 1 later, -1 earlier.
  int _weekStep = 1;

  /// Weeks, by their Monday, on their way, and those that came back with
  /// no lessons, as in the holidays. A week with lessons is known by them,
  /// so one a sync leaves out is loaded again.
  final _loadingWeeks = <DateTime>{};
  final _emptyWeeks = <DateTime>{};

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
    _pages?.dispose();
    super.dispose();
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTime _mondayOf(DateTime day) =>
      DateTime(day.year, day.month, day.day - day.weekday + 1);

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

  bool _schoolDay(DateTime day) =>
      day.weekday <= 5 || _weekendDays.contains(day);

  /// The next day of the strip after [day], or before it.
  DateTime _step(DateTime day, int step) {
    var next = day;
    do {
      next = DateTime(next.year, next.month, next.day + step);
    } while (!_schoolDay(next));
    return next;
  }

  DateTime _dayAt(int page) {
    final steps = page - _anchorPage;
    var day = _anchor;
    for (var index = 0; index < steps.abs(); index++) {
      day = _step(day, steps.sign);
    }
    return day;
  }

  int _pageOf(DateTime day) {
    var page = _anchorPage;
    if (day.isAfter(_anchor)) {
      var next = _step(_anchor, 1);
      while (!next.isAfter(day)) {
        page++;
        next = _step(next, 1);
      }
    } else {
      var next = _step(_anchor, -1);
      while (!next.isBefore(day)) {
        page--;
        next = _step(next, -1);
      }
    }
    return page;
  }

  /// Counts the pages from [day] afresh, which shows it at once.
  void _anchorAt(DateTime day) {
    final old = _pages;
    _anchor = day;
    _pages = PageController(initialPage: _anchorPage);
    _generation++;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  /// Picks [day], noting which way the week went for the strip.
  void _select(DateTime day) {
    final before = selectedDay;
    if (before != null && _mondayOf(before) != _mondayOf(day)) {
      _weekStep = day.isAfter(before) ? 1 : -1;
    }
    selectedDay = day;
  }

  /// A day swiped to.
  void _pageChanged(int page) {
    if (_moving) return;
    final day = _dayAt(page);
    setState(() => _select(day));
    _loadWeekOf(day);
  }

  /// Loads the week of [day] when nothing of it is here yet, as when the
  /// days are swiped back past Monday.
  Future<void> _loadWeekOf(DateTime day) async {
    final monday = _mondayOf(day);
    final weekEnd = DateTime(monday.year, monday.month, monday.day + 7);
    if (_loadingWeeks.contains(monday) || _emptyWeeks.contains(monday)) {
      return;
    }
    final known = widget.controller.snapshot.lessons.any(
      (lesson) =>
          !lesson.start.isBefore(monday) && lesson.start.isBefore(weekEnd),
    );
    if (known) return;
    setState(() => _loadingWeeks.add(monday));
    try {
      final lessons = await widget.controller.fetchTimetableWeek(monday);
      if (lessons.isEmpty) _emptyWeeks.add(monday);
    } on Object {
      if (mounted && _mondayOf(selectedDay!) == monday) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('timetableLoadFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingWeeks.remove(monday));
    }
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
    final week = _mondayOf(_day(picked));
    setState(() {
      _select(_day(picked));
      _anchorAt(_day(picked));
      loading = true;
      _loadingWeeks.add(week);
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
        final day = _nearestDayWithLessons(picked, availableDays);
        if (day != selectedDay) {
          setState(() {
            _select(day);
            _anchorAt(day);
          });
        }
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('timetableLoadFailed'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          _loadingWeeks.remove(week);
        });
      }
    }
  }

  void _selectFromStrip(DateTime requested, Iterable<DateTime> lessonDays) {
    HapticFeedback.selectionClick();
    _goTo(_nearestDayWithLessons(requested, lessonDays));
  }

  /// Slides the pages to [day], or shows it at once when it is far.
  Future<void> _goTo(DateTime day) async {
    final pages = _pages;
    setState(() => _select(day));
    if (pages == null || !pages.hasClients) return;
    final from = pages.page?.round() ?? _anchorPage;
    final to = _pageOf(day);
    if (to == from) return;
    if ((to - from).abs() > 5 || _reduceMotion(context)) {
      setState(() => _anchorAt(day));
      return;
    }
    _moving = true;
    try {
      await pages.animateToPage(
        to,
        duration: _Motion.page,
        curve: Curves.easeOutCubic,
      );
    } finally {
      _moving = false;
    }
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
    final weekendDays = {
      for (final day in groups.keys)
        if (day.weekday > 5) day,
    };
    // Days come in as weeks load; with a weekend day among them, the pages
    // are counted afresh from the day on screen.
    if (_pages == null || !setEquals(weekendDays, _weekendDays)) {
      _weekendDays = weekendDays;
      _anchorAt(selectedDay!);
    }
    final monday = _mondayOf(selectedDay!);
    final days = List.generate(5, (index) => monday.add(Duration(days: index)));
    final weekEnd = monday.add(const Duration(days: 7));
    for (final day in groups.keys.where(
      (day) =>
          day.weekday > 5 && !day.isBefore(monday) && day.isBefore(weekEnd),
    )) {
      if (!days.any((item) => _sameDay(item, day))) days.add(day);
    }
    final eventDays = {
      for (final event in widget.controller.snapshot.events) _day(event.date),
    };
    final today = _day(now);
    final insets = _chromeInsets(context);
    final strip = Row(
      key: ValueKey(monday),
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
    );
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
                // Another week slides in from the side it lies on.
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: _Motion.page,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) {
                      final incoming = child.key == ValueKey(monday);
                      final from = (incoming ? _weekStep : -_weekStep)
                          .toDouble();
                      return SlideTransition(
                        position: Tween(
                          begin: Offset(from, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      );
                    },
                    layoutBuilder: (current, previous) =>
                        Stack(children: [...previous, ?current]),
                    child: strip,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          // Days swipe like pages, as in the Calendar of an iPhone.
          child: ClipRect(
            child: PageView.builder(
              key: ValueKey(_generation),
              controller: _pages,
              onPageChanged: _pageChanged,
              itemBuilder: (context, page) =>
                  _dayPage(context, _dayAt(page), groups, now),
            ),
          ),
        ),
      ],
    );
  }

  /// One day: its date, and its lessons under it.
  Widget _dayPage(
    BuildContext context,
    DateTime day,
    Map<DateTime, List<Lesson>> groups,
    DateTime now,
  ) {
    final controller = widget.controller;
    final lessons = groups[day] ?? const <Lesson>[];
    final dayEvents = controller.snapshot.events
        .where(
          (event) => event.kind == EventKind.exam && _sameDay(event.date, day),
        )
        .toList(growable: false);
    final dayOff = _freeDayOn(controller.snapshot.freeDays, day);
    final mergeLessons = controller.mergeTimetableLessons;
    final showBreaks = controller.showTimetableBreaks;
    final placed = _placeTests(
      _lessonBlocks(lessons, merge: mergeLessons),
      dayEvents,
    );
    final view = controller.timetableView;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final title = _capitalize(
      (day.year == now.year
              ? DateFormat.MMMMEEEEd(locale)
              : DateFormat.yMMMMEEEEd(locale))
          .format(day),
    );
    final insets = _chromeInsets(context);
    final waiting = lessons.isEmpty && _loadingWeeks.contains(_mondayOf(day));
    return _TimetableDay(
      key: ValueKey(day),
      title: title,
      // Today opens at the lesson on now, or the next one.
      focus: _sameDay(day, now),
      padding: lessons.isEmpty
          ? EdgeInsets.fromLTRB(16, 0, 16, 24 + insets.bottom)
          : EdgeInsets.fromLTRB(12, 4, 16, 24 + insets.bottom),
      builder: (context, focusKey) => lessons.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (waiting)
                  const _LessonsSkeleton(key: ValueKey('timetable-loading'))
                else ...[
                  // A holiday says so, instead of "No data".
                  if (dayOff != null) ...[
                    _FreeDayCard(dayOff),
                    const SizedBox(height: 8),
                  ],
                  for (final event in dayEvents) ...[
                    _EventTile(event),
                    const SizedBox(height: 8),
                  ],
                  if (dayEvents.isEmpty && dayOff == null)
                    _Empty(
                      context.tr('emptyDay'),
                      icon: Icons.free_breakfast_rounded,
                    ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Some lessons off for the class.
                if (dayOff != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: _FreeDayCard(dayOff),
                  ),
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
                          focusKey: focusKey,
                        )
                      : _TimetableList(
                          lessons,
                          mergeLessons: mergeLessons,
                          showBreaks: showBreaks,
                          focusKey: focusKey,
                        ),
                ),
              ],
            ),
    );
  }
}

/// A page of the timetable: the date, and the day under it, which scrolls
/// only when it does not fit. With [focus], it opens at the lesson on now
/// or the next one, with a little of the one before above it.
class _TimetableDay extends StatefulWidget {
  const _TimetableDay({
    required this.title,
    required this.padding,
    required this.builder,
    this.focus = false,
    super.key,
  });

  final String title;
  final EdgeInsets padding;
  final bool focus;

  /// The day's content; the lesson to open at takes the key.
  final Widget Function(BuildContext context, GlobalKey focusKey) builder;

  @override
  State<_TimetableDay> createState() => _TimetableDayState();
}

class _TimetableDayState extends State<_TimetableDay> {
  final _scroll = ScrollController();
  final _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reveal() {
    final box = _focusKey.currentContext?.findRenderObject();
    if (!mounted || box == null || !_scroll.hasClients) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = _scroll.position;
    final top = viewport.getOffsetToReveal(box, 0).offset;
    final bottom = viewport.getOffsetToReveal(box, 1).offset;
    // Seen whole already.
    if (position.pixels <= top && position.pixels >= bottom) return;
    position.jumpTo(
      (top - 48).clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Text(
          widget.title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: widget.padding,
          child: widget.builder(context, _focusKey),
        ),
      ),
    ],
  );
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
/// An absent teacher is said to be.
String _blockDetails(BuildContext context, _LessonBlock block) {
  final lesson = block.lesson;
  final absent = _FreeDaysScope.absenceFor(context, lesson) != null;
  return [
    if (block.count > 1) _lessonCount(context, block.count),
    if (lesson.room.isNotEmpty) _room(context, lesson.room),
    if (absent && lesson.teacher.isNotEmpty)
      '${lesson.teacher} – ${context.tr('teacherAbsent')}'
    else
      lesson.teacher,
  ].where((value) => value.isNotEmpty).join(' · ');
}

/// "s. 101" in Polish, "каб. 101" in Russian.
String _room(BuildContext context, String room) =>
    '${context.tr('roomShort')} $room';

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
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    // The highlight moves from day to day, as in the Calendar.
    tween: Tween(end: selected ? 1 : 0),
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    builder: (context, picked, _) => _chip(context, picked),
  );

  /// The chip, [picked] of the way from plain to selected.
  Widget _chip(BuildContext context, double picked) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final plain = hasLessons
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final foreground = Color.lerp(plain, colors.onPrimary, picked)!;
    final border = today ? colors.primary : colors.outlineVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: colors.primary.withValues(alpha: picked),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: picked == 1
              ? BorderSide.none
              : BorderSide(
                  color: border.withValues(alpha: border.a * (1 - picked)),
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
                        : Color.lerp(colors.primary, colors.onPrimary, picked),
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
                    tooltip: localizations.previousMonthTooltip,
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
                    tooltip: localizations.nextMonthTooltip,
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
                    // Marked as in the strip of days above it.
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? colors.primary : null,
                        borderRadius: BorderRadius.circular(12),
                        border: today && !selected
                            ? Border.all(color: colors.primary, width: 1.5)
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              color: selected
                                  ? colors.onPrimary
                                  : enabled
                                  ? null
                                  : colors.onSurface.withValues(alpha: 0.38),
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
                                  color: selected
                                      ? colors.onPrimary
                                      : colors.primary,
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
