part of '../app_shell.dart';

/// The steps of the first setup, in order.
enum _SetupStep { welcome, appearance, account, notifications, done }

/// The first setup, as on a new phone: the language, the look, signing in
/// to Librus, notifications, and a few tips. A new install opens on it, and
/// Settings can run it again.
class _Onboarding extends StatefulWidget {
  const _Onboarding({required this.controller});
  final AppController controller;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final _pages = PageController();
  var _step = _SetupStep.welcome;

  /// Whether the system refused notifications at their step; the last step
  /// says where to turn them on.
  bool _permissionRefused = false;
  bool _asking = false;

  /// Run again from Settings, on a phone that is signed in already.
  late final bool _again = widget.controller.profiles.isNotEmpty;

  AppController get _controller => widget.controller;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(_SetupStep step) {
    setState(() => _step = step);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(step.index);
    } else {
      _pages.animateToPage(
        step.index,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_step.index > 0) {
      _go(_SetupStep.values[_step.index - 1]);
    } else if (_again) {
      // Run from Settings: going back from the first step leaves it.
      _controller.completeOnboarding();
    }
  }

  void _next() => _go(_SetupStep.values[_step.index + 1]);

  /// Asks for the permission once notifications are explained, if they are
  /// on, and goes on whatever the answer.
  Future<void> _allowNotifications() async {
    if (_controller.notificationSettings.needsBackgroundCheck) {
      setState(() => _asking = true);
      final granted = await _controller.askNotificationPermission();
      if (!mounted) return;
      setState(() {
        _asking = false;
        _permissionRefused = !granted;
      });
    }
    _next();
  }

  bool get _signedIn =>
      _controller.snapshot.profile.provider == 'Librus Synergia';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => PopScope(
      // The system back button steps back, and leaves the app only from
      // the first step of a new install.
      canPop: _step == _SetupStep.welcome && !_again,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _back();
      },
      child: Scaffold(
        key: const ValueKey('onboarding'),
        body: SafeArea(
          child: Column(
            children: [
              _SetupHeader(
                step: _step,
                onBack:
                    (_step.index > 0 || _again) &&
                        !_controller.syncing &&
                        !_asking
                    ? _back
                    : null,
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  // Each step decides when to go on.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _WelcomeStep(controller: _controller, onNext: _next),
                    _AppearanceStep(controller: _controller, onNext: _next),
                    _AccountStep(
                      controller: _controller,
                      onNext: _signedIn ? _next : null,
                      onSignedIn: _next,
                    ),
                    _NotificationsStep(
                      controller: _controller,
                      asking: _asking,
                      onSkip: _next,
                      onNext: _allowNotifications,
                    ),
                    _DoneStep(
                      permissionRefused: _permissionRefused,
                      onStart: _controller.completeOnboarding,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The back button and the dots that tell how far the setup has come.
class _SetupHeader extends StatelessWidget {
  const _SetupHeader({required this.step, required this.onBack});
  final _SetupStep step;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = _SetupStep.values.length;
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                key: const ValueKey('onboarding-back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          Semantics(
            label: context.trArgs('onboardingStep', {
              'n': '${step.index + 1}',
              'total': '$total',
            }),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < total; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: index == step.index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index <= step.index
                            ? colors.primary
                            : colors.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One step: a heading, its content scrolling when it does not fit, and the
/// buttons at the bottom.
class _SetupPage extends StatelessWidget {
  const _SetupPage({
    required this.title,
    required this.children,
    required this.actions,
    this.icon,
    this.top,
    this.text,
    super.key,
  });

  final IconData? icon;

  /// Shown instead of [icon], as the logo on the first step.
  final Widget? top;
  final String title;
  final String? text;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (top != null)
                      Center(child: top)
                    else if (icon != null)
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            size: 36,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _WholeWords(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (text != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        text!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _spaced(actions),
            ),
          ),
        ),
      ],
    );
  }
}

/// The wide button that goes on.
Widget _setupNext(
  BuildContext context,
  VoidCallback? onPressed, {
  String? label,
  bool busy = false,
}) => FilledButton(
  key: const ValueKey('onboarding-next'),
  style: _wideButton,
  onPressed: busy ? null : onPressed,
  child: busy
      ? const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Text(label ?? context.tr('onboardingNext')),
);

/// "Hello" in each language of the app, one after another, and the choice
/// of language. The logo hides the demo, as on the sign-in screen.
class _WelcomeStep extends StatefulWidget {
  const _WelcomeStep({required this.controller, required this.onNext});
  final AppController controller;
  final VoidCallback onNext;

  @override
  State<_WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<_WelcomeStep> {
  static const _greetings = ['Cześć', 'Hello', 'Привет', 'Hallo', 'Привіт'];

  /// Each language's name in itself, so anyone finds their own.
  static const _ownNames = {
    'pl': 'Polski',
    'en': 'English',
    'ru': 'Русский',
    'de': 'Deutsch',
    'uk': 'Українська',
  };

  Timer? _timer;
  var _greeting = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With animations off the greeting stays still.
    if (MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) {
          setState(() => _greeting = (_greeting + 1) % _greetings.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final chosen = controller.locale?.languageCode;
    return _SetupPage(
      key: const ValueKey('onboarding-welcome'),
      top: RawGestureDetector(
        key: const ValueKey('login-demo-logo'),
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(seconds: 5),
                ),
                (recognizer) => recognizer.onLongPress = controller.startDemo,
              ),
        },
        child: const AppLogo(),
      ),
      title: _greetings[_greeting],
      text: context.tr('onboardingLanguage'),
      actions: [_setupNext(context, widget.onNext)],
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final code in [null, ..._languageCodes])
                ListTile(
                  key: ValueKey('onboarding-language-${code ?? 'system'}'),
                  title: Text(
                    code == null
                        ? context.tr('systemLanguage')
                        : _ownNames[code]!,
                  ),
                  trailing: chosen == code
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  selected: chosen == code,
                  onTap: () =>
                      controller.setLocale(code == null ? null : Locale(code)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The theme and, where glass can be drawn, the design, each shown at once.
class _AppearanceStep extends StatelessWidget {
  const _AppearanceStep({required this.controller, required this.onNext});
  final AppController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _SetupPage(
    key: const ValueKey('onboarding-appearance'),
    icon: Icons.palette_outlined,
    title: context.tr('settingsAppearance'),
    text: context.tr('onboardingAppearanceText'),
    actions: [_setupNext(context, onNext)],
    children: [
      Card(
        child: Column(
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
                    key: ValueKey('onboarding-theme-${mode.name}'),
                    preview: _ThemePreview(mode),
                  ),
              ],
            ),
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
                      key: ValueKey('onboarding-design-${design.name}'),
                      preview: _DesignPreview(design),
                    ),
                ],
              ),
          ],
        ),
      ),
    ],
  );
}

/// Signing in to Librus. Once signed in, as when run again from Settings or
/// come back to with the back button, it lists the profiles and offers to add
/// one.
class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.controller,
    required this.onNext,
    required this.onSignedIn,
  });
  final AppController controller;

  /// Null until signed in.
  final VoidCallback? onNext;
  final VoidCallback onSignedIn;

  @override
  Widget build(BuildContext context) {
    final profiles = controller.profiles;
    final listed = profiles.isNotEmpty;
    return _SetupPage(
      key: const ValueKey('onboarding-account'),
      icon: Icons.school_rounded,
      title: context.tr(listed ? 'profiles' : 'onboardingAccount'),
      text: listed ? context.tr('onboardingProfilesText') : null,
      actions: [if (listed || onNext != null) _setupNext(context, onNext)],
      children: [
        if (listed) ...[
          for (final profile in profiles)
            _ProfileRow(
              name: profile.displayName,
              school: profile.school,
              color: profile.color,
              active: profile.id == controller.activeProfile?.id,
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('onboarding-add-profile'),
            onPressed: () => _showAddProfile(context, controller),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(context.tr('addProfile')),
          ),
        ] else
          _Login(controller, onSignedIn: onSignedIn),
      ],
    );
  }
}

