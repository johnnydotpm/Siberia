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
    required this.names,
    required this.colors,
    required super.child,
  });

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
      names != oldWidget.names || colors != oldWidget.colors;
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

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color)),
    ),
  );
}

class _Refresh extends StatelessWidget {
  const _Refresh({required this.controller, required this.child});
  final AppController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
    onRefresh: controller.sync,
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
    if (scope == null) return ListView(padding: padding, children: children);
    final insets = MediaQuery.paddingOf(context);
    final title = scope.largeTitle;
    return ListView(
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
  const _PageEmpty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scope = GlassPageScope.maybeOf(context);
    if (scope == null) return _Empty(text);
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
          Expanded(child: _Empty(text)),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _date(DateTime value) => DateFormat('dd.MM.yyyy').format(value);

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

String _capitalize(String value) => value.isEmpty
    ? value
    : '${value.characters.first.toUpperCase()}${value.substring(value.characters.first.length)}';
