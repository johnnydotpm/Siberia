import 'package:flutter/foundation.dart';

import 'models.dart';
import 'parent.dart';
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
    this.together = true,
    this.roleOverride,
    this.parentPreferences = const ParentPreferences(),
    this.tabs,
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
  final ProfileRole? roleOverride;
  final ParentPreferences parentPreferences;
  final List<int>? tabs;
  ProfileRole get role =>
      roleOverride ?? (parent ? ProfileRole.parent : ProfileRole.student);
  List<int> get bottomTabs =>
      tabs ??
      (role == ProfileRole.parent ? const [0, 6, 2, 5] : const [0, 1, 2, 5]);

  /// Whether it is in the view of every profile together.
  final bool together;

  /// The name to show: the user's own, or the student's.
  String get displayName {
    final own = label?.trim() ?? '';
    return own.isEmpty ? name : own;
  }

  /// Parent alerts always name the child, even when the profile has a custom school label.
  String get notificationName =>
      role == ProfileRole.parent &&
          name.trim().isNotEmpty &&
          displayName != name
      ? '$name · $displayName'
      : displayName;

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
    bool? together,
    ProfileRole? Function()? roleOverride,
    ParentPreferences? parentPreferences,
    List<int>? tabs,
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
    together: together ?? this.together,
    roleOverride: roleOverride == null ? this.roleOverride : roleOverride(),
    parentPreferences: parentPreferences ?? this.parentPreferences,
    tabs: tabs ?? this.tabs,
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
    'roleOverride': roleOverride?.name,
    'parentPreferences': parentPreferences.toJson(),
    'tabs': tabs,
    'together': together,
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
      roleOverride: ProfileRole.values
          .where((role) => role.name == json['roleOverride'])
          .firstOrNull,
      parentPreferences: ParentPreferences.fromJson(json['parentPreferences']),
      tabs:
          json['tabs'] is List &&
              (json['tabs'] as List).length == 4 &&
              (json['tabs'] as List).toSet().length == 4 &&
              (json['tabs'] as List).every(
                (tab) => tab is int && tab >= 0 && tab < 10,
              )
          ? (json['tabs'] as List).cast<int>()
          : null,
      together: json['together'] != false,
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
      other.parent == parent &&
      other.roleOverride == roleOverride &&
      mapEquals(other.parentPreferences.toJson(), parentPreferences.toJson()) &&
      listEquals(other.tabs, tabs) &&
      other.together == together;

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
    together,
    roleOverride,
    Object.hashAll(parentPreferences.toJson().values),
    tabs == null ? null : Object.hashAll(tabs!),
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

/// The logins of [students] a sign-in offers checked: every one, except a
/// parent's account whose child has an account of its own in the list too.
/// Those two are one child, and the student's own account is the one the
/// app has always opened.
Set<String> defaultStudentChoice(
  List<LinkedSynergiaAccount> students, {
  ProfileRole? role,
}) {
  if (role == ProfileRole.parent && students.any((student) => student.parent)) {
    return {
      for (final student in students)
        if (student.parent) student.login,
    };
  }
  String key(String name) => name.trim().toLowerCase();
  final ownAccounts = {
    for (final student in students)
      if (!student.parent && key(student.name).isNotEmpty) key(student.name),
  };
  return {
    for (final student in students)
      if (!student.parent || !ownAccounts.contains(key(student.name)))
        student.login,
  };
}
