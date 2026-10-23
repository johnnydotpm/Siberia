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
    final focus = _focusBlock(blocks, current, now);
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
              child: KeyedSubtree(
                key: identical(block, focus) ? focusKey : null,
                child: _TimelineLessonCard(
                  key: ValueKey('timeline-lesson-${block.lesson.id}'),
                  block: block,
                  hue: colors[block.lesson.subject] ?? 0,
                  current: identical(block, current),
                  now: now,
                ),
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
          KeyedSubtree(
            key: identical(blocks[index], focus) ? focusKey : null,
            child: _TimetableRow(
              key: ValueKey('timetable-row-${blocks[index].lesson.id}'),
              block: blocks[index],
              hue: colors[blocks[index].lesson.subject] ?? 0,
              current: identical(blocks[index], current),
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
