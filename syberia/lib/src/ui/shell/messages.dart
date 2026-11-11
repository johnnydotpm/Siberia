part of '../app_shell.dart';

class _Messages extends StatefulWidget {
  const _Messages(this.controller);
  final AppController controller;

  @override
  State<_Messages> createState() => _MessagesState();
}

enum _MessageFolder { inbox, sent }

/// The index of the Messages tab.
const _messagesTab = 5;

class _MessagesState extends State<_Messages> {
  final _search = TextEditingController();
  bool _unreadOnly = false;
  _MessageFolder _folder = _MessageFolder.inbox;
  bool _selecting = false;
  bool _working = false;
  final _selected = <String>{};
  late Object _scope;
  Object get _currentScope => (
    widget.controller.together,
    widget.controller.activeProfile?.id,
    widget.controller.snapshot.profile.id,
  );

  /// The messages shown as unread under the filter, by id: one read there,
  /// opened or swiped, stays, as read now, until the filter, the folder or
  /// the tab changes.
  final _shownUnread = <String>{};

  /// Where the shell shows what is picked, when it has bars for it.
  _SelectionBars? _bars;

  /// The messages on screen, by id, for picking them all.
  List<String> _visibleIds = const [];

  @override
  void initState() {
    super.initState();
    _scope = _currentScope;
    widget.controller.addListener(_onController);
  }

  /// Left for another tab: what was read here goes from the filter.
  void _onController() {
    if (widget.controller.tabIndex != _messagesTab || _scope != _currentScope) {
      _shownUnread.clear();
      _selected.clear();
      _selecting = false;
      _scope = _currentScope;
      _showInBars(null);
    }
  }

