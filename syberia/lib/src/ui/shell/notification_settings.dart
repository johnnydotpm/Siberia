part of '../app_shell.dart';

IconData _notificationIcon(SchoolNotificationCategory category) =>
    switch (category) {
      // The icons of the pages they come from.
      SchoolNotificationCategory.grades => Icons.school_rounded,
      SchoolNotificationCategory.messages => Icons.mail_rounded,
      SchoolNotificationCategory.announcements => Icons.campaign_rounded,
      SchoolNotificationCategory.notices => Icons.chat_bubble_rounded,
      SchoolNotificationCategory.attendance => Icons.fact_check_rounded,
      SchoolNotificationCategory.events => Icons.event_note_rounded,
      SchoolNotificationCategory.homework => Icons.assignment_rounded,
      SchoolNotificationCategory.timetable => Icons.calendar_view_week_rounded,
    };

Future<void> _showNotificationSettings(
  BuildContext context,
  AppController controller,
) {
  // Shown in the sheet: a SnackBar would appear behind it, and the switch
  // alone would look as if notifications were on.
  final permissionDenied = ValueNotifier(false);
  var open = true;
  // Changes only on the system's answer. Turning something off asks
  // nothing, so the notice stays while notifications still need it.
  void denied(bool? granted) {
    if (!open) return;
    if (granted != null) {
      permissionDenied.value = !granted;
    } else if (!controller.notificationSettings.needsBackgroundCheck) {
      permissionDenied.value = false;
    }
  }

  return showAppSheet<void>(
    context: context,
    compact: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: controller,
      builder: (sheetContext, _) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
            ),
            child: SingleChildScrollView(
              key: const ValueKey('notification-settings-sheet'),
              // The rows' own 16 makes the sheet's 20.
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: _NotificationSettingsBody(
                controller,
                onPermission: denied,
                afterMaster: ValueListenableBuilder(
                  valueListenable: permissionDenied,
                  builder: (context, shown, _) => shown
                      ? _PermissionDeniedNotice(
                          key: const ValueKey('notification-permission-denied'),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    ),
  ).whenComplete(() {
    open = false;
    permissionDenied.dispose();
  });
}

/// What notifications come and when: the master switch, the profiles, the
/// kinds of news and the test reminders. The settings sheet and the first
/// setup show it alike. [onPermission] gets what the system answered when a
/// change had to ask; [afterMaster] goes under the master switch.
class _NotificationSettingsBody extends StatelessWidget {
  const _NotificationSettingsBody(
    this.controller, {
    required this.onPermission,
    this.afterMaster,
    this.showMaster = true,
  });
  final AppController controller;
  final void Function(bool? granted) onPermission;
  final Widget? afterMaster;

  /// False in the setup, where "off" is a choice of its own.
  final bool showMaster;

  @override
  Widget build(BuildContext context) {
    final settings = controller.notificationSettings;
    final denied = onPermission;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMaster)
          SwitchListTile.adaptive(
            key: const ValueKey('notifications-master'),
            secondary: const _SettingsIcon(Icons.notifications_active_rounded),
            title: _WholeWords(
              context.tr('notifications'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(context.tr('notificationsDescription')),
            value: settings.enabled,
            onChanged: (value) async =>
                denied(await controller.setNotificationsEnabled(value)),
          ),
        ?afterMaster,
        if (controller.profiles.length > 1) ...[
          if (showMaster) const Divider(height: 1, indent: 16, endIndent: 16),
          _NotificationProfiles(controller),
        ],
        if (showMaster || controller.profiles.length > 1)
          const Divider(height: 1, indent: 16, endIndent: 16),
        for (final category in SchoolNotificationCategory.values)
          switch (category) {
            SchoolNotificationCategory.attendance =>
              _NotificationKindsTile<AttendanceKind>(
                controller: controller,
                category: category,
                onPermission: denied,
                // The ones that matter most first.
                options: const [
                  AttendanceKind.absent,
                  AttendanceKind.absentExcused,
                  AttendanceKind.late,
                  AttendanceKind.lateExcused,
                  AttendanceKind.released,
                  AttendanceKind.present,
                  AttendanceKind.other,
                ],
                label: (kind) => kind == AttendanceKind.other
                    ? 'otherAttendance'
                    : kind.name,
                chosen: settings.attendanceKinds,
                onChosen: (kinds) =>
                    controller.setNotificationKinds(attendance: kinds),
              ),
            SchoolNotificationCategory.timetable =>
              _NotificationKindsTile<TimetableChange>(
                controller: controller,
                category: category,
                onPermission: denied,
                options: TimetableChange.values,
                label: (change) => change.label,
                chosen: settings.timetableChanges,
                onChosen: (changes) =>
                    controller.setNotificationKinds(timetable: changes),
              ),
            _ => SwitchListTile.adaptive(
              key: ValueKey('notification-${category.name}'),
              secondary: _SettingsIcon(_notificationIcon(category)),
              title: Text(context.tr('notification_${category.name}')),
              value: settings.categories[category] ?? true,
              onChanged: settings.enabled
                  ? (value) async => denied(
                      await controller.setNotificationCategoryEnabled(
                        category,
                        value,
                      ),
                    )
                  : null,
            ),
          },
        const Divider(height: 24, indent: 16, endIndent: 16),
        _QuietHoursTile(controller),
        _ReminderTimeTile(
          key: const ValueKey('notify-digest'),
          icon: Icons.summarize_rounded,
          title: context.tr('digest'),
          description: context.tr('digestText'),
          minutes: settings.digestMinutes,
          value: settings.digest,
          enabled: settings.enabled,
          onChanged: (value) => controller.setDigest(on: value),
          onTime: (minutes) => controller.setDigest(minutes: minutes),
        ),
        const Divider(height: 24, indent: 16, endIndent: 16),
        _ReminderSettings(controller, onPermission: denied),
      ],
    );
  }
}

/// A switch for each profile: whether its news and reminders come. What
/// comes and when is the same for all of them.
class _NotificationProfiles extends StatelessWidget {
  const _NotificationProfiles(this.controller);
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.notificationSettings.enabled;
    return Column(
      key: const ValueKey('notification-profiles'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('profiles'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('notificationProfilesHelp'),
                style: _metaStyle(context),
              ),
            ],
          ),
        ),
        for (final profile in controller.profiles)
          SwitchListTile.adaptive(
            key: ValueKey('notification-profile-${profile.id}'),
            secondary: ProfileAvatar(
              name: profile.displayName,
              color: profile.color,
              radius: 18,
            ),
            title: Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: profile.school.isEmpty
                ? null
                : Text(
                    profile.school,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            value: profile.notify,
            onChanged: enabled
                ? (value) => controller.setProfileNotify(profile.id, value)
                : null,
          ),
      ],
    );
  }
}

