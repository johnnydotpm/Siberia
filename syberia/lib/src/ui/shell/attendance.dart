part of '../app_shell.dart';

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
        if (records.any((item) => item.subject.trim().isNotEmpty)) ...[
          const SizedBox(height: 16),
          _AttendanceBySubject(
            records: records,
            style: widget.controller.attendanceChartStyle,
          ),
        ] else if (records.isNotEmpty) ...[
          // Said, not hidden: a sync may still bring the subjects.
          const SizedBox(height: 16),
          _AttendanceNoSubjects(widget.controller),
        ],
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

/// Entries came without their subjects, so there is nothing to split by
/// subject yet; a sync may bring them.
class _AttendanceNoSubjects extends StatelessWidget {
  const _AttendanceNoSubjects(this.controller);
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      key: const ValueKey('attendance-no-subjects'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('attendanceNoSubjects'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: controller.syncing ? null : controller.sync,
              child: Text(
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The attendance of each subject, the lowest first; a tap shows the
/// subject's own summary and entries.
class _AttendanceBySubject extends StatelessWidget {
  const _AttendanceBySubject({required this.records, required this.style});
  final List<AttendanceRecord> records;
  final AttendanceChartStyle style;

  /// Below this a student may not be graded in the subject.
  static const _gradingThreshold = 50.0;

  @override
  Widget build(BuildContext context) {
    final bySubject = <String, List<AttendanceRecord>>{};
    for (final record in records) {
      final subject = record.subject.trim();
      if (subject.isNotEmpty) {
        bySubject.putIfAbsent(subject, () => []).add(record);
      }
    }
    double rate(List<AttendanceRecord> items) =>
        items.where((item) => item.isPresence).length / items.length * 100;
    final subjects = bySubject.keys.toList()
      ..sort((a, b) {
        final byRate = rate(bySubject[a]!).compareTo(rate(bySubject[b]!));
        return byRate != 0 ? byRate : a.compareTo(b);
      });
    return Card(
      key: const ValueKey('attendance-by-subject'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              child: Text(
                context.tr('attendanceBySubject'),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final subject in subjects)
              _SubjectAttendanceRow(
                subject: subject,
                records: bySubject[subject]!,
                percentage: rate(bySubject[subject]!),
                low: rate(bySubject[subject]!) < _gradingThreshold,
                style: style,
              ),
          ],
        ),
      ),
    );
  }
}

class _SubjectAttendanceRow extends StatelessWidget {
  const _SubjectAttendanceRow({
    required this.subject,
    required this.records,
    required this.percentage,
    required this.low,
    required this.style,
  });
  final String subject;
  final List<AttendanceRecord> records;
  final double percentage;
  final bool low;
  final AttendanceChartStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = _SubjectScope.of(context, subject);
    final accent = SubjectColors.colors(
      _SubjectScope.colorsOf(context).indexOf(subject),
      theme.brightness,
    ).accent;
    int count(bool Function(AttendanceKind kind) test) =>
        records.where((item) => test(item.kind)).length;
    final absences = count(
      (kind) =>
          kind == AttendanceKind.absent || kind == AttendanceKind.absentExcused,
    );
    final late = count(
      (kind) =>
          kind == AttendanceKind.late || kind == AttendanceKind.lateExcused,
    );
    final kinds = [
      for (final kind in AttendanceKind.values)
        (kind: kind, count: count((value) => value == kind)),
    ].where((entry) => entry.count > 0);
    return InkWell(
      key: ValueKey('attendance-subject-$subject'),
      onTap: () => _showSubjectAttendance(context, name, records, style),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _percent(context, percentage),
                        key: ValueKey('attendance-subject-rate-$subject'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: low ? colors.error : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // The same colours as the summary above, in proportion.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 7,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final entry in kinds)
                            Expanded(
                              flex: entry.count,
                              child: ColoredBox(
                                color: _attendanceColor(entry.kind),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (absences > 0)
                        '${context.tr('attendanceAbsences')}: $absences',
                      if (late > 0) '${context.tr('late')}: $late',
                      '${context.tr('attendanceLessons')}: ${records.length}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// One subject's summary and its entries, the latest first.
Future<void> _showSubjectAttendance(
  BuildContext context,
  String name,
  List<AttendanceRecord> records,
  AttendanceChartStyle style,
) => showAppSheet<void>(
  context: context,
  compact: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final latest = records.toList()..sort((a, b) => b.date.compareTo(a.date));
    return SafeArea(
      child: ConstrainedBox(
        key: const ValueKey('subject-attendance-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            _AttendanceChart(
              counts: {
                for (final kind in AttendanceKind.values)
                  kind: records.where((item) => item.kind == kind).length,
              },
              style: style,
            ),
            const SizedBox(height: 8),
            for (final item in latest)
              _AttendanceTile(item, showSubject: false),
          ],
        ),
      ),
    );
  },
);

class _AttendanceGraphic extends StatelessWidget {
  const _AttendanceGraphic({
    required this.entries,
    required this.style,
    required this.percentage,
  });
  final List<({int count, Color color, String label})> entries;
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
      // Wraps instead of overflowing when a long label meets a narrow
      // screen or large text.
      Flexible(child: Text(value == null ? label : '$label: $value')),
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
    // One pass over the records: a year holds a thousand or more, and this
    // runs on every tap of a day.
    final byDay = <int, List<AttendanceRecord>>{};
    for (final item in records) {
      if (item.date.year == month.year && item.date.month == month.month) {
        (byDay[item.date.day] ??= []).add(item);
      }
    }
    final days = {
      for (final MapEntry(key: day, value: dayRecords) in byDay.entries)
        day: _attendanceDay(dayRecords),
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
  const _AttendanceTile(this.item, {this.showSubject = true});
  final AttendanceRecord item;

  /// Off where every entry is of the same subject.
  final bool showSubject;
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
          if (showSubject && item.subject.isNotEmpty) item.subject,
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
  // Attended the same way the rate above the calendar counts it, so late
  // lessons are attendance too.
  final hasPresence = records.any((record) => record.kind.countsAsPresence);
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
