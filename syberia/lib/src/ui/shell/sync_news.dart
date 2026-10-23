part of '../app_shell.dart';

/// After a sync, what it brought: a small capsule at the top for a few
/// seconds, "New · 🎓 +2 · ✉ +1". A kind opens its page; a swipe up puts the
/// capsule away.
class _SyncNewsBanner extends StatefulWidget {
  const _SyncNewsBanner(this.controller);
  final AppController controller;

  /// How long the capsule stays.
  static const shownFor = Duration(seconds: 4);

  @override
  State<_SyncNewsBanner> createState() => _SyncNewsBannerState();
}

class _SyncNewsBannerState extends State<_SyncNewsBanner> {
  /// The news on screen, kept while the capsule leaves.
  SyncNews? _shown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(_SyncNewsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  /// New news starts the capsule's time again.
  void _follow() {
    final news = widget.controller.syncNews;
    if (news == null || identical(news, _shown)) return;
    _shown = news;
    _timer?.cancel();
    _timer = Timer(_SyncNewsBanner.shownFor, () {
      if (identical(widget.controller.syncNews, news)) {
        widget.controller.dismissSyncNews();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _open(int tab) {
    HapticFeedback.selectionClick();
    widget.controller.dismissSyncNews();
    widget.controller.selectTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.controller.syncNews != null;
    final news = _shown;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -0.6),
        duration: _motion(context, _Motion.page),
        curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: _motion(context, _Motion.list),
          child: news == null ? const SizedBox.shrink() : _capsule(news),
        ),
      ),
    );
  }

  Widget _capsule(SyncNews news) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final kinds = [
      (news.grades, Icons.school_rounded, 'grades', 2),
      (news.messages, Icons.mail_rounded, 'messages', 5),
      (news.homework, Icons.assignment_rounded, 'homework', 4),
      (news.events, Icons.event_note_rounded, 'calendar', 3),
      (news.announcements, Icons.campaign_rounded, 'announcements', 7),
      (news.notices, Icons.chat_bubble_rounded, 'notices', 8),
    ].where((kind) => kind.$1 > 0);
    final content = Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
            child: Text(
              context.tr('syncNews'),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final (count, icon, label, tab) in kinds)
            Semantics(
              button: true,
              label: '${context.tr(label)}: +$count',
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('sync-news-$label'),
                customBorder: const StadiumBorder(),
                onTap: () => _open(tab),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '+$count',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontFeatures: _tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return GestureDetector(
      key: const ValueKey('sync-news'),
      // Up and away, like a notification.
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) {
          widget.controller.dismissSyncNews();
        }
      },
      child: GlassStyle.of(context)
          ? GlassPanel(radius: 24, child: content)
          : DecoratedBox(
              // A soft shadow and a hairline edge, as iOS floats things.
              decoration: ShapeDecoration(
                color: dark ? colors.surfaceContainerHighest : colors.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                    width: 0.5,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.4 : 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: content,
              ),
            ),
    );
  }
}