/// A category with a switch that also opens, to pick which kinds of new
/// entries notify: only absences, say, or only cancelled lessons.
class _NotificationKindsTile<T extends Enum> extends StatefulWidget {
  const _NotificationKindsTile({
    required this.controller,
    required this.category,
    required this.onPermission,
    required this.options,
    required this.label,
    required this.chosen,
    required this.onChosen,
  });
  final AppController controller;
  final SchoolNotificationCategory category;
  final void Function(bool? granted) onPermission;
  final List<T> options;

  /// The translation key of an option.
  final String Function(T option) label;
  final Set<T> chosen;
  final Future<bool?> Function(Set<T> chosen) onChosen;

  @override
  State<_NotificationKindsTile<T>> createState() =>
      _NotificationKindsTileState<T>();
}

class _NotificationKindsTileState<T extends Enum>
    extends State<_NotificationKindsTile<T>> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.controller.notificationSettings;
    final category = widget.category;
    final on = settings.categories[category] ?? true;
    final active = settings.enabled && on;
    final chosen = [
      for (final option in widget.options)
        if (widget.chosen.contains(option)) option,
    ];
    final summary = chosen.length == widget.options.length
        ? context.tr('notificationKindsAll')
        : chosen.isEmpty
        ? context.tr('notificationKindsNone')
        : chosen.map((option) => context.tr(widget.label(option))).join(', ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: ValueKey('notification-${category.name}-open'),
          leading: _SettingsIcon(_notificationIcon(category)),
          title: Text(context.tr('notification_${category.name}')),
          subtitle: Text(
            summary,
            key: ValueKey('notification-${category.name}-summary'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => setState(() => expanded = !expanded),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Switch.adaptive(
                key: ValueKey('notification-${category.name}'),
                value: on,
                onChanged: settings.enabled
                    ? (value) async => widget.onPermission(
                        await widget.controller.setNotificationCategoryEnabled(
                          category,
                          value,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final option in widget.options)
                        CheckboxListTile.adaptive(
                          key: ValueKey(
                            'notification-${category.name}-${option.name}',
                          ),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(context.tr(widget.label(option))),
                          value: widget.chosen.contains(option),
                          onChanged: active
                              ? (value) async => widget.onPermission(
                                  await widget.onChosen(
                                    value == true
                                        ? {...widget.chosen, option}
                                        : ({...widget.chosen}..remove(option)),
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Notifications were turned on, but the system does not allow them.
class _PermissionDeniedNotice extends StatelessWidget {
  const _PermissionDeniedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('notificationPermissionDenied'),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// When the app reminds of tests: the evening before and the morning of,
/// each at its own time, and whether homework comes along.
class _ReminderSettings extends StatelessWidget {
  const _ReminderSettings(this.controller, {required this.onPermission});
  final AppController controller;
  final void Function(bool? granted) onPermission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = controller.notificationSettings;
    final reminders = settings.reminders;
    final enabled = settings.enabled;
    Future<void> change(TestReminderSettings next) async =>
        onPermission(await controller.setTestReminders(next));
    return Column(
      key: const ValueKey('reminder-settings'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
          child: Text(
            context.tr('reminders'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            context.tr('remindersDescription'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _ReminderTimeTile(
          key: const ValueKey('reminder-evening'),
          icon: Icons.nights_stay_rounded,
          title: context.tr('reminderEvening'),
          minutes: reminders.eveningMinutes,
          value: reminders.evening,
          enabled: enabled,
          onChanged: (value) => change(reminders.copyWith(evening: value)),
          onTime: (minutes) => change(
            reminders.copyWith(evening: true, eveningMinutes: minutes),
          ),
        ),
        _ReminderTimeTile(
          key: const ValueKey('reminder-morning'),
          icon: Icons.wb_sunny_rounded,
          title: context.tr('reminderMorning'),
          minutes: reminders.morningMinutes,
          value: reminders.morning,
          enabled: enabled,
          onChanged: (value) => change(reminders.copyWith(morning: value)),
          onTime: (minutes) => change(
            reminders.copyWith(morning: true, morningMinutes: minutes),
          ),
        ),
        SwitchListTile.adaptive(
          key: const ValueKey('reminder-homework'),
          secondary: const _SettingsIcon(Icons.assignment_rounded),
          title: Text(context.tr('reminderHomework')),
          subtitle: Text(context.tr('reminderHomeworkDescription')),
          value: reminders.homework,
          onChanged: enabled && reminders.any
              ? (value) => change(reminders.copyWith(homework: value))
              : null,
        ),
      ],
    );
  }
}

/// A reminder that can be switched on, with the time it comes at; a tap
/// changes the time.
class _ReminderTimeTile extends StatelessWidget {
  const _ReminderTimeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.minutes,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onTime,
    this.description,
  });
  final IconData icon;
  final String title;

  /// Said under the time, when the time alone does not say what it is for.
  final String? description;
  final int minutes;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final ValueChanged<int> onTime;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return ListTile(
      enabled: enabled,
      leading: _SettingsIcon(icon),
      title: Text(title),
      subtitle: Text(
        '${time.format(context)} · ${context.tr('reminderChangeTime')}'
        '${description == null ? '' : '\n$description'}',
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onTime(picked.hour * 60 + picked.minute);
      },
      trailing: Switch.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// Quiet hours: notifications without sound from one time to another. A tap
/// asks for the two times.
class _QuietHoursTile extends StatelessWidget {
  const _QuietHoursTile(this.controller);
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.notificationSettings;
    TimeOfDay time(int minutes) =>
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final from = time(settings.quietFromMinutes);
    final to = time(settings.quietToMinutes);
    return ListTile(
      key: const ValueKey('notify-quiet'),
      enabled: settings.enabled,
      leading: const _SettingsIcon(Icons.bedtime_rounded),
      title: Text(context.tr('quietHours')),
      subtitle: Text(
        '${from.format(context)}–${to.format(context)} · '
        '${context.tr('reminderChangeTime')}\n${context.tr('quietHoursText')}',
      ),
      onTap: () async {
        final start = await showTimePicker(context: context, initialTime: from);
        if (start == null || !context.mounted) return;
        final end = await showTimePicker(context: context, initialTime: to);
        if (end == null) return;
        await controller.setQuietHours(
          from: start.hour * 60 + start.minute,
          to: end.hour * 60 + end.minute,
        );
      },
      trailing: Switch.adaptive(
        value: settings.quietHours,
        onChanged: settings.enabled
            ? (value) => controller.setQuietHours(on: value)
            : null,
      ),
    );
  }
}
