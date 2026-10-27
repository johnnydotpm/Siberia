part of '../app_shell.dart';

Future<void> _showComposeMessage(
  BuildContext context,
  AppController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _ComposeMessageSheet(controller),
);

/// What was being written when the sheet closed unsent: the next "New
/// message" in the same view brings it back, until the app closes.
class _ComposeDraft {
  const _ComposeDraft({
    required this.view,
    required this.from,
    required this.recipients,
    required this.subject,
    required this.body,
  });

  /// The profile, or the view together, it was written in.
  final String view;
  final String? from;
  final List<MessageRecipient> recipients;
  final String subject;
  final String body;

  /// The draft kept in each app, for as long as it runs.
  static final kept = Expando<_ComposeDraft>('compose draft');

  /// Whether the word on a kept draft still shows in each app.
  static final told = Expando<bool>('compose draft told');

  bool get isEmpty =>
      recipients.isEmpty && subject.trim().isEmpty && body.trim().isEmpty;
}

class _ComposeMessageSheet extends StatefulWidget {
  const _ComposeMessageSheet(this.controller);
  final AppController controller;

  @override
  State<_ComposeMessageSheet> createState() => _ComposeMessageSheetState();
}

class _ComposeMessageSheetState extends State<_ComposeMessageSheet> {
  final subjectController = TextEditingController();
  final bodyController = TextEditingController();
  final selectedRecipients = <MessageRecipient>[];

  /// Once sent, there is no draft to keep.
  bool sent = false;
  TextEditingController? recipientSearchController;
  late Future<List<MessageRecipient>> recipients;
  bool sending = false;
  String? validationError;

  /// In the view together, the profile the message goes from: the one
  /// opened last, until another one is picked.
  String? from;

  @override
  void initState() {
    super.initState();
    final controller = widget.controller;
    if (controller.together) {
      final included = controller.togetherProfiles;
      final last = controller.activeProfile?.id;
      from = included.any((profile) => profile.id == last)
          ? last
          : included.firstOrNull?.id;
    }
    // A draft of the same view comes back as it was left.
    final draft = _ComposeDraft.kept[controller];
    if (draft != null && draft.view == controller.snapshot.profile.id) {
      _ComposeDraft.kept[controller] = null;
      // Its recipients only from the profile it was written from, while
      // that one is still in the view together.
      final fromKept =
          draft.from == from ||
          controller.togetherProfiles.any(
            (profile) => profile.id == draft.from,
          );
      if (fromKept) {
        from = draft.from;
        selectedRecipients.addAll(draft.recipients);
      }
      subjectController.text = draft.subject;
      bodyController.text = draft.body;
    }
    recipients = controller.fetchMessageRecipients(profileId: from);
  }

  /// Writes from the profile [profileId]: its school's teachers are others,
  /// so the recipients picked so far go.
  void pickFrom(String profileId) {
    if (profileId == from) return;
    setState(() {
      from = profileId;
      selectedRecipients.clear();
      recipientSearchController?.clear();
      validationError = null;
      recipients = widget.controller.fetchMessageRecipients(profileId: from);
    });
  }

