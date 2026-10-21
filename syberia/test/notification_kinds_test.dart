import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/background_notifications.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/data/librus/librus_client.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/test_reminders.dart';

AttendanceRecord _entry(String id, AttendanceKind kind, String type) =>
    AttendanceRecord(
      id: id,
      date: DateTime(2026, 10, 20),
      lessonNumber: 2,
      subject: 'Matematyka',
      type: type,
      symbol: type.substring(0, 1),
      kind: kind,
    );

Lesson _lesson(
  String id, {
  bool cancelled = false,
  bool substitution = false,
  DateTime? movedTo,
}) => Lesson(
  id: id,
  subject: 'Fizyka $id',
  teacher: 'Nauczyciel Testowy',
  room: '12',
  start: DateTime(2026, 10, 21, 8),
  end: DateTime(2026, 10, 21, 8, 45),
  cancelled: cancelled,
  substitution: substitution,
  movedTo: movedTo,
);

AppSnapshot _snapshot({
  List<AttendanceRecord> attendance = const [],
  List<Lesson> lessons = const [],
}) => AppSnapshot(
  profile: const StudentProfile(
    id: 'student-1',
    name: 'Uczeń testowy',
    school: 'School',
    provider: 'Librus Synergia',
  ),
  lessons: lessons,
  grades: const [],
  events: const [],
  messages: const [],
  attendance: attendance,
  announcements: const [],
  notices: const [],
  lastSync: DateTime(2026, 10, 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'app_locale_v1': 'pl'}));

  test('a lesson change is one kind: moved, cancelled or substitution', () {
    final moved = DateTime(2026, 10, 23, 9);
    expect(
      TimetableChange.of(
        _lesson('a', cancelled: true, substitution: true, movedTo: moved),
      ),
      TimetableChange.moved,
    );
    expect(
      TimetableChange.of(_lesson('b', cancelled: true, substitution: true)),
      TimetableChange.cancelled,
    );
    expect(
      TimetableChange.of(_lesson('c', substitution: true)),
      TimetableChange.substitution,
    );
    expect(TimetableChange.of(_lesson('d')), isNull);
  });

  test('only the chosen attendance entries notify', () async {
    final presenter = _Presenter();
    final service = SchoolNotificationService(presenter);
    await service.processSnapshot(_snapshot());
    await service.saveSettings(
      (await service.loadSettings()).copyWith(
        attendanceKinds: {AttendanceKind.absent},
      ),
    );

    await service.processSnapshot(
      _snapshot(attendance: [_entry('p1', AttendanceKind.present, 'Obecność')]),
    );
    expect(presenter.shown, isEmpty);

    await service.processSnapshot(
      _snapshot(
        attendance: [
          _entry('p1', AttendanceKind.present, 'Obecność'),
          _entry('p2', AttendanceKind.present, 'Obecność'),
          _entry('a1', AttendanceKind.absent, 'Nieobecność'),
        ],
      ),
    );
    // One absence: its own text, not "3 new items".
    expect(presenter.shown, [
      (SchoolNotificationCategory.attendance, 'Matematyka: Nieobecność'),
    ]);

    // Turning presence back on does not replay the entries already seen.
    await service.saveSettings(
      (await service.loadSettings()).copyWith(
        attendanceKinds: AttendanceKind.values.toSet(),
      ),
    );
    await service.processSnapshot(
      _snapshot(
        attendance: [
          _entry('p1', AttendanceKind.present, 'Obecność'),
          _entry('p2', AttendanceKind.present, 'Obecność'),
          _entry('a1', AttendanceKind.absent, 'Nieobecność'),
        ],
      ),
    );
    expect(presenter.shown, hasLength(1));
  });

  test('an entry without a subject reads as its type alone', () async {
    final presenter = _Presenter();
    final service = SchoolNotificationService(presenter);
    await service.processSnapshot(_snapshot());
    await service.processSnapshot(
      _snapshot(
        attendance: [
          AttendanceRecord(
            id: 'n1',
            date: DateTime(2026, 10, 20),
            lessonNumber: 3,
            subject: '',
            type: 'Nieobecność',
            symbol: 'nb',
            kind: AttendanceKind.absent,
          ),
        ],
      ),
    );
    expect(presenter.shown, [
      (SchoolNotificationCategory.attendance, 'Nieobecność'),
    ]);
  });

  test('only the chosen lesson changes notify, saying what changed', () async {
    final presenter = _Presenter();
    final service = SchoolNotificationService(presenter);
    await service.processSnapshot(_snapshot());
    await service.saveSettings(
      (await service.loadSettings()).copyWith(
        timetableChanges: {TimetableChange.cancelled},
      ),
    );
    await service.processSnapshot(
      _snapshot(
        lessons: [
          _lesson('1', substitution: true),
          _lesson('2', cancelled: true, substitution: true),
          _lesson(
            '3',
            cancelled: true,
            substitution: true,
            movedTo: DateTime(2026, 10, 23, 9),
          ),
          _lesson('4'),
        ],
      ),
    );
    expect(presenter.shown, [
      (
        SchoolNotificationCategory.timetable,
        'Fizyka 2, 21.10: Odwołana lekcja',
      ),
    ]);
  });

  test('the chosen kinds are saved; none saved means all', () async {
    final service = SchoolNotificationService(_Presenter());
    final defaults = await service.loadSettings();
    expect(defaults.attendanceKinds, AttendanceKind.values.toSet());
    expect(defaults.timetableChanges, TimetableChange.values.toSet());

    await service.saveSettings(
      defaults.copyWith(
        attendanceKinds: {AttendanceKind.absent, AttendanceKind.late},
        timetableChanges: const {},
      ),
    );
    final saved = await service.loadSettings();
    expect(saved.attendanceKinds, {AttendanceKind.absent, AttendanceKind.late});
    expect(saved.timetableChanges, isEmpty);
    // Nothing chosen is as good as off: the background check skips it.
    expect(saved.allows(SchoolNotificationCategory.timetable), isFalse);
    expect(saved.allows(SchoolNotificationCategory.attendance), isTrue);
    final parts = backgroundParts(saved);
    expect(parts, contains(LibrusPart.attendance));
    expect(parts, isNot(contains(LibrusPart.timetable)));
  });

  testWidgets('attendance opens to pick which entries notify', (tester) async {
    SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = SchoolNotificationService(_Presenter());
    final controller = AppController(
      _Repository(_snapshot()),
      updatesEnabled: false,
      notifications: service,
    );
    await controller.bootstrap();
    controller.selectTab(9);
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-notifications')));
    await tester.pumpAndSettle();

    Finder summary(String category) =>
        find.byKey(ValueKey('notification-$category-summary'));
    expect(tester.widget<Text>(summary('attendance')).data, 'All');
    expect(find.text('Excused lateness'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('notification-attendance-open')),
    );
    await tester.pumpAndSettle();
    for (final label in [
      'absentExcused',
      'late',
      'lateExcused',
      'released',
      'present',
      'other',
    ]) {
      await tester.tap(find.byKey(ValueKey('notification-attendance-$label')));
      await tester.pumpAndSettle();
    }
    expect(controller.notificationSettings.attendanceKinds, {
      AttendanceKind.absent,
    });
    expect(tester.widget<Text>(summary('attendance')).data, 'Absent');
    expect((await service.loadSettings()).attendanceKinds, {
      AttendanceKind.absent,
    });

    // The timetable has its own choice, closed until opened.
    expect(
      find.byKey(const ValueKey('notification-timetable-moved')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('notification-timetable-open')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('notification-timetable-substitution')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(summary('timetable')).data,
      'Lesson cancelled, Lesson moved',
    );

    // With the category off the choices stay, but cannot be changed.
    await tester.tap(find.byKey(const ValueKey('notification-attendance')));
    await tester.pumpAndSettle();
    final absent = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('notification-attendance-absent')),
    );
    expect(absent.onChanged, isNull);
    expect(absent.value, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}

class _Presenter implements SchoolNotificationPresenter {
  final shown = <(SchoolNotificationCategory, String)>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
  }) async => shown.add((category, body));

  @override
  Future<SchoolNotificationCategory?> launchCategory() async => null;

  @override
  void onTap(void Function(SchoolNotificationCategory) callback) {}

  @override
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  }) async {}
}
