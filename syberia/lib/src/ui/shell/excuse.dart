part of '../app_shell.dart';

/// Absences not excused yet from the last two weeks: what a parent still has
/// time to excuse.
List<AttendanceRecord> _absencesToExcuse(AppSnapshot data, DateTime now) {
  final since = DateTime(now.year, now.month, now.day - 14);
  return [
    for (final record in data.attendance)
      if (record.kind == AttendanceKind.absent && !record.date.isBefore(since))
        record,
  ]..sort((a, b) {
    final day = a.date.compareTo(b.date);
    return day != 0 ? day : a.lessonNumber.compareTo(b.lessonNumber);
  });
}

/// The class teacher among [recipients]: in the group Librus codes
/// "tutors" ("Wychowawca"), or else in one named so.
MessageRecipient? _classTeacher(List<MessageRecipient> recipients) {
  return recipients.where((item) => item.groupId == 'tutors').firstOrNull ??
      recipients
          .where((item) => _plainPolish(item.group).contains('wychowaw'))
          .firstOrNull;
}

/// The sheet that writes an excuse note to the class teacher.
Future<void> _showExcuseSheet(
  BuildContext context,
  AppController controller, {
  bool planned = false,
}) => showAppSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ExcuseSheet(controller, planned: planned),
);

/// One day of absences: its lessons, and the records behind them.
typedef _ExcuseDayRows = ({DateTime day, List<AttendanceRecord> records});

/// "lekcje 1–3, 5", or the whole day when every lesson of it was missed.
String _lessonsLabel(
  BuildContext context,
  AppSnapshot data,
  _ExcuseDayRows row,
) {
  final numbers = {
    for (final record in row.records)
      if (record.lessonNumber > 0) record.lessonNumber,
  }.toList()..sort();
  final planned = data.lessons
      .where((lesson) => _sameDay(lesson.start, row.day))
      .length;
  if (numbers.isEmpty || (planned > 0 && numbers.length >= planned)) {
    return context.tr('excuseWholeDay');
  }
  final runs = <String>[];
  for (var i = 0; i < numbers.length; i++) {
    var j = i;
    while (j + 1 < numbers.length && numbers[j + 1] == numbers[j] + 1) {
      j++;
    }
    runs.add(
      j - i >= 2
          ? '${numbers[i]}–${numbers[j]}'
          : [for (var k = i; k <= j; k++) '${numbers[k]}'].join(', '),
    );
    i = j;
  }
  return numbers.length == 1
      ? context.trArgs('lessonNumber', {'number': runs.single})
      : context.trArgs('excuseLessonList', {'list': runs.join(', ')});
}

class _ExcuseSheet extends StatefulWidget {
  const _ExcuseSheet(this.controller, {this.planned = false});
  final AppController controller;
  final bool planned;

  @override
  State<_ExcuseSheet> createState() => _ExcuseSheetState();
}

class _ExcuseSheetState extends State<_ExcuseSheet> {
  AppController get controller => widget.controller;
  late bool planned = widget.planned;
  bool own = false;
  bool sending = false;
  String? error;

  /// Why the child was away each day; days not in it are unexplained yet.
  final reasons = <DateTime, ExcuseReason>{};
  ExcuseReason plannedReason = ExcuseReason.familyTrip;
  final other = TextEditingController();
  final text = TextEditingController();
  final ownText = TextEditingController();
  DateTimeRange? range;

  /// The profile the note goes from, all together: whose absences they are.
  String? child;
  final chosen = <DateTime>{};

  /// The class teacher of the child: null while looking, or when there is
  /// none among the recipients.
  MessageRecipient? teacher;
  bool lookingForTeacher = true;

  late final List<AttendanceRecord> _all = _absencesToExcuse(
    controller.snapshot,
    DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _chooseUnsent();
    _findTeacher();
  }

  @override
  void dispose() {
    other.dispose();
    text.dispose();
    ownText.dispose();
    super.dispose();
  }

  /// The children who have absences, all together; one note goes from one.
  List<String> get _children => controller.together
      ? [
          for (final profile in controller.togetherProfiles)
            if (planned || _all.any((record) => record.source == profile.id))
              profile.id,
        ]
      : const [];

  String? get _firstChild =>
      _children.firstOrNull ?? controller.togetherProfiles.firstOrNull?.id;

  String? get _profileId =>
      controller.together ? child ?? _firstChild : controller.activeProfile?.id;

  SchoolProfile? get _profile => controller.profileOf(_profileId);

  ParentPreferences get _preferences =>
      _profile?.parentPreferences ?? const ParentPreferences();

  ExcuseChild get _word => ExcuseChild.byName(_preferences.excuseChild);

