part of '../app_shell.dart';

/// Opens the debug menu when [child], the wordmark at the top of the side
/// menu, is held for [hold].
class _DebugMenuGesture extends StatelessWidget {
  const _DebugMenuGesture({required this.controller, required this.child});

  final AppController controller;
  final Widget child;

  static const hold = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    key: const ValueKey('debug-menu-gesture'),
    gestures: {
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(duration: hold),
            (recognizer) => recognizer.onLongPress = () {
              unawaited(HapticFeedback.heavyImpact());
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _DebugMenu(controller: controller),
                  ),
                ),
              );
            },
          ),
    },
    child: child,
  );
}

/// A developer's page, in English: the build and a report to copy, recent
/// errors and Librus requests, notifications to try, and the logos.
class _DebugMenu extends StatefulWidget {
  const _DebugMenu({required this.controller});

  final AppController controller;

  @override
  State<_DebugMenu> createState() => _DebugMenuState();
}

class _DebugMenuState extends State<_DebugMenu> {
  late Future<Map<String, String>> _about = _readAbout();
  late Future<List<String>> _reminders = widget.controller.scheduledReminders();
  late BrandEvent _preview = BrandEvents.override ?? BrandEvents.today();
  bool _checking = false;
  String? _checked;

  AppController get _controller => widget.controller;

  Future<Map<String, String>> _readAbout() async {
    final controller = _controller;
    final platform = kIsWeb
        ? 'web'
        : '${defaultTargetPlatform.name} ${Platform.operatingSystemVersion}';
    final syncs = await controller.profileSyncTimes();
    return {
      'Version': '${AppBuildInfo.version} (${AppBuildInfo.shortCommit})',
      'Platform': platform,
      'Language':
          controller.locale?.languageCode ??
          'system (${ui.PlatformDispatcher.instance.locale.languageCode})',
      'Theme': controller.colorMode.name,
      'Design': controller.design.name,
      'Demo': '${controller.isDemo}',
      'Profiles': '${controller.profiles.length}',
      for (final (index, at) in syncs.indexed)
        'Profile ${index + 1} synced': at.millisecondsSinceEpoch == 0
            ? 'never'
            : _debugTime(at),
      'Logo': BrandEvents.override == null
          ? BrandEvents.today().name
          : '${BrandEvents.override!.name} (chosen here)',
    };
  }

  /// Everything private the report must not hold: names, schools and
  /// logins of every profile.
  List<String> get _private => [
    for (final profile in _controller.profiles) ...[
      profile.name,
      profile.school,
      ?profile.label,
      ?profile.synergiaLogin,
      profile.account,
    ],
    _controller.snapshot.profile.name,
    _controller.snapshot.profile.school,
  ];

