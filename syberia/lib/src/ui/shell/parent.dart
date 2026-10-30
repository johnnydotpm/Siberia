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
                  current.bottomTabs
                      .map((tab) => _title(context, tab))
                      .join(' · '),
                ),
                onTap: () => _showParentTabs(context, controller, current),
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

Future<void> _showParentTabs(
  BuildContext context,
  AppController controller,
  SchoolProfile profile,
) async {
  final tabs = [...profile.bottomTabs];
  await showAppSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('parentTabs'), style: _sheetTitleStyle(context)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var tab = 0; tab < 10; tab++)
                  FilterChip(
                    label: Text(_title(context, tab)),
                    selected: tabs.contains(tab),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        if (tabs.length < 4) tabs.add(tab);
                      } else {
                        tabs.remove(tab);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: tabs.length == 4
                  ? () async {
                      await controller.setBottomTabs(profile.id, tabs);
                      if (context.mounted) Navigator.pop(context);
                    }
                  : null,
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ParentDashboard extends StatelessWidget {
  const _ParentDashboard(this.controller);
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FutureBuilder<List<(SchoolProfile, AppSnapshot)>>(
      future: controller.parentOverview(),
      builder: (context, result) {
        final rows = result.data ?? const <(SchoolProfile, AppSnapshot)>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (profile, data) in rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (controller.profileHasNews(profile.id))
                            const Badge(),
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          final now = DateTime.now();
                          final lessons =
                              data.lessons
                                  .where(
                                    (lesson) =>
                                        !lesson.cancelled &&
                                        _sameDay(lesson.start, now),
                                  )
                                  .toList()
                                ..sort((a, b) => a.end.compareTo(b.end));
                          final tests = data.events
                              .where(
                                (item) =>
                                    item.kind == EventKind.exam &&
                                    !item.date.isBefore(
                                      DateTime(now.year, now.month, now.day),
                                    ) &&
                                    item.date.isBefore(
                                      now.add(const Duration(days: 7)),
                                    ),
                              )
                              .length;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (lessons.isNotEmpty)
                                Text(
                                  '${context.tr('endsLessons')}: ${DateFormat.Hm().format(lessons.last.end)}',
                                ),
                              Text('${context.tr('upcomingExams')}: $tests'),
                              for (final event
                                  in data.events
                                      .where(
                                        (event) =>
                                            event.kind == EventKind.event &&
                                            !event.date.isBefore(
                                              DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                              ),
                                            ),
                                      )
                                      .take(2))
                                Text(
                                  '${_shortDate(context, event.date)} · ${event.title}',
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: ValueKey('parent-absences-${profile.id}'),
                        onPressed: () => _showAbsenceRequests(
                          context,
                          controller,
                          profileId: profile.id,
                        ),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(
                          '${context.tr('doJustify')} · ${unexcusedAbsences(data.attendance).length}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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

class _AbsenceSheetState extends State<_AbsenceSheet> {
  final reason = TextEditingController();
  late String? profileId =
      widget.profileId ?? widget.controller.activeProfile?.id;
  List<MessageRecipient> recipients = [];
  List<AbsenceRequest> history = [];
  AppSnapshot? data;
  MessageRecipient? recipient;
  final selected = <String>{};
  bool busy = false, loading = true;
  String? error;
  List<SchoolProfile> get profiles => widget.controller.profiles
      .where((profile) => profile.role == ProfileRole.parent)
      .toList();
  SchoolProfile? get profile => widget.controller.profileOf(profileId);
  @override
  void initState() {
    super.initState();
    if (!profiles.any((profile) => profile.id == profileId)) {
      profileId = profiles.firstOrNull?.id;
    }
    _load();
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
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
      final people = await widget.controller.fetchMessageRecipients(
        profileId: id,
      );
      final sent = await widget.controller.absenceRequests(id);
      if (!mounted || profileId != id) return;
      setState(() {
        data = snapshot;
        recipients = people;
        history = sent;
        loading = false;
        selected.removeWhere(
          (id) =>
              !unexcusedAbsences(snapshot.attendance)
                  .any((record) => record.id == id),
        );
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

  String _body() {
    final rows = unexcusedAbsences(data?.attendance ?? const [])
        .where((record) => selected.contains(record.id));
    return '${context.trArgs('absenceIntro', {'child': profile?.name ?? ''})}\n\n${rows.map((record) => '${_shortDate(context, record.date)} · ${record.lessonNumber}. ${record.subject}').join('\n')}\n\n${reason.text.trim()}';
  }

  Future<void> _preview() async {
    final id = profileId;
    final to = recipient;
    if (id == null ||
        to == null ||
        selected.isEmpty ||
        reason.text.trim().isEmpty ||
        busy) {
      return;
    }
    setState(() => busy = true);
    final subject = context.tr('absenceSubject');
    final body = _body();
    final records = Set<String>.of(selected);
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('absencePreview')),
          scrollable: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${profile?.displayName ?? ''} · ${context.tr(profile?.parent == true ? 'parentAccount' : 'studentAccount')}',
              ),
              Text(to.name),
              const SizedBox(height: 12),
              Text(subject),
              const SizedBox(height: 12),
              SelectableText(body),
              const SizedBox(height: 12),
              Text(context.tr('absenceSendConfirm')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              key: const ValueKey('absence-send-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('send')),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await widget.controller.sendAbsenceRequest(
        profileId: id,
        recordIds: records,
        recipient: to,
        subject: subject,
        body: body,
      );
      if (!mounted) return;
      setState(() {
        selected.clear();
        reason.clear();
        error = null;
      });
      await _load();
    } on Object {
      if (mounted) {
        setState(() => error = context.tr('absenceUncertain'));
        history = await widget.controller.absenceRequests(id);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _period() async {
    final rows = unexcusedAbsences(data?.attendance ?? const []);
    if (rows.isEmpty) return;
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: rows.first.date,
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: rows.first.date,
        end: rows.last.date.isAfter(now) ? now : rows.last.date,
      ),
    );
    if (range == null || !mounted) return;
    setState(() {
      selected
        ..clear()
        ..addAll(
          rows
              .where(
                (record) =>
                    !DateTime(
                      record.date.year,
                      record.date.month,
                      record.date.day,
                    ).isBefore(range.start) &&
                    !DateTime(
                      record.date.year,
                      record.date.month,
                      record.date.day,
                    ).isAfter(range.end),
              )
              .map((record) => record.id),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = unexcusedAbsences(data?.attendance ?? const []);
    return ListView(
      primary: false,
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Text(context.tr('absenceRequests'), style: _sheetTitleStyle(context)),
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
            onChanged: busy
                ? null
                : (id) {
                    setState(() {
                      profileId = id;
                      data = null;
                      selected.clear();
                      recipient = null;
                      reason.clear();
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
        TextButton(
          onPressed: busy ? null : _load,
          child: Text(context.tr('sync')),
        ),
        if (!loading && rows.isEmpty) Text(context.tr('noAbsences')),
        if (!loading && rows.isNotEmpty) ...[
          OutlinedButton(
            onPressed: busy ? null : _period,
            child: Text(context.tr('absencePeriod')),
          ),
          for (final record in rows)
            CheckboxListTile(
              key: ValueKey('absence-row-${record.id}'),
              title: Text(
                '${_shortDate(context, record.date)} · ${record.lessonNumber}. ${record.subject}',
              ),
              value: selected.contains(record.id),
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        selected.add(record.id);
                      } else {
                        selected.remove(record.id);
                      }
                    }),
            ),
          DropdownButtonFormField<int>(
            key: ValueKey('absence-recipient-$profileId'),
            initialValue: recipient?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('absenceRecipient'),
            ),
            items: [
              for (final person in recipients)
                DropdownMenuItem(
                  value: person.id,
                  child: Text(person.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: busy
                ? null
                : (id) => setState(
                    () => recipient = recipients
                        .where((person) => person.id == id)
                        .firstOrNull,
                  ),
          ),
          TextField(
            key: const ValueKey('absence-reason'),
            controller: reason,
            enabled: !busy,
            maxLines: 3,
            decoration: InputDecoration(labelText: context.tr('absenceReason')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('absence-preview'),
            onPressed:
                !busy &&
                    selected.isNotEmpty &&
                    recipient != null &&
                    reason.text.trim().isNotEmpty
                ? _preview
                : null,
            child: Text(context.tr('absencePreview')),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          context.tr('absenceHistory'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final request in history)
          ListTile(
            title: Text(
              '${_shortDate(context, request.at)} · ${request.recipient}',
            ),
            subtitle: Text(
              context.tr(
                request.state == AbsenceRequestState.uncertain
                    ? 'absenceUncertain'
                    : request.recordIds.isNotEmpty &&
                          request.recordIds.every(
                            (id) =>
                                data?.attendance.any(
                                  (record) =>
                                      record.id == id &&
                                      record.kind ==
                                          AttendanceKind.absentExcused,
                                ) ??
                                false,
                          )
                    ? 'absenceSchoolStatus'
                    : 'absenceSent',
              ),
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(request.subject),
                content: SingleChildScrollView(
                  child: SelectableText(request.body),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
