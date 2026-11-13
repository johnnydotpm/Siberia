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

/// "Odebrane" or "Wysłane": the folder as the page's title says it.
String _folderName(BuildContext context, _MessageFolder folder) => context.tr(
  folder == _MessageFolder.inbox ? 'messagesInbox' : 'messagesSent',
);

class _MessagesState extends State<_Messages> {
  final _search = TextEditingController();
  bool _unreadOnly = false;

  /// The folder open, held by the shell when it has one, so its bar can be
  /// titled after it; else by the page.
  ValueNotifier<_MessageFolder>? _folderHeld;
  _MessageFolder _ownFolder = _MessageFolder.inbox;
  _MessageFolder get _folder => _folderHeld?.value ?? _ownFolder;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _folderHeld = _SelectionScope.maybeOf(context)?.folder;
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
    if (folder == _folder) return;
    HapticFeedback.selectionClick();
    _shownUnread.clear();
    _selected.clear();
    _selecting = false;
    setState(() {
      if (_folderHeld case final held?) {
        held.value = folder;
      } else {
        _ownFolder = folder;
      }
    });
    // A sync leaves the Sent folder out, so it is loaded when opened.
    if (folder == _MessageFolder.sent) {
      unawaited(widget.controller.refreshSentMessages());
    }
  }

  /// The menu of folders under the title, in the design's own kind.
  Future<void> _pickFolder(Rect anchor) async {
    final folder = _folder;
    final picked = GlassStyle.of(context)
        ? await showGlassMenu<_MessageFolder>(
            context: context,
            anchor: anchor,
            items: [
              for (final value in _MessageFolder.values)
                GlassMenuItem(
                  key: ValueKey('messages-folder-${value.name}'),
                  value: value,
                  label: _folderName(context, value),
                  selected: value == folder,
                ),
            ],
          )
        : await showMenu<_MessageFolder>(
            context: context,
            position: RelativeRect.fromRect(
              Rect.fromLTWH(anchor.left, anchor.bottom, anchor.width, 0),
              Offset.zero & MediaQuery.sizeOf(context),
            ),
            items: [
              for (final value in _MessageFolder.values)
                CheckedPopupMenuItem(
                  key: ValueKey('messages-folder-${value.name}'),
                  value: value,
                  checked: value == folder,
                  child: Text(_folderName(context, value)),
                ),
            ],
          );
    if (picked != null && mounted) _openFolder(picked);
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
    // Felt as picking starts, from a long press or the mark beside a row.
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

  /// The messages under their days: a label for each day, then its rows.
  List<Widget> _rows(List<SchoolMessage> messages, DateTime now) {
    final rows = <Widget>[];
    for (var index = 0; index < messages.length; index++) {
      final item = messages[index];
      final section = _section(item.receivedAt, now);
      final first =
          index == 0 ||
          _section(messages[index - 1].receivedAt, now) != section;
      final last =
          index == messages.length - 1 ||
          _section(messages[index + 1].receivedAt, now) != section;
      if (first) {
        rows.add(
          _MessagesSectionLabel(
            section,
            key: ValueKey('messages-section-$section'),
            top: index == 0 ? _Space.item : _Space.card,
          ),
        );
      }
      rows.add(
        _MessageRow(
          widget.controller,
          item,
          key: ValueKey('message-tile-${item.id}'),
          now: now,
          first: first,
          last: last,
          folder: _folderName(context, _folder),
          selecting: _selecting,
          selected: _selected.contains(item.id),
          busy: _working,
          onSelect: () => _toggle(item),
        ),
      );
    }
    return rows;
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
    final now = DateTime.now();
    final rows = _rows(messages, now);
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
      _MessagesSearchField(
        controller: _search,
        onChanged: () => setState(_selected.clear),
      ),
      _MessagesStatusRow(
        controller: controller,
        sentFolder: sentFolder,
        unreadOnly: _unreadOnly,
        selecting: _selecting,
        canSelect: !_working && messages.isNotEmpty,
        onSelect: _startSelection,
        onUnreadOnly: (value) => setState(() {
          _unreadOnly = value;
          _shownUnread.clear();
          _selected.clear();
        }),
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
      // Another folder or filter fades through; within one, messages
      // deleted fold away and new ones open, as on Today. A search shows
      // its matches at once.
      // Keyed, so a row coming above it, as the skeleton of the Sent
      // folder, does not make it start afresh.
      _FadeThroughSwitcher(
        key: const ValueKey('messages-rows'),
        child: KeyedSubtree(
          key: ValueKey(('messages', _folder, _unreadOnly)),
          child: _AnimatedColumn(key: ValueKey(query), children: rows),
        ),
      ),
    ];
    final scope = GlassPageScope.maybeOf(context);
    final folderTitle = _FolderTitle(
      _folderName(context, _folder),
      onPick: _pickFolder,
    );
    // Under a glass top bar the compose button lives in the bar, and the
    // folder is the page's large title.
    if (scope != null && scope.barActions) {
      return _picking(
        _Refresh(
          controller: controller,
          onRefresh: refresh,
          child: _PageList(
            padding: const EdgeInsets.all(_Space.page),
            // While picking, the count is the title.
            title: selection == null ? folderTitle : null,
            children: tiles,
          ),
        ),
      );
    }
    final insets = _chromeInsets(context);
    final picking = selection != null && hosted;
    final page = Column(
      children: [
        SizedBox(height: insets.top),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            scope != null ? GlassLargeTitle.margin : _Space.page,
            scope != null ? 0 : _Space.page,
            _Space.page,
            0,
          ),
          // While picking, Expressive's title is the count, and the bars
          // hold what there is to do. Both at least as tall as the title,
          // so the list below does not jump as one fades into the other.
          child: AnimatedSwitcher(
            duration: _motion(context, const Duration(milliseconds: 250)),
            switchInCurve: _FadeThroughSwitcher.inCurve,
            switchOutCurve: _FadeThroughSwitcher.outCurve,
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.bottomStart,
              children: [...previous, ?current],
            ),
            child: ConstrainedBox(
              key: ValueKey(picking && expressive),
              constraints: BoxConstraints(minHeight: expressive ? 56 : 0),
              child: picking && expressive
                  ? Align(
                      alignment: AlignmentDirectional.bottomStart,
                      heightFactor: 1,
                      child: _PickedHeadline(selection.count),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: folderTitle),
                        // A classic page in the shell has writing in its
                        // top bar; on a wide screen, with no bar of the
                        // page's own, it stands beside the title.
                        if (!expressive && !hosted && scope == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: FilledButton.icon(
                              key: const ValueKey('messages-compose'),
                              onPressed: () =>
                                  _showComposeMessage(context, controller),
                              icon: const AppIcon(Icons.edit_rounded),
                              label: Text(context.tr('newMessage')),
                            ),
                          ),
                      ],
                    ),
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
                0,
                _Space.page,
                // Clear of Expressive's writing button and floating toolbar.
                _Space.page + insets.bottom + (expressive ? 88 : 0),
              ),
              children: tiles,
            ),
          ),
        ),
      ],
    );
    if (!expressive) return _picking(page);
    return _picking(
      Stack(
        children: [
          Positioned.fill(child: page),
          // Writing floats at the end, as Material's extended button does;
          // while picking the bars hold what there is to do.
          PositionedDirectional(
            end: _Space.page,
            bottom: _Space.page + insets.bottom,
            child: AnimatedSwitcher(
              duration: _motion(context, const Duration(milliseconds: 200)),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: picking
                  ? const SizedBox.shrink()
                  : FloatingActionButton.extended(
                      key: const ValueKey('messages-compose'),
                      heroTag: null,
                      onPressed: () => _showComposeMessage(context, controller),
                      icon: const AppIcon(Icons.edit_rounded),
                      label: Text(context.tr('messagesWrite')),
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

/// The folder as the page's title, with a chevron: a tap opens the menu of
/// folders under it. Drawn as the design draws a page's title.
class _FolderTitle extends StatelessWidget {
  const _FolderTitle(this.text, {required this.onPick});

  final String text;
  final ValueChanged<Rect> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final glass = GlassStyle.of(context);
    final expressive = ExpressiveStyle.of(context);
    final TextStyle? style;
    final EdgeInsets padding;
    if (glass) {
      style = TextStyle(
        color: colors.onSurface,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.37,
        height: 41 / 34,
      );
      padding = const EdgeInsets.only(top: 3, bottom: 8);
    } else if (expressive) {
      final emphasized =
          theme.extension<ExpressiveType>()?.emphasized ?? theme.textTheme;
      style = emphasized.displaySmall?.copyWith(color: colors.onSurface);
      padding = const EdgeInsets.only(bottom: 12);
    } else {
      style = theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      );
      padding = const EdgeInsets.only(bottom: 8);
    }
    final size = (style?.fontSize ?? 24) * 0.6;
    return Padding(
      padding: padding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Builder(
          builder: (context) => Semantics(
            header: true,
            button: true,
            child: InkWell(
              key: const ValueKey('messages-folder'),
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final box = context.findRenderObject()! as RenderBox;
                onPick(box.localToGlobal(Offset.zero) & box.size);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AppIcon(
                    glass
                        ? CupertinoIcons.chevron_down
                        : Icons.keyboard_arrow_down_rounded,
                    size: glass ? size * 0.8 : size * 1.2,
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The search field above the messages: a filled capsule in the glass
/// design, as in Mail; a filled field in the classic one; Material's search
/// bar in Expressive.
class _MessagesSearchField extends StatelessWidget {
  const _MessagesSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final glass = GlassStyle.of(context);
    final expressive = ExpressiveStyle.of(context);
    final dark = theme.brightness == Brightness.dark;
    final radius = glass ? 20.0 : (expressive ? 28.0 : 24.0);
    return TextField(
      key: const ValueKey('messages-search'),
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: glass ? const TextStyle(fontSize: 17, letterSpacing: -0.41) : null,
      decoration: InputDecoration(
        hintText: context.tr('messagesSearch'),
        prefixIcon: AppIcon(
          glass ? CupertinoIcons.search : Icons.search_rounded,
          color: colors.onSurfaceVariant,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: AppIcon(
                  glass
                      ? CupertinoIcons.xmark_circle_fill
                      : Icons.clear_rounded,
                  color: colors.onSurfaceVariant,
                ),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        filled: true,
        // iOS's search field: the system's grey fill.
        fillColor: glass
            ? const Color(0xFF767680).withValues(alpha: dark ? 0.24 : 0.12)
            : colors.surfaceContainerHigh,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          vertical: glass ? 10 : (expressive ? 18 : 14),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// What the folder holds and the ways to narrow it, under the search:
/// "2 nieprzeczytane · zaktualizowano 12:41" with picking and the unread
/// filter beside it; Expressive's filter is a chip.
class _MessagesStatusRow extends StatelessWidget {
  const _MessagesStatusRow({
    required this.controller,
    required this.sentFolder,
    required this.unreadOnly,
    required this.selecting,
    required this.canSelect,
    required this.onSelect,
    required this.onUnreadOnly,
  });

  final AppController controller;
  final bool sentFolder;
  final bool unreadOnly;

  /// While picking, the bars hold the way out, so the button gives way.
  final bool selecting;
  final bool canSelect;
  final VoidCallback onSelect;
  final ValueChanged<bool> onUnreadOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final expressive = ExpressiveStyle.of(context);
    final glass = GlassStyle.of(context);
    final unread = controller.snapshot.unreadMessages;
    final loadingSent = sentFolder && controller.loadingSentMessages;
    final synced = controller.snapshot.lastSync;
    // As Mail's bar says it: what the folder holds, and when it was updated
    // under it.
    final first = sentFolder
        ? _plural(
            context,
            controller.snapshot.sentMessages.length,
            'messagesSentCount',
          )
        : unreadOnly
        ? context.tr('messagesFilteredUnread')
        : unread == 0
        ? context.tr('messagesAllRead')
        : _plural(context, unread, 'messagesUnreadCount');
    final second = sentFolder
        ? null
        : context.trArgs('messagesUpdatedAt', {
            'time': _messageTime(context, synced, DateTime.now()),
          });
    final small = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: glass ? 12 : null,
      fontFeatures: _tabular,
    );
    final text = Semantics(
      container: true,
      child: Column(
        key: const ValueKey('messages-status'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small?.copyWith(
              color: unreadOnly ? colors.primary : colors.onSurface,
              fontSize: glass ? 13 : null,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (second != null)
            Text(
              second,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small,
            ),
        ],
      ),
    );
    return ConstrainedBox(
      // As tall when picking as before, so no row below moves.
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          if (expressive && !sentFolder) ...[
            FilterChip(
              key: const ValueKey('messages-filter'),
              label: Text(context.tr('messagesUnread')),
              selected: unreadOnly,
              onSelected: onUnreadOnly,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: expressive ? 0 : 4),
              child: text,
            ),
          ),
          if (!selecting)
            // Beside Expressive's chip, an icon leaves the status its room.
            expressive
                ? IconButton(
                    key: const ValueKey('messages-select'),
                    tooltip: context.tr('messagesSelect'),
                    onPressed: canSelect ? onSelect : null,
                    icon: const AppIcon(Icons.checklist_rounded),
                  )
                : TextButton(
                    key: const ValueKey('messages-select'),
                    onPressed: canSelect ? onSelect : null,
                    child: Text(context.tr('messagesSelect')),
                  ),
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
            )
          else if (!expressive)
            IconButton(
              key: const ValueKey('messages-filter'),
              tooltip: context.tr('messagesUnread'),
              isSelected: unreadOnly,
              onPressed: () => onUnreadOnly(!unreadOnly),
              color: colors.primary,
              // Mail's filter: a circle with lines, filled while it filters.
              icon: AppIcon(
                glass
                    ? CupertinoIcons.line_horizontal_3_decrease_circle
                    : Icons.filter_list_rounded,
                color: colors.primary,
              ),
              selectedIcon: AppIcon(
                glass
                    ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
                    : Icons.filter_list_off_rounded,
                color: colors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// The label over a day's messages, lined up with the rows' text.
class _MessagesSectionLabel extends StatelessWidget {
  const _MessagesSectionLabel(this.text, {required this.top, super.key});
  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final expressive = ExpressiveStyle.of(context);
    final glass = GlassStyle.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        expressive ? 8 : _MessageRow.gutter,
        top,
        12,
        expressive ? 8 : 6,
      ),
      child: Text(
        text,
        style: expressive
            ? theme.textTheme.titleSmall?.copyWith(color: colors.primary)
            : glass
            ? TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.24,
              )
            : theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
      ),
    );
  }
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

/// A message in the list, as Mail shows it: a dot while unread beside the
/// sender, the date at the end, then the subject and two lines of the text.
/// The glass design and the classic one draw it as a row with a line under
/// it; Expressive as one piece of a group of the day, its outer corners
/// large and the inner ones small.
class _MessageRow extends StatelessWidget {
  const _MessageRow(
    this.controller,
    this.item, {
    super.key,
    required this.now,
    this.first = true,
    this.last = true,
    this.folder,
    this.selecting = false,
    this.selected = false,
    this.busy = false,
    this.onSelect,
    this.onCard = false,
  });
  final AppController controller;
  final SchoolMessage item;
  final DateTime now;

  /// Where it stands among the day's messages.
  final bool first, last;

  /// Where it was opened from, for the way back from the message.
  final String? folder;
  final bool selecting, selected, busy;

  /// Picks the message, or lets it go: a tap while picking, a long press or
  /// a tap on the mark beside it at any time.
  final VoidCallback? onSelect;

  /// Standing on a card of its own, as on Today: no line under it.
  final bool onCard;

  /// The room before the text, where the unread dot and the check stand.
  static const double gutter = 28;

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
    final glass = GlassStyle.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Mail's blue in the glass design, the theme's colour elsewhere.
    final accent = glass
        ? (dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF))
        : colors.primary;
    final tint = expressive
        ? _pickedTint(theme)
        : accent.withValues(alpha: dark ? 0.16 : 0.10);
    final radius = expressive
        ? BorderRadius.vertical(
            top: Radius.circular(first ? 20 : 4),
            bottom: Radius.circular(last ? 20 : 4),
          )
        : BorderRadius.circular(glass ? 12 : 14);
    final senderStyle = glass
        ? TextStyle(
            color: colors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
          )
        : theme.textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          );
    final subjectStyle = glass
        ? TextStyle(color: colors.onSurface, fontSize: 15, letterSpacing: -0.24)
        : theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
          );
    final previewStyle = glass
        ? TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 15,
            height: 20 / 15,
            letterSpacing: -0.24,
          )
        : theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
    final dateStyle = glass
        ? TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 15,
            letterSpacing: -0.24,
            fontFeatures: _tabular,
          )
        : theme.textTheme.labelMedium?.copyWith(
            color: unread ? accent : colors.onSurfaceVariant,
            fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
            fontFeatures: _tabular,
          );
    void longPress() {
      HapticFeedback.mediumImpact();
      onSelect?.call();
    }

    Widget dot() => Container(
      key: ValueKey('message-unread-${item.id}'),
      width: expressive ? 8 : 10,
      height: expressive ? 8 : 10,
      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
    );
    final line =
        MediaQuery.textScalerOf(context).scale(senderStyle?.fontSize ?? 16) *
        1.3;
    final mark = Semantics(
      button: true,
      selected: selected,
      label: '${context.tr('messagesSelect')}: ${item.subject}',
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey('message-select-${item.id}'),
        onTap: busy ? null : onSelect,
        radius: 20,
        child: SizedBox(
          width: gutter,
          // Level with the sender's line.
          height: line,
          child: Center(
            child: AnimatedSwitcher(
              duration: _motion(context, const Duration(milliseconds: 200)),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              // No layer of its own once settled, on every row at rest.
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                child: _Fade(opacity: animation, child: child),
              ),
              child: selecting
                  ? _PickCircle(
                      key: ValueKey(selected),
                      picked: selected,
                      color: accent,
                      square: expressive,
                    )
                  : unread
                  ? dot()
                  : const SizedBox.shrink(key: ValueKey('read')),
            ),
          ),
        ),
      ),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // While picking the check takes the dot's place, so the dot
            // stands before the sender.
            if (selecting && unread) ...[dot(), const SizedBox(width: 6)],
            Expanded(
              child: _MarkedTitle(
                item.sent
                    ? _RecipientsLine(item.recipients, style: senderStyle)
                    : Text(
                        item.sender.isEmpty ? '—' : item.sender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: senderStyle,
                      ),
                item.source,
              ),
            ),
            if (item.hasAttachments)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: AppIcon(
                  glass ? CupertinoIcons.paperclip : Icons.attach_file_rounded,
                  size: 15,
                  color: colors.onSurfaceVariant,
                  semanticLabel: context.tr('messageHasAttachment'),
                ),
              ),
            const SizedBox(width: 6),
            Text(_messageTime(context, item.receivedAt, now), style: dateStyle),
            if (glass)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: AppIcon(
                  CupertinoIcons.chevron_forward,
                  size: 14,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 1),
        Row(
          children: [
            Expanded(
              child: Text(
                item.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subjectStyle,
              ),
            ),
            if (item.sent && item.recipientRead != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: _ReadMark(
                  read: item.recipientRead!,
                  labelled: true,
                  key: ValueKey('sent-read-${item.id}'),
                ),
              ),
          ],
        ),
        if (item.preview.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              item.preview.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: previewStyle,
            ),
          ),
      ],
    );

    final content = Padding(
      padding: expressive
          ? const EdgeInsetsDirectional.fromSTEB(4, 12, 16, 12)
          : const EdgeInsetsDirectional.only(end: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: expressive || onCard ? 0 : 10),
            child: mark,
          ),
          Expanded(
            child: expressive || onCard
                ? text
                : Container(
                    // The line under a row starts where its text does, as
                    // in Mail; a picked row and a day's last need none.
                    padding: const EdgeInsets.only(top: 10, bottom: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: last || selected
                              ? Colors.transparent
                              : theme.dividerColor,
                          width: glass ? 0.5 : 1,
                        ),
                      ),
                    ),
                    child: text,
                  ),
          ),
        ],
      ),
    );
    final tile = Padding(
      padding: EdgeInsets.only(bottom: expressive && !last ? 2 : 0),
      child: Material(
        color: expressive ? colors.surfaceContainer : Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy
              ? null
              : selecting
              ? onSelect
              : () => _showMessageDetail(
                  context,
                  controller,
                  item,
                  folder: folder,
                ),
          onLongPress: busy ? null : longPress,
          child: AnimatedContainer(
            duration: _listMotion(context),
            curve: _motionCurve(context),
            padding: onCard
                ? const EdgeInsetsDirectional.fromSTEB(4, 12, 12, 12)
                : EdgeInsets.zero,
            color: selected ? tint : tint.withValues(alpha: 0),
            child: content,
          ),
        ),
      ),
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
        color: glass ? accent : null,
      ),
      child: accessible,
    );
  }
}