  Future<void> _copyReport() async {
    final report = Diagnostics.instance.report(
      about: await _about,
      private: _private,
    );
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Report copied. Names, logins, passwords and tokens are left out.',
        ),
      ),
    );
  }

  Future<void> _checkNow() async {
    setState(() {
      _checking = true;
      _checked = null;
    });
    String result;
    try {
      final checked = await _controller.checkInBackgroundNow();
      result = checked == 0
          ? 'Nothing fetched: notifications are off, or every profile '
                'synced in the last '
                '${AppRepository.backgroundPause.inMinutes} minutes.'
          : 'Fetched $checked ${checked == 1 ? 'profile' : 'profiles'}.';
    } on Object catch (error, stack) {
      Diagnostics.instance.recordError(error, stack, source: 'debug check');
      result = 'Failed: ${Diagnostics.scrub(error.toString())}';
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _checked = result;
      _reminders = _controller.scheduledReminders();
    });
  }

  void _pickLogo(BrandEvent event) => setState(() => _preview = event);

  Future<void> _keepLogo(bool keep) async {
    final event = keep ? _preview : null;
    BrandEvents.override = event;
    await _controller.saveLogoChoice(event?.name);
    if (!mounted) return;
    setState(() {
      _about = _readAbout();
    });
  }

  @override
  void dispose() {
    timeDilation = 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontFeatures: _tabular,
    );
    final diagnostics = Diagnostics.instance;
    final errors = diagnostics.errors.reversed.toList();
    final requests = diagnostics.requests.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: ListView(
        key: const ValueKey('debug-menu'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _GroupLabel('Build and report', accent: true),
          Card(
            child: FutureBuilder(
              future: _about,
              builder: (context, about) => Column(
                children: [
                  for (final MapEntry(:key, :value)
                      in (about.data ?? const {}).entries)
                    ListTile(
                      dense: true,
                      title: Text(key),
                      trailing: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: mono,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('debug-copy-report'),
            style: _wideButton,
            onPressed: _copyReport,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy report'),
          ),
          const SizedBox(height: 24),
          _GroupLabel('Errors (${errors.length})', accent: true),
          if (errors.isEmpty)
            const ListTile(title: Text('No errors since the app started.')),
          for (final error in errors)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${error.type}${error.times > 1 ? ' ×${error.times}' : ''}',
              ),
              subtitle: Text(
                '${_debugTime(error.at)} · ${error.source}\n${error.message}',
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _GroupLabel(
                  'Librus requests (${requests.length})',
                  accent: true,
                ),
              ),
              TextButton(
                onPressed: requests.isEmpty
                    ? null
                    : () => setState(diagnostics.clearRequests),
                child: const Text('Clear'),
              ),
            ],
          ),
          if (requests.isEmpty)
            const ListTile(title: Text('No requests since the app started.')),
          for (final request in requests)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(Diagnostics.describe(request), style: mono),
            ),
          const SizedBox(height: 24),
          const _GroupLabel('Notifications', accent: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in SchoolNotificationCategory.values)
                OutlinedButton(
                  key: ValueKey('debug-notify-${category.name}'),
                  onPressed: () =>
                      unawaited(_controller.showSampleNotification(category)),
                  child: Text(category.name),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Scheduled reminders', style: _rowTitleStyle(context)),
          FutureBuilder(
            future: _reminders,
            builder: (context, reminders) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reminders.data case final list? when list.isEmpty)
                  const Text('None.'),
                for (final reminder in reminders.data ?? const <String>[])
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(reminder),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            key: const ValueKey('debug-background-check'),
            style: _wideButton,
            onPressed: _checking ? null : _checkNow,
            icon: _checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_rounded),
            label: const Text('Run background check now'),
          ),
          if (_checked case final checked?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(checked),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const ValueKey('debug-refresh-widgets'),
            style: _wideButton,
            onPressed: () {
              _controller.refreshHomeWidget();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Widgets drawn again.')),
              );
            },
            icon: const Icon(Icons.widgets_rounded),
            label: const Text('Refresh widgets'),
          ),
          const SizedBox(height: 24),
          const _GroupLabel('Logos and animations', accent: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final event in BrandEvent.values)
                ChoiceChip(
                  key: ValueKey('debug-logo-${event.name}'),
                  label: Text(event.name),
                  selected: event == _preview,
                  onSelected: (_) => _pickLogo(event),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: AnimatedBrandLogo(key: ValueKey(_preview), event: _preview),
          ),
          SwitchListTile(
            key: const ValueKey('debug-keep-logo'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Show this logo at every launch'),
            subtitle: const Text('Until switched off here.'),
            value: BrandEvents.override == _preview,
            onChanged: _keepLogo,
          ),
          SwitchListTile(
            key: const ValueKey('debug-slow-motion'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Animations five times slower'),
            subtitle: const Text('Until this page is closed.'),
            value: timeDilation != 1,
            onChanged: (slow) => setState(() => timeDilation = slow ? 5 : 1),
          ),
        ],
      ),
    );
  }
}

String _debugTime(DateTime at) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(at.toLocal());