  /// Hands [selection] to the shell's bars once this frame is done: they
  /// belong to the shell, which may be building now.
  void _showInBars(_Selection? selection) {
    final bars = _bars;
    if (bars == null || bars.value == selection) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (bars.disposed) return;
      // A page gone, or left for another tab, takes back only its own.
      if (selection == null && bars.value?.onClose != _endSelection) return;
      bars.value = selection;
    });
  }

  /// Starts picking, with [first] picked when it came from a message.
  void _startSelection([SchoolMessage? first]) {
    if (_working) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selecting = true;
      if (first != null) _selected.add(first.id);
    });
  }

  void _endSelection() {
    if (!_selecting) return;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  /// Picks every message on screen, or none once all of them are.
  void _selectAll() {
    if (_working) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_visibleIds.isNotEmpty && _visibleIds.every(_selected.contains)) {
        _selected.clear();
      } else {
        _selected.addAll(_visibleIds);
      }
    });
  }

  void _readPicked() => _runSelection(delete: false);
  void _deletePicked() => _runSelection(delete: true);

  void _openFolder(_MessageFolder folder) {
    HapticFeedback.selectionClick();
    _shownUnread.clear();
    _selected.clear();
    _selecting = false;
    setState(() => _folder = folder);
    // A sync leaves the Sent folder out, so it is loaded when opened.
    if (folder == _MessageFolder.sent) {
      unawaited(widget.controller.refreshSentMessages());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _search.dispose();
    _showInBars(null);
    super.dispose();
  }

  List<SchoolMessage> get _selection => [
    for (final item
        in _folder == _MessageFolder.sent
            ? widget.controller.snapshot.sentMessages
            : widget.controller.snapshot.messages)
      if (_selected.contains(item.id)) item,
  ];

  void _toggle(SchoolMessage message) {
    if (_working) return;
    // Felt as picking starts, from a long press or an avatar.
    if (!_selecting) HapticFeedback.selectionClick();
    setState(() {
      _selecting = true;
      if (!_selected.remove(message.id)) _selected.add(message.id);
    });
  }

  Future<void> _runSelection({required bool delete}) async {
    if (_working) return;
    final scope = _scope;
    final folder = _folder;
    final selected = _selection;
    if (selected.isEmpty) return;
    if (!delete) setState(() => _working = true);
    try {
      if (delete) {
        await _deleteMessages(
          context,
          widget.controller,
          selected,
          onConfirmed: () => setState(() => _working = true),
        );
      } else {
        await widget.controller.markMessagesRead(selected);
      }
    } on Object {
      if (!mounted || scope != _currentScope) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('markAllReadFailed'))));
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          if (scope == _currentScope && folder == _folder) {
            final remaining = {
              for (final item in _selection)
                if (delete || item.unread) item.id,
            };
            _selected.retainAll(remaining);
            if (_selected.isEmpty) _selecting = false;
          }
        });
      }
    }
  }

  /// "Today", "Yesterday", "This week", then the month.
  String _section(DateTime value, DateTime now) =>
      switch (messageSection(value, now)) {
        MessageSection.today => context.tr('messagesToday'),
        MessageSection.yesterday => context.tr('messagesYesterday'),
        MessageSection.thisWeek => context.tr('messagesThisWeek'),
        MessageSection.earlier => _monthHeading(context, value, now),
      };

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
    _selected.retainAll(all.map((message) => message.id));
    final query = _plainPolish(_search.text.trim());
    if (_unreadOnly && !sentFolder) {
      _shownUnread.addAll([
        for (final item in all)
          if (item.unread) item.id,
      ]);
    }
    final messages = all
        .where(
          (item) =>
              sentFolder || !_unreadOnly || _shownUnread.contains(item.id),
        )
        .where(
          (item) =>
              query.isEmpty ||
              _plainPolish(item.subject).contains(query) ||
              _plainPolish(item.sender).contains(query) ||
              item.recipients.any(
                (name) => _plainPolish(name).contains(query),
              ) ||
              _plainPolish(item.preview).contains(query),
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
      rows.add(
        _MessageTile(
          controller,
          item,
          key: ValueKey('message-tile-${item.id}'),
          style: style,
          now: now,
          selecting: _selecting,
          selected: _selected.contains(item.id),
          busy: _working,
          onSelect: () => _toggle(item),
        ),
      );
    }
    Future<void> refresh() => sentFolder
        ? controller.refreshSentMessages(force: true)
        : controller.sync();

    // What is picked, for the shell's bars or, on a wide screen, for the
    // page's own row.
    _visibleIds = [for (final item in messages) item.id];
    final selectionScope = _SelectionScope.maybeOf(context);
    final hosted = selectionScope?.hosted ?? false;
    _bars = hosted ? selectionScope!.selection : null;
    final selection = _selecting
        ? _Selection(
            count: _selected.length,
            total: messages.length,
            readable: !sentFolder,
            canRead: _selection.any((item) => item.unread),
            busy:
                _working ||
                controller.syncing ||
                controller.markingMessagesRead ||
                controller.deletingMessages,
            onClose: _endSelection,
            onSelectAll: _selectAll,
            onRead: _readPicked,
            onDelete: _deletePicked,
          )
        : null;
    _showInBars(selection);
    final expressive = ExpressiveStyle.of(context);

    final tiles = <Widget>[
      TextField(
        key: const ValueKey('messages-search'),
        controller: _search,
        onChanged: (_) => setState(_selected.clear),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.tr('messagesSearch'),
          prefixIcon: const AppIcon(Icons.search_rounded),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const AppIcon(Icons.clear_rounded),
                  tooltip: MaterialLocalizations.of(context)
                      .deleteButtonTooltip,
                  onPressed: () => setState(() {
                    _search.clear();
                    _selected.clear();
                  }),
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
        child: _Segmented<_MessageFolder>(
          key: const ValueKey('messages-folder'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: _MessageFolder.inbox,
              icon: const AppIcon(Icons.inbox_rounded),
              // One line on a narrow phone with large text.
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(context.tr('messagesInbox')),
              ),
            ),
            ButtonSegment(
              value: _MessageFolder.sent,
              icon: const AppIcon(Icons.send_rounded),
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
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!sentFolder)
            FilterChip(
              key: const ValueKey('messages-filter'),
              label: Text(
                unreadCount == 0
                    ? context.tr('messagesUnread')
                    : '${context.tr('messagesUnread')} ($unreadCount)',
                style: const TextStyle(fontFeatures: _tabular),
              ),
              selected: _unreadOnly,
              onSelected: (value) => setState(() {
                _unreadOnly = value;
                _shownUnread.clear();
                _selected.clear();
              }),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      : const AppIcon(Icons.refresh_rounded),
                ),
              if (!_selecting) ...[
                if (expressive)
                  FilledButton.tonalIcon(
                    key: const ValueKey('messages-select'),
                    onPressed: _working || messages.isEmpty
                        ? null
                        : _startSelection,
                    icon: const AppIcon(Icons.check_circle_outline_rounded),
                    label: Text(context.tr('messagesSelect')),
                  )
                else
                  TextButton.icon(
                    key: const ValueKey('messages-select'),
                    onPressed: _working || messages.isEmpty
                        ? null
                        : _startSelection,
                    icon: const AppIcon(Icons.check_circle_outline_rounded),
                    label: Text(context.tr('messagesSelect')),
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
                  icon: AppIcon(
                    style == MessageListStyle.list
                        ? Icons.view_agenda_rounded
                        : Icons.view_list_rounded,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      // On a wide screen the shell has no bars to show the picking in.
      if (selection != null && !hosted) _InlineSelection(selection),
      if (_working) const LinearProgressIndicator(),
      if (error != null) ...[
        const SizedBox(height: _Space.item),
        _InfoCard(
          key: ValueKey('messages-error-${_folder.name}'),
          icon: Icons.error_outline_rounded,
          text: context.trError(error),
          color: Theme.of(context).colorScheme.error,
          trailing: IconButton(
            icon: const AppIcon(Icons.refresh_rounded),
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
      return _picking(
        _Refresh(
          controller: controller,
          onRefresh: refresh,
          child: _PageList(
            padding: const EdgeInsets.all(_Space.page),
            children: tiles,
          ),
        ),
      );
    }
    final insets = _chromeInsets(context);
    final title = scope?.largeTitle;
    final expressiveTitle = ExpressivePageScope.maybeOf(context)?.largeTitle;
    final picking = selection != null && hosted;
    return _picking(
      Column(
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
            )
          else if (expressiveTitle != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                _Space.page,
                _Space.page,
                _Space.page,
                0,
              ),
              // While picking, the count is the title and the bars hold
              // what there is to do; otherwise writing sits beside it, as
              // in the mockup.
              child: picking
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _PickedHeadline(selection.count),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: ExpressiveLargeTitle(expressiveTitle)),
                        const SizedBox(width: Space.medium),
                        _ExpressiveCompose(
                          onPressed: () =>
                              _showComposeMessage(context, controller),
                        ),
                      ],
                    ),
            ),
          // A classic page in the shell has writing in its top bar; on a
          // wide screen, with no bar of the page's own, it keeps a row.
          if (!picking && expressiveTitle == null && !hosted)
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
                  key: const ValueKey('messages-compose'),
                  onPressed: () => _showComposeMessage(context, controller),
                  icon: const AppIcon(Icons.edit_rounded),
                  label: Text(context.tr('newMessage')),
                ),
              ),
            ),
          Expanded(
            child: _Refresh(
              controller: controller,
              onRefresh: refresh,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  _Space.page,
                  _Space.page,
                  _Space.page,
                  // Clear of Expressive's floating toolbar.
                  _Space.page +
                      insets.bottom +
                      (picking && expressive ? 88 : 0),
                ),
                children: tiles,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [page], where going back while picking stops picking first.
  Widget _picking(Widget page) => PopScope(
    canPop: !_selecting,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _endSelection();
    },
    child: page,
  );
}

