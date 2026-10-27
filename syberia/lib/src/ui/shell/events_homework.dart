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
    return _Refresh(
      controller: widget.controller,
      child: _PageList(
        padding: const EdgeInsets.all(_Space.page),
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
          const SizedBox(height: _Space.section),
          _Heading(context.tr('selectedDay')),
          const SizedBox(height: _Space.heading),
          if (selectedEvents.isEmpty)
            _Empty(context.tr('emptyEvents'), icon: Icons.event_note_rounded)
          else
            ..._spaced(selectedEvents.map(_EventTile.new)),
          const SizedBox(height: _Space.section),
          _Heading(context.tr('upcomingEvents')),
          const SizedBox(height: _Space.heading),
          if (upcoming.isEmpty)
            _Empty(context.tr('emptyEvents'), icon: Icons.event_note_rounded)
          else
            ..._spaced(upcoming.map(_EventTile.new)),
        ],
      ),
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

  /// Whether the upcoming work already done is shown.
  bool _showDone = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Upcoming work by when it is due: "Today", "Tomorrow", "This week",
  /// "Next week", "Later". Past work by month.
  String _section(DateTime due, DateTime today) {
    final days = calendarDaysBetween(today, due);
    if (days < 0) return _monthHeading(context, due, today);
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
    if (all.isEmpty) {
      return _PageEmpty(
        context.tr('emptyHomework'),
        icon: Icons.assignment_rounded,
      );
    }
    final controller = widget.controller;
    final future = all.where((item) => !item.date.isBefore(today)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // Work marked as done leaves the upcoming list for a group of its own.
    final upcoming = future
        .where((item) => !controller.isHomeworkDone(item))
        .toList(growable: false);
    final past = all.where((item) => item.date.isBefore(today)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final query = _plainPolish(_search.text.trim());
    bool matches(SchoolEvent item) =>
        query.isEmpty ||
        _plainPolish(item.title).contains(query) ||
        _plainPolish(item.subject).contains(query) ||
        _plainPolish(_SubjectScope.of(context, item.subject)).contains(query) ||
        _plainPolish(item.description).contains(query);
    final shown = (_past ? past : upcoming).where(matches).toList();
    final done = _past
        ? const <SchoolEvent>[]
        : future.where(controller.isHomeworkDone).where(matches).toList();
    final rows = <Widget>[];
    String? lastSection;
    for (final item in shown) {
      final section = _section(item.date, today);
      final first = section != lastSection;
      if (first) {
        rows.add(
          _GroupLabel(
            section,
            key: ValueKey('homework-section-$section'),
            top: _Space.card,
          ),
        );
        lastSection = section;
      }
      rows.add(
        AnimatedPadding(
          key: ValueKey('homework-row-${item.id}'),
          duration: _motion(context, _Motion.list),
          curve: _Motion.curve,
          // The first of its group sits under the label; the next one under
          // it slides up when it goes.
          padding: EdgeInsets.only(top: first ? 0 : _Space.item),
          child: _HomeworkCard(item, now: now),
        ),
      );
    }
    if (done.isNotEmpty) {
      rows.add(
        InkWell(
          key: const ValueKey('homework-done-toggle'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _showDone = !_showDone),
          child: Row(
            children: [
              Expanded(
                child: _GroupLabel(
                  '${context.tr('homeworkDoneSection')} (${done.length})',
                  top: _Space.card,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: _Space.card,
                  bottom: _Space.heading,
                  end: 8,
                ),
                child: AnimatedRotation(
                  turns: _showDone ? 0.5 : 0,
                  duration: _motion(context, _Motion.list),
                  curve: _Motion.curve,
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (_showDone) {
        for (final (index, item) in done.indexed) {
          rows.add(
            AnimatedPadding(
              // Apart from its row above, so one moves out and one in.
              key: ValueKey('homework-done-row-${item.id}'),
              duration: _motion(context, _Motion.list),
              curve: _Motion.curve,
              padding: EdgeInsets.only(top: index == 0 ? 0 : _Space.item),
              child: _HomeworkCard(item, now: now),
            ),
          );
        }
      }
    }
    final empty = shown.isEmpty
        ? query.isNotEmpty && done.isEmpty
              ? _Empty(
                  key: const ValueKey('homework-empty-search'),
                  context.tr('noResults'),
                  icon: Icons.search_off_rounded,
                )
              : done.isNotEmpty
              // Everything due is done: said with a check, as a good thing.
              ? _Empty(
                  key: const ValueKey('homework-empty-done'),
                  context.tr('homeworkAllDone'),
                  icon: Icons.task_alt_rounded,
                  color: Theme.of(context).colorScheme.primary,
                )
              : _Empty(
                  key: const ValueKey('homework-empty'),
                  context.tr('emptyHomework'),
                  icon: Icons.assignment_rounded,
                )
        : null;
    final list = [?empty, ...rows];

    String counted(String key, int count) =>
        count == 0 ? context.tr(key) : '${context.tr(key)} ($count)';
    return _Refresh(
      controller: widget.controller,
      child: _PageList(
        padding: const EdgeInsets.all(_Space.page),
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
          const SizedBox(height: 12),
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
            onSelectionChanged: (selection) {
              HapticFeedback.selectionClick();
              setState(() => _past = selection.first);
            },
          ),
          // Past work is a long list that only changes with a sync, so it
          // is built as it scrolls in. What is to do comes and goes smoothly;
          // a search or the other list shows at once, as in Reminders.
          if (_past)
            ...list
          else
            _AnimatedColumn(key: ValueKey(query), children: list),
        ],
      ),
    );
  }
}

/// When an entry is due: "Today", "Tomorrow", or the weekday and date.
String _dueLabel(BuildContext context, DateTime date, DateTime now) =>
    switch (calendarDaysBetween(now, date)) {
      0 => context.tr('messagesToday'),
      1 => context.tr('widgetTomorrow'),
      _ => '${_shortWeekday(context, date)}, ${_shortDate(context, date)}',
    };

/// The assignment itself. Librus falls back to the type ("Zadanie domowe")
/// when an assignment has neither topic nor text.
String _homeworkTitle(BuildContext context, SchoolEvent item) =>
    item.title.isEmpty || item.title == item.typeLabel
    ? context.tr('homeworkItem')
    : item.title;

/// More text than the title, if the assignment has any.
String _homeworkDetails(SchoolEvent item) =>
    item.description == item.title ? '' : item.description;

/// What a calendar entry is, for its icon and colour.
enum _EventType {
  exam(Icons.assignment_rounded, 0),
  quiz(Icons.quiz_rounded, 28),
  oral(Icons.record_voice_over_rounded, 46),
  project(Icons.co_present_rounded, 172),
  trip(Icons.directions_bus_rounded, 135),
  meeting(Icons.groups_rounded, 215),
  other(Icons.event_rounded, null);

  const _EventType(this.icon, this.hue);
  final IconData icon;

  /// Null for the grey of entries of no particular kind.
  final double? hue;

  ({Color background, Color foreground, Color accent}) colors(
    Brightness brightness,
  ) => hue == null
      ? SubjectColors.grade(null, brightness)
      : SubjectColors.tone(hue!, brightness);
}

/// The words, without Polish accents, a category or the start of an entry
/// names its kind with. Kartkówka comes before the tests.
const _eventTypeWords = [
  (_EventType.quiz, ['kartkowka']),
  (
    _EventType.exam,
    ['sprawdzian', 'praca klasowa', 'klasowka', 'test', 'egzamin'],
  ),
  (_EventType.oral, ['odpowiedz', 'odpytywanie']),
  (_EventType.project, ['projekt', 'prezentacja', 'referat']),
  (_EventType.trip, ['wycieczka', 'wyjscie']),
  (_EventType.meeting, ['zebranie', 'wywiadowka', 'spotkanie']),
];

/// Categories that say nothing about the entry.
const _genericEventTypes = {'', 'inne', 'other', 'wydarzenie'};

/// The kind of [item], the word to show for it, if any, and the text
/// without that word when the kind came from it. The category decides; a
/// category of no kind ("inne") leaves it to the start of the text, as in
/// "kartkówka z ostatnich 3 lekcji".
({_EventType type, String? label, String text}) _eventType(SchoolEvent item) {
  final category = item.typeLabel.trim();
  final plainCategory = _plainPolish(category);
  if (!_genericEventTypes.contains(plainCategory)) {
    for (final (type, words) in _eventTypeWords) {
      if (words.any(plainCategory.contains)) {
        return (type: type, label: _capitalize(category), text: item.title);
      }
    }
    return (
      type: _EventType.other,
      label: _capitalize(category),
      text: item.title,
    );
  }
  final text = item.title.trim();
  final plainText = _plainPolish(text);
  for (final (type, words) in _eventTypeWords) {
    for (final word in words) {
      if (plainText.startsWith(word)) {
        // Lower case can change the length of rare letters.
        final original = text.length >= word.length
            ? text.substring(0, word.length)
            : word;
        // "kartkówka--elektryzowanie" reads "Elektryzowanie" under it.
        final rest = text
            .substring(original.length)
            .replaceFirst(RegExp(r'^[\s\-–—:,.;]+'), '');
        return (
          type: type,
          label: _capitalize(original),
          text: _capitalize(rest),
        );
      }
    }
  }
  return (type: _EventType.other, label: null, text: item.title);
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.item);
  final SchoolEvent item;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (item.kind == EventKind.homework) return _HomeworkCard(item, now: now);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final days = calendarDaysBetween(now, item.date);
    final soon = days == 0 || days == 1;
    final when = _dueLabel(context, item.date, now);
    final (:type, :label, :text) = _eventType(item);
    final tone = type.colors(theme.brightness);
    // Entries of no subject come from the client as "Librus".
    final hasSubject = item.subject.isNotEmpty && item.subject != 'Librus';
    final subjectAccent = SubjectColors.colors(
      _SubjectScope.colorsOf(context).indexOf(item.subject),
      theme.brightness,
    ).accent;
    // The subject leads; the teacher's text follows, unless it only repeats
    // the kind.
    final title = hasSubject
        ? _SubjectScope.of(context, item.subject)
        : item.title;
    final details =
        !hasSubject || _plainPolish(text.trim()) == _plainPolish(label ?? '')
        ? ''
        : text.trim();
    return Card(
      key: ValueKey('event-${item.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _Space.inset,
          vertical: 12,
        ),
        // The date, a year longer for one of next year, wraps rather than
        // pushing the card's content out.
        child: LayoutBuilder(
          builder: (context, card) => Row(
            children: [
              _IconTile(
                key: ValueKey('event-type-${item.id}-${type.name}'),
                icon: type.icon,
                background: tone.background,
                foreground: tone.foreground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The kind gives way before it pushes out of the card, as
                    // when a date of next year makes the date beside it wider.
                    LayoutBuilder(
                      builder: (context, constraints) => Row(
                        children: [
                          if (hasSubject) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: subjectAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              title,
                              maxLines: hasSubject ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: _rowTitleStyle(context),
                            ),
                          ),
                          if (_ControllerScope.maybeOf(context)
                                  ?.profileMark(item.source) !=
                              null) ...[
                            const SizedBox(width: 6),
                            // Gives way with the title before the kind does.
                            Flexible(child: _ProfileMark(item.source)),
                          ],
                          // "Wycieczka do Krakowa" needs no "Wycieczka" next to it.
                          if (label != null &&
                              !_plainPolish(title)
                                  .startsWith(_plainPolish(label))) ...[
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.45,
                              ),
                              child: Container(
                                key: ValueKey('event-label-${item.id}'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tone.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: tone.foreground,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (details.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          details,
                          maxLines: 2,
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
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: card.maxWidth * 0.35),
                child: Text(
                  when,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: soon ? colors.error : colors.onSurfaceVariant,
                    fontWeight: soon ? FontWeight.w800 : FontWeight.w600,
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
    final days = calendarDaysBetween(now, item.date);
    // Due today or tomorrow: the one to do first.
    final soon = days == 0 || days == 1;
    final due = _dueLabel(context, item.date, now);
    final controller = _ControllerScope.maybeOf(context);
    final done = controller?.isHomeworkDone(item) ?? false;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MarkedTitle(
                Text(
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
                item.source,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.event_rounded,
              size: 14,
              color: soon && !done ? colors.error : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              due,
              style: theme.textTheme.labelMedium?.copyWith(
                color: soon && !done ? colors.error : colors.onSurfaceVariant,
                fontWeight: soon && !done ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _homeworkTitle(context, item),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _rowTitleStyle(context)
              ?.copyWith(decoration: done ? TextDecoration.lineThrough : null),
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
    );
    final card = Card(
      key: ValueKey('homework-${item.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showHomeworkDetails(context, item),
        onLongPress: controller == null
            ? null
            : () => _showItemActions(
                context,
                title: _homeworkTitle(context, item),
                actions: [
                  (
                    key: ValueKey('homework-action-open-${item.id}'),
                    icon: Icons.assignment_outlined,
                    label: context.tr('open'),
                    run: () => _showHomeworkDetails(context, item),
                  ),
                  (
                    key: ValueKey('homework-action-done-${item.id}'),
                    icon: done
                        ? Icons.remove_done_rounded
                        : Icons.task_alt_rounded,
                    label: context.tr(
                      done ? 'homeworkMarkNotDone' : 'homeworkMarkDone',
                    ),
                    run: () =>
                        _setHomeworkDone(context, controller, item, !done),
                  ),
                ],
              ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: palette.accent, width: 4)),
          ),
          // With the stripe, 16 from the card's edge; the check's own room
          // makes up the rest.
          padding: controller == null
              ? const EdgeInsetsDirectional.fromSTEB(12, 12, 16, 12)
              : const EdgeInsetsDirectional.fromSTEB(4, 12, 16, 12),
          child: controller == null
              ? content
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DoneCheck(
                      key: ValueKey('homework-done-${item.id}'),
                      done: done,
                      onChanged: (value) =>
                          _setHomeworkDone(context, controller, item, value),
                    ),
                    const SizedBox(width: 4),
                    // Done work steps back.
                    Expanded(
                      child: _LightOpacity(
                        opacity: done ? 0.6 : 1,
                        child: content,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
    if (controller == null) return card;
    // A swipe marks it, as a swipe marks a message read; the card springs
    // back and leaves the list.
    return Dismissible(
      key: ValueKey('homework-swipe-${item.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        HapticFeedback.lightImpact();
        _setHomeworkDone(context, controller, item, !done);
        return false;
      },
      // A short word, seen in the little room a swipe opens.
      background: _SwipeAction(
        icon: done ? Icons.remove_done_rounded : Icons.task_alt_rounded,
        label: context.tr(done ? 'homeworkMarkNotDone' : 'homeworkDoneSection'),
      ),
      child: card,
    );
  }
}

/// Marks [item] done or not; a mark from a list can be taken back at once.
void _setHomeworkDone(
  BuildContext context,
  AppController controller,
  SchoolEvent item,
  bool done,
) {
  unawaited(controller.setHomeworkDone(item, done));
  // Marked after the card left the screen: nothing to show the message on.
  if (!done || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(context.tr('homeworkMarkedDone')),
      action: SnackBarAction(
        label: context.tr('undo'),
        onPressed: () => controller.setHomeworkDone(item, false),
      ),
    ),
  );
}

/// The round check in front of an assignment. As in Reminders, a tick
/// fills the circle at once and the work leaves the list a moment later, so
/// the tick is seen; a second tap meanwhile takes it back.
class _DoneCheck extends StatefulWidget {
  const _DoneCheck({required this.done, required this.onChanged, super.key});
  final bool done;
  final ValueChanged<bool> onChanged;

  /// How long a ticked circle shows before the work is marked.
  static const delay = Duration(milliseconds: 700);

  @override
  State<_DoneCheck> createState() => _DoneCheckState();
}

class _DoneCheckState extends State<_DoneCheck> {
  Timer? _ticking;

  void _tap() {
    if (_ticking != null) {
      _ticking!.cancel();
      setState(() => _ticking = null);
      return;
    }
    if (widget.done) {
      HapticFeedback.selectionClick();
      widget.onChanged(false);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _ticking = Timer(_DoneCheck.delay, _commit));
  }

  void _commit() {
    _ticking = null;
    widget.onChanged(true);
  }

  @override
  void dispose() {
    // Gone from the screen before the moment passed: still marked.
    if (_ticking?.isActive ?? false) {
      _ticking!.cancel();
      _commit();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ticked = widget.done || _ticking != null;
    final label = context.tr(
      widget.done ? 'homeworkMarkNotDone' : 'homeworkMarkDone',
    );
    return Semantics(
      button: true,
      checked: ticked,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: _tap,
          radius: 20,
          // A 40-point target around a 24-point circle.
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: AnimatedContainer(
                duration: _motion(context, const Duration(milliseconds: 150)),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ticked ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: ticked ? colors.primary : colors.outline,
                    width: 2,
                  ),
                ),
                child: ticked
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: colors.onPrimary,
                      )
                    : null,
              ),
            ),
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
  final controller = _ControllerScope.maybeOf(context);
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
        padding: const EdgeInsets.fromLTRB(_Space.sheet, 4, _Space.sheet, 24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller != null)
                _SheetProfileMark(controller, item.source),
              if (item.subject.isNotEmpty)
                Text(
                  displaySubject(item.subject, const {}),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 6),
              SelectableText(
                _homeworkTitle(context, item),
                style: _sheetTitleStyle(context),
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
              if (controller != null) ...[
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final done = controller.isHomeworkDone(item);
                    final button = done
                        ? OutlinedButton.icon(
                            key: const ValueKey('homework-sheet-not-done'),
                            onPressed: () =>
                                controller.setHomeworkDone(item, false),
                            icon: const Icon(Icons.undo_rounded),
                            label: Text(context.tr('homeworkMarkNotDone')),
                          )
                        : FilledButton.tonalIcon(
                            key: const ValueKey('homework-sheet-done'),
                            onPressed: () =>
                                controller.setHomeworkDone(item, true),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(context.tr('homeworkMarkDone')),
                          );
                    return SizedBox(width: double.infinity, child: button);
                  },
                ),
              ],
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
