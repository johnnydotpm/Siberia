part of '../app_shell.dart';

/// The lesson to open a day at: the one on now, or else the next one.
_LessonBlock? _focusBlock(
  List<_LessonBlock> blocks,
  _LessonBlock? current,
  DateTime now,
) =>
    current ??
    blocks
        .where(
          (block) => !block.lesson.cancelled && block.lesson.start.isAfter(now),
        )
        .firstOrNull;

class _TimetableTimeline extends StatelessWidget {
  const _TimetableTimeline(
    this.lessons, {
    required this.mergeLessons,
    required this.showBreaks,
    this.focusKey,
  });
  final bool mergeLessons;
  final bool showBreaks;

  /// Given to the lesson on now, or else the next one, to open the day at.
  final GlobalKey? focusKey;

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
    final breaks = _breaksBetween(blocks);
    double offset(DateTime time) {
      var result = time.difference(axisStart).inSeconds / 60 * _pixelsPerMinute;
      if (showBreaks) {
        for (final gapBetween in breaks) {
          final end = gapBetween.before.lesson.end;
          final start = gapBetween.after.lesson.start;
          final gap = start.difference(end).inMilliseconds;
          if (!time.isAfter(end)) continue;
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
    bool isCurrent(_LessonBlock block) =>
        !block.lesson.cancelled &&
        !now.isBefore(block.lesson.start) &&
        now.isBefore(block.lesson.end);
    final focus = _focusBlock(blocks, current, now);
    final lanes = _timelineLanes(blocks);
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
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (index, block) in blocks.indexed) ...[
              // Lessons side by side share the rail of the first one; each
              // of them says its times itself.
              if (lanes[index].lane == 0)
                Positioned(
                  top: offset(block.lesson.start),
                  left: 0,
                  width: _axisWidth - 8,
                  height: blockHeight(block),
                  child: _TimelineRail(block),
                ),
              Positioned(
                top: offset(block.lesson.start),
                left: _laneLeft(constraints.maxWidth, lanes[index]),
                width: _laneWidth(constraints.maxWidth, lanes[index]),
                height: blockHeight(block),
                child: KeyedSubtree(
                  key: identical(block, focus) ? focusKey : null,
                  child: _TimelineLessonCard(
                    key: ValueKey('timeline-lesson-${block.lesson.id}'),
                    block: block,
                    hue: colors[block.lesson.subject] ?? 0,
                    current: isCurrent(block),
                    now: now,
                    showTimes: lanes[index].lanes > 1,
                  ),
                ),
              ),
            ],
            if (showBreaks)
              for (final gap in breaks)
                Positioned(
                  top: offset(gap.before.lesson.end),
                  height:
                      offset(gap.after.lesson.start) -
                      offset(gap.before.lesson.end),
                  left: _axisWidth,
                  right: 0,
                  child: Center(
                    child: _BreakLabel(
                      gap.after.lesson.start.difference(gap.before.lesson.end),
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
      ),
    );
  }

  /// The gap between cards side by side.
  static const _laneGap = 6.0;

  static double _laneWidth(double width, ({int lane, int lanes}) place) =>
      (width - _axisWidth - _laneGap * (place.lanes - 1)) / place.lanes;

  static double _laneLeft(double width, ({int lane, int lanes}) place) =>
      _axisWidth + place.lane * (_laneWidth(width, place) + _laneGap);

  _TimetableBreak? _currentBreak(List<_LessonBlock> blocks, DateTime now) {
    final active = blocks.where((block) => !block.lesson.cancelled).toList();
    for (final gap in _breaksBetween(active)) {
      if (!now.isBefore(gap.before.lesson.end) &&
          now.isBefore(gap.after.lesson.start)) {
        return gap;
      }
    }
    return null;
  }
}

/// The breaks of a day of [blocks] in order of their start: from the end of
/// all the lessons before to the next lesson. With lessons of two schools
/// at once, the one ending last ends the time before a break.
List<_TimetableBreak> _breaksBetween(List<_LessonBlock> blocks) {
  final breaks = <_TimetableBreak>[];
  _LessonBlock? latest;
  for (final block in blocks) {
    if (latest != null && block.lesson.start.isAfter(latest.lesson.end)) {
      breaks.add(_TimetableBreak(before: latest, after: block));
    }
    if (latest == null || !block.lesson.end.isBefore(latest.lesson.end)) {
      latest = block;
    }
  }
  return breaks;
}

/// Where each of [blocks], in order of their start, stands across the day:
/// lessons at the same time, as two schools' in the view together, stand
/// side by side, each in a lane of the lanes of their group.
List<({int lane, int lanes})> _timelineLanes(List<_LessonBlock> blocks) {
  final lanes = List.filled(blocks.length, (lane: 0, lanes: 1));
  var group = <int>[];
  var laneEnds = <DateTime>[];
  DateTime? groupEnd;
  void closeGroup() {
    for (final index in group) {
      lanes[index] = (lane: lanes[index].lane, lanes: laneEnds.length);
    }
    group = [];
    laneEnds = [];
    groupEnd = null;
  }

  for (final (index, block) in blocks.indexed) {
    final start = block.lesson.start;
    final end = block.lesson.end;
    if (groupEnd case final until? when !start.isBefore(until)) closeGroup();
    var lane = laneEnds.indexWhere((laneEnd) => !start.isBefore(laneEnd));
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(end);
    } else {
      laneEnds[lane] = end;
    }
    lanes[index] = (lane: lane, lanes: 1);
    group.add(index);
    if (groupEnd case final until? when !end.isAfter(until)) continue;
    groupEnd = end;
  }
  closeGroup();
  return lanes;
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
        // Times line up down the rail, digit under digit.
        Text(
          _time(block.lesson.start),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: _tabular,
          ),
        ),
        if (showEnd)
          Text(
            _time(block.lesson.end),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: _tabular,
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
    this.showTimes = false,
  });

  final _LessonBlock block;
  final int hue;
  final bool current;
  final DateTime now;

  /// Its times in its details, beside another lesson at the same time,
  /// whose rail it shares.
  final bool showTimes;

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
    final details = [
      if (showTimes) '${_time(lesson.start)}–${_time(lesson.end)}',
      _blockDetails(context, block),
    ].where((part) => part.isNotEmpty).join(' · ');
    final marked =
        _ControllerScope.maybeOf(context)?.profileMark(lesson.source) != null;
    // No layer of its own for a lesson that is on.
    return _LightOpacity(
      opacity: lesson.cancelled ? 0.55 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showLessonDetails(context, block),
        child: Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(14),
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
              // As the text is drawn: over the page's text style, whose
              // line height the lines without one of their own take.
              final base = DefaultTextStyle.of(context).style;
              double lineHeight(TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(text: 'Ag', style: base.merge(style)),
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
                fontFeatures: _tabular,
              );
              final room = constraints.maxHeight;
              final subjectLine = lineHeight(subjectStyle);
              // A test's label beside the subject may stand taller than it:
              // 1 above it, 2 above and below its text or icon.
              final firstLine = tests.isEmpty
                  ? subjectLine
                  : math.max(
                      subjectLine,
                      5 +
                          math.max(
                            13.0,
                            lineHeight(
                              const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                    );
              final detailsHeight = 2 + lineHeight(detailsStyle);
              final progressHeight = current
                  ? 3 + math.max(4, lineHeight(progressStyle) + 2)
                  : 0;
              // Beside another lesson the card is narrow: the mark takes a
              // line of its own when there is room, so the times stay whole.
              // 3 above the mark and 1 above and below its name.
              final markHeight =
                  5 +
                  lineHeight(
                    Theme.of(context).textTheme.labelSmall!
                        .copyWith(fontWeight: FontWeight.w800, height: 1.35),
                  );
              final markLine =
                  marked &&
                  showTimes &&
                  room >=
                      firstLine + markHeight + detailsHeight + progressHeight;
              final showDetails =
                  (details.isNotEmpty || marked) &&
                  room >= firstLine + detailsHeight + progressHeight;
              final reserved =
                  (showDetails ? detailsHeight : 0) +
                  (markLine ? markHeight : 0) +
                  progressHeight;
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
                      // In a narrow card beside another lesson, the test's
                      // label gives way as the subject does.
                      if (tests.isNotEmpty)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6, top: 1),
                            child: _TestPill(tests),
                          ),
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
                  if (markLine)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _ProfileMark(lesson.source),
                    ),
                  if (showDetails)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          // A long name gives way to the room and teacher.
                          if (marked && !markLine) ...[
                            Flexible(child: _ProfileMark(lesson.source)),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            flex: 2,
                            child: Text(
                              details,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: detailsStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (current) ...[
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          // Glides as the lesson goes on, to the second.
                          child: _GlidingProgress(
                            value: duration.inSeconds <= 0
                                ? 0
                                : (now.difference(lesson.start).inSeconds /
                                          duration.inSeconds)
                                      .clamp(0.0, 1.0),
                            minHeight: 4,
                            radius: 3,
                            color: palette.accent,
                            backgroundColor: foreground.withValues(alpha: 0.15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Long words or large text cut it short rather than
                        // push the badge out of the card; the bar keeps the
                        // rest.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.55,
                          ),
                          child: Text(
                            context.trArgs('lessonProgress', {
                              'elapsed': '$elapsed',
                              'total': '${duration.inMinutes}',
                            }),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: progressStyle,
                          ),
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
    this.focusKey,
  });
  final bool mergeLessons;
  final bool showBreaks;

  /// Given to the lesson on now, or else the next one, to open the day at.
  final GlobalKey? focusKey;
  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    final blocks = _lessonBlocks(lessons, merge: mergeLessons);
    final now = DateTime.now();
    final current = _currentBlock(blocks, now);
    final focus = _focusBlock(blocks, current, now);
    final colors = _SubjectScope.colorsOf(context)
        .forDay(blocks.map((block) => block.lesson.subject));
    // A break comes before a lesson that starts after every one before it
    // has ended, lessons of two schools at once included.
    final breakBefore = {
      for (final gap in _breaksBetween(blocks)) gap.after: gap,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0)
            if (breakBefore[blocks[index]] case final gap? when showBreaks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _BreakLabel(
                        gap.after.lesson.start.difference(
                          gap.before.lesson.end,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              )
            else
              const SizedBox(height: 4),
          KeyedSubtree(
            key: identical(blocks[index], focus) ? focusKey : null,
            child: _TimetableRow(
              key: ValueKey('timetable-row-${blocks[index].lesson.id}'),
              block: blocks[index],
              hue: colors[blocks[index].lesson.subject] ?? 0,
              current:
                  identical(blocks[index], current) ||
                  (!blocks[index].lesson.cancelled &&
                      !now.isBefore(blocks[index].lesson.start) &&
                      now.isBefore(blocks[index].lesson.end)),
              now: now,
            ),
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
    // No layer of its own for a lesson that is on.
    return _LightOpacity(
      opacity: lesson.cancelled ? 0.55 : 1,
      child: Material(
        color: current
            ? palette.background.withValues(alpha: 0.6)
            // The cards' colour, as on every other page.
            : theme.cardTheme.color ?? theme.colorScheme.surface,
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
                          fontFeatures: _tabular,
                        ),
                      ),
                      Text(
                        _time(lesson.end),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          fontFeatures: _tabular,
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
                      _MarkedTitle(
                        Text(
                          _SubjectScope.of(context, lesson.subject),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _rowTitleStyle(context)?.copyWith(
                            decoration: lesson.cancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        lesson.source,
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

void _showLessonDetails(BuildContext context, _LessonBlock block) {
  final lesson = block.lesson;
  final tests = _DayTests.of(context, block);
  final controller = _ControllerScope.maybeOf(context);
  final screen = MediaQuery.sizeOf(context);
  final details = [
    if (block.count > 1) _lessonCount(context, block.count),
    lesson.teacher,
    if (lesson.room.isNotEmpty) _room(context, lesson.room),
  ].where((value) => value.isNotEmpty).join(' · ');
  final absence = _FreeDaysScope.absenceFor(context, lesson);
  String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
  final absenceDetails = absence == null
      ? ''
      : [
          if (absence.name.isNotEmpty) _capitalize(absence.name),
          if (absence.timeFrom != null && absence.timeTo != null)
            '${clock(absence.timeFrom!)}–${clock(absence.timeTo!)}',
        ].join(' · ');
  // Scrolls when the tests' descriptions are long, like the homework sheet.
  showAppSheet<void>(
    context: context,
    compact: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      minWidth: screen.width,
      maxWidth: screen.width,
      maxHeight: screen.height * 0.85,
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('lesson-details-sheet'),
        padding: const EdgeInsets.fromLTRB(_Space.sheet, 4, _Space.sheet, 24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller != null)
                _SheetProfileMark(controller, lesson.source),
              Text(
                displaySubject(lesson.subject, const {}),
                style: _sheetTitleStyle(context),
              ),
              const SizedBox(height: 10),
              Text('${_time(lesson.start)}–${_time(lesson.end)}'),
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
                            if (lesson.originalSubject.isNotEmpty)
                              _SubjectScope.of(context, lesson.originalSubject),
                            lesson.originalTeacher,
                            if (lesson.originalRoom.isNotEmpty)
                              _room(context, lesson.originalRoom),
                          ].where((value) => value.isNotEmpty).join(' · '),
                        }),
                ),
              ],
              if (absence != null) ...[
                const SizedBox(height: 14),
                Row(
                  key: const ValueKey('lesson-teacher-absent'),
                  children: [
                    Icon(
                      Icons.person_off_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('teacherAbsence'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                if (absenceDetails.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(absenceDetails),
                ],
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
