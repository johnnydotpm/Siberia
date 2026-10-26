import 'models.dart';
import 'profiles.dart';

/// The view of every profile together, where a single profile's id would
/// be.
const togetherId = 'together';

/// [id] of profile [profileId] in the view together: begun with the
/// profile's id, so the ids of two schools never meet.
String sourcedId(String profileId, String id) => '$profileId|$id';

/// The id an item of the view together has in its own profile.
String localId(String id, String? source) =>
    source != null && id.startsWith('$source|')
    ? id.substring(source.length + 1)
    : id;

/// The name [profile] goes by beside [together], the profiles in the view
/// together: its own, or its school when another one of them has the same
/// name, as one child at two schools does.
String togetherName(SchoolProfile profile, Iterable<SchoolProfile> together) {
  final name = profile.displayName;
  final shared = together.any(
    (other) => other.id != profile.id && other.displayName == name,
  );
  return shared && profile.school.isNotEmpty ? profile.school : name;
}

/// The profile among [profileIds] whose item in the view together has [id].
String? sourceOfId(String id, Iterable<String> profileIds) {
  final cut = id.indexOf('|');
  if (cut <= 0) return null;
  final prefix = id.substring(0, cut);
  return profileIds.contains(prefix) ? prefix : null;
}

/// The data of every profile in [parts] as one: each list holds the items
/// of all of them, each marked with its profile and given an id of its own,
/// in the order a single profile's come in. It was last synced when the
/// longest unsynced of them was; a profile never synced yet does not count.
AppSnapshot mergeSnapshots(List<(SchoolProfile, AppSnapshot)> parts) {
  if (parts.isEmpty) throw ArgumentError.value(parts, 'parts', 'is empty');
  List<T> all<T>(
    List<T> Function(AppSnapshot snapshot) list,
    T Function(T item, String profileId) sourced,
    int Function(T a, T b) order,
  ) => _merged([
    for (final (profile, snapshot) in parts)
      [for (final item in list(snapshot)) sourced(item, profile.id)],
  ], order);

  final synced = [
    for (final (_, snapshot) in parts)
      if (snapshot.lastSync.millisecondsSinceEpoch != 0) snapshot.lastSync,
  ];
  return AppSnapshot(
    profile: StudentProfile(
      id: togetherId,
      name: '',
      school: '',
      provider: parts.first.$2.profile.provider,
    ),
    lessons: all(
      (snapshot) => snapshot.lessons,
      (item, profile) =>
          item.withSource(profile, id: sourcedId(profile, item.id)),
      (a, b) => a.start.compareTo(b.start),
    ),
    grades: all(
      (snapshot) => snapshot.grades,
      (item, profile) =>
          item.withSource(profile, id: sourcedId(profile, item.id)),
      (a, b) => b.date.compareTo(a.date),
    ),
    events: all(
      (snapshot) => snapshot.events,
      (item, profile) =>
          item.withSource(profile, id: sourcedId(profile, item.id)),
      (a, b) => a.date.compareTo(b.date),
    ),
    messages: all(
      (snapshot) => snapshot.messages,
      (item, profile) =>
          item.withSource(profile, id: sourcedId(profile, item.id)),
      (a, b) => b.receivedAt.compareTo(a.receivedAt),
    ),
    messagesError: [for (final (_, snapshot) in parts) ?snapshot.messagesError]
        .firstOrNull,
    sentMessages: all(
      (snapshot) => snapshot.sentMessages,
      (item, profile) =>
          item.withSource(profile, id: sourcedId(profile, item.id)),
      (a, b) => b.receivedAt.compareTo(a.receivedAt),
    ),
    attendance: all(
      (snapshot) => snapshot.attendance,
      (item, profile) =>
          item.withSource(profile, id: sourcedId(profile, item.id)),
      (a, b) => b.date.compareTo(a.date),
    ),
    announcements: all(
      (snapshot) => snapshot.announcements,
      (item, profile) =>
          item.withSource(profile, id: sourcedId(profile, item.id)),
      (a, b) => b.createdAt.compareTo(a.createdAt),
    ),
    notices: all(
      (snapshot) => snapshot.notices,
      (item, profile) =>
          item.withSource(profile, id: sourcedId(profile, item.id)),
      (a, b) => b.date.compareTo(a.date),
    ),
    freeDays: all(
      (snapshot) => snapshot.freeDays,
      (item, profile) =>
          item.withSource(profile, id: sourcedId(profile, item.id)),
      (a, b) => a.from.compareTo(b.from),
    ),
    lastSync: synced.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : synced.reduce((a, b) => a.isBefore(b) ? a : b),
  );
}

/// The items of [lists] in [order]; items that tie keep the order of their
/// lists, and their order within them.
List<T> _merged<T>(List<List<T>> lists, int Function(T a, T b) order) {
  final items = [
    for (final (list, items) in lists.indexed)
      for (final (index, item) in items.indexed) (list, index, item),
  ];
  items.sort((a, b) {
    final byOrder = order(a.$3, b.$3);
    if (byOrder != 0) return byOrder;
    final byList = a.$1.compareTo(b.$1);
    return byList != 0 ? byList : a.$2.compareTo(b.$2);
  });
  return List.unmodifiable([for (final (_, _, item) in items) item]);
}
