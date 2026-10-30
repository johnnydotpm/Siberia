import 'models.dart';

/// What a sync brought that was not there before, counted by kind.
class SyncNews {
  const SyncNews({
    this.grades = 0,
    this.messages = 0,
    this.homework = 0,
    this.events = 0,
    this.announcements = 0,
    this.notices = 0,
  });

  /// What [after] has that [before] had not. A kind [before] had nothing of
  /// is only arriving, as on the first sync, and says nothing new; so do
  /// messages that could not be loaded before.
  factory SyncNews.between(AppSnapshot before, AppSnapshot after) {
    int added<T>(
      Iterable<T> old,
      Iterable<T> current,
      String Function(T item) id,
    ) {
      final known = {for (final item in old) id(item)};
      if (known.isEmpty) return 0;
      return current.where((item) => !known.contains(id(item))).length;
    }

    bool homework(SchoolEvent item) => item.kind == EventKind.homework;
    return SyncNews(
      grades: added(before.grades, after.grades, (item) => item.id),
      messages: before.messagesError != null
          ? 0
          : added(before.messages, after.messages, (item) => item.id),
      homework: added(
        before.events.where(homework),
        after.events.where(homework),
        (item) => item.id,
      ),
      events: added(
        before.events.where((item) => !homework(item)),
        after.events.where((item) => !homework(item)),
        (item) => item.id,
      ),
      announcements: added(
        before.announcements,
        after.announcements,
        (item) => item.id,
      ),
      notices: added(before.notices, after.notices, (item) => item.id),
    );
  }

  final int grades;
  final int messages;
  final int homework;
  final int events;
  final int announcements;
  final int notices;

  bool get isEmpty =>
      grades + messages + homework + events + announcements + notices == 0;
}
