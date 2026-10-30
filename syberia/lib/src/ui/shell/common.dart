part of '../app_shell.dart';

String _decimal(BuildContext context, double value) => NumberFormat(
  '0.##',
  Localizations.localeOf(context).toLanguageTag(),
).format(value);

/// The room a bar of system buttons takes at the bottom of the screen. It
/// lies over the app and takes the touches there, so a sheet that reaches
/// the bottom keeps its last control above it. An iPhone's home indicator
/// and Android's gesture handle are in the way of nothing and count as no
/// room at all. While the keyboard is up, the bar is under it.
double _systemButtonsRoom(BuildContext context) {
  final inset = MediaQuery.paddingOf(context).bottom;
  return inset > 34 ? inset : 0;
}

/// Short subject names and subject colours, for the pages of the shell.
class _SubjectScope extends InheritedWidget {
  const _SubjectScope({
    this.studentTools = true,
    required this.names,
    required this.colors,
    required super.child,
  });

  final bool studentTools;
  static bool allowsStudentTools(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SubjectScope>()
          ?.studentTools ??
      true;
  final Map<String, String> names;
  final SubjectColors colors;

  /// The short name for [subject], or the subject itself.
  static String of(BuildContext context, String subject) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SubjectScope>();
    return displaySubject(subject, scope?.names ?? const {});
  }

  static SubjectColors colorsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SubjectScope>()?.colors ??
      SubjectColors.empty;

  @override
  bool updateShouldNotify(_SubjectScope oldWidget) =>
      names != oldWidget.names ||
      colors != oldWidget.colors ||
      studentTools != oldWidget.studentTools;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.onAll});
  final String text;
  final VoidCallback? onAll;
  // A step below the cards' own titles, so the content leads.
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      if (onAll != null)
        TextButton(
          onPressed: onAll,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsetsDirectional.only(start: 10, end: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('all')),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
    ],
  );
}

/// Nothing to show, said the way the system does: the page's own symbol
/// and what is missing, rather than a generic "no data".
class _Empty extends StatelessWidget {
  const _Empty(
    this.text, {
    this.icon = Icons.inbox_rounded,
    this.color,
    super.key,
  });
  final String text;
  final IconData icon;

  /// The symbol's colour, when it says something good, like all done.
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: color ?? theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Digits of one width, so times and counts that change do not shift the
/// text around them.
const _tabular = [FontFeature.tabularFigures()];

/// The quiet chevron at the end of a row that opens something.
class _Chevron extends StatelessWidget {
  const _Chevron();
  @override
  Widget build(BuildContext context) => Icon(
    Icons.chevron_right_rounded,
    size: 20,
    color: Theme.of(context).colorScheme.outline,
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.text,
    required this.color,
    this.trailing,
    super.key,
  });
  final IconData icon;
  final String text;
  final Color color;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color)),
      trailing: trailing,
    ),
  );
}

/// Says that a VPN is on and Librus sometimes blocks VPNs, in [text], only
/// while one is. It asks when it appears and again whenever [error]
/// changes; nothing keeps asking in between.
class _VpnHint extends StatefulWidget {
  const _VpnHint({
    required this.text,
    this.error,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String text;
  final Object? error;

  /// Around the card, while it shows.
  final EdgeInsetsGeometry padding;

  @override
  State<_VpnHint> createState() => _VpnHintState();
}

class _VpnHintState extends State<_VpnHint> {
  bool _on = false;
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_ask());
  }

