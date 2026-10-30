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

/// How a step moves: its parts come in with [entrance], and its badge plays
/// while it is [active], and again each time [replay] changes.
typedef _StepMotion = ({Animation<double> entrance, bool active, int replay});

class _OnboardingState extends State<_Onboarding>
    with TickerProviderStateMixin {
  final _pages = PageController();
  var _step = _SetupStep.welcome;

  /// The parts of the open step coming in one after another.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  bool _entered = false;

  /// A moment for the bell to ring once notifications are allowed.
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// Counts the times the system allowed notifications, for the bell to
  /// ring again.
  int _allowed = 0;

  /// Whether the system refused notifications at their step; the last step
  /// says where to turn them on.
  bool _permissionRefused = false;
  bool _asking = false;

  /// Run again from Settings, on a phone that is signed in already.
  late final bool _again = widget.controller.profiles.isNotEmpty;

  /// The startup animation to open on, until its mark has landed on the
  /// first step's logo.
  Duration? _intro;

  /// Whether the logo of the first step came with the animation, rather
  /// than rising with the rest.
  bool _logoFlew = false;
  final _logoKey = GlobalKey();

  AppController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _intro = _controller.takeIntro();
    _logoFlew = _intro != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      // With less motion the first step shows at once.
      _intro = null;
      _logoFlew = false;
      _entrance.value = 1;
    } else if (!_entered && _intro == null) {
      _comeIn();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _entrance.dispose();
    _ring.dispose();
    super.dispose();
  }

  /// The open step's parts come in.
  void _comeIn() {
    _entered = true;
    if (_reduceMotion(context)) {
      _entrance.value = 1;
    } else {
      unawaited(_entrance.forward(from: 0));
    }
  }

  _StepMotion _motion(_SetupStep step) => (
    entrance: step == _step ? _entrance : kAlwaysCompleteAnimation,
    active: step == _step,
    replay: step == _SetupStep.notifications ? _allowed : 0,
  );

  void _go(_SetupStep step) {
    setState(() => _step = step);
    _comeIn();
    // The end is felt.
    if (step == _SetupStep.done) HapticFeedback.mediumImpact();
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
    HapticFeedback.lightImpact();
    if (_step.index > 0) {
      _go(_SetupStep.values[_step.index - 1]);
    } else if (_again) {
      // Run from Settings: going back from the first step leaves it.
      _finish();
    }
  }

  void _next() {
    HapticFeedback.lightImpact();
    _go(_SetupStep.values[_step.index + 1]);
  }

  /// Out of the setup: it moves back and the app comes forward.
  void _finish() => ScreenTransitions.run(
    context,
    ScreenChange.zoom,
    _controller.completeOnboarding,
  );

  /// Asks for the permission once notifications are explained, if they are
  /// on, and goes on whatever the answer.
  Future<void> _allowNotifications() async {
    if (_controller.notificationSettings.needsBackgroundCheck) {
      setState(() => _asking = true);
      final granted = await _controller.askNotificationPermission();
      if (!mounted) return;
      setState(() {
        _permissionRefused = !granted;
        // The bell rings for it, and the step waits for it to.
        if (granted) _allowed++;
      });
      if (granted && !_reduceMotion(context)) {
        try {
          await _ring.forward(from: 0).orCancel;
        } on TickerCanceled {
          return;
        }
        if (!mounted) return;
      }
      setState(() => _asking = false);
    }
    _next();
  }

  bool get _signedIn =>
      _controller.snapshot.profile.provider == 'Librus Synergia';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        _setup(context),
        if (_intro case final intro?)
          _SetupIntro(
            key: const ValueKey('setup-intro'),
            event: BrandEventScope.of(context),
            from: intro,
            target: _logoKey,
            background: startupBackground(
              Theme.of(context).brightness,
              amoled: _controller.colorMode == AppColorMode.amoled,
            ),
            onFlight: _comeIn,
            onDone: () => setState(() => _intro = null),
          ),
      ],
    ),
  );

  Widget _setup(BuildContext context) => PopScope(
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
                  _WelcomeStep(
                    controller: _controller,
                    motion: _motion(_SetupStep.welcome),
                    onNext: _next,
                    logoKey: _logoKey,
                    // Until the mark of the animation lands on it.
                    hideLogo: _intro != null,
                    logoFlew: _logoFlew,
                  ),
                  _AppearanceStep(
                    controller: _controller,
                    motion: _motion(_SetupStep.appearance),
                    onNext: _next,
                  ),
                  _AccountStep(
                    controller: _controller,
                    motion: _motion(_SetupStep.account),
                    onNext: _signedIn ? _next : null,
                    onSignedIn: () => _go(_SetupStep.notifications),
                  ),
                  _NotificationsStep(
                    controller: _controller,
                    motion: _motion(_SetupStep.notifications),
                    asking: _asking,
                    onSkip: _next,
                    onNext: _allowNotifications,
                  ),
                  _DoneStep(
                    controller: _controller,
                    motion: _motion(_SetupStep.done),
                    permissionRefused: _permissionRefused,
                    onEdit: (step) {
                      HapticFeedback.lightImpact();
                      _go(step);
                    },
                    onStart: _finish,
                  ),
                ],
              ),
            ),
          ],
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
    required this.motion,
    this.icon,
    this.badge = _BadgeMotion.palette,
    this.top,
    this.titleWidget,
    this.riseTop = true,
    this.text,
    super.key,
  });

  final IconData? icon;

  /// How the badge of [icon] comes alive.
  final _BadgeMotion badge;

  /// Shown instead of [icon], as the logo on the first step.
  final Widget? top;
  final String title;

  /// Shown instead of [title], as the greetings on the first step.
  final Widget? titleWidget;

  /// Whether [top] comes in with the rest; the logo that the startup
  /// animation brings stays where it landed.
  final bool riseTop;
  final String? text;
  final List<Widget> children;
  final List<Widget> actions;
  final _StepMotion motion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var order = 0;
    Widget rise(Widget child) =>
        _Rise(animation: motion.entrance, index: order++, child: child);
    final heading =
        titleWidget ??
        _WholeWords(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        );
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
                    if (top case final top?)
                      riseTop ? rise(Center(child: top)) : Center(child: top)
                    else if (icon case final icon?)
                      rise(
                        Center(
                          child: _StepBadge(
                            icon: icon,
                            motion: badge,
                            active: motion.active,
                            replay: motion.replay,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    rise(heading),
                    if (text != null) ...[
                      const SizedBox(height: 10),
                      rise(
                        Text(
                          text!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    for (final child in children) rise(child),
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
            child: rise(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _spaced(actions),
              ),
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
  const _WelcomeStep({
    required this.controller,
    required this.motion,
    required this.onNext,
    required this.logoKey,
    required this.hideLogo,
    required this.logoFlew,
  });
  final AppController controller;
  final _StepMotion motion;
  final VoidCallback onNext;

  /// On the logo, where the startup animation's mark lands.
  final GlobalKey logoKey;
  final bool hideLogo;
  final bool logoFlew;

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
    _greet();
  }

  @override
  void didUpdateWidget(_WelcomeStep old) {
    super.didUpdateWidget(old);
    if (old.hideLogo != widget.hideLogo) _greet();
  }

  /// The greetings go round once the page is in view, and stay still with
  /// less motion.
  void _greet() {
    if (MediaQuery.disableAnimationsOf(context) || widget.hideLogo) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(milliseconds: 2400), (_) {
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
      motion: widget.motion,
      riseTop: !widget.logoFlew,
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
        child: Opacity(
          opacity: widget.hideLogo ? 0 : 1,
          child: AppLogo(key: widget.logoKey),
        ),
      ),
      title: _greetings[_greeting],
      titleWidget: _GreetingSwitcher(
        text: _greetings[_greeting],
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
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
                  onTap: () {
                    if (chosen == code) return;
                    HapticFeedback.selectionClick();
                    // The texts dissolve into the new language.
                    ScreenTransitions.run(
                      context,
                      ScreenChange.dissolve,
                      () => controller.setLocale(
                        code == null ? null : Locale(code),
                      ),
                    );
                  },
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
  const _AppearanceStep({
    required this.controller,
    required this.motion,
    required this.onNext,
  });
  final AppController controller;
  final _StepMotion motion;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _SetupPage(
    key: const ValueKey('onboarding-appearance'),
    motion: motion,
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
class _AccountStep extends StatefulWidget {
  const _AccountStep({
    required this.controller,
    required this.motion,
    required this.onNext,
    required this.onSignedIn,
  });
  final AppController controller;
  final _StepMotion motion;

  /// Null until signed in.
  final VoidCallback? onNext;
  final VoidCallback onSignedIn;

  @override
  State<_AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<_AccountStep> {
  /// Whether signing in is on screen: it stays, the students added
  /// included, rather than giving way to the list of profiles.
  bool _flowing = false;

  @override
  void didUpdateWidget(_AccountStep old) {
    super.didUpdateWidget(old);
    // Come back to, the step lists the profiles signed in to.
    if (widget.motion.active && !old.motion.active) _flowing = false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final profiles = controller.profiles;
    final listed = profiles.isNotEmpty && !_flowing;
    return _SetupPage(
      key: const ValueKey('onboarding-account'),
      motion: widget.motion,
      icon: Icons.school_rounded,
      badge: _BadgeMotion.cap,
      title: context.tr(listed ? 'profiles' : 'onboardingAccount'),
      text: listed ? context.tr('onboardingProfilesText') : null,
      actions: [
        if (listed || (widget.onNext != null && !_flowing))
          _setupNext(context, widget.onNext),
      ],
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
          _SignInFlow(
            controller: controller,
            onFlowing: (flowing) => setState(() => _flowing = flowing),
            onDone: widget.onSignedIn,
          ),
      ],
    );
  }
}

/// What notifications come and when, said before the system asks for them:
/// all of them, the ones chosen, or none.
class _NotificationsStep extends StatefulWidget {
  const _NotificationsStep({
    required this.controller,
    required this.motion,
    required this.asking,
    required this.onSkip,
    required this.onNext,
  });
  final AppController controller;
  final _StepMotion motion;
  final bool asking;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  State<_NotificationsStep> createState() => _NotificationsStepState();
}

/// The choices of the notifications step.
enum _NotifyChoice { all, choose, off }

class _NotificationsStepState extends State<_NotificationsStep> {
  /// Where the settings already are: all on, off, or something between.
  late _NotifyChoice _choice = switch (widget.controller.notificationSettings) {
    final settings when !settings.enabled => _NotifyChoice.off,
    final settings when settings.everything => _NotifyChoice.all,
    _ => _NotifyChoice.choose,
  };

  Future<void> _pick(_NotifyChoice choice) async {
    if (choice == _choice) return;
    HapticFeedback.selectionClick();
    setState(() => _choice = choice);
    final controller = widget.controller;
    switch (choice) {
      case _NotifyChoice.all:
        await controller.useAllNotifications();
      case _NotifyChoice.choose:
        if (!controller.notificationSettings.enabled) {
          await controller.setNotificationsEnabled(true);
        }
      case _NotifyChoice.off:
        await controller.setNotificationsEnabled(false);
    }
  }

  Widget _option(
    _NotifyChoice choice,
    IconData icon,
    String title,
    String text,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chosen = choice == _choice;
    return Semantics(
      selected: chosen,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Card(
        key: ValueKey('notify-${choice.name}'),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: chosen ? colors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: () => _pick(choice),
          child: Padding(
            padding: const EdgeInsets.all(_Space.inset),
            child: Row(
              children: [
                _SettingsIcon(icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WholeWords(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _WholeWords(
                        text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: _motion(context, const Duration(milliseconds: 200)),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: chosen
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: ValueKey('notify-${choice.name}-chosen'),
                          color: colors.primary,
                        )
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: const ValueKey('unchosen'),
                          color: colors.outline,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _SetupPage(
    key: const ValueKey('onboarding-notifications'),
    motion: widget.motion,
    icon: Icons.notifications_active_rounded,
    badge: _BadgeMotion.bell,
    title: context.tr('notifications'),
    text: context.tr('onboardingNotificationsText'),
    actions: [
      _setupNext(context, widget.onNext, busy: widget.asking),
      TextButton(
        key: const ValueKey('onboarding-skip'),
        onPressed: widget.asking ? null : widget.onSkip,
        child: Text(context.tr('onboardingSkip')),
      ),
    ],
    children: [
      _option(
        _NotifyChoice.all,
        Icons.notifications_active_rounded,
        context.tr('notifyAll'),
        context.tr('notifyAllText'),
      ),
      _option(
        _NotifyChoice.choose,
        Icons.tune_rounded,
        context.tr('notifyChoose'),
        context.tr('notifyChooseText'),
      ),
      _option(
        _NotifyChoice.off,
        Icons.notifications_off_rounded,
        context.tr('notifyOff'),
        context.tr('notifyOffText'),
      ),
      // The full list unfolds under "choose".
      AnimatedSwitcher(
        duration: _motion(context, _Motion.list),
        switchInCurve: _Motion.curve,
        switchOutCurve: _Motion.curve,
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: _choice == _NotifyChoice.choose
            ? Card(
                key: const ValueKey('notify-list'),
                clipBehavior: Clip.antiAlias,
                child: _NotificationSettingsBody(
                  widget.controller,
                  onPermission: (_) {},
                  showMaster: false,
                ),
              )
            : const SizedBox(
                key: ValueKey('notify-none'),
                width: double.infinity,
              ),
      ),
    ],
  );
}

/// The end: what was chosen, a few things worth knowing, and into the app.
class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.controller,
    required this.motion,
    required this.permissionRefused,
    required this.onEdit,
    required this.onStart,
  });
  final AppController controller;
  final _StepMotion motion;
  final bool permissionRefused;

  /// Back to a step from its row in the summary.
  final ValueChanged<_SetupStep> onEdit;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final widgets =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    Widget tip(
      Key key,
      IconData icon,
      String text, {
      bool warning = false,
      Widget? extra,
    }) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        color: warning ? colors.onErrorContainer : null,
                      ),
                    ),
                    if (extra != null) ...[const SizedBox(height: 10), extra],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _SetupPage(
      key: const ValueKey('onboarding-done'),
      motion: motion,
      icon: Icons.check_rounded,
      badge: _BadgeMotion.check,
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
        _SetupSummary(
          controller: controller,
          permissionRefused: permissionRefused,
          onEdit: onEdit,
        ),
        if (widgets)
          _WidgetTip(
            bridge: controller.homeWidget,
            tip: (extra) => tip(
              const ValueKey('onboarding-tip-widget'),
              Icons.widgets_rounded,
              context.tr('onboardingTipWidget'),
              extra: extra,
            ),
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
