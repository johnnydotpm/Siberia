part of '../app_shell.dart';

class _Messages extends StatefulWidget {
  const _Messages(this.controller);
  final AppController controller;

  @override
  State<_Messages> createState() => _MessagesState();
}

enum _MessageFolder { inbox, sent }

class _MessagesState extends State<_Messages> {
  final _search = TextEditingController();
  bool _unreadOnly = false;
  _MessageFolder _folder = _MessageFolder.inbox;

  void _openFolder(_MessageFolder folder) {
    HapticFeedback.selectionClick();
    setState(() => _folder = folder);
    // A sync leaves the Sent folder out, so it is loaded when opened.
    if (folder == _MessageFolder.sent) {
      unawaited(widget.controller.refreshSentMessages());
    }
  }

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
    final sentFolder = _folder == _MessageFolder.sent;
    final all =
        (sentFolder
                ? controller.snapshot.sentMessages
                : controller.snapshot.messages)
            .toList()
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final query = _search.text.trim().toLowerCase();
    final messages = all
        .where((item) => sentFolder || !_unreadOnly || item.unread)
        .where(
          (item) =>
              query.isEmpty ||
              item.subject.toLowerCase().contains(query) ||
              item.sender.toLowerCase().contains(query) ||
              item.recipients.any(
                (name) => name.toLowerCase().contains(query),
              ) ||
              item.preview.toLowerCase().contains(query),
        )
        .toList();
    final error = sentFolder
        ? controller.sentMessagesError
        : controller.snapshot.messagesError;
    final loadingSent = sentFolder && controller.loadingSentMessages;
    final unreadCount = controller.snapshot.unreadMessages;
    final style = controller.messageListStyle;
    final now = DateTime.now();