/// The count of picked messages as the Expressive page's large title, the
/// number in the accent colour.
/// Writing a message, beside the Expressive page's title: a 56 square of
/// the primary container with the large corner, as Material's floating
/// action button is.
class _ExpressiveCompose extends StatelessWidget {
  const _ExpressiveCompose({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.tr('newMessage'),
      child: Material(
        key: const ValueKey('messages-compose'),
        color: colors.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.large),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 56,
            child: AppIcon(
              Icons.edit_rounded,
              color: colors.onPrimaryContainer,
              semanticLabel: context.tr('newMessage'),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickedHeadline extends StatelessWidget {
  const _PickedHeadline(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emphasized =
        theme.extension<ExpressiveType>()?.emphasized ?? theme.textTheme;
    final style = emphasized.displaySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontFeatures: _tabular,
    );
    final text = _selectionTitle(context, count);
    final number = '$count';
    final at = count == 0 ? -1 : text.indexOf(number);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        liveRegion: true,
        child: Text.rich(
          at < 0
              ? TextSpan(text: text)
              : TextSpan(
                  children: [
                    TextSpan(text: text.substring(0, at)),
                    TextSpan(
                      text: number,
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                    TextSpan(text: text.substring(at + number.length)),
                  ],
                ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

/// What the bars show while picking, as a row of the page itself, where
/// the shell has no bars: on a wide screen.
class _InlineSelection extends StatelessWidget {
  const _InlineSelection(this.selection);

  final _Selection selection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Material(
        color: _pickedTint(theme),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('messages-selection-close'),
                tooltip: context.tr('messagesEndSelection'),
                onPressed: selection.onClose,
                icon: const AppIcon(Icons.close_rounded),
              ),
              Expanded(
                child: _PickedCount(
                  selection.count,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('messages-select-all'),
                tooltip: _selectAllLabel(context, selection),
                onPressed: selection.selectAll,
                icon: AppIcon(_selectAllIcon(selection)),
              ),
              if (selection.readable)
                IconButton(
                  key: const ValueKey('messages-mark-selected-read'),
                  tooltip: context.tr('messageMarkRead'),
                  onPressed: selection.read,
                  icon: const AppIcon(Icons.mark_email_read_rounded),
                ),
              IconButton(
                key: const ValueKey('messages-delete-selected'),
                tooltip: context.tr('messagesDelete'),
                color: colors.error,
                onPressed: selection.delete,
                icon: const AppIcon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a message goes in the list: the part of it its day falls in.
enum MessageSection { today, yesterday, thisWeek, earlier }

/// The section of a message received at [value], seen at [now]. Days are
/// counted on the calendar, so the day after the clocks change still has
/// its yesterday.
@visibleForTesting
MessageSection messageSection(DateTime value, DateTime now) {
  final days = calendarDaysBetween(value, now);
  if (days <= 0) return MessageSection.today;
  if (days == 1) return MessageSection.yesterday;
  if (days < 7 && value.weekday < now.weekday) return MessageSection.thisWeek;
  return MessageSection.earlier;
}

/// When a message came, went or was read, as its sheet says it: the day in
/// words while it is near, and always the short date and the time:
/// "Dziś, 27.10, 12:30", "Wczoraj, 26.10, 12:30", "Pon, 20.10, 12:30",
/// then "14.09, 12:30", and with the year for another year. [inSentence]
/// writes "dziś" and "wczoraj" (and, where weekdays are not capitalised,
/// the weekday) in lower case, as after "Wysłano".
String _messageStamp(
  BuildContext context,
  DateTime value, {
  DateTime? now,
  bool inSentence = false,
}) {
  final days = calendarDaysBetween(value, now ?? DateTime.now());
  var day = switch (days) {
    0 => context.tr('messagesToday'),
    1 => context.tr('messagesYesterday'),
    > 1 && < 7 => _shortWeekday(context, value),
    _ => null,
  };
  final lowerWeekdays = const {
    'pl',
    'ru',
    'uk',
  }.contains(Localizations.localeOf(context).languageCode);
  if (day != null && inSentence && (days <= 1 || lowerWeekdays)) {
    day = day[0].toLowerCase() + day.substring(1);
  }
  return [?day, _shortDate(context, value), _time(value)].join(', ');
}

/// "12:30" today, the weekday this week, the date before that.
String _messageTime(BuildContext context, DateTime value, DateTime now) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final days = calendarDaysBetween(value, now);
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
    super.key,
    required this.style,
    required this.now,
    this.selecting = false,
    this.selected = false,
    this.busy = false,
    this.onSelect,
  });
  final AppController controller;
  final SchoolMessage item;
  final MessageListStyle style;
  final DateTime now;
  final bool selecting, selected, busy;

  /// Picks the message, or lets it go: a tap while picking, a long press or
  /// a tap on the avatar at any time.
  final VoidCallback? onSelect;

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
    final unread = !item.sent && item.unread;
    final expressive = ExpressiveStyle.of(context);
    // A picked row stands out softly, rounded as the design rounds rows.
    final tint = expressive
        ? _pickedTint(theme)
        : colors.primary.withValues(
            alpha: theme.brightness == Brightness.light ? 0.10 : 0.14,
          );
    final radius = BorderRadius.circular(
      expressive
          ? 20
          : GlassStyle.of(context)
          ? 14
          : 16,
    );
    void longPress() {
      HapticFeedback.mediumImpact();
      onSelect?.call();
    }

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
          Semantics(
            button: true,
            selected: selected,
            label: '${context.tr('messagesSelect')}: ${item.subject}',
            excludeSemantics: true,
            child: InkResponse(
              key: ValueKey('message-select-${item.id}'),
              onTap: busy ? null : onSelect,
              radius: 24,
              child: _PickMark(
                picked: selected,
                square: expressive,
                child: item.sent
                    ? _SentAvatar(item.recipients.firstOrNull ?? '')
                    : _SenderAvatar(item.sender),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MarkedTitle(
                        item.sent
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
                        item.source,
                      ),
                    ),
                    if (item.hasAttachments)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: AppIcon(
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
                        duration: _listMotion(context),
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
            color: selected ? tint : null,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: busy
                  ? null
                  : selecting
                  ? onSelect
                  : () => _showMessageDetail(context, controller, item),
              onLongPress: busy ? null : longPress,
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
                borderRadius: radius,
                onTap: busy
                    ? null
                    : selecting
                    ? onSelect
                    : () => _showMessageDetail(context, controller, item),
                onLongPress: busy ? null : longPress,
                child: AnimatedContainer(
                  duration: _listMotion(context),
                  curve: _motionCurve(context),
                  decoration: BoxDecoration(
                    color: selected ? tint : tint.withValues(alpha: 0),
                    borderRadius: radius,
                  ),
                  child: content,
                ),
              ),
              // Under the text, past the avatar: 12 + 40 + 12. A picked
              // row needs no line to stand apart.
              Divider(
                height: 1,
                indent: 64,
                color: selected ? Colors.transparent : null,
              ),
            ],
          );
    final accessible = Semantics(
      selected: selecting ? selected : null,
      child: tile,
    );
    if (item.sent) return accessible;
    // Kept once read, only no longer swiped, so the row changes in place.
    return Dismissible(
      key: ValueKey('message-${item.id}'),
      direction: unread && !selecting && !busy
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      confirmDismiss: (_) {
        // Felt, as the homework's swipe is.
        HapticFeedback.lightImpact();
        return _markRead(context);
      },
      background: _SwipeAction(
        icon: Icons.mark_email_read_rounded,
        label: context.tr('messageMarkRead'),
      ),
      child: accessible,
    );
  }
}

/// A row's avatar, turned into a check while the message is picked: a
/// circle, or in Expressive a rounded square, as its shapes change when
/// chosen.
class _PickMark extends StatelessWidget {
  const _PickMark({
    required this.picked,
    required this.square,
    required this.child,
  });

  final bool picked;
  final bool square;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: _motion(context, const Duration(milliseconds: 200)),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: picked
          ? Container(
              key: const ValueKey('picked'),
              width: 40,
              height: 40,
              decoration: ShapeDecoration(
                color: colors.primary,
                shape: square
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      )
                    : const CircleBorder(),
              ),
              child: AppIcon(
                Icons.check_rounded,
                size: 22,
                color: colors.onPrimary,
              ),
            )
          : KeyedSubtree(key: const ValueKey('avatar'), child: child),
    );
  }
}

/// Asks before [count] messages are deleted, the way the design asks: in
/// the glass design iOS's action sheet, UIKit's own on iOS 26 and drawn
/// alike elsewhere; Expressive's dialog with its icon; or the app's own
/// dialog.
Future<bool> _askDelete(BuildContext context, int count) async {
  final title = _plural(context, count, 'messagesDeleteCount');
  final note = _plural(context, count, 'messagesDeleteNote');
  if (GlassStyle.of(context)) {
    final theme = Theme.of(context);
    final native = await GlassPlatform.confirm(
      title: title,
      message: note,
      action: context.tr('messagesDelete'),
      cancel: MaterialLocalizations.of(context).cancelButtonLabel,
      tint: theme.colorScheme.primary,
      dark: theme.brightness == Brightness.dark,
    );
    if (native != null) return native;
    if (!context.mounted) return false;
    return _glassDeleteSheet(context, title: title, note: note);
  }
  if (ExpressiveStyle.of(context)) {
    return _expressiveDeleteDialog(context, title: title, note: note);
  }
  return _confirm(
    context,
    title: title,
    message: note,
    action: context.tr('messagesDelete'),
    actionKey: const ValueKey('messages-confirm-delete'),
  );
}

/// iOS's action sheet drawn on glass where UIKit does not draw it: what is
/// about to go with the destructive button under it, and the way back
/// apart, below.
Future<bool> _glassDeleteSheet(
  BuildContext context, {
  required String title,
  required String note,
}) async {
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: glassBarrierColor,
    transitionDuration: _motion(context, const Duration(milliseconds: 300)),
    pageBuilder: (dialogContext, animation, _) {
      final theme = Theme.of(dialogContext);
      final colors = theme.colorScheme;
      // Where Flutter draws the glass it brings the panels up itself; a
      // fade around them would leave them nothing to show through.
      final reveal = GlassPlatform.backend == GlassBackend.rendered
          ? animation
          : null;
      Widget button(
        String label, {
        required Key key,
        required Color color,
        required FontWeight weight,
        required bool value,
      }) => SizedBox(
        width: double.infinity,
        height: 58,
        child: TextButton(
          key: key,
          onPressed: () => Navigator.pop(dialogContext, value),
          style: TextButton.styleFrom(
            foregroundColor: color,
            shape: const RoundedRectangleBorder(),
            // The theme's typeface, Inter where the glass is drawn.
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: weight,
            ),
          ),
          child: Text(label),
        ),
      );
      final muted = theme.textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontSize: 13,
      );
      return Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassPanel(
                  radius: 28,
                  reveal: reveal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                        child: Column(
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: muted?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              note,
                              textAlign: TextAlign.center,
                              style: muted,
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: colors.outlineVariant),
                      button(
                        context.tr('messagesDelete'),
                        key: const ValueKey('messages-confirm-delete'),
                        // The system's red, as UIKit's sheet has it.
                        color: GlassToolbar.destructive(theme.brightness),
                        weight: FontWeight.w500,
                        value: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GlassPanel(
                  radius: 28,
                  reveal: reveal,
                  child: button(
                    MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                    key: const ValueKey('messages-cancel-delete'),
                    color: colors.primary,
                    weight: FontWeight.w600,
                    value: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.35),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
  return confirmed ?? false;
}

/// Material 3 Expressive's dialog with a hero icon: the icon in the error
/// container, the question under it, the two choices side by side.
Future<bool> _expressiveDeleteDialog(
  BuildContext context, {
  required String title,
  required String note,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colors = theme.colorScheme;
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: ShapeDecoration(
                  color: colors.errorContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: AppIcon(
                  Icons.delete_outline_rounded,
                  size: 28,
                  color: colors.onErrorContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(
                        MaterialLocalizations.of(dialogContext)
                            .cancelButtonLabel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('messages-confirm-delete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: colors.onError,
                      ),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(context.tr('messagesDelete')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}

Future<void> _deleteMessages(
  BuildContext context,
  AppController controller,
  List<SchoolMessage> messages, {
  VoidCallback? onConfirmed,
}) async {
  final scope = (
    controller.together,
    controller.activeProfile?.id,
    controller.snapshot.profile.id,
  );
  final confirmed = await _askDelete(context, messages.length);
  if (confirmed != true ||
      !context.mounted ||
      scope !=
          (
            controller.together,
            controller.activeProfile?.id,
            controller.snapshot.profile.id,
          )) {
    return;
  }
  try {
    onConfirmed?.call();
    await controller.deleteMessages(messages);
  } on Object {
    if (context.mounted &&
        scope ==
            (
              controller.together,
              controller.activeProfile?.id,
              controller.snapshot.profile.id,
            )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('messagesDeleteFailed'))),
      );
    }
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
            child: AppIcon(
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
      child: AppIcon(
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

  /// Whether the last link tapped in the text could not be opened.
  bool linkFailed = false;

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
        _SheetProfileMark(widget.controller, message.source),
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
                      _messageStamp(context, message.receivedAt),
                      key: const ValueKey('message-stamp'),
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
                icon: const AppIcon(Icons.close_rounded),
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
                  _SheetProfileMark(widget.controller, widget.message.source),
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
                                _messageStamp(context, message.receivedAt),
                                key: const ValueKey('message-stamp'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const Divider(height: 32),
                  // Its links open with a tap; the text stays selectable.
                  LinkedText(
                    message.body,
                    key: const ValueKey('message-body'),
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(height: 1.45),
                    onOpenFailed: () => setState(() => linkFailed = true),
                    onOpened: () => setState(() => linkFailed = false),
                  ),
                  if (linkFailed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.tr('linkOpenFailed'),
                        key: const ValueKey('link-open-failed'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
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
                          leading: const AppIcon(Icons.attach_file_rounded),
                          title: Text(attachment.name),
                          trailing: openingAttachment == attachment.id
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const AppIcon(Icons.open_in_new_rounded),
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
                                          _messageStamp(
                                            context,
                                            receiver.readAt!,
                                            inSentence: true,
                                          ),
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
                _messageStamp(context, summary.receivedAt, inSentence: true),
              ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