  String get _greeting {
    final saved = _preferences.excuseGreeting.trim();
    if (saved.isNotEmpty) return saved;
    return excuseGreetings(teacher?.name ?? '').first;
  }

  List<_ExcuseDayRows> get _days {
    final days = <DateTime, List<AttendanceRecord>>{};
    for (final record in _all) {
      if (controller.together && record.source != _profileId) continue;
      final day = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      days.putIfAbsent(day, () => []).add(record);
    }
    return [
      for (final day in days.keys.toList()..sort())
        (day: day, records: days[day]!),
    ];
  }

  /// Days some of whose absences went in no note yet start chosen.
  void _chooseUnsent() {
    chosen
      ..clear()
      ..addAll([
        for (final row in _days)
          if (row.records.any(
            (record) => controller.excuseSentAt(record) == null,
          ))
            row.day,
      ]);
    _regenerate();
  }

  Future<void> _findTeacher() async {
    setState(() => lookingForTeacher = true);
    final from = _profileId;
    MessageRecipient? found;
    try {
      found = _classTeacher(
        await controller.fetchMessageRecipients(
          profileId: controller.together ? from : null,
        ),
      );
    } on Object {
      // The teacher is then picked in the message.
    }
    if (!mounted || from != _profileId) return;
    setState(() {
      teacher = found;
      lookingForTeacher = false;
    });
    _regenerate();
  }

  String get _sentence => planned
      ? plannedSentence(
          from: range?.start ?? DateTime.now(),
          to: range?.end ?? range?.start ?? DateTime.now(),
          word: _word,
          reason: plannedReason,
          other: other.text,
        )
      : excuseSentence([
          for (final day in chosen.toList()..sort())
            (
              date: day,
              reason: reasons[day] ?? ExcuseReason.unwell,
              other: other.text,
            ),
        ], word: _word);

  String get _generated => excuseBody(
    sentence: _sentence,
    greeting: _greeting,
    closing: _preferences.excuseClosing,
    signature: controller.excuseSignature,
  );

  /// Reasons, the child's word and the greeting rewrite the text at once.
  void _regenerate() {
    final value = _generated;
    if (text.text != value) text.text = value;
    if (mounted) setState(() {});
  }

  String get _body => own ? ownText.text.trim() : text.text.trim();

  bool get _usesOther => planned
      ? plannedReason == ExcuseReason.other
      : chosen.any((day) => reasons[day] == ExcuseReason.other);

  bool get _ready =>
      (planned ? range != null : chosen.isNotEmpty) &&
      (!_usesOther || other.text.trim().isNotEmpty || own) &&
      _body.isNotEmpty &&
      !lookingForTeacher &&
      !sending;

  List<AttendanceRecord> get _records => [
    if (!planned)
      for (final row in _days)
        if (chosen.contains(row.day)) ...row.records,
  ];

  List<DateTime> get _chosenDays => planned
      ? [
          if (range case final range?)
            for (
              var day = range.start;
              !day.isAfter(range.end);
              day = DateTime(day.year, day.month, day.day + 1)
            )
              day,
        ]
      : (chosen.toList()..sort());

  List<String> get _reasonNames => planned
      ? [plannedReason.name]
      : {
          for (final day in chosen.toList()..sort())
            (reasons[day] ?? ExcuseReason.unwell).name,
        }.toList();

  String get _subject => excuseSubject(
    _profile?.name.isNotEmpty == true
        ? _profile!.name
        : controller.snapshot.profile.name,
    planned: planned,
  );

  Future<void> _setPreferences(ParentPreferences preferences) async {
    final id = _profileId;
    if (id == null) return;
    await controller.setParentPreferences(id, preferences);
    _regenerate();
  }

  Future<void> _editGreeting() async {
    final field = TextEditingController(text: _greeting);
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('excuseGreeting')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final greeting in excuseGreetings(teacher?.name ?? ''))
                  ActionChip(
                    label: Text(greeting),
                    onPressed: () => field.text = greeting,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('excuse-greeting-field'),
              controller: field,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            key: const ValueKey('excuse-greeting-save'),
            onPressed: () => Navigator.pop(context, field.text),
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
    field.dispose();
    if (picked == null) return;
    await _setPreferences(_preferences.copyWith(excuseGreeting: picked.trim()));
  }

