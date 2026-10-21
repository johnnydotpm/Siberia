part of '../app_shell.dart';

/// Holidays, the class's days off and teachers' absences, for the pages of
/// the shell.
class _FreeDaysScope extends InheritedWidget {
  const _FreeDaysScope({required this.days, required super.child});

  final List<FreeDay> days;

  /// The absence of [lesson]'s teacher while it is on, if any.
  static FreeDay? absenceFor(BuildContext context, Lesson lesson) => context
      .dependOnInheritedWidgetOfExactType<_FreeDaysScope>()
      ?.days
      .where((day) => day.absentFor(lesson))
      .firstOrNull;

  @override
  bool updateShouldNotify(_FreeDaysScope oldWidget) => days != oldWidget.days;
}

/// The days off under way, or the next ones.
FreeDay? _nextFreeDays(List<FreeDay> days, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return (days.where((day) => day.wholeDays && !day.to.isBefore(today)).toList()
        ..sort((a, b) => a.from.compareTo(b.from)))
      .firstOrNull;
}

/// The school's or the class's day off on [day], the school's first.
FreeDay? _freeDayOn(List<FreeDay> days, DateTime day) =>
    (days
            .where((item) => item.kind != FreeDayKind.teacher)
            .where((item) => item.covers(day))
            .toList()
          ..sort((a, b) => a.kind.index.compareTo(b.kind.index)))
        .firstOrNull;

/// "Za 12 dni", "Jutro", "Jeszcze 3 dni", "Ostatni dzień".
String _freeDaysCountdown(BuildContext context, FreeDay day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (day.covers(today)) {
    final left = _daysBetween(today, day.to) + 1;
    return left <= 1
        ? context.tr('freeDaysLastDay')
        : context.trArgs('freeDaysLeft', {
            'days': _plural(context, left, 'days'),
          });
  }
  final until = _daysBetween(today, day.from);
  return until == 1
      ? context.tr('widgetTomorrow')
      : context.trArgs('freeDaysIn', {'days': _plural(context, until, 'days')});
}

/// Days off: their name and dates and, with [now], how far away they are.
class _FreeDayCard extends StatelessWidget {
  const _FreeDayCard(this.day, {this.now});

  final FreeDay day;

  /// With it, the card counts the days to the days off, or those left.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final school = day.kind == FreeDayKind.school;
    // The tones of the calendar's kinds: warm for holidays.
    final tone = SubjectColors.tone(school ? 46 : 172, brightness);
    final name = day.name.isEmpty
        ? context.tr(school ? 'freeDaySchool' : 'freeDayClass')
        : _capitalize(day.name);
    final dates = _sameDay(day.from, day.to)
        ? _shortDate(context, day.from)
        : '${_shortDate(context, day.from)}–${_shortDate(context, day.to)}';
    final lessons = day.lessonFrom == null
        ? null
        : context.trArgs('freeDayLessons', {
            'from': '${day.lessonFrom}',
            'to': '${day.lessonTo ?? day.lessonFrom}',
          });
    final countdown = now == null
        ? null
        : _freeDaysCountdown(context, day, now!);
    return Card(
      key: ValueKey('free-day-${day.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _Space.inset,
          vertical: 12,
        ),
        child: Row(
          children: [
            _IconTile(
              icon: school
                  ? Icons.beach_access_rounded
                  : Icons.event_busy_rounded,
              background: tone.background,
              foreground: tone.foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, style: _rowTitleStyle(context)),
                  const SizedBox(height: 2),
                  Text(
                    [dates, ?lessons].join(' · '),
                    style: _metaStyle(context),
                  ),
                ],
              ),
            ),
            if (countdown != null) ...[
              const SizedBox(width: 8),
              Text(
                countdown,
                key: const ValueKey('free-days-countdown'),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tone.accent,
                  fontWeight: FontWeight.w800,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
