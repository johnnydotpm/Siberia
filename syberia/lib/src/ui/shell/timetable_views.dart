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

  /// The axis at the usual text size: the rail of numbers and times, and
  /// the room that keeps it apart from the cards.
  static const _axisWidth = 62.0;
  static const _railGap = 12.0;

  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    final blocks = _lessonBlocks(lessons, merge: mergeLessons);
    final breaks = _breaksBetween(blocks);
    final now = DateTime.now();
    final current = _currentBlock(blocks, now);
    final focus = _focusBlock(blocks, current, now);
    final lanes = _timelineLanes(blocks);
    // The break on now says so, in place of a line across the day; it has
    // its label even when the others are hidden.
    final currentBreak = current == null
        ? breaks
              .where(
                (gap) =>
                    !now.isBefore(gap.before.lesson.end) &&
                    now.isBefore(gap.after.lesson.start),
              )
              .firstOrNull
        : null;
    final geometry = _TimelineGeometry.of(
      context,
      blocks,
      breaks: breaks,
      labelled: (gap) => showBreaks || identical(gap, currentBreak),
    );
    // Large text widens the rail, so a time stays on one line.
    final railWidth = _TimelineRail.widthFor(context);
    final axisWidth = railWidth + _railGap;
    final colors = _SubjectScope.colorsOf(context)
        .forDay(blocks.map((block) => block.lesson.subject));
    // Only today: the lessons already over step back, so the eye finds now.
    final past = Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.55;
    // Lessons of two schools at once may both be on.
    bool isCurrent(_LessonBlock block) =>
        !block.lesson.cancelled &&
        !now.isBefore(block.lesson.start) &&
        now.isBefore(block.lesson.end);
    bool over(_LessonBlock block) =>
        _sameDay(block.lesson.start, now) && !block.lesson.end.isAfter(now);

    return SizedBox(
      height: geometry.height,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (index, block) in blocks.indexed) ...[
              // Lessons side by side share the rail of the first one; each
              // of them says its times itself.
              if (lanes[index].lane == 0)
                Positioned(
                  top: geometry.top(block),
                  left: 0,
                  width: railWidth,
                  height: geometry.blockHeight(block),
                  child: _LightOpacity(
                    opacity: over(block) ? past : 1,
                    child: _TimelineRail(block, width: railWidth),
                  ),
                ),
              Positioned(
                top: geometry.top(block),
                left: _laneLeft(axisWidth, constraints.maxWidth, lanes[index]),
                width: _laneWidth(
                  axisWidth,
                  constraints.maxWidth,
                  lanes[index],
                ),
                height: geometry.blockHeight(block),
                child: KeyedSubtree(
                  key: identical(block, focus) ? focusKey : null,
                  child: _TimelineLessonCard(
                    key: ValueKey('timeline-lesson-${block.lesson.id}'),
                    block: block,
                    hue: colors[block.lesson.subject] ?? 0,
                    current: isCurrent(block),
                    over: over(block),
                    now: now,
                    showTimes: lanes[index].lanes > 1,
                  ),
                ),
              ),
            ],
            for (final gap in breaks)
              if (geometry.labelled(gap))
                Positioned(
                  top: geometry.offset(gap.before.lesson.end),
                  height:
                      geometry.offset(gap.after.lesson.start) -
                      geometry.offset(gap.before.lesson.end),
                  left: axisWidth,
                  right: 0,
                  child: Center(
                    child: _BreakLabel(
                      gap.after.lesson.start.difference(gap.before.lesson.end),
                      left: identical(gap, currentBreak)
                          ? gap.after.lesson.start.difference(now)
                          : null,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// The gap between cards side by side.
  static const _laneGap = 6.0;

  static double _laneWidth(
    double axis,
    double width,
    ({int lane, int lanes}) place,
  ) => (width - axis - _laneGap * (place.lanes - 1)) / place.lanes;

  static double _laneLeft(
    double axis,
    double width,
    ({int lane, int lanes}) place,
  ) => axis + place.lane * (_laneWidth(axis, width, place) + _laneGap);
}

/// Where the lessons and breaks of a day stand down the timeline: a minute
/// is [perMinute] high, and a break with a label is at least tall enough
/// for it.
class _TimelineGeometry {
  _TimelineGeometry._({
    required this.start,
    required this.end,
    required this.timeScale,
    required this.breaks,
    required this.breakHeight,
    required this.labelled,
  });

  factory _TimelineGeometry.of(
    BuildContext context,
    List<_LessonBlock> blocks, {
    required List<_TimetableBreak> breaks,
    required bool Function(_TimetableBreak gap) labelled,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    return _TimelineGeometry._(
      start: blocks.first.lesson.start,
      end: blocks
          .map((block) => block.lesson.end)
          .reduce((left, right) => left.isAfter(right) ? left : right),
      // Measured at the subject's size, as Android's larger text grows
      // large letters less than small ones.
      timeScale: (scaler.scale(15) / 15).clamp(1.0, maxTimeScale),
      breaks: breaks,
      breakHeight: math.max(30.0, scaler.scale(12) * 1.5 + 8),
      labelled: labelled,
    );
  }

  static const pixelsPerMinute = 1.75;

  /// Lessons grow with the system text size up to twice as tall, so larger
  /// text keeps every line; beyond that the cards leave lines out.
  static const maxTimeScale = 2.0;

  final DateTime start;
  final DateTime end;
  final double timeScale;
  final List<_TimetableBreak> breaks;
  final double breakHeight;

  /// Whether a break has its label, and with it room for one.
  final bool Function(_TimetableBreak gap) labelled;

  double get perMinute => pixelsPerMinute * timeScale;

  double get height => math.max(60.0, offset(end));

  double offset(DateTime time) {
    var result = time.difference(start).inSeconds / 60 * perMinute;
    for (final gapBetween in breaks) {
      if (!labelled(gapBetween)) continue;
      final before = gapBetween.before.lesson.end;
      final after = gapBetween.after.lesson.start;
      final gap = after.difference(before).inMilliseconds;
      if (!time.isAfter(before)) continue;
      final extra = math.max(0.0, breakHeight - gap / 60000 * perMinute);
      result +=
          extra *
          (time.difference(before).inMilliseconds / gap).clamp(0.0, 1.0);
    }
    return result;
  }

  double top(_LessonBlock block) => offset(block.lesson.start);

  /// A little air keeps back-to-back lessons apart.
  double blockHeight(_LessonBlock block) => math.max(
    34 * timeScale,
    offset(block.lesson.end) - offset(block.lesson.start) - 4,
  );
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

/// The height a line of [style] takes as drawn: over the page's text style,
/// whose line height lines without one of their own take, at the system
/// text size.
double _lineHeight(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: 'Ag',
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// How wide [text] stands in [style] at the system text size.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The room inside a lesson card around its text.
const _cardPadding = EdgeInsets.fromLTRB(12, 9, 12, 7);

/// The subject on a lesson card; the rail lines up with its first line.
TextStyle _cardSubjectStyle(Color color, {bool cancelled = false}) => TextStyle(
  color: color,
  fontSize: 15.5,
  height: 1.15,
  fontWeight: FontWeight.w600,
  decoration: cancelled ? TextDecoration.lineThrough : null,
  decorationColor: color,
);

/// The lesson number and its times beside its card, down the middle of the
/// rail: the number level with the subject, then the start, a short tick
/// and the end.
class _TimelineRail extends StatelessWidget {
  const _TimelineRail(this.block, {required this.width});
  final _LessonBlock block;

  /// As wide as a time at the system text size, and never narrower than
  /// the usual axis leaves.
  final double width;

  /// The width of the rail at the system text size.
  static double widthFor(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: '00:00',
        style: DefaultTextStyle.of(context).style
            .merge(_startStyle(Theme.of(context).colorScheme)),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return math.max(
      _TimetableTimeline._axisWidth - _TimetableTimeline._railGap,
      (width + 6).ceilToDouble(),
    );
  }

  static TextStyle _startStyle(ColorScheme colors) => TextStyle(
    color: colors.onSurface,
    fontSize: 15,
    height: 1.15,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  static const _numberHeight = 20.0;
  static const _numberGap = 4.0;
  static const _tick = 6.0;
  static const _tickGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final numberStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 11.5,
      height: 1.2,
      fontWeight: FontWeight.w700,
    );
    final startStyle = _startStyle(colors);
    final endStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 12.5,
      height: 1.2,
      fontWeight: FontWeight.w500,
      fontFeatures: _tabular,
    );
    final subjectLine = _lineHeight(
      context,
      _cardSubjectStyle(colors.onSurface),
    );
    final startLine = _lineHeight(context, startStyle);
    final endHeight = _tick + _tickGap * 2 + _lineHeight(context, endStyle);
    final numberHeight = math.max(
      _numberHeight,
      _lineHeight(context, numberStyle) + 4,
    );
    final number = block.number;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A short lesson keeps only what fits: the number goes first, then
        // the end time.
        double topOf(double height) =>
            math.max(0, _cardPadding.top + (subjectLine - height) / 2);
        final room = constraints.maxHeight;
        final showEnd = room >= topOf(startLine) + startLine + endHeight;
        final showNumber =
            number != null &&
            showEnd &&
            room >=
                topOf(numberHeight) +
                    numberHeight +
                    _numberGap +
                    startLine +
                    endHeight;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: width),
            child: Padding(
              padding: EdgeInsets.only(
                top: topOf(showNumber ? numberHeight : startLine),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showNumber) ...[
                    Container(
                      key: const ValueKey('timeline-rail-number'),
                      height: numberHeight,
                      constraints: BoxConstraints(minWidth: numberHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(number, style: numberStyle),
                    ),
                    const SizedBox(height: _numberGap),
                  ],
                  // Times line up down the rail, digit under digit.
                  Text(_time(block.lesson.start), style: startStyle),
                  if (showEnd) ...[
                    Container(
                      width: 1.5,
                      height: _tick,
                      margin: const EdgeInsets.symmetric(vertical: _tickGap),
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Text(_time(block.lesson.end), style: endStyle),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Przerwa 5 min" quietly between lessons, a long break a little louder,
/// and the break on now in colour with the minutes it has left.
class _BreakLabel extends StatelessWidget {
  const _BreakLabel(this.length, {this.left});
  final Duration length;

  /// Until the next lesson, for the break on now.
  final Duration? left;

  /// From this long a break is a long one.
  static const longBreak = Duration(minutes: 15);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final long = length >= longBreak;
    final minutes = '${length.inMinutes}';
    final text = [
      context.trArgs(long ? 'lessonLongBreak' : 'lessonBreak', {
        'minutes': minutes,
      }),
      if (left case final left?)
        context.trArgs('timeLeftInline', {'minutes': '${_minutesLeft(left)}'}),
    ].join(' · ');
    return Text(
      text,
      key: left == null ? null : const ValueKey('timetable-current-break'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: left != null
            ? colors.primary
            : long
            ? colors.onSurfaceVariant
            : colors.onSurfaceVariant.withValues(alpha: 0.75),
        fontSize: long ? 12 : 11,
        fontWeight: left != null || long ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

/// Whole minutes left, rounded up: a minute and a bit is two.
int _minutesLeft(Duration left) => math.max(1, (left.inSeconds / 60).ceil());

/// The space between the subject and the line below it.
const _cardRowGap = 3.0;

/// The room, teacher and the rest under the subject: one neutral colour on
/// every subject's card, so the subject's own colour stays with its name.
TextStyle _cardDetailsStyle(Brightness brightness) => TextStyle(
  color: brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.84)
      : Colors.black.withValues(alpha: 0.7),
  fontSize: 12.5,
  height: 1.2,
  fontWeight: FontWeight.w500,
);

/// What a lesson card with [room] of height inside has room for.
///
/// The subject keeps two lines open, so the line below stands at the same
/// height on every card, short name or long; one line when two do not fit
/// with the line below; and the line below only under a whole line of the
/// subject. Beside another lesson the profile's mark takes a line of its
/// own when there is room, and joins the line below when there is not.
({int titleLines, double? titleHeight, bool row, bool markLine})
_lessonCardLayout({
  required double room,
  required double titleLine,
  required double rowLine,
  required double markLine,
  required bool hasRow,
  required bool ownMarkLine,
}) {
  if (hasRow) {
    final below = _cardRowGap + rowLine;
    final mark = ownMarkLine ? markLine : 0.0;
    if (room >= titleLine * 2 + mark + below) {
      return (
        titleLines: 2,
        titleHeight: titleLine * 2,
        row: true,
        markLine: ownMarkLine,
      );
    }
    if (room >= titleLine + mark + below) {
      return (
        titleLines: 1,
        titleHeight: titleLine,
        row: true,
        markLine: ownMarkLine,
      );
    }
    if (ownMarkLine && room >= titleLine + below) {
      return (
        titleLines: 1,
        titleHeight: titleLine,
        row: true,
        markLine: false,
      );
    }
  }
  return (
    titleLines: room >= titleLine * 2 ? 2 : 1,
    titleHeight: null,
    row: false,
    markLine: false,
  );
}

class _TimelineLessonCard extends StatelessWidget {
  const _TimelineLessonCard({
    super.key,
    required this.block,
    required this.hue,
    required this.current,
    required this.now,
    this.over = false,
    this.showTimes = false,
  });

  final _LessonBlock block;
  final int hue;
  final bool current;
  final DateTime now;

  /// Over already today: the card steps back.
  final bool over;

  /// Its times in its details, beside another lesson at the same time,
  /// whose rail it shares.
  final bool showTimes;

  @override
  Widget build(BuildContext context) {
    final lesson = block.lesson;
    final brightness = Theme.of(context).brightness;
    final palette = SubjectColors.colors(hue, brightness);
    final tests = _DayTests.of(context, block);
    final marked =
        _ControllerScope.maybeOf(context)?.profileMark(lesson.source) != null;
    final subjectStyle = _cardSubjectStyle(
      palette.foreground,
      cancelled: lesson.cancelled,
    );
    final hasRow =
        current ||
        marked ||
        lesson.substitution ||
        tests.isNotEmpty ||
        lesson.room.isNotEmpty ||
        lesson.teacher.isNotEmpty ||
        block.count > 1 ||
        showTimes;
    final radius = BorderRadius.circular(
      ExpressiveStyle.of(context) ? Corners.largeIncreased : 14,
    );
    // No layer of its own for a lesson that is on.
    return _LightOpacity(
      opacity: lesson.cancelled
          ? 0.55
          : over
          ? (brightness == Brightness.dark ? 0.5 : 0.55)
          : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showLessonDetails(context, block),
        child: Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: radius,
          ),
          // The lesson on now: a hairline drawn over the card, which takes no
          // room from the text.
          foregroundDecoration: current
              ? BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: palette.accent),
                )
              : null,
          padding: _cardPadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Measured, so a short card or very large text leaves lines out
              // before anything overflows.
              final rowLine = _lineHeight(
                context,
                _cardDetailsStyle(brightness),
              );
              final titleLine = _lineHeight(context, subjectStyle);
              final markLine =
                  3 +
                  _lineHeight(
                    context,
                    Theme.of(context).textTheme.labelSmall!
                        .copyWith(fontWeight: FontWeight.w800, height: 1.35),
                  ) +
                  2;
              final layout = _lessonCardLayout(
                room: constraints.maxHeight,
                titleLine: titleLine,
                rowLine: rowLine,
                markLine: markLine,
                hasRow: hasRow,
                ownMarkLine: marked && showTimes,
              );
              // The bar of the lesson on now stands beside the time left;
              // where the line is too narrow for it, as beside another
              // lesson, it takes a slim line of its own below when there is
              // room for one.
              final inlineBar =
                  current &&
                  layout.row &&
                  _LessonDetailsRow.barFits(
                    context,
                    block: block,
                    showTimes: showTimes,
                    now: now,
                    tests: tests,
                    width: constraints.maxWidth,
                  );
              final used =
                  (layout.titleHeight ?? layout.titleLines * titleLine) +
                  (layout.markLine ? markLine : 0) +
                  (layout.row ? _cardRowGap + rowLine : 0);
              final barLine =
                  current &&
                  layout.row &&
                  !inlineBar &&
                  constraints.maxHeight - used >=
                      _cardRowGap + _LessonTimeLeft.heightIn(context);
              final title = Text(
                _SubjectScope.of(context, lesson.subject),
                maxLines: layout.titleLines,
                overflow: TextOverflow.ellipsis,
                style: subjectStyle,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (layout.titleHeight case final height?)
                    SizedBox(height: height, child: title)
                  else
                    title,
                  if (layout.markLine)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _ProfileMark(lesson.source),
                    ),
                  if (layout.row)
                    Padding(
                      padding: const EdgeInsets.only(top: _cardRowGap),
                      child: _LessonDetailsRow(
                        block: block,
                        height: rowLine,
                        hue: hue,
                        tests: tests,
                        markInline: marked && !layout.markLine,
                        showTimes: showTimes,
                        current: current,
                        bar: inlineBar,
                        now: now,
                      ),
                    ),
                  if (barLine)
                    Padding(
                      padding: const EdgeInsets.only(top: _cardRowGap),
                      child: _LessonTimeLeft(
                        block: block,
                        now: now,
                        palette: palette,
                        width: null,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "s. 207 · Teacher" under the subject, the room's number bold; for the
/// lesson on now the time left in place of the teacher; and the day's test
/// at the end, standing out of the line evenly above and below, so it
/// moves nothing.
class _LessonDetailsRow extends StatelessWidget {
  const _LessonDetailsRow({
    required this.block,
    required this.height,
    required this.hue,
    required this.tests,
    required this.markInline,
    required this.showTimes,
    required this.current,
    required this.bar,
    required this.now,
  });

  final _LessonBlock block;

  /// One line of the text, which the row keeps to whatever stands in it.
  final double height;
  final int hue;
  final List<SchoolEvent> tests;
  final bool markInline;
  final bool showTimes;
  final bool current;

  /// The bar beside the time left, when the line has room for it.
  final bool bar;
  final DateTime now;

  static const _barWidth = _LessonTimeLeft.inlineWidth + 6;

  /// What stays whole on the line: the room and, for the lesson on now, the
  /// time left. A test gives way to them, down to its icon; the teacher
  /// gives way to the test.
  static double _essentialWidth(
    BuildContext context, {
    required _LessonBlock block,
    required bool showTimes,
    required bool current,
    required DateTime now,
  }) {
    final lesson = block.lesson;
    final left = _minutesLeft(lesson.end.difference(now));
    return _textWidth(
          context,
          [
            if (showTimes) '${_time(lesson.start)}–${_time(lesson.end)}',
            if (block.count > 1) _lessonCount(context, block.count),
            if (lesson.room.isNotEmpty) _room(context, lesson.room),
            if (current)
              context.trArgs('lessonMinutesLeft', {'minutes': '$left'}),
          ].join(' · '),
          _cardDetailsStyle(Theme.of(context).brightness)
              .copyWith(fontWeight: FontWeight.w700),
        ) +
        (lesson.substitution ? 18 : 0);
  }

  /// Whether the bar fits on a line [width] wide beside what stays whole
  /// and a test's icon; short of room the bar goes before the minutes do.
  static bool barFits(
    BuildContext context, {
    required _LessonBlock block,
    required bool showTimes,
    required DateTime now,
    required List<SchoolEvent> tests,
    required double width,
  }) =>
      _essentialWidth(
            context,
            block: block,
            showTimes: showTimes,
            current: true,
            now: now,
          ) +
          _barWidth +
          (tests.isEmpty ? 0 : 8 + _TestPill.compactWidth) <=
      width;

  @override
  Widget build(BuildContext context) {
    final lesson = block.lesson;
    final brightness = Theme.of(context).brightness;
    final palette = SubjectColors.colors(hue, brightness);
    final strong = brightness == Brightness.dark ? Colors.white : Colors.black;
    final absent = _FreeDaysScope.absenceFor(context, lesson) != null;
    final left = _minutesLeft(lesson.end.difference(now));
    List<(InlineSpan, String)> partsWith({required bool bar}) => [
      if (showTimes) _plain('${_time(lesson.start)}–${_time(lesson.end)}'),
      if (block.count > 1) _plain(_lessonCount(context, block.count)),
      if (lesson.room.isNotEmpty)
        (
          TextSpan(
            children: [
              TextSpan(text: '${context.tr('roomShort')} '),
              TextSpan(
                text: lesson.room,
                style: TextStyle(color: strong, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          _room(context, lesson.room),
        ),
      if (current)
        (
          TextSpan(
            children: [
              if (bar)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: _LessonTimeLeft(
                      block: block,
                      now: now,
                      palette: palette,
                    ),
                  ),
                ),
              TextSpan(
                text: context.trArgs('lessonMinutesLeft', {'minutes': '$left'}),
                style: TextStyle(
                  color: palette.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          context.trArgs('timeLeftInline', {'minutes': '$left'}),
        )
      else if (absent && lesson.teacher.isNotEmpty)
        _plain('${lesson.teacher} – ${context.tr('teacherAbsent')}')
      else if (lesson.teacher.isNotEmpty)
        _plain(lesson.teacher),
    ];
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final parts = partsWith(bar: bar);
          final essential = _essentialWidth(
            context,
            block: block,
            showTimes: showTimes,
            current: current,
            now: now,
          );
          final free =
              constraints.maxWidth - essential - (bar ? _barWidth : 0) - 8;
          final compact =
              tests.isNotEmpty && free < _TestPill.fullWidth(context, tests);
          return Row(
            children: [
              // A long name gives way to the room and teacher.
              if (markInline) ...[
                Flexible(child: _ProfileMark(lesson.source)),
                const SizedBox(width: 6),
              ],
              if (lesson.substitution) ...[
                AppIcon(
                  Icons.swap_horiz_rounded,
                  color: palette.foreground,
                  size: 14,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (final (index, part) in parts.indexed) ...[
                        if (index > 0) const TextSpan(text: ' · '),
                        part.$1,
                      ],
                    ],
                  ),
                  semanticsLabel: parts.map((part) => part.$2).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cardDetailsStyle(brightness),
                ),
              ),
              if (tests.isNotEmpty) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compact ? constraints.maxWidth : free,
                  ),
                  child: _StandOut(
                    child: _TestPill(tests, hue: hue, compact: compact),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static (InlineSpan, String) _plain(String text) =>
      (TextSpan(text: text), text);
}

/// Lets [child] be taller than the line it stands in and centres it on the
/// line, standing out evenly above and below without making the line taller.
class _StandOut extends SingleChildRenderObjectWidget {
  const _StandOut({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStandOut();
}

class _RenderStandOut extends RenderShiftedBox {
  _RenderStandOut() : super(null);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      BoxConstraints(maxWidth: constraints.maxWidth),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      (size.height - child.size.height) / 2,
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => 0;
}

/// A short bar of the lesson on now, gliding to the second: Material's flat
/// indicator in Expressive, too short for a wave.
class _LessonTimeLeft extends StatelessWidget {
  const _LessonTimeLeft({
    required this.block,
    required this.now,
    required this.palette,
    this.width = inlineWidth,
  });

  final _LessonBlock block;
  final DateTime now;
  final ({Color background, Color foreground, Color accent}) palette;

  /// Null for a line of its own.
  final double? width;

  static const inlineWidth = 40.0;

  /// Its height in the current design.
  static double heightIn(BuildContext context) =>
      ExpressiveStyle.of(context) ? WavyProgressIndicator.height : 4;

  @override
  Widget build(BuildContext context) {
    final lesson = block.lesson;
    final duration = lesson.end.difference(lesson.start).inSeconds;
    final value = duration <= 0
        ? 0.0
        : (now.difference(lesson.start).inSeconds / duration).clamp(0.0, 1.0);
    final track = palette.foreground.withValues(alpha: 0.2);
    return SizedBox(
      key: const ValueKey('timeline-time-left'),
      width: width ?? double.infinity,
      child: ExpressiveStyle.of(context)
          ? WavyProgressIndicator(
              value: value,
              flat: true,
              color: palette.accent,
              trackColor: track,
            )
          : _GlidingProgress(
              value: value,
              minHeight: 4,
              radius: 2,
              color: palette.accent,
              backgroundColor: track,
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
        borderRadius: BorderRadius.circular(
          ExpressiveStyle.of(context) ? Corners.largeIncreased : 14,
        ),
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
                    child: AppIcon(
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
                    const AppIcon(Icons.swap_horiz_rounded),
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
                    AppIcon(
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
                      child: AppIcon(
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
