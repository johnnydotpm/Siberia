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
    if (lesson.room.isNotEmpty) _room(context, lesson.room),
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
