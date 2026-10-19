part of '../app_shell.dart';

IconData _notificationIcon(SchoolNotificationCategory category) =>
    switch (category) {
      SchoolNotificationCategory.grades => Icons.school_outlined,
      SchoolNotificationCategory.messages => Icons.mail_outline_rounded,
      SchoolNotificationCategory.announcements => Icons.campaign_outlined,
      SchoolNotificationCategory.notices => Icons.thumbs_up_down_outlined,
      SchoolNotificationCategory.attendance => Icons.fact_check_outlined,
      SchoolNotificationCategory.events => Icons.event_outlined,
      SchoolNotificationCategory.homework => Icons.assignment_outlined,
      SchoolNotificationCategory.timetable => Icons.calendar_view_week_outlined,
    };

Future<void> _showNotificationSettings(
  BuildContext context,
  AppController controller,
) {
  void denied(bool granted) {
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('notificationPermissionDenied'))),
      );
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
        final settings = controller.notificationSettings;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
            ),
            child: SingleChildScrollView(
              key: const ValueKey('notification-settings-sheet'),
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey('notifications-master'),
                    secondary: const _SettingsIcon(
                      Icons.notifications_active_outlined,
                    ),
                    title: Text(
                      sheetContext.tr('notifications'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(sheetContext.tr('notificationsDescription')),
                    value: settings.enabled,
                    onChanged: (value) async =>
                        denied(await controller.setNotificationsEnabled(value)),
                  ),
                  const Divider(height: 1),
                  for (final category in SchoolNotificationCategory.values)
                    SwitchListTile.adaptive(
                      key: ValueKey('notification-${category.name}'),
                      secondary: Icon(_notificationIcon(category)),
                      title: Text(
                        sheetContext.tr('notification_${category.name}'),
                      ),
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
                  const Divider(height: 24),
                  _ReminderSettings(controller, onPermission: denied),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// When the app reminds of tests: the evening before and the morning of,
/// each at its own time, and whether homework comes along.
class _ReminderSettings extends StatelessWidget {
  const _ReminderSettings(this.controller, {required this.onPermission});
  final AppController controller;
  final void Function(bool granted) onPermission;

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
          icon: Icons.nights_stay_outlined,
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
          icon: Icons.wb_sunny_outlined,
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
          secondary: const Icon(Icons.assignment_outlined),
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
  });
  final IconData icon;
  final String title;
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
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        '${time.format(context)} · ${context.tr('reminderChangeTime')}',
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
