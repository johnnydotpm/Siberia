part of '../app_shell.dart';

/// Opens [message] on a page of its own over the list, as Mail does; the
/// way back is named after [folder], where it was opened from.
Future<void> _showMessageDetail(
  BuildContext context,
  AppController controller,
  SchoolMessage message, {
  String? folder,
}) => Navigator.of(context).push<void>(
  // Slides in as the platform's pages do: iOS's, with its swipe back, in
  // the glass design; Android's predictive back in Expressive.
  MaterialPageRoute(
    builder: (context) => _MessagePage(
      controller: controller,
      message: message,
      folder: folder ?? context.tr('messages'),
    ),
  ),
);

/// A message on its own page: the subject large, who it is from and when,
/// its text with links, and its attachments. In the glass design the bars
/// are glass, UIKit's on iOS 26 and Flutter's elsewhere, with deleting and
/// writing floating at the bottom; elsewhere a top bar with a way back and
/// deleting.
class _MessagePage extends StatefulWidget {
  const _MessagePage({
    required this.controller,
    required this.message,
    required this.folder,
  });

  final AppController controller;
  final SchoolMessage message;

  /// Where the message was opened from, which the way back says.
  final String folder;

  @override
  State<_MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<_MessagePage> {
  late Future<SchoolMessageContent> content;
  String? openingAttachment;

  /// Whether the last attachment could not be opened. Said under the
  /// attachments, beside what failed.
  bool attachmentFailed = false;

  /// Whether the last link tapped in the text could not be opened.
  bool linkFailed = false;

  bool deleting = false;

  @override
  void initState() {
    super.initState();
    // Fetching the text marks the message read, in Librus and here.
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

  /// Asks, as deleting from the list does, and goes back once the message
  /// is gone.
  Future<void> delete() async {
    final controller = widget.controller;
    final message = widget.message;
    bool gone() =>
        !(message.sent
                ? controller.snapshot.sentMessages
                : controller.snapshot.messages)
            .any((item) => item.id == message.id);
    await _deleteMessages(context, controller, [
      message,
    ], onConfirmed: () => setState(() => deleting = true));
    if (!mounted) return;
    setState(() => deleting = false);
    if (gone()) await Navigator.of(context).maybePop();
  }

  void compose() => _showComposeMessage(context, widget.controller);

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<SchoolMessageContent>(
      future: content,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _list(
            context,
            key: const ValueKey('message-loading'),
            children: _loading(context),
          );
        }
        if (snapshot.hasError) {
          return _list(
            context,
            children: [
              _RecipientError(
                message: context.trError(AppError.from(snapshot.error!)),
                onRetry: retry,
              ),
            ],
          );
        }
        return _list(context, children: _loaded(context, snapshot.data!));
      },
    );
    if (GlassStyle.of(context)) {
      return GlassPage(
        leading: [
          GlassBarButton(
            id: 'message-page-back',
            symbol: GlassSymbol.back,
            label: widget.folder,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
        actionBar: GlassToolbar(
          actions: [
            GlassAction(
              id: 'message-page-delete',
              label: context.tr('messagesDelete'),
              symbol: GlassSymbol.trash,
              destructive: true,
              onPressed: deleting ? null : delete,
            ),
            GlassAction(
              id: 'message-page-compose',
              label: context.tr('newMessage'),
              symbol: GlassSymbol.compose,
              onPressed: compose,
            ),
          ],
        ),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(key: ValueKey('message-page-back')),
        title: Text(widget.folder),
        actions: [
          IconButton(
            key: const ValueKey('message-page-delete'),
            tooltip: context.tr('messagesDelete'),
            onPressed: deleting ? null : delete,
            icon: const AppIcon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: body,
    );
  }

  /// The page's scrolling list, clear of floating glass bars.
  Widget _list(
    BuildContext context, {
    required List<Widget> children,
    Key? key,
  }) {
    final glass = GlassStyle.of(context);
    final insets = glass ? MediaQuery.paddingOf(context) : EdgeInsets.zero;
    return ListView(
      key: key,
      padding: EdgeInsets.fromLTRB(
        20,
        insets.top + (glass ? 8 : 16),
        20,
        insets.bottom + 24 + (glass ? 0 : _systemButtonsRoom(context)),
      ),
      children: children,
    );
  }

  TextStyle? _subjectStyle(BuildContext context) {
    final theme = Theme.of(context);
    if (GlassStyle.of(context)) {
      return TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
      );
    }
    if (ExpressiveStyle.of(context)) {
      final emphasized =
          theme.extension<ExpressiveType>()?.emphasized ?? theme.textTheme;
      return emphasized.headlineSmall?.copyWith(
        color: theme.colorScheme.onSurface,
      );
    }
    return theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800);
  }

  /// "Sent message" over a message that went out, and the subject.
  List<Widget> _heading(BuildContext context, String subject) {
    final theme = Theme.of(context);
    return [
      _SheetProfileMark(widget.controller, widget.message.source),
      if (widget.message.sent)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            context.tr('sentMessage'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      Text(subject, style: _subjectStyle(context)),
      const SizedBox(height: 16),
    ];
  }

  /// Who it is from and when, on a piece of its own in Expressive.
  Widget _sender(BuildContext context, String sender, DateTime at) {
    final theme = Theme.of(context);
    final row = Row(
      children: [
        // The same avatar as in the list.
        _SenderAvatar(sender, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sender.isEmpty ? '—' : sender,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _messageStamp(context, at),
                key: const ValueKey('message-stamp'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (!ExpressiveStyle.of(context)) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: row),
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 32, thickness: GlassStyle.of(context) ? 0.5 : 1);

  /// While the text loads: what the list knows already, the subject and
  /// who it is from, and grey lines where the text will be.
  List<Widget> _loading(BuildContext context) {
    final message = widget.message;
    return [
      ..._heading(context, message.subject),
      if (message.sent)
        const _Skeleton(
          child: Row(
            children: [
              _Bone.circle(44),
              SizedBox(width: 12),
              _Bone(width: 140, height: 13),
            ],
          ),
        )
      else
        _sender(context, message.sender, message.receivedAt),
      _divider(context),
      const _TextSkeleton(),
    ];
  }

  List<Widget> _loaded(BuildContext context, SchoolMessageContent message) {
    final theme = Theme.of(context);
    final glass = GlassStyle.of(context);
    return [
      ..._heading(context, message.subject),
      if (widget.message.sent)
        _SentRecipients(summary: widget.message, content: message)
      else
        _sender(context, message.sender, message.receivedAt),
      _divider(context),
      // Its links open with a tap; the text stays selectable.
      LinkedText(
        message.body,
        key: const ValueKey('message-body'),
        style: glass
            ? TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 17,
                height: 25 / 17,
                letterSpacing: -0.41,
              )
            : theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        onOpenFailed: () => setState(() => linkFailed = true),
        onOpened: () => setState(() => linkFailed = false),
      ),
      if (linkFailed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            context.tr('linkOpenFailed'),
            key: const ValueKey('link-open-failed'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      if (message.attachments.isNotEmpty) ...[
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '${context.tr('attachments')} · ${message.attachments.length}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: ExpressiveStyle.of(context)
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final (index, attachment) in message.attachments.indexed)
          _AttachmentTile(
            attachment,
            first: index == 0,
            last: index == message.attachments.length - 1,
            opening: openingAttachment == attachment.id,
            onTap: openingAttachment == null
                ? () => openAttachment(attachment)
                : null,
          ),
        if (attachmentFailed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.tr('attachmentOpenFailed'),
              key: const ValueKey('attachment-open-failed'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    ];
  }
}

/// One attachment: a tile with a mark of its kind, its name and a way to
/// open it. In Expressive the tiles of a message make one group.
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile(
    this.attachment, {
    required this.first,
    required this.last,
    required this.opening,
    required this.onTap,
  });

  final MessageAttachment attachment;
  final bool first, last, opening;
  final VoidCallback? onTap;

  /// The hue of a file's kind by its extension: red for a PDF, blue for a
  /// document, green for a spreadsheet, violet for a picture.
  static double? _hue(String name) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    return switch (extension) {
      'pdf' => 0,
      'doc' || 'docx' || 'odt' || 'rtf' || 'txt' => 215,
      'xls' || 'xlsx' || 'ods' || 'csv' => 135,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'heic' || 'webp' => 280,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final expressive = ExpressiveStyle.of(context);
    final glass = GlassStyle.of(context);
    final hue = _hue(attachment.name);
    final kind = hue == null
        ? SubjectColors.grade(null, theme.brightness)
        : SubjectColors.tone(hue, theme.brightness);
    final radius = expressive
        ? BorderRadius.vertical(
            top: Radius.circular(first ? 20 : 4),
            bottom: Radius.circular(last ? 20 : 4),
          )
        : BorderRadius.circular(14);
    return Padding(
      padding: EdgeInsets.only(bottom: expressive ? 2 : 8),
      child: Material(
        color: expressive || glass
            ? colors.surfaceContainer
            : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: expressive || glass
              ? BorderSide.none
              : BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kind.background,
                    borderRadius: BorderRadius.circular(expressive ? 12 : 10),
                  ),
                  child: AppIcon(
                    Icons.description_rounded,
                    size: 20,
                    color: kind.foreground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (opening)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  AppIcon(
                    glass
                        ? CupertinoIcons.arrow_down_circle
                        : Icons.open_in_new_rounded,
                    color: colors.primary,
                    semanticLabel: attachment.name,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
