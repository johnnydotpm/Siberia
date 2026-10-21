import 'package:shared_preferences/shared_preferences.dart';

/// The homework the student marked as done. Librus has no such mark, so it
/// stays on the phone. Each mark keeps its work's due day, so marks for
/// work long past are dropped.
abstract final class HomeworkDoneStore {
  static const key = 'homework_done_v1';

  /// Marks for work due longer ago than this are dropped when saving.
  static const keep = Duration(days: 60);

  /// The marked homework's ids with their due days.
  static Map<String, DateTime> read(SharedPreferences preferences) => {
    for (final entry in preferences.getStringList(key) ?? const <String>[])
      if (_parse(entry) case (final id, final due)) id: due,
  };

  static Future<void> write(
    SharedPreferences preferences,
    Map<String, DateTime> marks, {
    DateTime? now,
  }) {
    final oldest = (now ?? DateTime.now()).subtract(keep);
    return preferences.setStringList(key, [
      for (final MapEntry(key: id, value: due) in marks.entries)
        if (!due.isBefore(oldest)) '${_day(due)}|$id',
    ]);
  }

  /// "2026-10-21|id": the day first, so an id may hold any character.
  static (String, DateTime)? _parse(String entry) {
    final split = entry.indexOf('|');
    if (split < 0) return null;
    final due = DateTime.tryParse(entry.substring(0, split));
    return due == null ? null : (entry.substring(split + 1), due);
  }

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
