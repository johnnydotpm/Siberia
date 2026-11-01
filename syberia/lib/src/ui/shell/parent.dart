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
      if (!mounted || profileId != id) return;
      setState(() {
        data = snapshot;
        history = sent;
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

  /// Whether the school excused every absence [request] was about.
  bool _excused(AbsenceRequest request) =>
      request.recordIds.isNotEmpty &&
      request.recordIds.every(
        (id) =>
            data?.attendance.any(
              (record) =>
                  record.id == id &&
                  record.kind == AttendanceKind.absentExcused,
            ) ??
            false,
      );

  @override
  Widget build(BuildContext context) => ListView(
    primary: false,
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
        icon: const Icon(Icons.edit_note_rounded),
        label: Text(context.tr('excuseAttendance')),
        onPressed: () async {
          await _showExcuseSheet(context, widget.controller);
          if (mounted) await _load();
        },
      ),
      const SizedBox(height: 16),
      if (!loading && history.isEmpty) Text(context.tr('noAbsences')),
      for (final request in history)
        ListTile(
          key: ValueKey('absence-history-${request.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            request.recipient.isEmpty
                ? _shortDate(context, request.at)
                : '${_shortDate(context, request.at)} · ${request.recipient}',
          ),
          subtitle: Text(
            context.tr(
              request.state == AbsenceRequestState.uncertain
                  ? 'absenceUncertain'
                  : _excused(request)
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
