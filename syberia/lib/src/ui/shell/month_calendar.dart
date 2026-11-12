part of '../app_shell.dart';

/// How one day of a [_MonthCalendar] looks.
@immutable
class _CalendarDay {
  const _CalendarDay({
    this.background,
    this.dot,
    this.crossed = false,
    this.enabled = true,
    this.key,
    this.dotKey,
  });

  /// The day's own colour, as attendance gives each day.
  final Color? background;

  /// A mark under the number: lessons or events that day.
  final Color? dot;

  /// Crossed out, as a day without lessons in the timetable's calendar.
  final bool crossed;
  final bool enabled;
  final Key? key;
  final Key? dotKey;
}

/// The one month calendar of the app, for events, attendance and picking a
/// day of the timetable: the month between its arrows, the days of the week
/// as the app writes them, and the days in rows of seven. A picked day is
/// filled with the primary colour, or ringed with it on a day of its own
/// colour; today is outlined.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.onMonthChanged,
    required this.onDaySelected,
    required this.dayOf,
    this.selected,
    this.first,
    this.last,
    super.key,
  });

  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;
  final _CalendarDay Function(DateTime day) dayOf;
  final DateTime? selected;

  /// The first and the last day there is to go to, if there are such.
  final DateTime? first;
  final DateTime? last;

  static bool _monthBefore(DateTime left, DateTime right) =>
      left.year < right.year ||
      (left.year == right.year && left.month < right.month);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final start = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = start.weekday - 1;
    final canGoBack = first == null || _monthBefore(first!, start);
    final canGoOn = last == null || _monthBefore(start, last!);
    final today = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: canGoBack
                  ? () => onMonthChanged(DateTime(month.year, month.month - 1))
                  : null,
              icon: const AppIcon(Icons.chevron_left_rounded),
              tooltip: localizations.previousMonthTooltip,
            ),
            Expanded(
              child: Text(
                _capitalize(DateFormat.yMMMM(locale).format(month)),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: canGoOn
                  ? () => onMonthChanged(DateTime(month.year, month.month + 1))
                  : null,
              icon: const AppIcon(Icons.chevron_right_rounded),
              tooltip: localizations.nextMonthTooltip,
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
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Another month fades in where the last one was.
        AnimatedSwitcher(
          duration: _motion(context, const Duration(milliseconds: 150)),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: GridView.builder(
            key: ValueKey(start),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Not the screen's safe area, which a page under glass bars
            // passes on.
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: ((leading + count + 6) ~/ 7) * 7,
            itemBuilder: (context, index) {
              final number = index - leading + 1;
              if (number < 1 || number > count) return const SizedBox.shrink();
              final day = DateTime(month.year, month.month, number);
              return _dayCell(
                context,
                day,
                dayOf(day),
                picked: selected != null && _sameDay(selected!, day),
                today: _sameDay(day, today),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day,
    _CalendarDay spec, {
    required bool picked,
    required bool today,
  }) {
    final colors = Theme.of(context).colorScheme;
    final own = spec.background;
    final fill = own ?? (picked ? colors.primary : null);
    final Color? foreground;
    if (own != null) {
      foreground = ThemeData.estimateBrightnessForColor(own) == Brightness.light
          ? const Color(0xFF101416)
          : Colors.white;
    } else if (picked) {
      foreground = colors.onPrimary;
    } else if (!spec.enabled) {
      foreground = colors.onSurface.withValues(alpha: 0.38);
    } else {
      foreground = null;
    }
    final border = picked && own != null
        ? Border.all(color: colors.primary, width: 2)
        : today && !picked
        ? Border.all(color: colors.primary, width: 1.5)
        : null;
    final strong = own != null || picked || spec.dot != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: spec.enabled ? () => onDaySelected(day) : null,
      child: DecoratedBox(
        key: spec.key,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: foreground,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            if (spec.crossed)
              AppIcon(
                Icons.close_rounded,
                size: 27,
                color: colors.outline.withAlpha(150),
              ),
            if (spec.dot case final dot?)
              Positioned(
                bottom: 5,
                child: Container(
                  key: spec.dotKey,
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: picked && own == null ? colors.onPrimary : dot,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