/// What notifications come and when, said before the system asks for them.
class _NotificationsStep extends StatelessWidget {
  const _NotificationsStep({
    required this.controller,
    required this.asking,
    required this.onSkip,
    required this.onNext,
  });
  final AppController controller;
  final bool asking;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _SetupPage(
    key: const ValueKey('onboarding-notifications'),
    icon: Icons.notifications_active_rounded,
    title: context.tr('notifications'),
    text: context.tr('onboardingNotificationsText'),
    actions: [
      _setupNext(context, onNext, busy: asking),
      TextButton(
        key: const ValueKey('onboarding-skip'),
        onPressed: asking ? null : onSkip,
        child: Text(context.tr('onboardingSkip')),
      ),
    ],
    children: [
      Card(
        clipBehavior: Clip.antiAlias,
        child: _NotificationSettingsBody(controller, onPermission: (_) {}),
      ),
    ],
  );
}

/// The end: a few things worth knowing, and into the app.
class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.permissionRefused, required this.onStart});
  final bool permissionRefused;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final widgets =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    Widget tip(Key key, IconData icon, String text, {bool warning = false}) {
      final colors = Theme.of(context).colorScheme;
      return Card(
        key: key,
        color: warning ? colors.errorContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(_Space.inset),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: warning ? colors.onErrorContainer : colors.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: warning ? colors.onErrorContainer : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _SetupPage(
      key: const ValueKey('onboarding-done'),
      icon: Icons.check_rounded,
      title: context.tr('onboardingDoneTitle'),
      actions: [
        _setupNext(context, onStart, label: context.tr('onboardingStart')),
      ],
      children: _spaced([
        if (permissionRefused)
          tip(
            const ValueKey('onboarding-tip-permission'),
            Icons.notifications_off_rounded,
            context.tr('onboardingTipPermission'),
            warning: true,
          ),
        if (widgets)
          tip(
            const ValueKey('onboarding-tip-widget'),
            Icons.widgets_rounded,
            context.tr('onboardingTipWidget'),
          ),
        tip(
          const ValueKey('onboarding-tip-profiles'),
          Icons.switch_account_rounded,
          context.tr('onboardingTipProfiles'),
        ),
        tip(
          const ValueKey('onboarding-tip-short-names'),
          Icons.short_text_rounded,
          context.tr('onboardingTipShortNames'),
        ),
      ]),
    );
  }
}
