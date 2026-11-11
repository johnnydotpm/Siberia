part of '../app_shell.dart';

/// A setting chosen from a few picture cards.
class _PreviewChoice<T> extends StatelessWidget {
  const _PreviewChoice({
    required this.title,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final String title;
  final IconData icon;
  final List<({T value, String label, Key key, Widget preview})> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SettingsIcon(icon),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final option in options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Semantics(
                      selected: option.value == selected,
                      button: true,
                      child: Builder(
                        builder: (optionContext) => InkWell(
                          key: option.key,
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _choose(optionContext, option.value),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 64,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: option.value == selected
                                          ? colors.primary
                                          : colors.outlineVariant,
                                      width: option.value == selected ? 2.5 : 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: SizedBox.expand(
                                      child: option.preview,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _WholeWords(
                                  option.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: option.value == selected
                                        ? colors.primary
                                        : colors.onSurface,
                                    fontWeight: option.value == selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The new look spreads in a circle from the option tapped, as in
  /// Telegram.
  void _choose(BuildContext context, T value) {
    if (value == selected) return;
    HapticFeedback.selectionClick();
    final box = context.findRenderObject();
    ScreenTransitions.run(
      context,
      ScreenChange.reveal,
      () => onSelected(value),
      origin: box is RenderBox && box.hasSize
          ? box.localToGlobal(box.size.center(Offset.zero))
          : null,
    );
  }
}

/// A tiny screen in the given colours: a title, and a card with two lines.
Widget _miniScreen({
  required Color background,
  required Color card,
  required Color line,
  required Color accent,
}) => ColoredBox(
  color: background,
  child: Padding(
    padding: const EdgeInsets.all(6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 6,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 4, color: line),
                const SizedBox(height: 3),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: Container(height: 4, color: line),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);

class _ThemePreview extends StatelessWidget {
  const _ThemePreview(this.mode);
  final AppColorMode mode;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final light = _miniScreen(
      background: const Color(0xFFF2F4F5),
      card: Colors.white,
      line: const Color(0xFFCBD2D6),
      accent: accent,
    );
    final dark = _miniScreen(
      background: const Color(0xFF151A1D),
      card: const Color(0xFF232A2E),
      line: const Color(0xFF414B51),
      accent: accent,
    );
    return switch (mode) {
      AppColorMode.light => light,
      AppColorMode.dark => dark,
      AppColorMode.amoled => _miniScreen(
        background: Colors.black,
        card: const Color(0xFF0E1012),
        line: const Color(0xFF2C3236),
        accent: accent,
      ),
      AppColorMode.system => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: light),
          Expanded(child: dark),
        ],
      ),
    };
  }
}

/// The app's designs to choose from. Glass is among them only where the
/// platform can draw it; there the app is classic when glass was chosen.
class _DesignChoice extends StatelessWidget {
  const _DesignChoice(this.controller, {required this.keyPrefix});
  final AppController controller;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final glass = GlassPlatform.supported;
    return _PreviewChoice<AppDesign>(
      title: context.tr('design'),
      icon: Icons.auto_awesome_rounded,
      selected: controller.design == AppDesign.glass && !glass
          ? AppDesign.classic
          : controller.design,
      onSelected: controller.setDesign,
      options: [
        for (final design in AppDesign.values)
          if (design != AppDesign.glass || glass)
            (
              value: design,
              label: context.tr('design_${design.name}'),
              key: ValueKey('$keyPrefix-design-${design.name}'),
              preview: _DesignPreview(design),
            ),
      ],
    );
  }
}

class _DesignPreview extends StatelessWidget {
  const _DesignPreview(this.design);
  final AppDesign design;

  @override
  Widget build(BuildContext context) {
    if (design == AppDesign.expressive) return const _ExpressivePreview();
    if (design == AppDesign.classic) return const _ClassicPreview();
    final colors = Theme.of(context).colorScheme;
    final glass = design == AppDesign.glass;
    Widget bar({required bool top}) => Container(
      height: 10,
      margin: glass
          ? EdgeInsets.fromLTRB(top ? 4 : 10, 4, top ? 4 : 10, 4)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: glass
            ? Colors.white.withValues(alpha: 0.42)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(glass ? 6 : 0),
        border: glass
            ? Border.all(color: Colors.white.withValues(alpha: 0.6))
            : null,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? null : colors.surface,
        gradient: glass
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primaryContainer, colors.tertiaryContainer],
              )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [bar(top: true), bar(top: false)],
      ),
    );
  }
}

