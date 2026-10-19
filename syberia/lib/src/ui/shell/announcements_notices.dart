part of '../app_shell.dart';

class _Announcements extends StatelessWidget {
  const _Announcements(this.data);
  final AppSnapshot data;
  @override
  Widget build(BuildContext context) => data.announcements.isEmpty
      ? _PageEmpty(context.tr('noData'))
      : _PageList(
          padding: const EdgeInsets.all(12),
          children: data.announcements
              .map(
                (item) => Card(
                  child: ExpansionTile(
                    leading: Icon(
                      item.read
                          ? Icons.campaign_outlined
                          : Icons.campaign_rounded,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.read
                            ? FontWeight.w500
                            : FontWeight.w800,
                      ),
                    ),
                    subtitle: Text('${item.author} · ${_date(item.createdAt)}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(item.content),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
}

class _Notices extends StatelessWidget {
  const _Notices(this.data);
  final AppSnapshot data;
  @override
  Widget build(BuildContext context) => data.notices.isEmpty
      ? _PageEmpty(context.tr('noData'))
      : _PageList(
          padding: const EdgeInsets.all(12),
          children: data.notices.map((item) {
            final color = switch (item.tone) {
              NoticeTone.positive => Colors.green,
              NoticeTone.neutral => Colors.blueGrey,
              NoticeTone.negative => Colors.red,
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
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                title: Text(
                  toneLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(item.teacher),
                trailing: Text(_date(item.date)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.category.isNotEmpty) ...[
                            Text(
                              item.category,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: color),
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
          }).toList(),
        );
}