  @override
  void didUpdateWidget(_VpnHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.error, widget.error)) unawaited(_ask());
  }

  Future<void> _ask() async {
    final asked = ++_asked;
    final on = await Vpn.isActive() == true;
    if (!mounted || asked != _asked || on == _on) return;
    setState(() => _on = on);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.topStart,
      child: !_on
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: widget.padding,
              child: Card(
                key: const ValueKey('vpn-hint'),
                color: colors.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.vpn_lock_rounded,
                        color: colors.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.text,
                          style: TextStyle(color: colors.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// The app's controller, for widgets deep in a page that act on it. Pages
/// rebuild when it changes, so this never needs to tell them.
class _ControllerScope extends InheritedWidget {
  const _ControllerScope({required this.controller, required super.child});
  final AppController controller;

  static AppController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ControllerScope>()
      ?.controller;

  @override
  bool updateShouldNotify(_ControllerScope oldWidget) =>
      controller != oldWidget.controller;
}

/// The one spacing scale of the pages, so that they line up with each
/// other.
abstract final class _Space {
  /// From the edge of the screen to a page's content.
  static const double page = 16;

  /// Between the cards of one list.
  static const double item = 8;

  /// Between cards that stand on their own.
  static const double card = 16;

  /// Above a section's heading.
  static const double section = 24;

  /// From a heading to what it heads.
  static const double heading = 8;

  /// From a card's edge to its content.
  static const double inset = 16;

  /// From a sheet's edge to its content.
  static const double sheet = 20;
}

/// [items] with the gap of a list between them.
List<Widget> _spaced(Iterable<Widget> items, [double gap = _Space.item]) => [
  for (final (index, item) in items.indexed) ...[
    if (index > 0) SizedBox(height: gap),
    item,
  ],
];

/// "{count} days" in the right form: Polish, Russian and Ukrainian have
/// three of them, English and German two. [key] names the three texts:
/// `${key}One`, `${key}Few` and `${key}Many`.
String _plural(BuildContext context, int count, String key) =>
    AppLocalizations.of(context).plural(count, key);

/// The label over a group of a list: a day, a month, a part of the
/// settings. [accent] draws it in the theme's colour, as the settings do.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.accent = false, this.top = 0, super.key});
  final String text;
  final bool accent;
  final double top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(12, top, 12, _Space.heading),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: accent
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// A button across the whole width: one height for all of them.
final _wideButton = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(48),
);

/// A sheet's title.
TextStyle? _sheetTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800);

/// A row's title in a list of cards.
TextStyle? _rowTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall
        ?.copyWith(fontWeight: FontWeight.w700);

/// The quiet line under or beside a row's title: a date, a teacher.
TextStyle? _metaStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

/// The square in front of a row that stands for a kind of thing; people
/// get a round avatar instead.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.background,
    required this.foreground,
    this.icon,
    this.label,
    super.key,
  });
  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? label;

  static const double size = 40;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: icon != null
        ? Icon(icon, size: 22, color: foreground)
        : Text(
            label ?? '',
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: foreground, fontWeight: FontWeight.w800),
          ),
  );
}

/// Asks before something that cannot be undone. True once confirmed.
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  Key? actionKey,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AppDialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(
                      MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                    ),
                  ),
                  FilledButton(
                    key: actionKey,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(action),
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

class _Refresh extends StatelessWidget {
  const _Refresh({
    required this.controller,
    required this.child,
    this.onRefresh,
    this.nested = false,
  });
  final AppController controller;
  final Widget child;

  /// What a pull does, when not a sync of everything.
  final Future<void> Function()? onRefresh;

  /// Whether the list pulled is deeper down, as a day inside the timetable's
  /// pages: the indicator still comes at the top of the page, under the bar.
  final bool nested;

  @override
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
    // A tap felt the moment the pull takes, as in the system apps.
    onRefresh: () {
      HapticFeedback.mediumImpact();
      return (onRefresh ?? controller.sync)();
    },
    notificationPredicate: nested
        ? (notification) => notification.metrics.axis == Axis.vertical
        : defaultScrollNotificationPredicate,
    // Under a glass top bar the indicator would otherwise appear behind it.
    edgeOffset: _chromeInsets(context).top,
    child: child,
  );
}

/// The space the floating glass bars take from a page. Outside the glass
/// chrome the bars are not floating, and there is nothing to make room for.
EdgeInsets _chromeInsets(BuildContext context) =>
    GlassPageScope.maybeOf(context) == null
    ? EdgeInsets.zero
    : MediaQuery.paddingOf(context);

/// A page's own list. Inside the glass chrome it starts below the top bar,
/// ends above the tab bar and opens with the page's large title.
class _PageList extends StatelessWidget {
  const _PageList({required this.padding, required this.children});
  final EdgeInsets padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scope = GlassPageScope.maybeOf(context);
    if (scope == null) {
      return ListView(
        // A search field's keyboard goes once the list is moved.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: padding,
        children: children,
      );
    }
    final insets = MediaQuery.paddingOf(context);
    final title = scope.largeTitle;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: padding.copyWith(
        // The title brings its own spacing below the bar.
        top: (title == null ? padding.top : 0) + insets.top,
        bottom: padding.bottom + insets.bottom,
      ),
      children: [
        if (title != null)
          Padding(
            // Titles keep the system margin whatever the page's own padding.
            padding: EdgeInsets.symmetric(
              horizontal: math.max(0.0, GlassLargeTitle.margin - padding.left),
            ),
            child: GlassLargeTitle(title),
          ),
        ...children,
      ],
    );
  }
}

