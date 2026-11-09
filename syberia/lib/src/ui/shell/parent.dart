part of '../app_shell.dart';

Future<void> _showParentSettings(
  BuildContext context,
  AppController controller, {
  SchoolProfile? profile,
}) async {
  final id = (profile ?? controller.activeProfile)?.id;
  if (id == null) return;
  await showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * .82,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final current = controller.profileOf(id);
          if (current == null) return const SizedBox.shrink();
          final preferences = current.parentPreferences;
          Future<void> changeTime(bool start, {bool digest = false}) async {
            final minutes = digest
                ? preferences.digestAt
                : start
                ? preferences.quietStart
                : preferences.quietEnd;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
            );
            if (time == null) return;
            final latest =
                controller.profileOf(id)?.parentPreferences ?? preferences;
            final value = time.hour * 60 + time.minute;
            await controller.setParentPreferences(
              id,
              digest
                  ? latest.copyWith(digestAt: value)
                  : start
                  ? latest.copyWith(quietStart: value)
                  : latest.copyWith(quietEnd: value),
            );
          }

          String time(int minutes) => TimeOfDay(
            hour: minutes ~/ 60,
            minute: minutes % 60,
          ).format(context);
          return ListView(
            primary: false,
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                context.tr('parentSettings'),
                style: _sheetTitleStyle(context),
              ),
              Text(current.displayName),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProfileRole>(
                key: ValueKey('profile-role-${current.roleOverride}'),
                initialValue: current.roleOverride,
                decoration: InputDecoration(
                  labelText: context.tr('profileRole'),
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(context.tr('roleAuto')),
                  ),
                  for (final role in ProfileRole.values)
                    DropdownMenuItem(
                      value: role,
                      child: Text(
                        context.tr(
                          role == ProfileRole.parent
                              ? 'roleParent'
                              : 'roleStudent',
                        ),
                      ),
                    ),
                ],
                onChanged: (value) => controller.setProfileRole(id, value),
              ),
              const SizedBox(height: 8),
              Text(context.tr('roleInterfaceHint'), style: _metaStyle(context)),
              ListTile(
                title: Text(context.tr('parentTabs')),
                subtitle: Text(
                  controller
                      .bottomTabsOf(current)
                      .map((tab) => _title(context, tab))
                      .join(' · '),
                ),
                onTap: () =>
                    _showBottomTabsSheet(context, controller, profile: current),
              ),
              if (current.role == ProfileRole.parent) ...[
                SwitchListTile.adaptive(
                  key: const ValueKey('parent-quiet'),
                  title: Text(context.tr('quietHours')),
                  value: preferences.quiet,
                  onChanged: (value) => controller.setParentPreferences(
                    id,
                    preferences.copyWith(quiet: value),
                  ),
                ),
                if (preferences.quiet)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => changeTime(true),
                          child: Text(time(preferences.quietStart)),
                        ),
                      ),
                      const Text('–'),
                      Expanded(
                        child: TextButton(
                          onPressed: () => changeTime(false),
                          child: Text(time(preferences.quietEnd)),
                        ),
                      ),
                    ],
                  ),
                SwitchListTile.adaptive(
                  title: Text(context.tr('parentDigest')),
                  value: preferences.digest,
                  onChanged: (value) => controller.setParentPreferences(
                    id,
                    preferences.copyWith(digest: value),
                  ),
                ),
                if (preferences.digest)
                  TextButton(
                    onPressed: () => changeTime(false, digest: true),
                    child: Text(time(preferences.digestAt)),
                  ),
                SwitchListTile.adaptive(
                  title: Text(context.tr('studentTools')),
                  value: preferences.studentTools,
                  onChanged: (value) => controller.setParentPreferences(
                    id,
                    preferences.copyWith(studentTools: value),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

Future<void> _showAbsenceRequests(
  BuildContext context,
  AppController controller, {
  String? profileId,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .88,
    child: _AbsenceSheet(controller, profileId: profileId),
  ),
);

class _AbsenceSheet extends StatefulWidget {
  const _AbsenceSheet(this.controller, {this.profileId});
  final AppController controller;
  final String? profileId;
  @override
  State<_AbsenceSheet> createState() => _AbsenceSheetState();
}

/// The excuse notes sent of one child, newest first, each with how it
/// stands: sent, not sure whether it went, or excused by the school.
class _AbsenceSheetState extends State<_AbsenceSheet> {
  late String? profileId =
      widget.profileId ?? widget.controller.activeProfile?.id;
  List<AbsenceRequest> history = [];

  /// The notes the diary's own e-Usprawiedliwienia module keeps.
  List<SchoolJustification> fromDiary = [];
  AppSnapshot? data;
  bool loading = true;
  String? error;
  List<SchoolProfile> get profiles => widget.controller.profiles
      .where((profile) => profile.role == ProfileRole.parent)
      .toList();

  @override
  void initState() {
    super.initState();
    if (!profiles.any((profile) => profile.id == profileId)) {
      profileId = profiles.firstOrNull?.id;
    }
    _load();
  }

  Future<void> _load() async {
    final id = profileId;
    if (id == null) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final snapshot = await widget.controller.absenceSnapshot(id);
      final sent = await widget.controller.absenceRequests(id);
      // The diary's own notes are a bonus: without them the rest still shows.
      var kept = const <SchoolJustification>[];
      try {
        kept = await widget.controller.schoolJustifications(id);
      } on Object {
        // Offline, or a school without the module.
      }
      if (!mounted || profileId != id) return;
      setState(() {
        data = snapshot;
        history = sent;
        fromDiary = kept;
        loading = false;
      });
    } on Object {
      if (mounted && profileId == id) {
        setState(() {
          loading = false;
          error = context.tr('absenceRefresh');
        });
      }
    }
  }

  /// How [request] stands: not sure it went, accepted once the school
  /// excused all it was about, or waiting.
  String _status(AbsenceRequest request) {
    if (request.state == AbsenceRequestState.uncertain) {
      return 'excuseStatusUnsure';
    }
    final attendance = data?.attendance ?? const <AttendanceRecord>[];
    if (request.planned) {
      final last = request.days.isEmpty ? null : request.days.last;
      final today = DateTime.now();
      final over =
          last != null &&
          DateTime(last.year, last.month, last.day + 1).isBefore(today);
      final open = attendance.any(
        (record) =>
            record.kind == AttendanceKind.absent &&
            request.days.any((day) => _sameDay(day, record.date)),
      );
      return over && !open ? 'excuseStatusAccepted' : 'excuseStatusWaiting';
    }
    final excused =
        request.recordIds.isNotEmpty &&
        request.recordIds.every(
          (id) => attendance.any(
            (record) =>
                record.id == id && record.kind == AttendanceKind.absentExcused,
          ),
        );
    return excused ? 'excuseStatusAccepted' : 'excuseStatusWaiting';
  }

  /// The first message from whom [request] went to after it went: the
  /// class teacher's answer, if there is one.
  SchoolMessage? _reply(AbsenceRequest request) {
    final to = request.recipient.trim();
    if (to.isEmpty) return null;
    final replies =
        (data?.messages ?? const <SchoolMessage>[])
            .where(
              (message) =>
                  message.sender.trim() == to &&
                  message.receivedAt.isAfter(request.at),
            )
            .toList()
          ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    return replies.firstOrNull;
  }

  /// "wt 27.10 · lekcje 1–2", or "3–5.11 · planowana".
  String _when(BuildContext context, AbsenceRequest request) {
    final days = [...request.days]..sort();
    if (days.isEmpty) return _shortDate(context, request.at);
    if (request.planned) {
      final range = days.length == 1
          ? _shortDate(context, days.first)
          : '${_shortDate(context, days.first)} – ${_shortDate(context, days.last)}';
      return '$range · ${context.tr('excusePlannedTag')}';
    }
    return [
      for (final day in days)
        '${_shortWeekday(context, day)} ${_shortDate(context, day)}',
    ].join(', ');
  }

  Widget _card(BuildContext context, AbsenceRequest request) {
    final theme = Theme.of(context);
    final status = _status(request);
    final reply = _reply(request);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (background, foreground) = switch (status) {
      'excuseStatusAccepted' => (
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
      'excuseStatusUnsure' => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      _ => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
    };
    return Card(
      key: ValueKey('absence-history-${request.id}'),
      margin: const EdgeInsets.only(bottom: _Space.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(request.subject),
            content: SingleChildScrollView(child: SelectableText(request.body)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_Space.inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _when(context, request),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    key: ValueKey('absence-status-${request.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.tr(status),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
              if (request.reasons.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _capitalize(
                    request.reasons
                        .map((name) => context.tr('excuseReason_$name'))
                        .join(' · '),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                [
                  context.trArgs('excuseSentTime', {
                    'date':
                        '${_shortDate(context, request.at)}, '
                        '${DateFormat.Hm(locale).format(request.at)}',
                  }),
                  if (request.recipient.isNotEmpty) request.recipient,
                ].join(' · '),
                style: _metaStyle(context),
              ),
              if (reply != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: ValueKey('absence-reply-${request.id}'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('excuseTeacherReplied'),
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reply.preview.isEmpty ? reply.subject : reply.preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  key: ValueKey('absence-write-${request.id}'),
                  icon: const AppIcon(Icons.reply_rounded),
                  label: Text(context.tr('excuseWriteTeacher')),
                  onPressed: () {
                    final view = widget.controller.snapshot.profile.id;
                    _ComposeDraft.kept[widget.controller] = _ComposeDraft(
                      view: view,
                      from: widget.controller.together ? profileId : null,
                      recipients: const [],
                      subject: 'Re: ${request.subject}',
                      body: '',
                    );
                    _showComposeMessage(context, widget.controller);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A note the diary's module keeps, with the school's answer.
  Widget _diaryCard(BuildContext context, SchoolJustification note) {
    final theme = Theme.of(context);
    final (label, background, foreground) = switch (note.state) {
      JustificationState.accepted => (
        context.tr('excuseStatusAccepted'),
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
      JustificationState.rejected => (
        context.tr('excuseStatusRejected'),
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      JustificationState.pending => (
        context.tr('excuseStatusWaiting'),
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      // A word not known yet is shown as the diary says it.
      JustificationState.unknown => (
        note.status.isEmpty ? '?' : note.status,
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
      ),
    };
    final from = note.from;
    final to = note.to;
    final when = from == null
        ? (note.postedAt == null ? '' : _shortDate(context, note.postedAt!))
        : to == null || _sameDay(from, to)
        ? _shortDate(context, from)
        : '${_shortDate(context, from)} – ${_shortDate(context, to)}';
    return Card(
      key: ValueKey('absence-diary-${note.id}'),
      margin: const EdgeInsets.only(bottom: _Space.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: note.message.isEmpty
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(when),
                  content: SingleChildScrollView(
                    child: SelectableText(note.message),
                  ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(_Space.inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(when, style: theme.textTheme.titleMedium),
                  ),
                  Container(
                    key: ValueKey('absence-diary-status-${note.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
              if (note.message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                [
                  if (note.postedAt case final at?)
                    context.trArgs('excuseSentTime', {
                      'date': _shortDate(context, at),
                    }),
                  if (note.justified > 0)
                    context.trArgs('excuseJustifiedCount', {
                      'count': '${note.justified}',
                    }),
                  if (note.teachers.isNotEmpty)
                    note.teachers.every((name) => name.isNotEmpty)
                        ? note.teachers.join(', ')
                        : context.trArgs('excuseNotifiedCount', {
                            'count': '${note.teachers.length}',
                          }),
                ].join(' · '),
                style: _metaStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = <DateTime, List<AbsenceRequest>>{};
    for (final request in [...history]..sort((a, b) => b.at.compareTo(a.at))) {
      final day = request.days.isEmpty ? request.at : request.days.first;
      months.putIfAbsent(DateTime(day.year, day.month), () => []).add(request);
    }
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Text(
          context.tr('excuseHistoryTitle'),
          style: _sheetTitleStyle(context),
        ),
        const SizedBox(height: 12),
        if (profiles.length > 1)
          DropdownButtonFormField<String>(
            initialValue: profileId,
            decoration: InputDecoration(labelText: context.tr('children')),
            items: [
              for (final profile in profiles)
                DropdownMenuItem(
                  value: profile.id,
                  child: Text(profile.displayName),
                ),
            ],
            onChanged: (id) {
              setState(() {
                profileId = id;
                data = null;
                history = [];
              });
              _load();
            },
          ),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton.tonalIcon(
          key: const ValueKey('absence-history-new'),
          style: _wideButton,
          icon: const AppIcon(Icons.edit_note_rounded),
          label: Text(context.tr('excuseAttendance')),
          onPressed: () async {
            await _showExcuseSheet(context, widget.controller);
            if (mounted) await _load();
          },
        ),
        const SizedBox(height: 16),
        if (!loading && history.isEmpty && fromDiary.isEmpty)
          Text(context.tr('excuseHistoryEmpty')),
        if (fromDiary.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              context.tr('excuseInLibrus'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final note in fromDiary) _diaryCard(context, note),
        ],
        for (final MapEntry(key: month, value: requests) in months.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              _monthHeading(context, month, now),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final request in requests) _card(context, request),
        ],
      ],
    );
  }
}
