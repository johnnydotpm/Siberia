part of '../app_shell.dart';

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                RawGestureDetector(
                  key: const ValueKey('login-demo-logo'),
                  gestures: {
                    LongPressGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          LongPressGestureRecognizer
                        >(
                          () => LongPressGestureRecognizer(
                            duration: const Duration(seconds: 5),
                          ),
                          (recognizer) =>
                              recognizer.onLongPress = controller.startDemo,
                        ),
                  },
                  child: const AppLogo(),
                ),
                const SizedBox(height: 24),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BrandWordmark(fontSize: 34, accessories: true),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('loginRequiredTitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('loginRequiredText'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: _wideButton,
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      builder: (_) => _Login(controller),
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(context.tr('connect')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The profile button of the glass top bar: the open profile's initials in
/// its colour where Flutter draws the bar, its first letter in that colour
/// where UIKit does, and a dot when another profile has news.
GlassBarButton _profileBarButton(
  BuildContext context,
  AppController controller,
) {
  final look = controller.profileLook;
  final news = controller.otherProfilesHaveNews;
  return GlassBarButton(
    id: 'account',
    symbol: look.name.trim().isEmpty
        ? GlassSymbol.account
        : GlassSymbol.profile(look.name),
    label: context.trArgs('profileButton', {'name': look.name}),
    avatar: ProfileAvatar(name: look.name, color: look.color, news: news),
    tint: SubjectColors.colors(look.color, Theme.of(context).brightness).accent,
    badge: news,
    onPressed: () => _showProfiles(context, controller),
  );
}

/// The profiles on the phone: a tap opens one at once. Each can be renamed,
/// recoloured or removed, and more can be added. In demo mode it shows the
/// demo's profiles.
Future<void> _showProfiles(BuildContext context, AppController controller) =>
    showAppSheet<void>(
      context: context,
      compact: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Follows the sync, so signing out cannot happen in the middle of one.
      builder: (sheetContext) => ListenableBuilder(
        listenable: controller,
        builder: (sheetContext, _) =>
            _ProfilesSheet(controller: controller, outer: context),
      ),
    );

class _ProfilesSheet extends StatelessWidget {
  const _ProfilesSheet({required this.controller, required this.outer});
  final AppController controller;

  /// Where sheets opened from this one open, once this one is closed.
  final BuildContext outer;

  @override
  Widget build(BuildContext context) {
    final profiles = controller.profiles;
    final active = controller.activeProfile;
    final look = controller.profileLook;
    final several = profiles.length > 1;
    return ListView(
      shrinkWrap: true,
      // Scrolls only when it does not fit; a sheet that fits moves as a whole.
      primary: false,
      padding: EdgeInsets.fromLTRB(
        _Space.sheet,
        0,
        _Space.sheet,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        Text(
          context.tr(controller.isDemo ? 'demoMode' : 'profiles'),
          style: _sheetTitleStyle(context),
        ),
        const SizedBox(height: 12),
        if (profiles.isEmpty)
          _ProfileRow(
            name: look.name,
            school: look.school,
            color: look.color,
            active: true,
          )
        else
          for (final profile in profiles)
            _ProfileRow(
              key: ValueKey('profile-${profile.id}'),
              name: profile.displayName,
              school: [
                if (profile.label?.trim().isNotEmpty ?? false) profile.name,
                if (profile.school.isNotEmpty) profile.school,
              ].join(' · '),
              color: profile.color,
              active: profile.id == active?.id,
              news: controller.profileHasNews(profile.id),
              onTap: () {
                Navigator.pop(context);
                controller.switchProfile(profile.id);
              },
              onMore: () {
                Navigator.pop(context);
                _showProfileActions(outer, controller, profile);
              },
            ),
        const SizedBox(height: 16),
        if (!controller.isDemo)
          OutlinedButton.icon(
            key: const ValueKey('profiles-add'),
            onPressed: profiles.length >= SchoolProfile.maxProfiles
                ? null
                : () {
                    Navigator.pop(context);
                    _showAddProfile(outer, controller);
                  },
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(context.tr('addProfile')),
          ),
        const SizedBox(height: 12),
        // Red and asked first, like resetting the settings. A sync that runs
        // on after signing out would bring back an error, or the data.
        TextButton.icon(
          key: const ValueKey('account-logout'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: controller.syncing
              ? null
              : () async {
                  Navigator.pop(context);
                  final confirmed = await _confirm(
                    outer,
                    title: context.tr(several ? 'logoutAll' : 'logout'),
                    message: context.tr(
                      several ? 'logoutAllConfirm' : 'logoutConfirm',
                    ),
                    action: context.tr(several ? 'logoutAll' : 'logout'),
                    actionKey: const ValueKey('account-logout-confirm'),
                  );
                  if (confirmed && !controller.syncing) {
                    await controller.logout();
                  }
                },
          icon: const Icon(Icons.logout_rounded),
          label: Text(context.tr(several ? 'logoutAll' : 'logout')),
        ),
      ],
    );
  }
}

/// One profile in the list: its sign, its name and school, a check when it
/// is open, and the button for its actions.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.name,
    required this.school,
    required this.color,
    required this.active,
    this.news = false,
    this.onTap,
    this.onMore,
    super.key,
  });
  final String name;
  final String school;
  final int color;
  final bool active;
  final bool news;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: active,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: active ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ProfileAvatar(name: name, color: color, news: news && !active),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _rowTitleStyle(context),
                    ),
                    if (school.isNotEmpty)
                      Text(
                        school,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _metaStyle(context),
                      ),
                  ],
                ),
              ),
              if (active)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.check_rounded,
                    color: theme.colorScheme.primary,
                    semanticLabel: context.tr('profileOpen'),
                  ),
                ),
              if (onMore != null)
                IconButton(
                  tooltip: context.trArgs('profileActions', {'name': name}),
                  onPressed: onMore,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renaming, recolouring and removing one profile.
Future<void> _showProfileActions(
  BuildContext context,
  AppController controller,
  SchoolProfile profile,
) => showAppSheet<void>(
  context: context,
  compact: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheetContext) {
    final error = Theme.of(sheetContext).colorScheme.error;
    return ListView(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        16 + MediaQuery.viewPaddingOf(sheetContext).bottom,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              ProfileAvatar(name: profile.displayName, color: profile.color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  profile.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _sheetTitleStyle(sheetContext),
                ),
              ),
            ],
          ),
        ),
        ListTile(
          key: const ValueKey('profile-rename'),
          leading: const Icon(Icons.edit_rounded),
          title: Text(sheetContext.tr('renameProfile')),
          onTap: () {
            Navigator.pop(sheetContext);
            _renameProfile(context, controller, profile);
          },
        ),
        ListTile(
          key: const ValueKey('profile-color'),
          leading: const Icon(Icons.palette_outlined),
          title: Text(sheetContext.tr('profileColor')),
          onTap: () {
            Navigator.pop(sheetContext);
            _showProfileColors(context, controller, profile);
          },
        ),
        if (!controller.isDemo)
          ListTile(
            key: const ValueKey('profile-remove'),
            iconColor: error,
            textColor: error,
            leading: const Icon(Icons.person_remove_rounded),
            title: Text(sheetContext.tr('removeProfile')),
            onTap: () async {
              Navigator.pop(sheetContext);
              final confirmed = await _confirm(
                context,
                title: context.tr('removeProfile'),
                message: context.trArgs('removeProfileConfirm', {
                  'name': profile.displayName,
                }),
                action: context.tr('remove'),
                actionKey: const ValueKey('profile-remove-confirm'),
              );
              if (confirmed) await controller.removeProfile(profile.id);
            },
          ),
      ],
    );
  },
);

