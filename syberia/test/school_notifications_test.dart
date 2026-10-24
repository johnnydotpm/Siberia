import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/school_notifications.dart';
import 'package:syberia/src/test_reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'seeds the first snapshot and only notifies about new entries',
    () async {
      final presenter = _Presenter();
      final service = SchoolNotificationService(presenter);
      final first = _snapshot();
      await service.processSnapshot(first);
      expect(presenter.shown, isEmpty);

      final next = _snapshot(
        grades: [_grade('g1', '4+')],
        announcements: [_announcement('a1')],
        notices: [_notice('n1')],
      );
      await service.processSnapshot(next);
      expect(presenter.shown, [
        SchoolNotificationCategory.grades,
        SchoolNotificationCategory.announcements,
        SchoolNotificationCategory.notices,
      ]);
      await service.processSnapshot(next);
      expect(presenter.shown, hasLength(3));

      await service.processSnapshot(_snapshot(grades: [_grade('g1', '5')]));
      expect(presenter.shown.last, SchoolNotificationCategory.grades);
    },
  );

  test('category and master mute do not replay missed items later', () async {
    final presenter = _Presenter();
    final service = SchoolNotificationService(presenter);
    await service.processSnapshot(_snapshot());

    var settings = await service.loadSettings();
    settings = settings.copyWith(
      category: SchoolNotificationCategory.announcements,
      categoryEnabled: false,
    );
    await service.saveSettings(settings);
    await service.processSnapshot(
      _snapshot(
        announcements: [_announcement('a1')],
        grades: [_grade('g1', '4')],
      ),
    );
    expect(presenter.shown, [SchoolNotificationCategory.grades]);

    settings = settings.copyWith(enabled: false);
    await service.saveSettings(settings);
    await service.processSnapshot(_snapshot(messages: [_message('m1')]));
    expect(presenter.shown, hasLength(1));

    settings = settings.copyWith(
      enabled: true,
      category: SchoolNotificationCategory.announcements,
      categoryEnabled: true,
    );
    await service.saveSettings(settings);
    await service.processSnapshot(
      _snapshot(
        announcements: [_announcement('a1')],
        messages: [_message('m1')],
      ),
    );
    expect(presenter.shown, hasLength(1));

    await service.processSnapshot(
      _snapshot(announcements: [_announcement('a1'), _announcement('a2')]),
    );
    expect(presenter.shown.last, SchoolNotificationCategory.announcements);
  });

  test('test reminders follow the settings and the account', () async {
    final presenter = _Presenter();
    final service = SchoolNotificationService(presenter);
    final now = DateTime.now();
    final inThreeDays = DateTime(now.year, now.month, now.day + 3);
    final snapshot = _snapshot(events: [_test('t1', inThreeDays)]);

    // On by default: the evening before, at 19:00.
    await service.updateReminders(snapshot);
    expect(presenter.scheduled, hasLength(1));
    expect(
      presenter.scheduled!.single.at,
      DateTime(now.year, now.month, now.day + 2, 19),
    );
    expect(presenter.scheduled!.single.body, 'Matematyka: Sprawdzian');

    final settings = await service.loadSettings();
    await service.saveSettings(
      settings.copyWith(
        reminders: settings.reminders.copyWith(
          morning: true,
          morningMinutes: 6 * 60 + 30,
          homework: true,
        ),
      ),
    );
    final saved = await service.loadSettings();
    expect(saved.reminders.morning, isTrue);
    expect(saved.reminders.morningMinutes, 6 * 60 + 30);
    expect(saved.reminders.homework, isTrue);
    await service.updateReminders(snapshot);
    expect(presenter.scheduled, hasLength(2));

    // The master switch turns reminders off too.
    await service.saveSettings(saved.copyWith(enabled: false));
    await service.updateReminders(snapshot);
    expect(presenter.scheduled, isEmpty);
    await service.saveSettings(saved);

    // Signed out, nothing is left scheduled.
    await service.updateReminders(
      _snapshot(events: [_test('t1', inThreeDays)], provider: 'Demo'),
    );
    expect(presenter.scheduled, isEmpty);
  });
}

SchoolEvent _test(String id, DateTime date) => SchoolEvent(
  id: id,
  title: 'Rozdział 3',
  subject: 'Matematyka',
  date: date,
  kind: EventKind.exam,
  typeLabel: 'Sprawdzian',
);

AppSnapshot _snapshot({
  List<Grade> grades = const [],
  List<SchoolMessage> messages = const [],
  List<SchoolAnnouncement> announcements = const [],
  List<StudentNotice> notices = const [],
  List<SchoolEvent> events = const [],
  String provider = 'Librus Synergia',
}) => AppSnapshot(
  profile: StudentProfile(
    id: 'student-1',
    name: 'Uczeń testowy',
    school: 'School',
    provider: provider,
  ),
  lessons: const [],
  grades: grades,
  events: events,
  messages: messages,
  attendance: const [],
  announcements: announcements,
  notices: notices,
  lastSync: DateTime(2026, 9, 29),
);

Grade _grade(String id, String value) => Grade(
  id: id,
  subject: 'Matematyka',
  value: value,
  description: 'Test',
  date: DateTime(2026, 9, 29),
  weight: 1,
  semester: 1,
);

SchoolAnnouncement _announcement(String id) => SchoolAnnouncement(
  id: id,
  title: 'Ogłoszenie $id',
  content: '',
  author: 'School',
  createdAt: DateTime(2026, 9, 29),
  validUntil: null,
  read: false,
);

StudentNotice _notice(String id) => StudentNotice(
  id: id,
  text: 'Text',
  category: 'Uwaga',
  teacher: 'Nauczyciel A',
  date: DateTime(2026, 9, 29),
  tone: NoticeTone.negative,
);

SchoolMessage _message(String id) => SchoolMessage(
  id: id,
  sender: 'Nauczyciel A',
  subject: 'Test',
  preview: '',
  receivedAt: DateTime(2026, 9, 29),
);

class _Presenter implements SchoolNotificationPresenter {
  final List<SchoolNotificationCategory> shown = [];
  List<TestReminder>? scheduled;

  @override
  Future<void> scheduleReminders(
    List<TestReminder> reminders, {
    required String channelName,
  }) async {
    scheduled = reminders;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationTarget?> launchTarget() async => null;

  @override
  void onTap(void Function(NotificationTarget) callback) {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required SchoolNotificationCategory category,
    required String title,
    required String body,
    int? id,
    NotificationTarget? target,
    String? channelName,
  }) async {
    shown.add(category);
  }
}
