part of '../app_shell.dart';

/// What the setup was told, each row going back to its step.
class _SetupSummary extends StatelessWidget {
  const _SetupSummary({
    required this.controller,
    required this.permissionRefused,
    required this.onEdit,
  });

  final AppController controller;
  final bool permissionRefused;
  final ValueChanged<_SetupStep> onEdit;

  String _notifications(BuildContext context) {
    final settings = controller.notificationSettings;
    final kinds = SchoolNotificationCategory.values;
    final value = !settings.enabled
        ? context.tr('notifySummaryOff')
        : settings.everything
        ? context.tr('notifyAll')
        : context.trArgs('notifySummarySome', {
            'n': '${kinds.where(settings.allows).length}',
            'total': '${kinds.length}',
          });
    return settings.enabled && permissionRefused
        ? '$value · ${context.tr('notifyNoPermission')}'
        : value;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = controller.profiles;
    Widget row(
      String key,
      IconData icon,
      String label,
      String value,
      _SetupStep step,
    ) => ListTile(
      key: ValueKey('summary-$key'),
      leading: _SettingsIcon(icon),
      title: _WholeWords(label),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const _Chevron(),
      onTap: () => onEdit(step),
    );
    final rows = [
      row(
        'language',
        Icons.language_rounded,
        context.tr('language'),
        _languageName(context, controller.locale),
        _SetupStep.welcome,
      ),
      row(
        'theme',
        Icons.brightness_6_rounded,
        context.tr('colorMode'),
        context.tr('colorMode_${controller.colorMode.name}'),
        _SetupStep.appearance,
      ),
      if (GlassPlatform.supported)
        row(
          'design',
          Icons.auto_awesome_rounded,
          context.tr('design'),
          context.tr('design_${controller.design.name}'),
          _SetupStep.appearance,
        ),
      row(
        'profiles',
        Icons.switch_account_rounded,
        context.tr(controller.isParent ? 'children' : 'profiles'),
        profiles.isEmpty
            ? '—'
            : profiles.map((profile) => profile.displayName).join(', '),
        _SetupStep.account,
      ),
      row(
        'notifications',
        Icons.notifications_rounded,
        context.tr('notifications'),
        _notifications(context),
        _SetupStep.notifications,
      ),
    ];
    return Column(
      key: const ValueKey('setup-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupLabel(context.tr('onboardingSummary'), accent: true),
        if (controller.isParent)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(context.tr('parentTip')),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, child) in rows.indexed) ...[
                if (index > 0) const Divider(height: 1, indent: 66),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The home screen widget, offered on Android: the launcher's own dialog
/// places it, and once back the tip says it is there.
class _WidgetTip extends StatefulWidget {
  const _WidgetTip({required this.bridge, required this.tip});

  final HomeWidgetBridge? bridge;

  /// The tip shown around the button.
  final Widget Function(Widget? extra) tip;

  @override
  State<_WidgetTip> createState() => _WidgetTipState();
}

class _WidgetTipState extends State<_WidgetTip> with WidgetsBindingObserver {
  bool _canPin = false;
  bool _asked = false;
  bool _added = false;
  int _before = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    final bridge = widget.bridge;
    if (bridge == null) return;
    final canPin = await bridge.canPinWidget();
    final placed = await bridge.placedWidgets();
    if (!mounted) return;
    setState(() {
      _canPin = canPin;
      _before = placed.length;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _asked && !_added) {
      unawaited(_check());
    }
  }

  /// Back from the launcher's dialog: whether a widget was placed.
  Future<void> _check() async {
    final placed = await widget.bridge?.placedWidgets() ?? const [];
    if (mounted && placed.length > _before) {
      HapticFeedback.mediumImpact();
      setState(() => _added = true);
    }
  }

  Future<void> _pin() async {
    HapticFeedback.lightImpact();
    _asked = true;
    await widget.bridge?.pinWidget();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Widget? extra = _added
        ? Row(
            key: const ValueKey('onboarding-widget-added'),
            children: [
              Icon(Icons.check_circle_rounded, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('onboardingWidgetAdded'),
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          )
        : _canPin
        ? Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              key: const ValueKey('onboarding-pin-widget'),
              onPressed: _pin,
              icon: const Icon(Icons.add_to_home_screen_rounded),
              label: Text(context.tr('onboardingPinWidget')),
            ),
          )
        : null;
    return widget.tip(extra);
  }
}
