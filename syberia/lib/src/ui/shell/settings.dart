part of '../app_shell.dart';

const _repositoryUrl = 'https://github.com/johnnydotpm/Siberia';

Future<void> _openLink(BuildContext context, String link) async {
  final opened = await launchUrl(
    Uri.parse(link),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(link)));
  }
}

class _Settings extends StatelessWidget {
  const _Settings(this.controller);
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final bridge = controller.homeWidget ?? const HomeWidgetBridge();
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final settings = controller.gradeAverage;
    final notifications = controller.notificationSettings;
    final enabledCategories = SchoolNotificationCategory.values
        .where(notifications.allows)
        .length;
    return _PageList(
      padding: const EdgeInsets.all(_Space.page),
      children: [
        _SettingsProfile(controller),
        _SettingsSection(
          title: context.tr('settingsAppearance'),
          children: [
            _PreviewChoice<AppColorMode>(
              title: context.tr('colorMode'),
              icon: Icons.brightness_6_rounded,
              selected: controller.colorMode,
              onSelected: controller.setColorMode,
              options: [
                for (final mode in AppColorMode.values)
                  (
                    value: mode,
                    label: context.tr('colorMode_${mode.name}'),
                    key: ValueKey('settings-theme-${mode.name}'),
                    preview: _ThemePreview(mode),
                  ),
              ],
            ),
            // Where the platform cannot draw glass there is nothing to choose.
            if (GlassPlatform.supported)
              _PreviewChoice<AppDesign>(
                title: context.tr('design'),
                icon: Icons.auto_awesome_rounded,
                selected: controller.design,
                onSelected: controller.setDesign,
                options: [
                  for (final design in AppDesign.values)
                    (
                      value: design,
                      label: context.tr('design_${design.name}'),
                      key: ValueKey('settings-design-${design.name}'),
                      preview: _DesignPreview(design),
                    ),
                ],
              ),
            ListTile(
              key: const ValueKey('settings-language'),
              leading: const _SettingsIcon(Icons.language_rounded),
              title: Text(context.tr('language')),
              subtitle: Text(_languageName(context, controller.locale)),
              trailing: const _Chevron(),
              onTap: () => _showLanguageSheet(context, controller),
            ),
          ],
        ),
        _SettingsSection(
          title: context.tr('settingsSyncNotifications'),
          children: [
            SwitchListTile.adaptive(
              secondary: const _SettingsIcon(Icons.sync_rounded),
              title: Text(context.tr('autoSyncOnOpen')),
              subtitle: Text(context.tr('autoSyncOnOpenDescription')),
              value: controller.autoSyncOnOpen,
              onChanged: controller.setAutoSyncOnOpen,
            ),
            ListTile(
              key: const ValueKey('settings-notifications'),
              leading: const _SettingsIcon(Icons.notifications_active_rounded),
              title: Text(context.tr('notifications')),
              subtitle: Text(
                notifications.enabled
                    ? context.trArgs('notificationsOn', {
                        'enabled': '$enabledCategories',
                        'total': '${SchoolNotificationCategory.values.length}',
                      })
                    : context.tr('notificationsOff'),
              ),
              trailing: const _Chevron(),
              onTap: () => _showNotificationSettings(context, controller),
            ),
          ],
        ),
        _SettingsSection(
          title: context.tr('settingsScreens'),
          children: [
            ListTile(
              key: const ValueKey('settings-today-screen'),
              leading: const _SettingsIcon(Icons.dashboard_customize_rounded),
              title: Text(context.tr('todayCustomizeSettings')),
              trailing: const _Chevron(),
              onTap: () => _showTodayLayoutSheet(context, controller),
            ),
            ListTile(
              key: const ValueKey('settings-timetable'),
              leading: const _SettingsIcon(Icons.calendar_view_week_rounded),
              title: Text(context.tr('timetable')),
              subtitle: Text(context.tr('timetableStyle')),
              trailing: const _Chevron(),
              onTap: () => _showTimetableSettings(context, controller),
            ),
            ListTile(
              key: const ValueKey('settings-short-names'),
              leading: const _SettingsIcon(Icons.short_text_rounded),
              title: Text(context.tr('shortSubjectNames')),
              subtitle: Text(context.tr('shortSubjectNamesDescription')),
              trailing: const _Chevron(),
              onTap: () => showAppSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => SubjectShortNamesSheet(controller: controller),
              ),
            ),
            _PreviewChoice<AttendanceChartStyle>(
              title: context.tr('attendanceChartStyle'),
              icon: Icons.donut_large_rounded,
              selected: controller.attendanceChartStyle,
              onSelected: controller.setAttendanceChartStyle,
              options: [
                for (final style in AttendanceChartStyle.values)
                  (
                    value: style,
                    label: context.tr('chartStyle_${style.name}'),
                    key: ValueKey('settings-chart-${style.name}'),
                    preview: _ChartPreview(style),
                  ),
              ],
            ),
          ],
        ),
        _SettingsSection(
          title: context.tr('grades'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (sign, key, value) in [
                    ('+', 'grade-plus', settings.plus),
                    ('-', 'grade-minus', settings.minus),
                  ]) ...[
                    if (sign == '-') const SizedBox(height: 16),
                    Row(
                      children: [
                        _SettingsIcon(
                          sign == '+'
                              ? Icons.add_rounded
                              : Icons.remove_rounded,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '${context.tr(sign == '+' ? 'gradePlusValue' : 'gradeMinusValue')} · 3$sign',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<double>(
                        key: ValueKey(key),
                        showSelectedIcon: false,
                        segments: [
                          for (final modifier
                              in GradeAverageSettings.modifierOptions)
                            ButtonSegment(
                              value: modifier,
                              label: Text(
                                _decimal(
                                  context,
                                  sign == '+' ? 3 + modifier : 3 - modifier,
                                ),
                              ),
                            ),
                        ],
                        selected: {value},
                        onSelectionChanged: (selection) =>
                            controller.setGradeAverageSettings(
                              sign == '+'
                                  ? settings.copyWith(plus: selection.first)
                                  : settings.copyWith(minus: selection.first),
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('grade-weighted'),
              secondary: const _SettingsIcon(Icons.balance_rounded),
              title: Text(context.tr('weightedAverage')),
              subtitle: Text(context.tr('weightedAverageDescription')),
              value: settings.weighted,
              onChanged: (value) => controller.setGradeAverageSettings(
                settings.copyWith(weighted: value),
              ),
            ),
            _AveragePreview(controller),
          ],
        ),
        if (bridge.configurableInApp || ios)
          _SettingsSection(
            title: context.tr('homeWidgets'),
            children: [_HomeWidgetsRow(bridge)],
          ),
        _SettingsSection(
          title: context.tr('settingsAbout'),
          children: [
            ListTile(
              leading: const _SettingsIcon(Icons.info_outline_rounded),
              title: Text('SiberiaGB ${AppBuildInfo.version}'),
              subtitle: Text(
                '${context.tr('buildCommit')}: ${AppBuildInfo.shortCommit}',
              ),
            ),
            _CheckUpdatesRow(controller),
            ListTile(
              key: const ValueKey('settings-whats-new'),
              leading: const _SettingsIcon(Icons.new_releases_rounded),
              title: Text(context.tr('whatsNew')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => _openLink(context, '$_repositoryUrl/releases'),
            ),
            ListTile(
              key: const ValueKey('settings-source'),
              leading: const _SettingsIcon(Icons.code_rounded),
              title: Text(context.tr('sourceCode')),
              subtitle: const Text('github.com/johnnydotpm/Siberia'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => _openLink(context, _repositoryUrl),
            ),
          ],
        ),
        const SizedBox(height: _Space.section),
        Center(
          child: TextButton.icon(
            key: const ValueKey('settings-reset'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _confirmResetSettings(context, controller),
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(context.tr('resetSettings')),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A titled group of settings in one card.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _Space.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GroupLabel(title, accent: true),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, child) in children.indexed) ...[
                  // From the text on, past the icon, as in the system's
                  // own settings.
                  if (index > 0) const Divider(height: 1, indent: 66),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The icon at the start of a settings row.
class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
    );
  }
}

/// The signed-in student, when the data was last synced, and a sync button.
class _SettingsProfile extends StatelessWidget {
  const _SettingsProfile(this.controller);
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final profile = controller.profileLook;
    final several = controller.profiles.length > 1;
    return Card(
      key: const ValueKey('settings-profile'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showProfiles(context, controller),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            children: [
              ProfileAvatar(
                name: profile.name,
                color: profile.color,
                radius: 28,
                news: controller.otherProfilesHaveNews,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      several
                          ? context.trArgs('profilesCount', {
                              'count': '${controller.profiles.length}',
                            })
                          : context.tr('profile'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                      ),
                    ),
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (profile.school.isNotEmpty)
                      Text(
                        profile.school,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.cloud_done_rounded, size: 15, color: muted),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _syncedAgo(context, controller.snapshot.lastSync),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (controller.syncing)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  key: const ValueKey('settings-sync'),
                  tooltip: context.tr('sync'),
                  onPressed: controller.sync,
                  icon: const Icon(Icons.sync_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Synced just now", "5 min ago", "2 h ago", or the date.
String _syncedAgo(BuildContext context, DateTime lastSync) {
  final elapsed = DateTime.now().difference(lastSync);
  if (elapsed.inMinutes < 1) return context.tr('syncedJustNow');
  if (elapsed.inHours < 1) {
    return context.trArgs('syncedMinutesAgo', {
      'minutes': '${elapsed.inMinutes}',
    });
  }
  if (elapsed.inHours < 24) {
    return context.trArgs('syncedHoursAgo', {'hours': '${elapsed.inHours}'});
  }
  return context.trArgs('syncedAt', {
    'date': '${_shortDate(context, lastSync)}, ${_time(lastSync)}',
  });
}

const _languageCodes = ['pl', 'en', 'ru', 'de', 'uk'];

String _languageName(BuildContext context, Locale? locale) =>
    switch (locale?.languageCode) {
      null => context.tr('systemLanguage'),
      'pl' => context.tr('polish'),
      'en' => context.tr('english'),
      'ru' => context.tr('russian'),
      'de' => context.tr('german'),
      'uk' => context.tr('ukrainian'),
      final code => code,
    };

Future<void> _showLanguageSheet(
  BuildContext context,
  AppController controller,
) => showAppSheet<void>(
  context: context,
  compact: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: Padding(
      key: const ValueKey('language-sheet'),
      // The rows' own 16 makes the sheet's 20.
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              sheetContext.tr('language'),
              style: _sheetTitleStyle(sheetContext),
            ),
          ),
          for (final code in [null, ..._languageCodes])
            ListTile(
              key: ValueKey('language-${code ?? 'system'}'),
              title: Text(
                _languageName(sheetContext, code == null ? null : Locale(code)),
              ),
              trailing: controller.locale?.languageCode == code
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                controller.setLocale(code == null ? null : Locale(code));
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    ),
  ),
);

class _HomeWidgetsRow extends StatefulWidget {
  const _HomeWidgetsRow(this.bridge);
  final HomeWidgetBridge bridge;

  @override
  State<_HomeWidgetsRow> createState() => _HomeWidgetsRowState();
}

class _HomeWidgetsRowState extends State<_HomeWidgetsRow> {
  late final Future<HomeWidgetStatus?> _status = widget.bridge.status();

  @override
  Widget build(BuildContext context) {
    final android = widget.bridge.configurableInApp;
    return ListTile(
      key: const ValueKey('settings-home-widgets'),
      leading: const _SettingsIcon(Icons.widgets_rounded),
      title: Text(context.tr('homeWidgets')),
      subtitle: android
          ? Text(context.tr('homeWidgetsDescription'))
          : FutureBuilder(
              future: _status,
              builder: (context, snapshot) {
                // A signer that dropped the app group leaves the widget
                // without data; say so instead of the hint.
                final status = snapshot.data;
                if (status != null && !status.shared) {
                  return Text(
                    context.tr('homeWidgetsIosNoGroup'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                return Text(context.tr('homeWidgetsIosHint'));
              },
            ),
      trailing: android ? const _Chevron() : null,
      onTap: android
          ? () => showAppSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (_) => HomeWidgetsSheet(bridge: widget.bridge),
            )
          : null,
    );
  }
}

class _CheckUpdatesRow extends StatefulWidget {
  const _CheckUpdatesRow(this.controller);
  final AppController controller;

  @override
  State<_CheckUpdatesRow> createState() => _CheckUpdatesRowState();
}

class _CheckUpdatesRowState extends State<_CheckUpdatesRow> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final latest = await widget.controller.checkForUpdateNow();
    if (!mounted) return;
    setState(() => _checking = false);
    final messenger = ScaffoldMessenger.of(context);
    if (latest == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('updateCheckFailed'))),
      );
    } else if (isNewerVersion(latest, AppBuildInfo.version)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.trArgs('updateAvailableShort', {'version': latest}),
          ),
          action: SnackBarAction(
            label: context.tr('openRelease'),
            onPressed: () =>
                _openLink(context, '$_repositoryUrl/releases/latest'),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('updateLatest'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('settings-check-updates'),
    leading: const _SettingsIcon(Icons.system_update_rounded),
    title: Text(context.tr('checkUpdates')),
    trailing: _checking
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const _Chevron(),
    onTap: _checking ? null : _check,
  );
}

Future<void> _confirmResetSettings(
  BuildContext context,
  AppController controller,
) async {
  final confirmed = await _confirm(
    context,
    title: context.tr('resetSettings'),
    message: context.tr('resetSettingsConfirm'),
    action: context.tr('resetDefaults'),
    actionKey: const ValueKey('settings-reset-confirm'),
  );
  if (!confirmed) return;
  await controller.resetSettings();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(context.tr('resetSettingsDone'))));
}
