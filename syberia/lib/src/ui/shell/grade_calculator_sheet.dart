part of '../app_shell.dart';

Future<void> _showGradeCalculator(
  BuildContext context,
  String subject,
  List<Grade> grades,
  GradeAverageSettings settings,
) => showAppSheet<void>(
  context: context,
  compact: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: _GradeCalculator(
        subject: subject,
        grades: grades,
        settings: settings,
      ),
    ),
  ),
);

/// Tries out grades for one subject: the average they would give, and how
/// many of a grade a target average takes. Nothing is sent to Librus.
class _GradeCalculator extends StatefulWidget {
  const _GradeCalculator({
    required this.subject,
    required this.grades,
    required this.settings,
  });
  final String subject;
  final List<Grade> grades;
  final GradeAverageSettings settings;

  @override
  State<_GradeCalculator> createState() => _GradeCalculatorState();
}

class _GradeCalculatorState extends State<_GradeCalculator> {
  final List<Grade> _added = [];
  int _modifier = 0;
  var _nextId = 0;
  late double _weight = usualWeight(widget.grades);
  late double _target = suggestedTarget(widget.settings.average(widget.grades));

  void _add(int value) => setState(
    () => _added.add(
      Grade(
        id: 'what-if-${_nextId++}',
        subject: widget.subject,
        value: gradeLabel(value, _modifier),
        description: '',
        // Never shown; the field is required.
        date: DateTime(2000),
        weight: _weight,
        semester: 0,
      ),
    ),
  );