  Future<bool> _confirm() async {
    final when = planned
        ? '${_shortDate(context, range!.start)} – ${_shortDate(context, range!.end)}'
        : [for (final day in chosen.toList()..sort()) _shortDate(context, day)]
              .join(', ');
    final theme = Theme.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: _metaStyle(context))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('excuse-confirm'),
        icon: const AppIcon(Icons.send_rounded),
        title: Text(
          context.tr(planned ? 'excuseConfirmPlanned' : 'excuseConfirmTitle'),
        ),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _Space.inset,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    row(
                      context.tr('excuseConfirmChild'),
                      _profile?.displayName ?? '',
                    ),
                    row(context.tr('excuseConfirmWhen'), when),
                    row(
                      context.tr('excuseConfirmWho'),
                      teacher?.name ?? context.tr('excuseConfirmTeacher'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsetsDirectional.only(start: 12),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: theme.colorScheme.primary, width: 3),
                ),
              ),
              child: Text(_body, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 12),
            Text(context.tr('excuseConfirmNote'), style: _metaStyle(context)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            key: const ValueKey('excuse-confirm-send'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('send')),
          ),
        ],
      ),
    );
    return go ?? false;
  }

  Future<void> _send() async {
    final id = _profileId;
    if (id == null || !_ready) return;
    final to = teacher;
    if (to == null) return _sendInMessage();
    if (!await _confirm() || !mounted) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await controller.sendAbsenceRequest(
        profileId: id,
        recordIds: {
          for (final record in _records) localId(record.id, record.source),
        },
        recipient: to,
        subject: _subject,
        body: _body,
        days: _chosenDays,
        reasons: _reasonNames,
        planned: planned,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final messenger = ScaffoldMessenger.of(context);
      final done = context.tr('excuseSentDone');
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on Object catch (failure) {
      if (!mounted) return;
      setState(() {
        sending = false;
        error = failure is StateError
            ? context.tr('absenceRefresh')
            : context.trError(AppError.from(failure));
      });
    }
  }

  /// Without a class teacher found, the note opens as a message to pick one.
  Future<void> _sendInMessage() async {
    final from = controller.together ? _profileId : null;
    final excused = _records;
    _ComposeDraft.kept[controller] = _ComposeDraft(
      view: controller.snapshot.profile.id,
      from: from,
      recipients: const [],
      subject: _subject,
      body: _body,
    );
    var sent = false;
    // Kept as not sure before it goes: if the app stops halfway, the history
    // says so rather than inviting a second note.
    final requestId = '${DateTime.now().microsecondsSinceEpoch}';
    Future<void> record(
      String subject,
      String body,
      List<MessageRecipient> to, {
      required bool done,
    }) => controller.recordExcuse(
      requestId,
      excused,
      profileId: from,
      subject: subject,
      body: body,
      recipient: to.map((person) => person.name).join(', '),
      sent: done,
      days: _chosenDays,
      reasons: _reasonNames,
      planned: planned,
    );
    await _showComposeMessage(
      context,
      controller,
      beforeSend: (subject, body, to) => record(subject, body, to, done: false),
      onSent: (subject, body, to) {
        sent = true;
        return record(subject, body, to, done: true);
      },
    );
    if (sent && mounted) Navigator.pop(context);
  }

  Widget _reasonMenu(
    ExcuseReason value,
    ValueChanged<ExcuseReason> onChanged, {
    required Key key,
  }) {
    final theme = Theme.of(context);
    return PopupMenuButton<ExcuseReason>(
      key: key,
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final reason in ExcuseReason.values)
          PopupMenuItem(
            key: ValueKey('excuse-reason-${reason.name}'),
            value: reason,
            child: Text(context.tr('excuseReason_${reason.name}')),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 36, maxWidth: 190),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                context.tr('excuseReason_${value.name}'),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            AppIcon(
              Icons.arrow_drop_down_rounded,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _days;
    final label = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return ListView(
      primary: false,
      padding: EdgeInsets.fromLTRB(
        _Space.sheet,
        0,
        _Space.sheet,
        24 +
            MediaQuery.viewPaddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('excuseTitle'),
                style: _sheetTitleStyle(context),
              ),
            ),
            TextButton(
              key: const ValueKey('excuse-mode'),
              onPressed: () {
                setState(() {
                  planned = !planned;
                  error = null;
                });
                _regenerate();
              },
              child: Text(
                planned
                    ? '‹ ${context.tr('excuseAbsences')}'
                    : '${context.tr('excusePlanned')} ›',
              ),
            ),
          ],
        ),
        if (planned) ...[
          const SizedBox(height: 4),
          Text(context.tr('excusePlannedHint'), style: _metaStyle(context)),
        ],
        if (_children.length > 1) ...[
          const SizedBox(height: 12),
          Text(context.tr('excuseChild'), style: label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final id in _children)
                ChoiceChip(
                  key: ValueKey('excuse-child-$id'),
                  label: Text(controller.profileOf(id)?.displayName ?? ''),
                  selected: id == _profileId,
                  onSelected: (_) {
                    setState(() {
                      child = id;
                      teacher = null;
                    });
                    _chooseUnsent();
                    _findTeacher();
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: const ValueKey('excuse-teacher'),
            leading: AppIcon(
              Icons.send_rounded,
              color: theme.colorScheme.primary,
            ),
            title: Text(context.tr('excuseSendTo'), style: _metaStyle(context)),
            subtitle: Text(
              lookingForTeacher
                  ? '…'
                  : teacher == null
                  ? context.tr('excuseNoTeacher')
                  : context.trArgs('excuseTeacherName', {
                      'name': teacher!.name,
                    }),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (planned) ...[
          OutlinedButton.icon(
            key: const ValueKey('excuse-dates'),
            icon: const AppIcon(Icons.date_range_rounded),
            label: Text(
              range == null
                  ? context.tr('excuseDates')
                  : '${_shortDate(context, range!.start)} – '
                        '${_shortDate(context, range!.end)}',
            ),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year + 1, now.month, now.day),
                initialDateRange: range,
              );
              if (picked == null) return;
              range = picked;
              _regenerate();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(context.tr('excuseReason'), style: label)),
              _reasonMenu(plannedReason, (value) {
                plannedReason = value;
                _regenerate();
              }, key: const ValueKey('excuse-planned-reason')),
            ],
          ),
        ] else ...[
          Text(context.tr('excuseDays'), style: label),
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(context.tr('excuseNothing')),
            ),
          for (final row in days)
            Padding(
              key: ValueKey('excuse-day-${row.day.month}-${row.day.day}'),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    key: ValueKey(
                      'excuse-check-${row.day.month}-${row.day.day}',
                    ),
                    value: chosen.contains(row.day),
                    onChanged: (value) {
                      if (value ?? false) {
                        chosen.add(row.day);
                      } else {
                        chosen.remove(row.day);
                      }
                      _regenerate();
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_shortWeekday(context, row.day)} '
                          '${_shortDate(context, row.day)}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          [
                            _lessonsLabel(context, controller.snapshot, row),
                            if (row.records
                                    .map(controller.excuseSentAt)
                                    .nonNulls
                                    .firstOrNull
                                case final at?)
                              context.trArgs('excuseSentOn', {
                                'date': _shortDate(context, at),
                              }),
                          ].join(' · '),
                          style: _metaStyle(context),
                        ),
                      ],
                    ),
                  ),
                  if (chosen.contains(row.day))
                    _reasonMenu(
                      reasons[row.day] ?? ExcuseReason.unwell,
                      (value) {
                        reasons[row.day] = value;
                        _regenerate();
                      },
                      key: ValueKey(
                        'excuse-reason-${row.day.month}-${row.day.day}',
                      ),
                    ),
                ],
              ),
            ),
        ],
        if (_usesOther) ...[
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('excuse-other'),
            controller: other,
            textCapitalization: TextCapitalization.none,
            onChanged: (_) => _regenerate(),
            decoration: InputDecoration(
              labelText: context.tr('excuseOtherReason'),
              helperText: 'z powodu …',
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Wraps under the label when both do not fit.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(context.tr('excuseText'), style: label),
            _Segmented<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(
                    context.tr('excuseFromGenerator'),
                    key: const ValueKey('excuse-generator'),
                  ),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    context.tr('excuseOwn'),
                    key: const ValueKey('excuse-own'),
                  ),
                ),
              ],
              selected: {own},
              showSelectedIcon: false,
              onSelectionChanged: (value) => setState(() => own = value.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (own) ...[
          TextField(
            key: const ValueKey('excuse-own-text'),
            controller: ownText,
            minLines: 6,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.tr('excuseOwnLabel'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 6),
          Text(context.tr('excuseOwnHint'), style: _metaStyle(context)),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              PopupMenuButton<ExcuseChild>(
                key: const ValueKey('excuse-word'),
                initialValue: _word,
                onSelected: (word) => _setPreferences(
                  _preferences.copyWith(excuseChild: word.name),
                ),
                itemBuilder: (context) => [
                  for (final word in ExcuseChild.values)
                    PopupMenuItem(
                      key: ValueKey('excuse-word-${word.name}'),
                      value: word,
                      child: Text(word.nominative),
                    ),
                ],
                child: Chip(label: Text('${_word.nominative} ▾')),
              ),
              ActionChip(
                key: const ValueKey('excuse-greeting'),
                label: Text('$_greeting ✎'),
                onPressed: _editGreeting,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('excuse-preview'),
            controller: text,
            minLines: 4,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(context.tr('excuseGeneratorHint'), style: _metaStyle(context)),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            key: const ValueKey('excuse-error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('excuse-send'),
          style: _wideButton,
          icon: sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const AppIcon(Icons.send_rounded),
          label: Text(context.tr(planned ? 'excuseSendPlanned' : 'excuseSend')),
          onPressed: _ready ? _send : null,
        ),
      ],
    );
  }
}