  @override
  void dispose() {
    subjectController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  /// Closed unsent with something picked or written, however it was closed
  /// (a swipe down closes the sheet past any question, though not past
  /// being told): it is kept, and the page says so with a way to throw it
  /// away.
  void _keepDraft() {
    if (sent) return;
    final controller = widget.controller;
    final draft = _ComposeDraft(
      view: controller.snapshot.profile.id,
      from: from,
      recipients: [...selectedRecipients],
      subject: subjectController.text,
      body: bodyController.text,
    );
    if (draft.isEmpty) return;
    _ComposeDraft.kept[controller] = draft;
    // The word of a draft closed moments ago still shows, and its button
    // throws away whichever draft is kept: one is enough.
    if (_ComposeDraft.told[controller] ?? false) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _ComposeDraft.told[controller] = true;
    messenger
        .showSnackBar(
          SnackBar(
            key: const ValueKey('draft-saved'),
            content: Text(context.tr('draftSaved')),
            action: SnackBarAction(
              label: context.tr('draftDiscard'),
              onPressed: () => _ComposeDraft.kept[controller] = null,
            ),
          ),
        )
        .closed
        .whenComplete(() => _ComposeDraft.told[controller] = null);
  }

  void retryRecipients() {
    setState(() {
      validationError = null;
      recipients = widget.controller.fetchMessageRecipients(profileId: from);
    });
  }

  Future<void> send() async {
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();
    final error = switch ((selectedRecipients.isEmpty, subject, body)) {
      (true, _, _) => context.tr('requiredRecipients'),
      (_, '', _) => context.tr('requiredSubject'),
      (_, _, '') => context.tr('requiredBody'),
      _ => null,
    };
    if (error != null) {
      setState(() => validationError = error);
      return;
    }
    setState(() {
      sending = true;
      validationError = null;
    });
    try {
      await widget.controller.sendMessage(
        recipients: selectedRecipients.toList(),
        subject: subject,
        body: body,
        from: from,
      );
      sent = true;
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('messageSent'))),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => validationError = context.trError(AppError.from(error)));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    // Told of every way the sheet closes: its button, a tap outside, the
    // back gesture and a swipe down.
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _keepDraft();
    },
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('newMessage'),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: sending ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (from != null) ...[
                      _ComposeFrom(
                        controller: widget.controller,
                        from: from!,
                        onPicked: sending ? null : pickFrom,
                      ),
                      const Divider(height: 28),
                    ],
                    FutureBuilder<List<MessageRecipient>>(
                      future: recipients,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          // Where the recipient field will be.
                          return const _Skeleton(
                            key: ValueKey('recipients-loading'),
                            child: _Bone(height: 56, radius: 12),
                          );
                        }
                        if (snapshot.hasError) {
                          return _RecipientError(
                            message: context.trError(
                              AppError.from(snapshot.error!),
                            ),
                            onRetry: retryRecipients,
                          );
                        }
                        final items = snapshot.data!;
                        if (items.isEmpty) {
                          return _RecipientError(
                            message: context.tr('noRecipients'),
                            onRetry: retryRecipients,
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (selectedRecipients.isNotEmpty) ...[
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selectedRecipients
                                    .map(
                                      (recipient) => InputChip(
                                        label: Text(recipient.name),
                                        onDeleted: sending
                                            ? null
                                            : () => setState(
                                                () => selectedRecipients.remove(
                                                  recipient,
                                                ),
                                              ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Autocomplete<MessageRecipient>(
                              displayStringForOption: (item) => item.name,
                              optionsBuilder: (value) {
                                final query = _plainPolish(value.text.trim());
                                return items.where(
                                  (item) =>
                                      !selectedRecipients.any(
                                        (selected) => selected.id == item.id,
                                      ) &&
                                      (query.isEmpty ||
                                          _plainPolish(item.name)
                                              .contains(query) ||
                                          _plainPolish(item.group)
                                              .contains(query)),
                                );
                              },
                              onSelected: (item) {
                                setState(() => selectedRecipients.add(item));
                                recipientSearchController?.clear();
                              },
                              fieldViewBuilder:
                                  (context, controller, focusNode, onSubmit) {
                                    recipientSearchController = controller;
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      enabled: !sending,
                                      decoration: InputDecoration(
                                        labelText: context.tr('recipient'),
                                        hintText: context.tr('searchRecipient'),
                                        prefixIcon: const Icon(
                                          Icons.person_search_rounded,
                                        ),
                                      ),
                                    );
                                  },
                              optionsViewBuilder:
                                  (context, onSelected, options) => Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(12),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 280,
                                          maxWidth: 520,
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          // Scrolls only when the names do
                                          // not fit.
                                          primary: false,
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final item = options.elementAt(
                                              index,
                                            );
                                            return ListTile(
                                              title: Text(item.name),
                                              subtitle: item.group.isEmpty
                                                  ? null
                                                  : Text(item.group),
                                              onTap: () => onSelected(item),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('compose-subject'),
                      controller: subjectController,
                      enabled: !sending,
                      maxLength: 100,
                      // The count shows only near the limit, not "0/100".
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => currentLength >= 80
                          ? Text('$currentLength/$maxLength')
                          : null,
                      textCapitalization: TextCapitalization.sentences,
                      // On to the message, the next field.
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.tr('subject'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('compose-body'),
                      controller: bodyController,
                      enabled: !sending,
                      minLines: 7,
                      maxLines: 14,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: context.tr('messageBody'),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                _Space.sheet,
                16,
                _Space.sheet,
                16 + _systemButtonsRoom(context),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: _wideButton,
                  onPressed: sending ? null : send,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(context.tr(sending ? 'sending' : 'send')),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecipientError extends StatelessWidget {
  const _RecipientError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: MaterialLocalizations.of(context)
                .refreshIndicatorSemanticLabel,
          ),
        ],
      ),
    ),
  );
}

/// Which profile a message of the view together goes from: one chip per
/// profile in it, and the school whose teachers it can go to.
class _ComposeFrom extends StatelessWidget {
  const _ComposeFrom({
    required this.controller,
    required this.from,
    required this.onPicked,
  });
  final AppController controller;
  final String from;
  final ValueChanged<String>? onPicked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final school = controller.profileOf(from)?.school ?? '';
    return Column(
      key: const ValueKey('compose-from'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('composeFrom'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final profile in controller.togetherProfiles)
              ChoiceChip(
                key: ValueKey('compose-from-${profile.id}'),
                avatar: ProfileAvatar(
                  name: controller.togetherSign(profile),
                  color: profile.color,
                  radius: 12,
                ),
                label: Text(
                  controller.profileMark(profile.id)?.name ??
                      profile.displayName,
                ),
                selected: profile.id == from,
                showCheckmark: false,
                onSelected: onPicked == null
                    ? null
                    : (_) => onPicked!(profile.id),
              ),
          ],
        ),
        if (school.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            context.trArgs('composeRecipientsOf', {'school': school}),
            style: _metaStyle(context),
          ),
        ],
      ],
    );
  }
}
