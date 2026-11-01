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
Future<void> _showExcuseSheet(BuildContext context, AppController controller) =>
    showAppSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExcuseSheet(controller),
    );

class _ExcuseSheet extends StatefulWidget {
  const _ExcuseSheet(this.controller);
  final AppController controller;

  @override
  State<_ExcuseSheet> createState() => _ExcuseSheetState();
}

class _ExcuseSheetState extends State<_ExcuseSheet> {
  AppController get controller => widget.controller;
  bool planned = false;
  ExcuseReason reason = ExcuseReason.illness;
  final note = TextEditingController();
  DateTimeRange? range;
  bool preparing = false;

  /// The profile the note goes from, all together: whose absences they are.
  String? child;
  late final Set<String> chosen = {
    for (final record in _absences)
      if (controller.excuseSentAt(record) == null) record.id,
  };

  late final List<AttendanceRecord> _all = _absencesToExcuse(
    controller.snapshot,
    DateTime.now(),
  );

  /// The children who have absences, all together; one note goes from one.
  List<String> get _children => controller.together
      ? [
          for (final profile in controller.togetherProfiles)
            if (planned || _all.any((record) => record.source == profile.id))
              profile.id,
        ]
      : const [];

  List<AttendanceRecord> get _absences => [
    for (final record in _all)
      if (!controller.together || record.source == (child ?? _firstChild))
        record,
  ];

  String? get _firstChild =>
      _children.firstOrNull ?? controller.togetherProfiles.firstOrNull?.id;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  String get _childName {
    final profile = controller.together
        ? controller.profileOf(child ?? _firstChild)
        : controller.activeProfile;
    final name = profile?.name ?? controller.snapshot.profile.name;
    return name.isEmpty ? (profile?.displayName ?? '') : name;
  }

  ({String subject, String body}) get _message => excuseMessage(
    child: _childName,
    lessons: planned
        ? const []
        : [
            for (final record in _absences)
              if (chosen.contains(record.id))
                (
                  date: record.date,
                  lesson: record.lessonNumber,
                  subject: record.subject,
                ),
          ],
    from: planned ? range?.start : null,
    to: planned ? range?.end : null,
    reason: reason,
    note: note.text,
    signature: controller.excuseSignature,
  );

  bool get _ready =>
      (planned
          ? range != null
          : _absences.any((record) => chosen.contains(record.id))) &&
      (reason != ExcuseReason.other || note.text.trim().isNotEmpty);

  Future<void> _prepare() async {
    setState(() => preparing = true);
    final from = controller.together ? (child ?? _firstChild) : null;
    var teacher = <MessageRecipient>[];
    try {
      final recipients = await controller.fetchMessageRecipients(
        profileId: from,
      );
      teacher = [?_classTeacher(recipients)];
    } on Object {
      // The teacher is then picked in the message.
    }
    if (!mounted) return;
    setState(() => preparing = false);
    final message = _message;
    final excused = [
      if (!planned)
        for (final record in _absences)
          if (chosen.contains(record.id)) record,
    ];
    _ComposeDraft.kept[controller] = _ComposeDraft(
      view: controller.snapshot.profile.id,
      from: from,
      recipients: teacher,
      subject: message.subject,
      body: message.body,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final absences = _absences;
    return ListView(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.fromLTRB(
        _Space.sheet,
        0,
        _Space.sheet,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        Text(context.tr('excuseTitle'), style: _sheetTitleStyle(context)),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(
                context.tr('excuseAbsences'),
                key: const ValueKey('excuse-mode-absences'),
              ),
            ),
            ButtonSegment(
              value: true,
              label: Text(
                context.tr('excusePlanned'),
                key: const ValueKey('excuse-mode-planned'),
              ),
            ),
          ],
          selected: {planned},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => planned = value.first),
        ),
        if (_children.length > 1) ...[
          const SizedBox(height: 12),
          Text(context.tr('excuseChild'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final id in _children)
                ChoiceChip(
                  key: ValueKey('excuse-child-$id'),
                  label: Text(controller.profileOf(id)?.displayName ?? ''),
                  selected: id == (child ?? _firstChild),
                  onSelected: (_) => setState(() {
                    child = id;
                    chosen
                      ..clear()
                      ..addAll([
                        for (final record in _absences)
                          if (controller.excuseSentAt(record) == null)
                            record.id,
                      ]);
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (planned)
          OutlinedButton.icon(
            key: const ValueKey('excuse-dates'),
            icon: const Icon(Icons.date_range_rounded),
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
              if (picked != null) setState(() => range = picked);
            },
          )
        else
          for (final record in absences)
            CheckboxListTile(
              key: ValueKey('excuse-absence-${record.id}'),
              contentPadding: EdgeInsets.zero,
              value: chosen.contains(record.id),
              onChanged: (value) => setState(() {
                if (value ?? false) {
                  chosen.add(record.id);
                } else {
                  chosen.remove(record.id);
                }
              }),
              title: Text(
                '${_shortWeekday(context, record.date)} '
                '${_shortDate(context, record.date)}'
                '${record.lessonNumber > 0 ? ' · ${context.trArgs('lessonNumber', {'number': '${record.lessonNumber}'})}' : ''}',
              ),
              subtitle: Text(
                [
                  if (record.subject.isNotEmpty) record.subject,
                  if (controller.excuseSentAt(record) case final at?)
                    context.trArgs('excuseSentOn', {
                      'date': _shortDate(context, at),
                    }),
                ].join(' · '),
              ),
            ),
        const SizedBox(height: 12),
        Text(context.tr('excuseReason'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (value, label) in [
              (ExcuseReason.illness, 'excuseReasonIllness'),
              (ExcuseReason.doctor, 'excuseReasonDoctor'),
              (ExcuseReason.family, 'excuseReasonFamily'),
              (ExcuseReason.other, 'excuseReasonOther'),
            ])
              ChoiceChip(
                key: ValueKey('excuse-reason-${value.name}'),
                label: Text(context.tr(label)),
                selected: reason == value,
                onSelected: (_) => setState(() => reason = value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('excuse-note'),
          controller: note,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: context.tr(
              reason == ExcuseReason.other ? 'excuseOtherReason' : 'excuseNote',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(context.tr('excusePreview'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(_Space.inset),
            child: Text(
              _message.body,
              key: const ValueKey('excuse-preview'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(context.tr('excusePolishNote'), style: _metaStyle(context)),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('excuse-prepare'),
          style: _wideButton,
          icon: preparing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.edit_rounded),
          label: Text(context.tr('excusePrepare')),
          onPressed: _ready && !preparing ? _prepare : null,
        ),
      ],
    );
  }
}