/// A page with nothing to list. Inside the glass chrome the large title stays
/// in place above the placeholder.
class _PageEmpty extends StatelessWidget {
  const _PageEmpty(this.text, {this.icon = Icons.inbox_rounded});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scope = GlassPageScope.maybeOf(context);
    if (scope == null) return _Empty(text, icon: icon);
    final insets = MediaQuery.paddingOf(context);
    final title = scope.largeTitle;
    return Padding(
      padding: EdgeInsets.only(top: insets.top, bottom: insets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GlassLargeTitle.margin,
              ),
              child: GlassLargeTitle(title),
            ),
          Expanded(child: _Empty(text, icon: icon)),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _date(DateTime value) => DateFormat('dd.MM.yyyy').format(value);

/// A date in a list: the day and month, and the year only when it is not
/// this one.
String _shortDate(BuildContext context, DateTime value) => DateFormat(
  value.year == DateTime.now().year ? 'dd.MM' : 'dd.MM.yyyy',
  Localizations.localeOf(context).toLanguageTag(),
).format(value);

String _percent(BuildContext context, double value) =>
    NumberFormat.decimalPercentPattern(
      locale: Localizations.localeOf(context).toLanguageTag(),
      decimalDigits: 1,
    ).format(value / 100);

String _shortWeekday(BuildContext context, DateTime value) => _capitalize(
  DateFormat.E(Localizations.localeOf(context).toLanguageTag())
      .format(value)
      .replaceAll('.', ''),
);

/// The heading of a month in a list: "Wrzesień", and "Wrzesień 2025" for
/// another year than [now]'s.
String _monthHeading(BuildContext context, DateTime month, DateTime now) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return _capitalize(
    (month.year == now.year
            ? DateFormat.LLLL(locale)
            : DateFormat.yMMMM(locale))
        .format(month),
  );
}

String _capitalize(String value) => value.isEmpty
    ? value
    : '${value.characters.first.toUpperCase()}${value.substring(value.characters.first.length)}';

/// What a swipe along a row does, shown under it as it slides.
class _SwipeAction extends StatelessWidget {
  const _SwipeAction({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One action of a row's long-press menu.
typedef _ItemAction = ({
  Key key,
  IconData icon,
  String label,
  VoidCallback run,
});

/// What a long press on a row offers, as a menu sheet: the row's name and
/// its actions. Felt as the press takes, as in iOS.
Future<void> _showItemActions(
  BuildContext context, {
  required String title,
  required List<_ItemAction> actions,
}) {
  HapticFeedback.mediumImpact();
  return showAppSheet<void>(
    context: context,
    compact: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        key: const ValueKey('item-actions'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _Space.sheet,
              0,
              _Space.sheet,
              8,
            ),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _rowTitleStyle(sheet),
            ),
          ),
          for (final action in actions)
            ListTile(
              key: action.key,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: _Space.sheet,
              ),
              leading: Icon(action.icon),
              title: Text(action.label),
              onTap: () {
                Navigator.pop(sheet);
                action.run();
              },
            ),
          SizedBox(height: 8 + _systemButtonsRoom(sheet)),
        ],
      ),
    ),
  );
}

/// Text that wraps between words rather than inside one. When a single word
/// is wider than the space, as long German words are with large text, the
/// font shrinks until that word fits, but not below 70%: past that a break
/// inside the word reads better than tiny text.
class _WholeWords extends StatelessWidget {
  const _WholeWords(
    this.text, {
    this.style,
    this.textAlign,
    this.maxLines,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      style: _fitWords(context, text, style, constraints.maxWidth),
    ),
  );
}

TextStyle? _fitWords(
  BuildContext context,
  String text,
  TextStyle? style,
  double width,
) {
  if (!width.isFinite) return style;
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  final words = text.split(RegExp(r'\s+'));
  double widest(TextStyle style) {
    var result = 0.0;
    for (final word in words) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      result = math.max(result, painter.width);
      painter.dispose();
    }
    return result;
  }

  final base = DefaultTextStyle.of(context).style.merge(style);
  final smallest = (base.fontSize ?? 14) * 0.7;
  var fitted = base;
  // Large text can scale non-linearly, so check again after each step.
  for (var step = 0; step < 4; step++) {
    final needed = widest(fitted);
    final size = fitted.fontSize ?? 14;
    if (needed <= width || size <= smallest) break;
    fitted = fitted.copyWith(
      fontSize: math.max(smallest, size * width / needed * 0.98),
    );
  }
  return identical(fitted, base) ? style : fitted;
}

/// Lower case without Polish accents, one letter for one, so positions
/// stay the same as in the original. Searches compare in it: "lukasz"
/// finds "Łukasz".
String _plainPolish(String value) {
  const from = 'ąćęłńóśźż';
  const to = 'acelnoszz';
  final lower = value.toLowerCase();
  final out = StringBuffer();
  for (final unit in lower.split('')) {
    final index = from.indexOf(unit);
    out.write(index < 0 ? unit : to[index]);
  }
  return out.toString();
}
