import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

const _profile = StudentProfile(
  id: 'test',
  name: 'Demo Student',
  school: 'School',
  provider: 'Librus Synergia',
);

AppSnapshot _snapshot({List<AttendanceRecord>? attendance}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final month = now.month;
  final semester = month >= 2 && month <= 8 ? 2 : 1;
  SchoolEvent event(String id, String type, int days) => SchoolEvent(
    id: id,
    title: 'Wpis $id',
    subject: 'fizyka',
    date: today.add(Duration(days: days)),
    kind: EventKind.exam,
    typeLabel: type,
  );
  AttendanceRecord record(String id, AttendanceKind kind, int daysAgo) =>
      AttendanceRecord(
        id: id,
        date: today.subtract(Duration(days: daysAgo)),
        lessonNumber: 1,
        subject: 'Fizyka',
        type: kind.name,
        symbol: kind.name.substring(0, 2),
        kind: kind,
        semester: semester,
      );
  return AppSnapshot(
    profile: _profile,
    lessons: const [],
    grades: [
      for (final (index, subject) in ['matematyka', 'fizyka'].indexed)
        Grade(
          id: 'g$index',
          subject: subject,
          value: '${index + 4}',
          description: '',
          date: now,
          weight: 1,
          semester: semester,
        ),
    ],
    events: [
      SchoolEvent(
        id: 'hw1',
        title: 'Zadanie',
        subject: 'fizyka',
        date: today.add(const Duration(days: 1)),
        kind: EventKind.homework,
      ),
      event('e1', 'sprawdzian', 2),
      event('e2', 'kartkówka', 3),
      event('e3', 'inne', 4),
    ],
    messages: [
      SchoolMessage(
        id: 'm1',
        sender: 'Nauczyciel Testowy',
        subject: 'Temat',
        preview: 'Treść',
        receivedAt: now,
      ),
    ],
    attendance:
        attendance ??
        [
          record('a1', AttendanceKind.present, 1),
          record('a2', AttendanceKind.absent, 2),
          record('a3', AttendanceKind.late, 3),
        ],
    announcements: [
      for (final id in ['an1', 'an2'])
        SchoolAnnouncement(
          id: id,
          title: 'Ogłoszenie $id',
          content: 'Treść',
          author: 'Dyrekcja',
          createdAt: now,
          validUntil: null,
          read: id == 'an2',
        ),
    ],
    notices: [
      for (final tone in NoticeTone.values)
        StudentNotice(
          id: tone.name,
          text: 'Uwaga',
          category: 'Kategoria',
          teacher: 'Nauczyciel Testowy',
          date: now,
          tone: tone,
        ),
    ],
    lastSync: now,
  );
}

Future<(AppController, _Repository)> _pump(
  WidgetTester tester, {
  int tab = 0,
  AppSnapshot? data,
}) async {
  SharedPreferences.setMockInitialValues({'app_design_v1': 'classic'});
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Made once the stored settings are in place, as it reads them.
  final repository = _Repository(data ?? _snapshot());
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  controller.selectTab(tab);
  await tester.pumpWidget(SyberiaApp(controller: controller));
  await tester.pumpAndSettle();
  return (controller, repository);
}

/// The cards on screen, top to bottom.
List<Rect> _cards(WidgetTester tester) => [
  for (final card in find.byType(Card).evaluate())
    tester.getRect(find.byWidget(card.widget)),
]..sort((a, b) => a.top.compareTo(b.top));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every page starts 16 from the edge', (tester) async {
    for (final tab in [0, 2, 3, 4, 6, 7, 8, 9]) {
      await _pump(tester, tab: tab);
      final cards = _cards(tester);
      expect(cards, isNotEmpty, reason: 'tab $tab');
      expect(cards.first.left, 16, reason: 'tab $tab');
      expect(cards.first.right, 400 - 16, reason: 'tab $tab');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    // Messages open with the search, not a card.
    await _pump(tester, tab: 5);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('messages-search'))).dx,
      16,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cards of a list never touch', (tester) async {
    for (final tab in [3, 6, 7, 8]) {
      await _pump(tester, tab: tab);
      final cards = _cards(tester);
      for (var index = 1; index < cards.length; index++) {
        final gap = cards[index].top - cards[index - 1].bottom;
        expect(gap, greaterThanOrEqualTo(8), reason: 'tab $tab, card $index');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('sheets have one kind of title', (tester) async {
    final (controller, _) = await _pump(tester, tab: 2);
    Future<TextStyle> title(String text) async {
      await tester.pumpAndSettle();
      final style = tester.widget<Text>(find.text(text).last).style!;
      Navigator.of(tester.element(find.text(text).last)).pop();
      await tester.pumpAndSettle();
      return style;
    }

    final expected = Theme.of(tester.element(find.byType(Scaffold).first))
        .textTheme
        .headlineSmall!;
    final styles = <String, TextStyle>{};
    await tester.tap(find.byKey(const ValueKey('grades-subject-matematyka')));
    styles['subject'] = await title('Matematyka');
    controller.selectTab(9);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-language')));
    styles['language'] = await title('Language');
    await tester.tap(find.byKey(const ValueKey('settings-today-screen')));
    styles['today'] = await title('Today screen');
    await tester.tap(find.byKey(const ValueKey('settings-timetable')));
    styles['timetable'] = await title('Timetable style');
    await tester.tap(find.byKey(const ValueKey('settings-profile')));
    styles['account'] = await title('Demo Student');
    for (final MapEntry(key: sheet, value: style) in styles.entries) {
      expect(style.fontSize, expected.fontSize, reason: sheet);
      expect(style.fontWeight, FontWeight.w800, reason: sheet);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('signing out asks first', (tester) async {
    final (controller, repository) = await _pump(tester, tab: 9);
    Future<void> tapLogout() async {
      await tester.tap(find.byKey(const ValueKey('settings-profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-logout')));
      await tester.pumpAndSettle();
    }

    await tapLogout();
    expect(
      find.text(
        'Sign out? Your diary data leaves this phone until you sign in again.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.logouts, 0);
    expect(controller.snapshot.profile.provider, 'Librus Synergia');

    await tapLogout();
    await tester.tap(find.byKey(const ValueKey('account-logout-confirm')));
    await tester.pumpAndSettle();
    expect(repository.logouts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('attendance with no entries says there is no data', (
    tester,
  ) async {
    await _pump(tester, tab: 6, data: _snapshot(attendance: const []));
    expect(find.text('No data'), findsOneWidget);
    expect(find.text('Attendance summary'), findsNothing);
    expect(find.byType(Card), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('list pages refresh on a pull, as Today does', (tester) async {
    for (final tab in [2, 3, 6, 7, 8]) {
      final (_, repository) = await _pump(tester, tab: tab);
      final page = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      // Far enough for any viewport: the indicator arms at a quarter of it.
      await tester.fling(page.first, const Offset(0, 1500), 1000);
      await tester.pumpAndSettle();
      expect(repository.syncs, 1, reason: 'tab $tab');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

class _Repository extends AppRepository {
  _Repository(this.data);
  final AppSnapshot data;
  int syncs = 0;
  int logouts = 0;

  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<AppSnapshot> sync(AppSnapshot current) async {
    syncs++;
    return current;
  }

  @override
  Future<AppSnapshot> logout() async {
    logouts++;
    return AppSnapshot(
      profile: const StudentProfile(id: '', name: '', school: '', provider: ''),
      lessons: const [],
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}
