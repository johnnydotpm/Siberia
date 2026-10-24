import 'package:flutter/foundation.dart';

import 'stable_hash.dart';

/// One student at one school: a Librus Synergia account kept on the phone.
/// A parent with two children, or a student at two schools, has two, and
/// each keeps its own data, marks and settings.
@immutable
class SchoolProfile {
  const SchoolProfile({
    required this.id,
    required this.account,
    required this.synergiaLogin,
    required this.name,
    this.school = '',
    this.label,
    this.color = 0,
    this.slot = 0,
    this.notify = true,
    this.studentId,
    this.parent = false,
  });

  /// Names the profile's own data on the phone. It never changes.
  final String id;

  /// The Librus login the profile comes from, as `LibrusLogin.keyOf` names
  /// it; empty when the phone has no login for it.
  final String account;

  /// The profile's Synergia account in that login. Null for a profile from
  /// a version before profiles, until its first sync picks the student.
  final String? synergiaLogin;

  /// The student's name as Librus gives it.
  final String name;
  final String school;

  /// The user's own name for the profile, such as "Anna · music school".
  final String? label;

  /// Its colour: an index into the palette of subject colours.
  final int color;

  /// Keeps its notifications apart from the other profiles'. The first
  /// profile has 0, so its notifications keep the numbers they had.
  final int slot;

  /// Whether its news and reminders come as notifications.
  final bool notify;

  /// `StudentProfile.id` of its data, once synced.
  final String? studentId;

  /// Whether it is a parent's account rather than the student's own.
  final bool parent;

  /// The name to show: the user's own, or the student's.
  String get displayName {
    final own = label?.trim() ?? '';
    return own.isEmpty ? name : own;
  }

  /// The id of the profile for [synergiaLogin] in [account]: the same student
  /// added again finds the same id.
  static String idFor(String account, String? synergiaLogin) =>
      'p-${stableHash('$account\n${synergiaLogin ?? ''}')}';

  /// The most profiles the phone keeps: their slots must stay below the
  /// numbers test reminders use.
  static const maxProfiles = 99;

  SchoolProfile copyWith({
    String? synergiaLogin,
    String? name,
    String? school,
    String? Function()? label,
    int? color,
    bool? notify,
    String? studentId,
    bool? parent,
  }) => SchoolProfile(
    id: id,
    account: account,
    synergiaLogin: synergiaLogin ?? this.synergiaLogin,
    name: name ?? this.name,
    school: school ?? this.school,
    label: label == null ? this.label : label(),
    color: color ?? this.color,
    slot: slot,
    notify: notify ?? this.notify,
    studentId: studentId ?? this.studentId,
    parent: parent ?? this.parent,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'account': account,
    'synergiaLogin': synergiaLogin,
    'name': name,
    'school': school,
    'label': label,
    'color': color,
    'slot': slot,
    'notify': notify,
    'studentId': studentId,
    'parent': parent,
  };

  /// Null for anything that is not a saved profile.
  static SchoolProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final account = json['account'];
    if (id is! String || id.isEmpty || account is! String) return null;
    int number(Object? value) => value is num ? value.toInt() : 0;
    String? text(Object? value) => value is String ? value : null;
    return SchoolProfile(
      id: id,
      account: account,
      synergiaLogin: text(json['synergiaLogin']),
      name: text(json['name']) ?? '',
      school: text(json['school']) ?? '',
      label: text(json['label']),
      color: number(json['color']),
      slot: number(json['slot']),
      notify: json['notify'] != false,
      studentId: text(json['studentId']),
      parent: json['parent'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SchoolProfile &&
      other.id == id &&
      other.account == account &&
      other.synergiaLogin == synergiaLogin &&
      other.name == name &&
      other.school == school &&
      other.label == label &&
      other.color == color &&
      other.slot == slot &&
      other.notify == notify &&
      other.studentId == studentId &&
      other.parent == parent;

  @override
  int get hashCode => Object.hash(
    id,
    account,
    synergiaLogin,
    name,
    school,
    label,
    color,
    slot,
    notify,
    studentId,
    parent,
  );

  @override
  String toString() => 'SchoolProfile($id, $displayName)';
}

/// The lowest slot no profile in [profiles] has.
int freeProfileSlot(Iterable<SchoolProfile> profiles) {
  final taken = {for (final profile in profiles) profile.slot};
  var slot = 0;
  while (taken.contains(slot)) {
    slot++;
  }
  return slot;
}

/// How many colours profiles choose from: the hues of the subject colours.
const profileColorCount = 16;

/// A colour for a new profile among [profiles]: as far from theirs as the
/// [hues] allow, so two profiles never look alike. The first one's colour
/// comes from its [name].
int freeProfileColor(
  Iterable<SchoolProfile> profiles,
  String name, {
  int hues = profileColorCount,
}) {
  final taken = {for (final profile in profiles) profile.color % hues};
  if (taken.isEmpty) return int.parse(stableHash(name), radix: 16) % hues;
  var best = 0;
  var bestDistance = -1;
  for (var hue = 0; hue < hues; hue++) {
    var nearest = hues;
    for (final other in taken) {
      final apart = (hue - other).abs();
      final distance = apart < hues - apart ? apart : hues - apart;
      if (distance < nearest) nearest = distance;
    }
    if (nearest > bestDistance) {
      best = hue;
      bestDistance = nearest;
    }
  }
  return best;
}