Future<void> _renameProfile(
  BuildContext context,
  AppController controller,
  SchoolProfile profile,
) async {
  final label = await showAppDialog<String>(
    context: context,
    builder: (_) => _RenameProfile(profile),
  );
  if (label != null) await controller.renameProfile(profile.id, label);
}

class _RenameProfile extends StatefulWidget {
  const _RenameProfile(this.profile);
  final SchoolProfile profile;
  @override
  State<_RenameProfile> createState() => _RenameProfileState();
}

class _RenameProfileState extends State<_RenameProfile> {
  late final text = TextEditingController(text: widget.profile.label ?? '');

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void save() => Navigator.pop(context, text.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    return AppDialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('renameProfile'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: TextField(
                key: const ValueKey('profile-name-field'),
                controller: text,
                autofocus: true,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => save(),
                decoration: InputDecoration(
                  labelText: context.tr('profileName'),
                  hintText: widget.profile.name,
                  helperText: context.tr('profileNameHelp'),
                  helperMaxLines: 6,
                  // The limit only stops runaway names; a counter would
                  // squeeze the help beside it.
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(material.cancelButtonLabel),
                ),
                FilledButton(
                  key: const ValueKey('profile-name-save'),
                  onPressed: save,
                  child: Text(material.saveButtonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The colours a profile can take, its own checked.
Future<void> _showProfileColors(
  BuildContext context,
  AppController controller,
  SchoolProfile profile,
) => showAppSheet<void>(
  context: context,
  compact: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.fromLTRB(
      _Space.sheet,
      0,
      _Space.sheet,
      24 + MediaQuery.viewPaddingOf(sheetContext).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          sheetContext.tr('profileColor'),
          style: _sheetTitleStyle(sheetContext),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var color = 0; color < profileColorCount; color++)
              Semantics(
                button: true,
                selected: color == profile.color % profileColorCount,
                label: '${sheetContext.tr('profileColor')} ${color + 1}',
                child: InkWell(
                  key: ValueKey('profile-color-$color'),
                  customBorder: const CircleBorder(),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    controller.setProfileColor(profile.id, color);
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ProfileAvatar(
                        name: profile.displayName,
                        color: color,
                        radius: 24,
                      ),
                      if (color == profile.color % profileColorCount)
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(sheetContext).colorScheme.primary,
                              width: 2.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  ),
);

/// Adding a profile: a student of a login the phone has takes one tap;
/// another Librus account is signed in to.
Future<void> _showAddProfile(BuildContext context, AppController controller) =>
    showAppSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddProfile(controller: controller, outer: context),
    );

class _AddProfile extends StatefulWidget {
  const _AddProfile({required this.controller, required this.outer});
  final AppController controller;
  final BuildContext outer;
  @override
  State<_AddProfile> createState() => _AddProfileState();
}

class _AddProfileState extends State<_AddProfile> {
  late Future<List<LinkedSynergiaAccount>> students = widget.controller
      .availableStudents();
  String? adding;
  AppError? error;

  Future<void> add(LinkedSynergiaAccount student) async {
    setState(() {
      adding = student.login;
      error = null;
    });
    final added = await widget.controller.addStudent(student);
    if (!mounted) return;
    if (added != null) {
      Navigator.pop(context);
      if (widget.outer.mounted) {
        _announceNotifications(widget.outer, widget.controller);
      }
    } else {
      setState(() {
        adding = null;
        error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: students,
    builder: (context, result) => ListView(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.fromLTRB(
        _Space.sheet,
        0,
        _Space.sheet,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        Text(context.tr('addProfile'), style: _sheetTitleStyle(context)),
        const SizedBox(height: 12),
        if (result.connectionState != ConnectionState.done || adding != null)
          const LinearProgressIndicator(),
        if (result.hasError)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.trError(AppError.from(result.error!))),
            trailing: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: MaterialLocalizations.of(context)
                  .refreshIndicatorSemanticLabel,
              onPressed: () => setState(() {
                students = widget.controller.availableStudents();
              }),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.trError(error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (result.data case final found? when found.isNotEmpty) ...[
          _GroupLabel(context.tr('studentsOnPhone'), top: 8),
          for (final student in found)
            ListTile(
              key: ValueKey('add-student-${student.login}'),
              contentPadding: EdgeInsets.zero,
              enabled: adding == null,
              leading: ProfileAvatar(
                name: student.name,
                color: freeProfileColor(
                  widget.controller.profiles,
                  student.name,
                ),
              ),
              title: Text(student.name.isEmpty ? student.login : student.name),
              subtitle: Text(
                context.tr(student.parent ? 'parentAccount' : 'studentAccount'),
              ),
              trailing: const Icon(Icons.add_rounded),
              onTap: () => add(student),
            ),
          const Divider(height: 24),
        ],
        OutlinedButton.icon(
          key: const ValueKey('add-other-login'),
          onPressed: adding != null
              ? null
              : () {
                  Navigator.pop(context);
                  showAppSheet<void>(
                    context: widget.outer,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    builder: (_) => _Login(widget.controller),
                  );
                },
          icon: const Icon(Icons.login_rounded),
          label: Text(context.tr('otherLibrusAccount')),
        ),
      ],
    ),
  );
}

/// Tells the user, once a profile is added next to others, that its
/// notifications are on and where to change that.
void _announceNotifications(BuildContext context, AppController controller) {
  final profile = controller.activeProfile;
  if (profile == null ||
      controller.profiles.length < 2 ||
      !profile.notify ||
      !controller.notificationSettings.enabled) {
    return;
  }
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      key: const ValueKey('profile-notifications-notice'),
      content: Text(
        context.trArgs('profileNotificationsOn', {'name': profile.displayName}),
      ),
    ),
  );
}

/// "Who to add?": the new students of a Librus account, offered checked as
/// [defaultStudentChoice] picks them. Null when the user backs out.
Future<List<LinkedSynergiaAccount>?> _chooseStudents(
  BuildContext context,
  List<LinkedSynergiaAccount> students,
) => showAppSheet<List<LinkedSynergiaAccount>>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ChooseStudents(students),
);

class _ChooseStudents extends StatefulWidget {
  const _ChooseStudents(this.students);
  final List<LinkedSynergiaAccount> students;
  @override
  State<_ChooseStudents> createState() => _ChooseStudentsState();
}

class _ChooseStudentsState extends State<_ChooseStudents> {
  late final Set<String> chosen = defaultStudentChoice(widget.students);

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    primary: false,
    padding: EdgeInsets.fromLTRB(
      _Space.sheet,
      0,
      _Space.sheet,
      24 + MediaQuery.viewPaddingOf(context).bottom,
    ),
    children: [
      Text(context.tr('chooseStudents'), style: _sheetTitleStyle(context)),
      const SizedBox(height: 8),
      Text(context.tr('chooseStudentsHelp')),
      const SizedBox(height: 12),
      for (final student in widget.students)
        CheckboxListTile(
          key: ValueKey('choose-${student.login}'),
          contentPadding: EdgeInsets.zero,
          value: chosen.contains(student.login),
          onChanged: (value) => setState(() {
            if (value ?? false) {
              chosen.add(student.login);
            } else {
              chosen.remove(student.login);
            }
          }),
          title: Text(student.name.isEmpty ? student.login : student.name),
          subtitle: Text(
            context.tr(student.parent ? 'parentAccount' : 'studentAccount'),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton(
        key: const ValueKey('choose-students-add'),
        style: _wideButton,
        onPressed: chosen.isEmpty
            ? null
            : () => Navigator.pop(context, [
                for (final student in widget.students)
                  if (chosen.contains(student.login)) student,
              ]),
        child: Text(context.tr('addChosen')),
      ),
    ],
  );
}

class _Login extends StatefulWidget {
  const _Login(this.controller, {this.onStarted, this.onFinished});
  final AppController controller;

  /// Called as signing in starts, on a page of the first setup.
  final VoidCallback? onStarted;

  /// Set when the form sits on a page of the first setup rather than in a
  /// sheet: it then has no title of its own, and the end of signing in, and
  /// whether it worked, comes here instead of closing.
  final ValueChanged<bool>? onFinished;
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    widget.onStarted?.call();
    final ok = await widget.controller.loginLibrus(
      username: email.text,
      password: password.text,
      choose: (students) => _chooseStudents(context, students),
    );
    final embedded = widget.onFinished;
    if (mounted && embedded != null) {
      embedded(ok);
      if (!ok) setState(() {});
    } else if (mounted && ok) {
      final navigator = Navigator.of(context);
      navigator.pop();
      // The sheet is gone; the screen under it tells about notifications.
      if (navigator.context.mounted) {
        _announceNotifications(navigator.context, widget.controller);
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields(context);
    if (widget.onFinished != null) {
      return Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: fields,
        ),
      );
    }
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.fromLTRB(
        _Space.sheet,
        0,
        _Space.sheet,
        // The list below already keeps clear of the system buttons.
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: form,
        child: ListView(
          shrinkWrap: true,
          // Scrolls only when the form does not fit, as with the keyboard up.
          primary: false,
          children: [
            Text(context.tr('account'), style: _sheetTitleStyle(context)),
            const SizedBox(height: 8),
            ...fields,
          ],
        ),
      ),
    );
  }

  List<Widget> _fields(BuildContext context) => [
    Text(context.tr('loginHelp')),
    const SizedBox(height: 20),
    // Only with a VPN on; asked again after a failed sign-in.
    _VpnHint(
      text: context.tr('vpnOnSignIn'),
      error: widget.controller.error,
      padding: const EdgeInsets.only(bottom: 20),
    ),
    TextFormField(
      controller: email,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: context.tr('email'),
        prefixIcon: const Icon(Icons.alternate_email_rounded),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? context.tr('requiredEmail')
          : null,
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: password,
      obscureText: obscure,
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: (_) => submit(),
      decoration: InputDecoration(
        labelText: context.tr('password'),
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => obscure = !obscure),
          icon: Icon(
            obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
        ),
      ),
      validator: (value) => value == null || value.isEmpty
          ? context.tr('requiredPassword')
          : null,
    ),
    if (widget.controller.error != null) ...[
      const SizedBox(height: 12),
      Text(
        context.trError(widget.controller.error!),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
    const SizedBox(height: 20),
    ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => FilledButton(
        style: _wideButton,
        onPressed: widget.controller.syncing ? null : submit,
        child: widget.controller.syncing
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.tr('login')),
      ),
    ),
  ];
}
