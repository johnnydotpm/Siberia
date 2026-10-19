part of '../app_shell.dart';

class _Messages extends StatefulWidget {
  const _Messages(this.controller);
  final AppController controller;

  @override
  State<_Messages> createState() => _MessagesState();
}

class _MessagesState extends State<_Messages> {
  final _search = TextEditingController();
  bool _unreadOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    try {
      await widget.controller.markAllMessagesRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('allMessagesRead'))));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('markAllReadFailed'))));
    }
  }

  /// "Today", "Yesterday", "This week", then the month.
  String _section(DateTime value, DateTime now) {
    final day = DateTime(value.year, value.month, value.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return context.tr('messagesToday');
    if (days == 1) return context.tr('messagesYesterday');
    if (days < 7 && day.weekday < today.weekday) {
      return context.tr('messagesThisWeek');
    }
    return _capitalize(
      DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag())
          .format(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final all = controller.snapshot.messages.toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final query = _search.text.trim().toLowerCase();
    final messages = all
        .where((item) => !_unreadOnly || item.unread)
        .where(
          (item) =>
              query.isEmpty ||
              item.subject.toLowerCase().contains(query) ||
              item.sender.toLowerCase().contains(query) ||
              item.preview.toLowerCase().contains(query),
        )
        .toList();
    final error = controller.snapshot.messagesError;
    final unreadCount = all.where((item) => item.unread).length;
    final style = controller.messageListStyle;
    final now = DateTime.now();
    final colors = Theme.of(context).colorScheme;

    final rows = <Widget>[];
    String? lastSection;
    for (final item in messages) {
      final section = _section(item.receivedAt, now);
      if (section != lastSection) {
        rows.add(
          Padding(
            key: ValueKey('messages-section-$section'),
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
            child: Text(
              section,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
        lastSection = section;
      }
      rows.add(_MessageTile(controller, item, style: style, now: now));
    }

    final tiles = <Widget>[
      TextField(
        key: const ValueKey('messages-search'),
        controller: _search,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.tr('messagesSearch'),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  tooltip: MaterialLocalizations.of(context)
                      .deleteButtonTooltip,
                  onPressed: () => setState(_search.clear),
                ),
          filled: true,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: SegmentedButton<bool>(
              key: const ValueKey('messages-filter'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(context.tr('messagesAll')),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    unreadCount == 0
                        ? context.tr('messagesUnread')
                        : '${context.tr('messagesUnread')} ($unreadCount)',
                  ),
                ),
              ],
              selected: {_unreadOnly},
              onSelectionChanged: (selection) =>
                  setState(() => _unreadOnly = selection.first),
            ),
          ),
          IconButton(
            key: const ValueKey('messages-mark-all-read'),
            tooltip: context.tr('markAllRead'),
            onPressed:
                unreadCount == 0 ||
                    controller.markingMessagesRead ||
                    controller.syncing
                ? null
                : _markAllRead,
            icon: controller.markingMessagesRead
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            key: const ValueKey('messages-style-toggle'),
            tooltip: context.tr(
              style == MessageListStyle.list
                  ? 'messagesViewCards'
                  : 'messagesViewList',
            ),
            onPressed: () => controller.setMessageListStyle(
              style == MessageListStyle.list
                  ? MessageListStyle.cards
                  : MessageListStyle.list,
            ),
            icon: Icon(
              style == MessageListStyle.list
                  ? Icons.view_agenda_outlined
                  : Icons.view_list_rounded,
            ),
          ),
        ],
      ),
      if (error != null)
        ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(context.trError(error)),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: MaterialLocalizations.of(context)
                .refreshIndicatorSemanticLabel,
            onPressed: controller.syncing ? null : controller.sync,
          ),
        ),
      if (messages.isEmpty && error == null) _Empty(context.tr('noData')),
      ...rows,
    ];
    final scope = GlassPageScope.maybeOf(context);
    // Under a glass top bar the compose button lives in the bar.
    if (scope != null && scope.barActions) {
      return _PageList(padding: const EdgeInsets.all(12), children: tiles);
    }
    final insets = _chromeInsets(context);
    final title = scope?.largeTitle;
    return Column(
      children: [
        SizedBox(height: insets.top),
        if (title != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GlassLargeTitle.margin,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: GlassLargeTitle(title),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showComposeMessage(context, controller),
              icon: const Icon(Icons.edit_rounded),
              label: Text(context.tr('newMessage')),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + insets.bottom),
            children: tiles,
          ),
        ),
      ],
    );
  }
}

/// "12:30" today, the weekday this week, the date before that.
String _messageTime(BuildContext context, DateTime value, DateTime now) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final day = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  // Today and yesterday have their own sections, so the time says more.
  if (days <= 1) return DateFormat('HH:mm').format(value);
  if (days < 7) return _shortWeekday(context, value);
  if (value.year == now.year) return DateFormat('dd.MM', locale).format(value);
  return DateFormat('dd.MM.yyyy', locale).format(value);
}