  void _moveTarget(double step) =>
      setState(() => _target = (_target + step).clamp(1.0, 6.0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.settings;
    final projection = GradeProjection(settings, widget.grades, _added);
    final current = projection.current;
    final projected = projection.projected;
    final delta = current == null || projected == null || _added.isEmpty
        ? null
        : projected - current;
    final reached = projected != null && projected >= _target - 1e-9;
    // needed() decides which grades can get there: with no counted grades
    // yet, one grade equal to the target is enough.
    final needed = {
      for (var value = 1; value <= 6; value++)
        value: projection.needed(
          target: _target,
          label: '$value',
          weight: _weight,
        ),
    }..removeWhere((_, count) => count == null);
    final heading = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SingleChildScrollView(
      key: const ValueKey('grade-calculator-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('gradeCalculator'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.subject,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('gradeCalculatorNow'),
                          style: muted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          context.tr('gradeCalculatorAfter'),
                          textAlign: TextAlign.end,
                          style: muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _AveragePill(current, large: true),
                      Expanded(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      KeyedSubtree(
                        key: const ValueKey('calculator-projected'),
                        child: _AveragePill(projected, large: true),
                      ),
                    ],
                  ),
                  if (delta != null && delta.abs() >= 0.005) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${delta > 0 ? '+' : '−'}${_decimal(context, delta.abs())}',
                      key: const ValueKey('calculator-delta'),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: delta > 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(context.tr('gradeCalculatorAdd'), style: heading),
              ),
              SegmentedButton<int>(
                key: const ValueKey('calculator-modifier'),
                showSelectedIcon: false,
                emptySelectionAllowed: true,
                segments: const [
                  ButtonSegment(value: -1, label: Text('−')),
                  ButtonSegment(value: 1, label: Text('+')),
                ],
                selected: {if (_modifier != 0) _modifier},
                onSelectionChanged: (selection) => setState(
                  () => _modifier = selection.isEmpty ? 0 : selection.first,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var value = 1; value <= 6; value++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _CalculatorGradeButton(
                      key: ValueKey('calculator-add-$value'),
                      label: gradeLabel(value, _modifier),
                      value: settings.valueOf(gradeLabel(value, _modifier)),
                      onPressed: () => _add(value),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (settings.weighted)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${context.tr('weight')}:', style: muted),
                for (final weight in weightOptions(widget.grades))
                  ChoiceChip(
                    key: ValueKey(
                      'calculator-weight-${_decimal(context, weight)}',
                    ),
                    label: Text(_decimal(context, weight)),
                    selected: _weight == weight,
                    onSelected: (_) => setState(() => _weight = weight),
                  ),
              ],
            )
          else
            Text(context.tr('gradeCalculatorUnweighted'), style: muted),
          const SizedBox(height: 12),
          if (_added.isEmpty)
            Text(context.tr('gradeCalculatorHint'), style: muted)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var index = 0; index < _added.length; index++)
                        _CalculatorAddedGrade(
                          // By id, so removing one grade does not hand
                          // its chip to the next.
                          key: ValueKey(_added[index].id),
                          grade: _added[index],
                          settings: settings,
                          onDeleted: () =>
                              setState(() => _added.removeAt(index)),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  key: const ValueKey('calculator-clear'),
                  onPressed: () => setState(_added.clear),
                  child: Text(context.tr('gradeCalculatorClear')),
                ),
              ],
            ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('gradeCalculatorTarget'),
                  style: heading,
                ),
              ),
              IconButton.outlined(
                key: const ValueKey('calculator-target-down'),
                onPressed: _target > 1 ? () => _moveTarget(-0.25) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  _decimal(context, _target),
                  key: const ValueKey('calculator-target'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.outlined(
                key: const ValueKey('calculator-target-up'),
                onPressed: _target < 6 ? () => _moveTarget(0.25) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (reached)
            Row(
              key: const ValueKey('calculator-reached'),
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr('gradeCalculatorReached'))),
              ],
            )
          else if (needed.isEmpty)
            Text(
              context.tr('gradeCalculatorOut'),
              key: const ValueKey('calculator-out-of-reach'),
            )
          else
            Column(
              key: const ValueKey('calculator-needed'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.weighted
                      ? '${context.tr('gradeCalculatorNeeded')} (${context.tr('weight').toLowerCase()} ${_decimal(context, _weight)})'
                      : context.tr('gradeCalculatorNeeded'),
                  style: muted,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final MapEntry(key: value, value: count)
                        in needed.entries)
                      Row(
                        key: ValueKey('calculator-needed-$value'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CalculatorGradeBadge('$value', settings: settings),
                          const SizedBox(width: 6),
                          Text(
                            '× $count',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A grade from 1 to 6 to try out, in that grade's colour.
class _CalculatorGradeButton extends StatelessWidget {
  const _CalculatorGradeButton({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
  });
  final String label;
  final double? value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = SubjectColors.grade(value, Theme.of(context).brightness);
    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: palette.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A grade value in its colour, without a Librus grade behind it.
class _CalculatorGradeBadge extends StatelessWidget {
  const _CalculatorGradeBadge(this.label, {required this.settings});
  final String label;
  final GradeAverageSettings settings;

  @override
  Widget build(BuildContext context) {
    final palette = SubjectColors.grade(
      settings.valueOf(label),
      Theme.of(context).brightness,
    );
    return Container(
      height: 30,
      constraints: const BoxConstraints(minWidth: 30),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: TextStyle(
            color: palette.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// A grade the student added to try out, with its weight and a way to drop
/// it again.
class _CalculatorAddedGrade extends StatelessWidget {
  const _CalculatorAddedGrade({
    super.key,
    required this.grade,
    required this.settings,
    required this.onDeleted,
  });
  final Grade grade;
  final GradeAverageSettings settings;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final palette = SubjectColors.grade(
      settings.valueOf(grade.value),
      Theme.of(context).brightness,
    );
    return InputChip(
      label: Text(
        settings.weighted
            ? '${grade.value} · ${_decimal(context, grade.weight)}'
            : grade.value,
      ),
      labelStyle: TextStyle(
        color: palette.foreground,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: palette.background,
      deleteIconColor: palette.foreground,
      side: BorderSide.none,
      onDeleted: onDeleted,
    );
  }
}
