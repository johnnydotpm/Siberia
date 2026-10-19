part of '../app_shell.dart';

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