/// The check beside a row while picking: a circle, or in Expressive a
/// rounded square, as its shapes change when chosen.
class _PickCircle extends StatelessWidget {
  const _PickCircle({
    required this.picked,
    required this.color,
    required this.square,
    super.key,
  });

  final bool picked;
  final Color color;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = square
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: picked
                ? BorderSide.none
                : BorderSide(color: colors.outline, width: 1.5),
          )
        : CircleBorder(
            side: picked
                ? BorderSide.none
                : BorderSide(color: colors.outline, width: 1.5),
          );
    return Container(
      width: 22,
      height: 22,
      decoration: ShapeDecoration(
        color: picked ? color : Colors.transparent,
        shape: shape,
      ),
      child: picked
          ? AppIcon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// The count of picked messages as the Expressive page's large title, the
/// number in the accent colour.
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

/// "To: Teacher Alpha +2".
class _RecipientsLine extends StatelessWidget {
  const _RecipientsLine(this.recipients, {this.style});
  final List<String> recipients;

  /// The names' style, as the row's sender would have it.
  final TextStyle? style;

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
            style:
                style ??
                theme.textTheme.titleSmall?.copyWith(
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
  const _ReadMark({required this.read, this.labelled = false, super.key});
  final bool read;

  /// With its word beside it, as a row of the Sent folder says it.
  final bool labelled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = read ? colors.primary : colors.onSurfaceVariant;
    final label = context.tr(read ? 'messageRead' : 'messageNotRead');
    final icon = AppIcon(
      read ? Icons.done_all_rounded : Icons.done_rounded,
      size: labelled ? 16 : 18,
      color: color,
    );
    if (!labelled) return Tooltip(message: label, child: icon);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
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
