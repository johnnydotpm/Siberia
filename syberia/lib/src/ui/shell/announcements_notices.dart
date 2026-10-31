part of '../app_shell.dart';

class _Announcements extends StatelessWidget {
  const _Announcements(this.controller);
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final announcements = controller.snapshot.announcements;
    if (announcements.isEmpty) {
      return _PageEmpty(
        context.tr('emptyAnnouncements'),
        icon: Icons.campaign_rounded,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return _Refresh(
      controller: controller,
      child: _PageList(
        padding: const EdgeInsets.all(_Space.page),
        children: _spaced(
          announcements.map(
            (item) => Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: _Space.inset,
                ),
                // Unread ones stand out in the theme's colour.
                leading: _IconTile(
                  icon: Icons.campaign_rounded,
                  background: item.read
                      ? colors.surfaceContainerHighest
                      : colors.primaryContainer,
                  foreground: item.read
                      ? colors.onSurfaceVariant
                      : colors.onPrimaryContainer,
                ),
                title: _MarkedTitle(
                  Text(
                    item.title,
                    style: _rowTitleStyle(context)?.copyWith(
                      fontWeight: item.read ? FontWeight.w700 : FontWeight.w800,
                    ),
                  ),
                  item.source,
                ),
                subtitle: Text(
                  '${item.author} · ${_shortDate(context, item.createdAt)}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _Space.inset,
                      0,
                      _Space.inset,
                      _Space.inset,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SelectableText(item.content),
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
}

class _Notices extends StatelessWidget {
  const _Notices(this.controller);
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final notices = controller.snapshot.notices;
    if (notices.isEmpty) {
      return _PageEmpty(
        context.tr('emptyNotices'),
        icon: Icons.chat_bubble_rounded,
      );
    }
    return _Refresh(
      controller: controller,
      child: _PageList(
        padding: const EdgeInsets.all(_Space.page),
        children: _spaced(notices.map(_NoticeCard.new)),
      ),
    );
  }
}

/// One note from a teacher: its kind in its tone, the teacher and the day;
/// a tap unfolds the text.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard(this.item);
  final StudentNotice item;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // The tones of the calendar's kinds, so they suit the theme.
    final tone = switch (item.tone) {
      NoticeTone.positive => SubjectColors.tone(135, brightness),
      NoticeTone.neutral => SubjectColors.grade(null, brightness),
      NoticeTone.negative => SubjectColors.tone(4, brightness),
    };
    final icon = switch (item.tone) {
      NoticeTone.positive => Icons.thumb_up_alt_rounded,
      NoticeTone.neutral => Icons.chat_bubble_rounded,
      NoticeTone.negative => Icons.report_rounded,
    };
    final toneLabel = context.tr(switch (item.tone) {
      NoticeTone.positive => 'noticePositive',
      NoticeTone.neutral => 'noticeNeutral',
      NoticeTone.negative => 'noticeNegative',
    });
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: _Space.inset),
        leading: _IconTile(
          icon: icon,
          background: tone.background,
          foreground: tone.foreground,
        ),
        // What the note is, "Pochwała", says more than its tone,
        // which the colour and the symbol show already.
        title: _MarkedTitle(
          Text(
            item.category.isEmpty ? toneLabel : _capitalize(item.category),
            style: _rowTitleStyle(context)?.copyWith(color: tone.accent),
          ),
          item.source,
        ),
        subtitle: Text(item.teacher),
        trailing: Text(
          _shortDate(context, item.date),
          style: _metaStyle(context),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _Space.inset,
              0,
              _Space.inset,
              _Space.inset,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.category.isNotEmpty) ...[
                    Text(
                      toneLabel,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: tone.accent),
                    ),
                    const SizedBox(height: 6),
                  ],
                  SelectableText(item.text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
