import 'models.dart';

/// A subject's grades with "what if" grades added: how they would move the
/// average, and how many of one grade it takes to reach a target average.
class GradeProjection {
  const GradeProjection(this.settings, this.grades, [this.added = const []]);

  final GradeAverageSettings settings;
  final List<Grade> grades;

  /// Grades the student is trying out; they are never sent anywhere.
  final List<Grade> added;

  double? get current => settings.average(grades);

  double? get projected => settings.average([...grades, ...added]);

  /// How many grades [label] of [weight], on top of [grades] and [added],
  /// bring the average to at least [target]. 0 when it is there already,
  /// null when that grade never gets there or it takes more than [limit].
  int? needed({
    required double target,
    required String label,
    required double weight,
    int limit = 30,
  }) {
    const epsilon = 1e-9;
    final value = settings.valueOf(label);
    final counted = settings.weighted ? weight : 1.0;
    if (value == null || counted <= 0) return null;
    final (:sum, :total) = settings.totals([...grades, ...added]);
    if (total > 0 && sum / total >= target - epsilon) return 0;
    if (total == 0) return value >= target - epsilon ? 1 : null;
    // Grades equal to the target only come closer to it, never reach it.
    if (value <= target + epsilon) return null;
    final count =
        ((target * total - sum) / (counted * (value - target)) - epsilon)
            .ceil();
    final atLeastOne = count < 1 ? 1 : count;
    return atLeastOne > limit ? null : atLeastOne;
  }
}

/// The grades a student can try out: 1 to 6, with "+" and "-" where Librus
/// uses them.
String gradeLabel(int value, int modifier) {
  if (modifier > 0 && value < 6) return '$value+';
  if (modifier < 0 && value > 1) return '$value-';
  return '$value';
}

/// The weights to offer for a subject: those its grades already have, or 1
/// to 3 when it has none yet.
List<double> weightOptions(Iterable<Grade> grades) {
  final weights = {
    for (final grade in grades)
      if (grade.weight > 0) grade.weight,
  }.toList()..sort();
  return weights.isEmpty ? const [1, 2, 3] : weights;
}

/// The weight most of a subject's grades have, 1 when it has none.
double usualWeight(Iterable<Grade> grades) {
  final counts = <double, int>{};
  for (final grade in grades) {
    if (grade.weight > 0) {
      counts[grade.weight] = (counts[grade.weight] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return 1;
  return counts.entries
      .reduce(
        (best, entry) =>
            entry.value > best.value ||
                (entry.value == best.value && entry.key < best.key)
            ? entry
            : best,
      )
      .key;
}

/// A first target to suggest: the next half grade above [average].
double suggestedTarget(double? average) {
  if (average == null) return 4;
  final next = (average * 2).floorToDouble() / 2 + 0.5;
  return next > 6 ? 6 : next;
}
