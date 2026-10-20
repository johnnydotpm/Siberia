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
  TextEditingController? recipientSearchController;
  late Future<List<MessageRecipient>> recipients;
  bool sending = false;
  String? validationError;

  @override
  void initState() {
    super.initState();
    recipients = widget.controller.fetchMessageRecipients();
  }

  @override
  void dispose() {
    subjectController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  void retryRecipients() {
    setState(() {
      validationError = null;
      recipients = widget.controller.fetchMessageRecipients();
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
      );
      if (!mounted) return;
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
  Widget build(BuildContext context) => Padding(
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
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
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
                  FutureBuilder<List<MessageRecipient>>(
                    future: recipients,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
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
                              final query = value.text.trim().toLowerCase();
                              return items.where(
                                (item) =>
                                    !selectedRecipients.any(
                                      (selected) => selected.id == item.id,
                                    ) &&
                                    (query.isEmpty ||
                                        item.name.toLowerCase().contains(
                                          query,
                                        ) ||
                                        item.group.toLowerCase().contains(
                                          query,
                                        )),
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
                                      border: const OutlineInputBorder(),
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
                                        itemCount: options.length,
                                        itemBuilder: (context, index) {
                                          final item = options.elementAt(index);
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
                    controller: subjectController,
                    enabled: !sending,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: context.tr('subject'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bodyController,
                    enabled: !sending,
                    minLines: 7,
                    maxLines: 14,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: context.tr('messageBody'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
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
              16,
              16,
              16,
              16 + _systemButtonsRoom(context),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
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
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    ),
  );
}