    final rows = <Widget>[];
    String? lastSection;
    for (final item in messages) {
      final section = _section(item.receivedAt, now);
      if (section != lastSection) {
        rows.add(
          _GroupLabel(
            section,
            key: ValueKey('messages-section-$section'),
            top: _Space.card,
          ),
        );
        lastSection = section;
      } else if (style == MessageListStyle.cards) {
        rows.add(const SizedBox(height: _Space.item));
      }
      rows.add(_MessageTile(controller, item, style: style, now: now));
    }
    Future<void> refresh() => sentFolder
        ? controller.refreshSentMessages(force: true)
        : controller.sync();

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
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<_MessageFolder>(
          key: const ValueKey('messages-folder'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: _MessageFolder.inbox,
              icon: const Icon(Icons.inbox_rounded),
              // One line on a narrow phone with large text.
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(context.tr('messagesInbox')),
              ),
            ),
            ButtonSegment(
              value: _MessageFolder.sent,
              icon: const Icon(Icons.send_rounded),
              // One line on a narrow phone with large text.
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(context.tr('messagesSent')),
              ),
            ),
          ],
          selected: {_folder},
          onSelectionChanged: (selection) => _openFolder(selection.first),
        ),
      ),
      const SizedBox(height: _Space.item),
      Row(
        children: [
          if (!sentFolder)
            FilterChip(
              key: const ValueKey('messages-filter'),
              label: Text(
                unreadCount == 0
                    ? context.tr('messagesUnread')
                    : '${context.tr('messagesUnread')} ($unreadCount)',
              ),
              selected: _unreadOnly,
              onSelected: (value) => setState(() => _unreadOnly = value),
            ),
          const Spacer(),
          if (sentFolder)
            IconButton(
              key: const ValueKey('messages-sent-refresh'),
              tooltip: MaterialLocalizations.of(context)
                  .refreshIndicatorSemanticLabel,
              onPressed: loadingSent
                  ? null
                  : () => controller.refreshSentMessages(force: true),
              icon: loadingSent
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            )
          else
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
                  ? Icons.view_agenda_rounded
                  : Icons.view_list_rounded,
            ),
          ),
        ],
      ),
      if (error != null) ...[
        const SizedBox(height: _Space.item),
        _InfoCard(
          key: ValueKey('messages-error-${_folder.name}'),
          icon: Icons.error_outline_rounded,
          text: context.trError(error),
          color: Theme.of(context).colorScheme.error,
          trailing: IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: MaterialLocalizations.of(context)
                .refreshIndicatorSemanticLabel,
            onPressed: (sentFolder ? loadingSent : controller.syncing)
                ? null
                : refresh,
          ),
        ),
      ],
      if (loadingSent && all.isEmpty)
        // The rows to come, in place of a spinner.
        const Padding(
          key: ValueKey('sent-loading'),
          padding: EdgeInsets.only(top: _Space.card),
          child: _MessageRowsSkeleton(),
        )
      else if (messages.isEmpty && error == null)
        if (query.isNotEmpty)
          _Empty(context.tr('noResults'), icon: Icons.search_off_rounded)
        else if (sentFolder)
          _Empty(context.tr('noSentMessages'), icon: Icons.send_rounded)
        else if (_unreadOnly)
          _Empty(
            context.tr('noUnreadMessages'),
            icon: Icons.mark_email_read_rounded,
            color: Theme.of(context).colorScheme.primary,
          )
        else
          _Empty(context.tr('emptyMessages'), icon: Icons.mail_rounded),
      ...rows,
    ];
    final scope = GlassPageScope.maybeOf(context);
    // Under a glass top bar the compose button lives in the bar.
    if (scope != null && scope.barActions) {
      return _Refresh(
        controller: controller,
        onRefresh: refresh,
        child: _PageList(
          padding: const EdgeInsets.all(_Space.page),
          children: tiles,
        ),
      );
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
          padding: const EdgeInsets.fromLTRB(
            _Space.page,
            _Space.page,
            _Space.page,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: () => _showComposeMessage(context, controller),
              icon: const Icon(Icons.edit_rounded),
              label: Text(context.tr('newMessage')),
            ),
          ),
        ),
        Expanded(
          child: _Refresh(
            controller: controller,
            onRefresh: refresh,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                _Space.page,
                _Space.page,
                _Space.page,
                _Space.page + insets.bottom,
              ),
              children: tiles,
            ),
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

  /// A long press: open it, or mark it read without opening it.
  void _actions(BuildContext context, bool unread) => _showItemActions(
    context,
    title: item.subject.isEmpty ? item.sender : item.subject,
    actions: [
      (
        key: ValueKey('message-action-open-${item.id}'),
        icon: Icons.mail_outline_rounded,
        label: context.tr('open'),
        run: () => _showMessageDetail(context, controller, item),
      ),
      if (unread)
        (
          key: ValueKey('message-action-read-${item.id}'),
          icon: Icons.mark_email_read_rounded,
          label: context.tr('messageMarkRead'),
          run: () => _markRead(context),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unread = !item.sent && item.unread;
    final content = Padding(
      // A card's content starts 16 from its edge, the stripe included.
      // In the list, the avatar lines up with the label of its group.
      padding: style == MessageListStyle.list
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsetsDirectional.fromSTEB(
              _Space.inset - 3,
              10,
              _Space.inset,
              10,
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item.sent
              ? _SentAvatar(item.recipients.firstOrNull ?? '')
              : _SenderAvatar(item.sender),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: item.sent
                          ? _RecipientsLine(item.recipients)
                          : Text(
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
                        fontFeatures: _tabular,
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
                    // Read, the dot fades away rather than vanish.
                    if (!item.sent)
                      AnimatedSwitcher(
                        duration: _motion(context, _Motion.list),
                        transitionBuilder: (child, animation) =>
                            _Fade(opacity: animation, child: child),
                        child: unread
                            ? Container(
                                key: ValueKey('message-unread-${item.id}'),
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(left: 8, top: 6),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    if (item.sent && item.recipientRead != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 1),
                        child: _ReadMark(
                          read: item.recipientRead!,
                          key: ValueKey('sent-read-${item.id}'),
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
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showMessageDetail(context, controller, item),
              onLongPress: item.sent ? null : () => _actions(context, unread),
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
                onLongPress: item.sent ? null : () => _actions(context, unread),
                child: content,
              ),
              // Under the text, past the avatar: 12 + 40 + 12.
              const Divider(height: 1, indent: 64),
            ],
          );
    if (item.sent) return tile;
    // Kept once read, only no longer swiped, so the row changes in place.
    return Dismissible(
      key: ValueKey('message-${item.id}'),
      direction: unread ? DismissDirection.startToEnd : DismissDirection.none,
      confirmDismiss: (_) => _markRead(context),
      background: _SwipeAction(
        icon: Icons.mark_email_read_rounded,
        label: context.tr('messageMarkRead'),
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

/// The recipient's initials with a small arrow: a message that went out.
class _SentAvatar extends StatelessWidget {
  const _SentAvatar(this.recipient);
  final String recipient;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _SenderAvatar(recipient),
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
            ),
            child: Icon(
              Icons.north_east_rounded,
              size: 11,
              color: colors.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// "To: Teacher Alpha +2".
class _RecipientsLine extends StatelessWidget {
  const _RecipientsLine(this.recipients);
  final List<String> recipients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final more = recipients.length - 1;
    return Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${context.tr('messageTo')} ',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(text: recipients.firstOrNull ?? '—'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (more > 0)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$more',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

/// Two ticks once a sent message was read, one until then.
class _ReadMark extends StatelessWidget {
  const _ReadMark({required this.read, super.key});
  final bool read;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.tr(read ? 'messageRead' : 'messageNotRead'),
      child: Icon(
        read ? Icons.done_all_rounded : Icons.done_rounded,
        size: 18,
        color: read ? colors.primary : colors.onSurfaceVariant,
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

  /// While the text loads: what the list knows already, the subject and
  /// who it is from, and grey lines where the text will be.
  Widget _loadingMessage(BuildContext context) {
    final message = widget.message;
    return ListView(
      key: const ValueKey('message-loading'),
      primary: false,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          message.subject,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (message.sent)
          const _Skeleton(
            child: Row(
              children: [
                _Bone.circle(36),
                SizedBox(width: 12),
                _Bone(width: 140, height: 13),
              ],
            ),
          )
        else
          Row(
            children: [
              _SenderAvatar(message.sender),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.sender,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
        const _TextSkeleton(),
      ],
    );
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
                  context.tr(widget.message.sent ? 'sentMessage' : 'messages'),
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
                return _loadingMessage(context);
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
                // Scrolls only when it does not fit; a sheet that fits moves as a whole.
                primary: false,
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
                  if (widget.message.sent)
                    _SentRecipients(summary: widget.message, content: message)
                  else
                    Row(
                      children: [
                        // The same avatar as in the list.
                        _SenderAvatar(message.sender),
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
                        margin: const EdgeInsets.only(bottom: _Space.item),
                        clipBehavior: Clip.antiAlias,
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

/// Who a sent message went to, whether each has read it, and when it went.
class _SentRecipients extends StatefulWidget {
  const _SentRecipients({required this.summary, required this.content});
  final SchoolMessage summary;
  final SchoolMessageContent content;

  @override
  State<_SentRecipients> createState() => _SentRecipientsState();
}

class _SentRecipientsState extends State<_SentRecipients> {
  /// More recipients than this fold behind "Show all".
  static const _shown = 4;
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = widget.summary;
    // The list knows a single recipient's state; the message knows each one.
    final receivers = widget.content.recipients.isNotEmpty
        ? widget.content.recipients
        : [
            for (final name in summary.recipients)
              MessageReceiver(
                name: name,
                read: summary.recipients.length == 1
                    ? summary.recipientRead
                    : null,
              ),
          ];
    final folded = !expanded && receivers.length > _shown + 1;
    final visible = folded ? receivers.take(_shown) : receivers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('messageTo'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        for (final receiver in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _SenderAvatar(receiver.name, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receiver.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      // Under the name, so long names are not cut short.
                      if (receiver.read != null)
                        Row(
                          children: [
                            _ReadMark(read: receiver.read!),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                receiver.read!
                                    ? [
                                        context.tr('messageRead'),
                                        if (receiver.readAt != null)
                                          DateFormat('dd.MM, HH:mm')
                                              .format(receiver.readAt!),
                                      ].join(' · ')
                                    : context.tr('messageNotRead'),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: receiver.read!
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (folded)
          TextButton(
            key: const ValueKey('sent-recipients-all'),
            onPressed: () => setState(() => expanded = true),
            child: Text(
              context
                  .tr('messageRecipientsAll')
                  .replaceAll('{count}', '${receivers.length}'),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          context
              .tr('messageSentAt')
              .replaceAll(
                '{date}',
                DateFormat('dd.MM.yyyy, HH:mm').format(summary.receivedAt),
              ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
