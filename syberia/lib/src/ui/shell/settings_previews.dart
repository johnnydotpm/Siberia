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
                      child: InkWell(
                        key: option.key,
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onSelected(option.value),
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
                                  child: SizedBox.expand(child: option.preview),
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
            ],
          ),
        ],
      ),
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

class _DesignPreview extends StatelessWidget {
  const _DesignPreview(this.design);
  final AppDesign design;

  @override
  Widget build(BuildContext context) {
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
      title: Text(context.tr('averagePreview')),
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
