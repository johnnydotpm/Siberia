import 'dart:async';

import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/data/librus/librus_logins.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';

/// Fictional Librus accounts for profile tests: one family login with a
/// student at two schools, and another login with one more student.
const familyEmail = 'family@example.com';
final familyAccount = LibrusLogin.keyOf(familyEmail);
const otherEmail = 'other@example.com';
final otherAccount = LibrusLogin.keyOf(otherEmail);

/// A parent's login whose child also has a login of its own linked.
const parentEmail = 'parent@example.com';
final parentAccount = LibrusLogin.keyOf(parentEmail);

StudentProfile testStudent(String id, {String school = 'Szkoła Testowa'}) =>
    StudentProfile(
      id: id,
      name: 'Uczeń Testowy',
      school: school,
      provider: 'Librus Synergia',
    );

AppSnapshot studentSnapshot(
  String studentId,
  String tag, {
  String school = 'Szkoła Testowa',
  DateTime? lastSync,
}) => AppSnapshot(
  profile: testStudent(studentId, school: school),
  lessons: const [],
  grades: [
    Grade(
      id: 'g-$tag',
      subject: 'Matematyka',
      value: '5',
      description: '',
      date: DateTime(2026, 10, 1),
      weight: 1,
      semester: 1,
    ),
  ],
  events: const [],
  messages: const [],
  attendance: const [],
  announcements: const [],
  notices: const [],
  lastSync: lastSync ?? DateTime(2026, 10, 20, 12),
);

/// A lesson an hour from now named after the student, so each profile's
/// widget lessons can be told apart.
Lesson upcomingLesson(String studentId) {
  final start = DateTime.now().add(const Duration(hours: 1));
  return Lesson(
    id: 'l-$studentId',
    subject: 'Lekcja $studentId',
    teacher: '',
    room: '',
    start: start,
    end: start.add(const Duration(minutes: 45)),
  );
}

LinkedSynergiaAccount linkedStudent(
  String login, {
  String? account,
  String name = 'Uczeń Testowy',
  bool parent = false,
}) => LinkedSynergiaAccount(
  login: login,
  name: name,
  selected: false,
  account: account ?? familyAccount,
  parent: parent,
);

/// Answers for one profile, or for a sign-in when it has none.
class FakeProfileClient extends LibrusClient {
  FakeProfileClient(this.profile, this.world);
  final SchoolProfile? profile;
  final FakeLibrusWorld world;

  @override
  String? get synergiaLogin => profile?.synergiaLogin;

  @override
  Future<AppSnapshot?> restoreAndFetch({Set<LibrusPart>? parts}) async {
    final login = profile!.synergiaLogin ?? '';
    world.fetches.add(login);
    final number = ++world.fetchCount;
    final hold = world.holds[login];
    if (hold != null) await hold.future;
    if (world.offline) throw StateError('offline');
    if (world.failing.contains(login)) {
      throw LibrusException(world.failingWith);
    }
    final student = world.students[login];
    if (student == null) return null;
    final fetched = studentSnapshot(
      student.$1,
      '${student.$1}-$number',
      school: student.$2,
      lastSync: world.syncedAt?.call(),
    ).copyWith(lessons: [upcomingLesson(student.$1)]);
    return world.changes[login]?.call(fetched) ?? fetched;
  }

  @override
  Future<LibrusSignIn> signIn({
    required String username,
    required String password,
  }) async {
    world.signIns.add(username);
    return LibrusSignIn(
      account: LibrusLogin.keyOf(username),
      students: world.logins[LibrusLogin.keyOf(username)] ?? const [],
    );
  }

  @override
  Future<List<LinkedSynergiaAccount>> fetchSynergiaAccounts() async =>
      world.logins[profile!.account] ?? const [];

  @override
  Future<void> forget() async => world.forgotten.add(profile!.id);

  @override
  Future<String> sendMessage({
    required List<int> recipientIds,
    required String subject,
    required String body,
  }) async {
    await world.sending;
    return 'sent-${profile!.synergiaLogin}';
  }

  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async {
    world.weeks.add(profile!.synergiaLogin ?? '');
    return const [];
  }

  @override
  Future<List<MessageRecipient>> fetchMessageRecipients() async {
    final login = profile!.synergiaLogin ?? '';
    return [MessageRecipient(id: 1, name: 'Nauczyciel $login', group: '')];
  }

  @override
  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage message,
  ) async {
    world.opened.add('${profile!.synergiaLogin}:${message.id}');
    return SchoolMessageContent(
      id: message.id,
      sender: message.sender,
      subject: message.subject,
      body: 'Treść',
      receivedAt: message.receivedAt,
    );
  }
}

class FakeLibrusWorld {
  /// Synergia login → the student's id and school.
  final students = <String, (String, String)>{
    'kid-regular': ('s-regular', 'Szkoła Podstawowa'),
    'kid-music': ('s-music', 'Szkoła Muzyczna'),
    'other-kid': ('s-other', 'Liceum Testowe'),
    'child-parent': ('s-child-parent', 'Szkoła Podstawowa'),
    'child-u': ('s-child', 'Szkoła Podstawowa'),
  };

  /// Librus login → its students.
  final logins = <String, List<LinkedSynergiaAccount>>{
    familyAccount: [linkedStudent('kid-regular'), linkedStudent('kid-music')],
    otherAccount: [linkedStudent('other-kid', account: otherAccount)],
    parentAccount: [
      linkedStudent('child-parent', account: parentAccount, parent: true),
      linkedStudent('child-u', account: parentAccount),
    ],
  };
  final fetches = <String>[];

  /// The logins whose timetable weeks were asked for, in turn.
  final weeks = <String>[];

  /// The messages opened, as "login:message id".
  final opened = <String>[];

  /// Every fetch so far, so each one's data differs.
  var fetchCount = 0;
  final signIns = <String>[];
  final forgotten = <String>[];

  /// Fetches of a login wait for its completer.
  final holds = <String, Completer<void>>{};
  bool offline = false;

  /// Logins whose fetches fail, by default as when Librus does not answer.
  final failing = <String>{};
  LibrusErrorCode failingWith = LibrusErrorCode.networkTimeout;

  /// Login → what to make of its fetched data, for data of a test's own.
  final changes = <String, AppSnapshot Function(AppSnapshot data)>{};
  Future<void> sending = Future.value();

  /// When fetched data says it was synced; a fixed day by default.
  DateTime Function()? syncedAt;

  AppRepository repository() => AppRepository(
    librusClients: (profile) => FakeProfileClient(profile, this),
  );
}