/// A page of the classic design in miniature, in the app's colours: the
/// bar with the title, a card with two lines, and the navigation bar with
/// the open tab. It shows in the black theme too, where the containers are
/// near black.
class _ClassicPreview extends StatelessWidget {
  const _ClassicPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget line(double width) => Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: colors.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    Widget dot(Color color, {double width = 8}) => Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            height: 12,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            child: dot(colors.primary, width: 18),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(double.infinity),
                    const SizedBox(height: 3),
                    line(22),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 12,
            color: colors.surfaceContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                dot(colors.primary.withValues(alpha: 0.35), width: 14),
                dot(colors.onSurfaceVariant.withValues(alpha: 0.4)),
                dot(colors.onSurfaceVariant.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A page of the Expressive design in miniature: a rounded card in the
/// primary container and the navigation bar with its pill.
class _ExpressivePreview extends StatelessWidget {
  const _ExpressivePreview();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.brandScheme(Theme.of(context).brightness);
    Widget dot(Color color, {double width = 8}) => Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 14,
            color: colors.surfaceContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                dot(colors.secondaryContainer, width: 16),
                dot(colors.onSurfaceVariant.withValues(alpha: 0.4)),
                dot(colors.onSurfaceVariant.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPreview extends StatelessWidget {
  const _ChartPreview(this.style);
  final AttendanceChartStyle style;

  static final _segments = [
    (count: 6, color: _attendanceColor(AttendanceKind.present)),
    (count: 2, color: _attendanceColor(AttendanceKind.absent)),
    (count: 1, color: _attendanceColor(AttendanceKind.absentExcused)),
    (count: 1, color: _attendanceColor(AttendanceKind.late)),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Center(
        child: style == AttendanceChartStyle.bar
            ? ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  width: 52,
                  height: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final segment in _segments)
                        Expanded(
                          flex: segment.count,
                          child: ColoredBox(color: segment.color),
                        ),
                    ],
                  ),
                ),
              )
            : CustomPaint(
                size: const Size.square(42),
                painter: _AttendancePiePainter(
                  segments: _segments,
                  ring: style == AttendanceChartStyle.ring,
                  emptyColor: colors.surfaceContainerHighest,
                ),
              ),
      ),
    );
  }
}

/// The student's average with the chosen settings, or a sample before there
/// are grades, so a change shows what it does.
class _AveragePreview extends StatelessWidget {
  const _AveragePreview(this.controller);
  final AppController controller;

  static final _sample = [
    for (final (value, weight) in const [('4+', 2.0), ('3-', 1.0), ('5', 3.0)])
      Grade(
        id: 'sample-$value',
        subject: '',
        value: value,
        description: '',
        date: DateTime(2000),
        weight: weight,
        semester: 1,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = controller.gradeAverage;
    final grades = controller.snapshot.grades;
    final semester = _preferredSemester(grades);
    final own = settings.average(
      grades.where((grade) => grade.semester == semester),
    );
    return ListTile(
      key: const ValueKey('settings-average-preview'),
      leading: const _SettingsIcon(Icons.calculate_rounded),
      title: Text(
        controller.isParent
            ? context.trArgs('parentAverage', {
                'child': controller.activeProfile?.name ?? '',
              })
            : context.tr('averagePreview'),
      ),
      subtitle: Text(
        own != null
            ? context.tr('averagePreviewOwn')
            : context.trArgs('averageExample', {
                'grades': _sample.map((grade) => grade.value).join(', '),
              }),
      ),
      trailing: _AveragePill(own ?? settings.average(_sample)),
    );
  }
}