class _MessageTile extends StatelessWidget {
  const _MessageTile(
    this.controller,
    this.item, {
    required this.style,
    required this.now,
  });
  final AppController controller;
  final SchoolMessage item;
  final MessageListStyle style;
  final DateTime now;

  Future<bool> _markRead(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.markMessageRead(item);
    } on Object catch (error) {
      // A message that failed stays unread, so its row is still here.
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.trError(AppError.from(error)))),
        );
      }
    }
    // The row stays; it just turns read.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unread = item.unread;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: style == MessageListStyle.list ? 8 : 12,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SenderAvatar(item.sender),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.sender.isEmpty ? '—' : item.sender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.hasAttachments)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.attach_file_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _messageTime(context, item.receivedAt, now),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: unread
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: unread
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        key: ValueKey('message-unread-${item.id}'),
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(left: 8, top: 6),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (item.preview.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.preview.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final tile = style == MessageListStyle.cards
        ? Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showMessageDetail(context, controller, item),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: unread ? colors.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: content,
              ),
            ),
          )
        : Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showMessageDetail(context, controller, item),
                child: content,
              ),
              const Divider(height: 1, indent: 60),
            ],
          );
    if (!unread) return tile;
    return Dismissible(
      key: ValueKey('message-${item.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) => _markRead(context),
      background: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              context.tr('messageMarkRead'),
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: tile,
    );
  }
}

/// The sender's initials on a calm colour of their own.
class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar(this.sender, {this.radius = 20});
  final String sender;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final words = sender
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    final initials = words.isEmpty
        ? '?'
        : words
              .take(2)
              .map((word) => word.characters.first.toUpperCase())
              .join();
    final palette = SubjectColors.colors(
      SubjectColors.stableHash(sender) % SubjectColors.hueCount,
      Theme.of(context).brightness,
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.background,
      foregroundColor: palette.foreground,
      child: Text(
        initials,
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w800),
      ),
    );
  }
}

Future<void> _showMessageDetail(
  BuildContext context,
  AppController controller,
  SchoolMessage message,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) =>
      _MessageDetailSheet(controller: controller, message: message),
);

class _MessageDetailSheet extends StatefulWidget {
  const _MessageDetailSheet({required this.controller, required this.message});
  final AppController controller;
  final SchoolMessage message;

  @override
  State<_MessageDetailSheet> createState() => _MessageDetailSheetState();
}

class _MessageDetailSheetState extends State<_MessageDetailSheet> {
  late Future<SchoolMessageContent> content;
  String? openingAttachment;

  /// Whether the last attachment could not be opened. Shown in the sheet:
  /// a SnackBar would appear behind it.
  bool attachmentFailed = false;

  @override
  void initState() {
    super.initState();
    content = widget.controller.fetchMessageContent(widget.message);
  }

  void retry() {
    setState(() {
      content = widget.controller.fetchMessageContent(widget.message);
    });
  }

  Future<void> openAttachment(MessageAttachment attachment) async {
    setState(() {
      openingAttachment = attachment.id;
      attachmentFailed = false;
    });
    try {
      final url = await widget.controller.fetchMessageAttachmentUrl(
        messageId: widget.message.id,
        attachmentId: attachment.id,
      );
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Unable to open attachment URL');
    } on Object {
      if (mounted) setState(() => attachmentFailed = true);
    } finally {
      if (mounted) setState(() => openingAttachment = null);
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.92,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('messages'),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<SchoolMessageContent>(
            future: content,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: _RecipientError(
                    message: context.trError(AppError.from(snapshot.error!)),
                    onRetry: retry,
                  ),
                );
              }
              final message = snapshot.data!;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + _systemButtonsRoom(context),
                ),
                children: [
                  Text(
                    message.subject,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          message.sender.isEmpty
                              ? '?'
                              : message.sender.characters.first.toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.sender,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              DateFormat('dd.MM.yyyy, HH:mm')
                                  .format(message.receivedAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  SelectableText(
                    message.body,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(height: 1.45),
                  ),
                  if (message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      context.tr('attachments'),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...message.attachments.map(
                      (attachment) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.attach_file_rounded),
                          title: Text(attachment.name),
                          trailing: openingAttachment == attachment.id
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.open_in_new_rounded),
                          enabled: openingAttachment == null,
                          onTap: openingAttachment == null
                              ? () => openAttachment(attachment)
                              : null,
                        ),
                      ),
                    ),
                    if (attachmentFailed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          context.tr('attachmentOpenFailed'),
                          key: const ValueKey('attachment-open-failed'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
