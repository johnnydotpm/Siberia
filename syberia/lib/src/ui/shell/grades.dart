part of '../app_shell.dart';

class _Grades extends StatefulWidget {
  const _Grades(this.controller);
  final AppController controller;

  @override
  State<_Grades> createState() => _GradesState();
}

class _GradesState extends State<_Grades> {
  late int semester = _preferredSemester(widget.controller.snapshot.grades);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = controller.gradeAverage;
    final view = controller.gradesView;
    final grades = controller.snapshot.grades
        .where((grade) => grade.semester == semester)
        .toList(growable: false);
    // Grades come newest first, so subjects with recent grades lead.
    final groups = <String, List<Grade>>{};
    for (final item in grades) {
      groups.putIfAbsent(item.subject, () => []).add(item);
    }
    return _PageList(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 1, label: Text(context.tr('period1'))),
                  ButtonSegment(value: 2, label: Text(context.tr('period2'))),
                ],
                selected: {semester},
                onSelectionChanged: (selection) =>
                    setState(() => semester = selection.first),
              ),
            ),
            IconButton(
              key: const ValueKey('grades-view-toggle'),
              tooltip: context.tr(
                view == GradesView.compact
                    ? 'gradesViewCards'
                    : 'gradesViewCompact',
              ),
              onPressed: () => controller.setGradesView(
                view == GradesView.compact
                    ? GradesView.cards
                    : GradesView.compact,
              ),
              icon: Icon(
                view == GradesView.compact
                    ? Icons.view_agenda_outlined
                    : Icons.view_list_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GradesOverview(grades, settings),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          _Empty(context.tr('noData'))
        else
          for (final MapEntry(key: subject, value: items) in groups.entries)
            view == GradesView.compact
                ? _SubjectGradesRow(
                    subject: subject,
                    grades: items,
                    settings: settings,
                  )
                : _SubjectGradesTile(
                    subject: subject,
                    grades: items,
                    settings: settings,
                  ),
      ],
    );
  }
}

/// The semester under way: the second from February to August.
int _preferredSemester(List<Grade> grades) {
  final now = DateTime.now();
  final preferred = now.month >= 2 && now.month <= 8 ? 2 : 1;
  final available = grades.map((grade) => grade.semester).toSet();
  return available.contains(preferred) || available.isEmpty
      ? preferred
      : available.first;
}

/// Grades added in the last week count as new.
bool _isNewGrade(Grade grade, DateTime now) =>
    now.difference(grade.date) < const Duration(days: 7);

