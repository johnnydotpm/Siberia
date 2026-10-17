import 'package:flutter/material.dart';

/// Soft colours for subjects and senders.
///
/// Each subject gets one of [hueCount] hues; Material's tonal palette turns a
/// hue into a calm container colour with readable text, pastel in light mode
/// and deep in dark mode. Subjects are spread over the hues so that two
/// subjects share one only when there are more subjects than hues, and
/// [forDay] keeps the subjects of a single day apart even then.
@immutable
class SubjectColors {
  const SubjectColors._(this._indexes);

  factory SubjectColors.assign(Iterable<String> subjects) {
    final sorted = subjects.toSet().toList()..sort();
    final taken = <int>{};
    final indexes = <String, int>{};
    for (final subject in sorted) {
      final index = _free(stableHash(subject) % hueCount, taken);
      indexes[subject] = index;
      taken.add(index);
      // Once every hue is in use, a new round spreads the rest again.
      if (taken.length == hueCount) taken.clear();
    }
    return SubjectColors._(indexes);
  }

  static const hueCount = 16;
  static const empty = SubjectColors._({});

  final Map<String, int> _indexes;

  int indexOf(String subject) =>
      _indexes[subject] ?? stableHash(subject) % hueCount;

  /// Hue indexes for the subjects of one day, no two of them alike while
  /// there are hues left.
  Map<String, int> forDay(Iterable<String> subjects) {
    final taken = <int>{};
    final result = <String, int>{};
    for (final subject in subjects.toSet().toList()..sort()) {
      final index = _free(indexOf(subject), taken);
      result[subject] = index;
      taken.add(index);
    }
    return result;
  }

  /// The background and text colour of hue [index].
  static ({Color background, Color foreground, Color accent}) colors(
    int index,
    Brightness brightness,
  ) {
    final scheme = _schemes.putIfAbsent(
      (index % hueCount, brightness),
      () => ColorScheme.fromSeed(
        seedColor: HSVColor.fromAHSV(
          1,
          (index % hueCount) * 360 / hueCount,
          0.65,
          0.8,
        ).toColor(),
        brightness: brightness,
      ),
    );
    return (
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
      accent: scheme.primary,
    );
  }

  static final _schemes = <(int, Brightness), ColorScheme>{};

  /// The colours of a grade worth [value]: red for 1 through orange, amber
  /// and lime to green and teal for 6. Grades without a number are grey.
  static ({Color background, Color foreground, Color accent}) grade(
    double? value,
    Brightness brightness,
  ) {
    final bucket = value == null ? 0 : value.round().clamp(1, 6);
    final scheme = _gradeSchemes.putIfAbsent(
      (bucket, brightness),
      () => ColorScheme.fromSeed(
        seedColor: bucket == 0
            ? const Color(0xFF8A9199)
            : HSVColor.fromAHSV(
                1,
                const [0.0, 4.0, 28.0, 46.0, 84.0, 135.0, 172.0][bucket],
                0.75,
                0.85,
              ).toColor(),
        brightness: brightness,
        dynamicSchemeVariant: bucket == 0
            ? DynamicSchemeVariant.neutral
            : DynamicSchemeVariant.tonalSpot,
      ),
    );
    return (
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
      accent: scheme.primary,
    );
  }

  static final _gradeSchemes = <(int, Brightness), ColorScheme>{};

  /// A hash that stays the same across runs and platforms, unlike
  /// [String.hashCode].
  static int stableHash(String text) {
    var hash = 0;
    for (final unit in text.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  static int _free(int start, Set<int> taken) {
    for (var step = 0; step < hueCount; step++) {
      final index = (start + step) % hueCount;
      if (!taken.contains(index)) return index;
    }
    return start;
  }

  @override
  bool operator ==(Object other) =>
      other is SubjectColors && _sameMap(other._indexes, _indexes);

  @override
  int get hashCode => Object.hashAllUnordered(
    _indexes.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );

  static bool _sameMap(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);
}
