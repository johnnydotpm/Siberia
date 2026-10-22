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
                  child: BrandWordmark(fontSize: 34),
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

/// The signed-in account: its linked Synergia logins and logging out. It
/// only opens for a Librus Synergia account, from inside the shell.
Future<void> _showAccount(BuildContext context, AppController controller) =>
    showAppSheet<void>(
      context: context,
      compact: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Follows the sync, so neither button can act in the middle of one.
      builder: (sheetContext) => ListenableBuilder(
        listenable: controller,
        builder: (sheetContext, _) => Padding(
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
              if (controller.isDemo) ...[
                Text(context.tr('demoMode'), style: _sheetTitleStyle(context)),
                const SizedBox(height: 8),
              ],
              Text(
                controller.snapshot.profile.name,
                style: _sheetTitleStyle(context),
              ),
              const SizedBox(height: 4),
              Text(
                controller.snapshot.profile.school,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              if (!controller.isDemo)
                OutlinedButton.icon(
                  onPressed: controller.syncing
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          showAppSheet<void>(
                            context: context,
                            useSafeArea: true,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (_) => _LinkedSynergiaAccounts(controller),
                          );
                        },
                  icon: const Icon(Icons.switch_account_rounded),
                  label: Text(context.tr('synergiaAccounts')),
                ),
              const SizedBox(height: 12),
              // Red and asked first, like resetting the settings. A sync
              // that runs on after logging out would bring back an error,
              // or the old account's data.
              TextButton.icon(
                key: const ValueKey('account-logout'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: controller.syncing
                    ? null
                    : () async {
                        Navigator.pop(sheetContext);
                        final confirmed = await _confirm(
                          context,
                          title: context.tr('logout'),
                          message: context.tr('logoutConfirm'),
                          action: context.tr('logout'),
                          actionKey: const ValueKey('account-logout-confirm'),
                        );
                        if (confirmed && !controller.syncing) {
                          await controller.logout();
                        }
                      },
                icon: const Icon(Icons.logout_rounded),
                label: Text(context.tr('logout')),
              ),
            ],
          ),
        ),
      ),
    );

class _LinkedSynergiaAccounts extends StatefulWidget {
  const _LinkedSynergiaAccounts(this.controller);
  final AppController controller;
  @override
  State<_LinkedSynergiaAccounts> createState() =>
      _LinkedSynergiaAccountsState();
}

class _LinkedSynergiaAccountsState extends State<_LinkedSynergiaAccounts> {
  late Future<List<LinkedSynergiaAccount>> accounts = widget.controller
      .fetchSynergiaAccounts();
  bool selecting = false;
  AppError? selectionError;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: FutureBuilder<List<LinkedSynergiaAccount>>(
      future: accounts,
      builder: (context, result) => ListView(
        shrinkWrap: true,
        // Scrolls only when it does not fit; a sheet that fits moves as a whole.
        primary: false,
        children: [
          Text(
            context.tr('synergiaAccounts'),
            style: _sheetTitleStyle(context),
          ),
          const SizedBox(height: 12),
          if (result.connectionState != ConnectionState.done || selecting)
            const LinearProgressIndicator(),
          if (result.hasError)
            ListTile(
              title: Text(context.trError(AppError.from(result.error!))),
              trailing: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: MaterialLocalizations.of(context)
                    .refreshIndicatorSemanticLabel,
                onPressed: () => setState(() {
                  accounts = widget.controller.fetchSynergiaAccounts();
                }),
              ),
            ),
          if (selectionError != null) Text(context.trError(selectionError!)),
          for (final account in result.data ?? <LinkedSynergiaAccount>[])
            ListTile(
              title: Text(account.name.isEmpty ? account.login : account.name),
              subtitle: account.name.isEmpty ? null : Text(account.login),
              trailing: account.selected
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              enabled: !selecting,
              onTap: () async {
                setState(() {
                  selecting = true;
                  selectionError = null;
                });
                final ok = await widget.controller.selectSynergiaAccount(
                  account.login,
                );
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    selecting = false;
                    selectionError = widget.controller.error;
                  });
                }
              },
            ),
        ],
      ),
    ),
  );
}

class _Login extends StatefulWidget {
  const _Login(this.controller);
  final AppController controller;
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
    final ok = await widget.controller.loginLibrus(
      username: email.text,
      password: password.text,
    );
    if (mounted && ok) {
      Navigator.pop(context);
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
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
          Text(context.tr('loginHelp')),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.vpn_lock_rounded,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.tr('vpnWarning'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                  obscure
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
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
        ],
      ),
    ),
  );
}