/// The semester average, how many grades and how they spread from 1 to 6.
class _GradesOverview extends StatelessWidget {
  const _GradesOverview(this.grades, this.settings);
  final List<Grade> grades;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = settings.average(grades);
    final now = DateTime.now();
    final fresh = grades.where((grade) => _isNewGrade(grade, now)).length;
    final buckets = <int, int>{};
    for (final grade in grades) {
      final value = settings.valueOf(grade.value);
      if (value == null) continue;
      final bucket = value.round().clamp(1, 6);
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    return Card(
      key: const ValueKey('grades-overview'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AveragePill(average, large: true),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('averageGrade'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          context.trArgs('gradesCount', {
                            'count': '${grades.length}',
                          }),
                          if (fresh > 0)
                            context.trArgs('gradesNew', {'count': '$fresh'}),
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (buckets.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var bucket = 1; bucket <= 6; bucket++)
                        if (buckets[bucket] != null)
                          Expanded(
                            flex: buckets[bucket]!,
                            child: ColoredBox(
                              color: SubjectColors.grade(
                                bucket.toDouble(),
                                theme.brightness,
                              ).accent,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (var bucket = 1; bucket <= 6; bucket++)
                    if (buckets[bucket] != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: SubjectColors.grade(
                                bucket.toDouble(),
                                theme.brightness,
                              ).accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$bucket',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            ' × ${buckets[bucket]}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An average in the colour of the grade it rounds to.
class _AveragePill extends StatelessWidget {
  const _AveragePill(this.average, {this.large = false});
  final double? average;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SubjectColors.grade(average, theme.brightness);
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(large ? 16 : 10),
      ),
      child: Text(
        average == null ? '—' : _decimal(context, average!),
        style: TextStyle(
          color: palette.foreground,
          fontSize: large ? 26 : 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// A grade in the colour of its value. A grade that replaced an earlier
/// one keeps Librus's brackets, and a new grade has a dot.
class _GradeChip extends StatelessWidget {
  const _GradeChip(
    this.grade, {
    required this.settings,
    this.size = 32,
    this.showNew = true,
  });
  final Grade grade;
  final GradeAverageSettings settings;
  final double size;

  /// The dot on grades from the last week.
  final bool showNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SubjectColors.grade(
      settings.valueOf(grade.value),
      theme.brightness,
    );
    final chip = Container(
      key: ValueKey('grade-chip-${grade.id}'),
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: EdgeInsets.symmetric(horizontal: size * 0.16),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      // As wide as the grade, never wider.
      child: Center(
        widthFactor: 1,
        child: Text(
          grade.wasChanged ? '[${grade.value}]' : grade.value,
          maxLines: 1,
          style: TextStyle(
            color: palette.foreground,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    if (!showNew || !_isNewGrade(grade, DateTime.now())) return chip;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        chip,
        PositionedDirectional(
          top: -2,
          end: -2,
          child: Container(
            key: ValueKey('grade-new-${grade.id}'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// A subject on one row: its grades in order and its average.
class _SubjectGradesRow extends StatelessWidget {
  const _SubjectGradesRow({
    required this.subject,
    required this.grades,
    required this.settings,
  });
  final String subject;
  final List<Grade> grades;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = SubjectColors.colors(
      _SubjectScope.colorsOf(context).indexOf(subject),
      theme.brightness,
    ).accent;
    final chronological = grades.reversed.toList(growable: false);
    return Card(
      key: ValueKey('grades-subject-$subject'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSubjectGrades(context, subject, grades, settings),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _SubjectScope.of(context, subject),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final grade in chronological)
                          _GradeChip(grade, settings: settings, size: 30),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AveragePill(settings.average(grades)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A subject as a card that opens to list its grades.
class _SubjectGradesTile extends StatelessWidget {
  const _SubjectGradesTile({
    required this.subject,
    required this.grades,
    required this.settings,
  });
  final String subject;
  final List<Grade> grades;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = SubjectColors.colors(
      _SubjectScope.colorsOf(context).indexOf(subject),
      theme.brightness,
    ).accent;
    final average = settings.average(grades);
    return Card(
      key: ValueKey('grades-subject-$subject'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _SubjectScope.of(context, subject),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _AveragePill(average),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final grade in grades.reversed)
                  _GradeChip(grade, settings: settings, size: 24),
              ],
            ),
          ),
          children: [
            for (final grade in grades) _GradeRow(grade, settings: settings),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: ValueKey('grade-calculator-open-$subject'),
                  onPressed: () =>
                      _showGradeCalculator(context, subject, grades, settings),
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(context.tr('gradeCalculator')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One grade with what it was for, when and how much it weighs.
class _GradeRow extends StatelessWidget {
  const _GradeRow(this.grade, {required this.settings});
  final Grade grade;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () => _showGradeDetails(context, grade),
    leading: _GradeChip(grade, settings: settings, size: 42),
    title: Text(
      grade.category.isNotEmpty
          ? grade.category
          : (grade.description.isNotEmpty
                ? grade.description
                : context.tr('grade')),
    ),
    subtitle: Text(
      '${_date(grade.date)} · ${context.tr('weight').toLowerCase()} ${_decimal(context, grade.weight)}',
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}

Future<void> _showSubjectGrades(
  BuildContext context,
  String subject,
  List<Grade> grades,
  GradeAverageSettings settings,
) => showAppSheet<void>(
  context: context,
  compact: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        key: const ValueKey('subject-grades-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.tr('averageGrade')} · ${context.trArgs('gradesCount', {'count': '${grades.length}'})}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AveragePill(settings.average(grades), large: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: FilledButton.tonalIcon(
                key: const ValueKey('grade-calculator-open'),
                onPressed: () =>
                    _showGradeCalculator(context, subject, grades, settings),
                icon: const Icon(Icons.calculate_outlined),
                label: Text(context.tr('gradeCalculator')),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final grade in grades)
                    _GradeRow(grade, settings: settings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);

Future<void> _showGradeDetails(BuildContext context, Grade grade) =>
    showAppSheet<void>(
      context: context,
      compact: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final history = [grade, ...grade.previousGrades.reversed];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      context.tr('gradeDetails'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < history.length; index++) ...[
                    if (index > 0)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    _GradeHistoryCard(
                      key: ValueKey('grade-history-${history[index].id}'),
                      grade: history[index],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

class _GradeHistoryCard extends StatelessWidget {
  const _GradeHistoryCard({super.key, required this.grade});

  final Grade grade;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            grade.value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          _GradeDetailRow(context.tr('subject'), grade.subject),
          if (grade.category.isNotEmpty)
            _GradeDetailRow(context.tr('category'), grade.category),
          _GradeDetailRow(
            context.tr('description'),
            grade.description.isEmpty ? '—' : grade.description,
          ),
          _GradeDetailRow(context.tr('date'), _date(grade.date)),
          _GradeDetailRow(
            context.tr('weight'),
            _decimal(context, grade.weight),
          ),
        ],
      ),
    ),
  );
}

class _GradeDetailRow extends StatelessWidget {
  const _GradeDetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
