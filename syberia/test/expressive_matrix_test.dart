import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';
import 'package:syberia/src/theme/wallpaper_colors.dart';

import 'support/profile_fakes.dart';

/// Every page of the Expressive design in the light, dark and black themes,
/// at the usual and the largest text Android offers (200 %), on a usual and
/// a narrow phone: nothing may overflow or fail to lay out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WallpaperColors.ask = () async => null;
  });

  for (final mode in const [
    AppColorMode.light,
    AppColorMode.dark,
    AppColorMode.amoled,
  ]) {
    for (final scale in const [1.0, 2.0]) {
      for (final width in const [412.0, 320.0]) {
        testWidgets('${mode.name}, text ×$scale, ${width.round()} wide', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 780);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final repository = _Repository();
          await repository.saveDesign(AppDesign.expressive);
          await repository.saveColorMode(mode);
          final controller = AppController(repository, updatesEnabled: false);
          await controller.bootstrap();
          await tester.pumpWidget(SyberiaApp(controller: controller));
          await frames(tester);
          final problems = <String>[];
          for (var tab = 0; tab < 10; tab++) {
            controller.selectTab(tab);
            await frames(tester);
            // Down the whole page too, where long content may overflow.
            final lists = find.byType(Scrollable);
            if (lists.evaluate().isNotEmpty) {
              await tester.drag(lists.last, const Offset(0, -2000));
              await frames(tester);
            }
            final error = tester.takeException();
            if (error != null) problems.add('tab $tab: $error');
          }
          expect(problems, isEmpty);
        });
      }
    }
  }
}

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class _Repository extends AppRepository {
  @override
  Future<AppSnapshot> load() async {
    final now = DateTime.now();
    final base = studentSnapshot('s1', 'a');
    Lesson lesson(String id, String subject, int start, int number) => Lesson(
      id: id,
      subject: subject,
      teacher: 'Nauczyciel Testowy',
      room: '12',
      start: now.add(Duration(minutes: start)),
      end: now.add(Duration(minutes: start + 45)),
      lessonNumber: number,
    );
    Grade grade(String id, String subject, String value, int daysAgo) => Grade(
      id: id,
      subject: subject,
      value: value,
      description: 'Sprawdzian',
      date: now.subtract(Duration(days: daysAgo)),
      weight: 2,
      semester: 1,
    );
    return AppSnapshot(
      profile: base.profile,
      lessons: [
        lesson('l1', 'Język polski', -83, 1),
        lesson('l2', 'Mechatronika pojazdów samochodowych', -28, 2),
        lesson('l3', 'Fizyka', 27, 3),
        lesson('l4', 'Chemia', 82, 4),
      ],
      grades: [
        grade('g1', 'Matematyka', '5', 1),
        grade('g2', 'Matematyka', '4+', 9),
        grade('g3', 'Fizyka', '3-', 2),
        grade('g4', 'Historia i teraźniejszość', '6', 3),
        grade('g5', 'Fizyka', '2', 20),
      ],
      events: [
        SchoolEvent(
          id: 'e1',
          title: 'Kartkówka z działu drugiego',
          subject: 'Chemia',
          date: now.add(const Duration(days: 1)),
          kind: EventKind.exam,
        ),
        SchoolEvent(
          id: 'e2',
          title: 'Zadanie: ćwiczenia 1–5',
          subject: 'Matematyka',
          date: now.add(const Duration(days: 2)),
          kind: EventKind.homework,
        ),
      ],
      messages: [
        SchoolMessage(
          id: 'm1',
          sender: 'Nauczyciel Testowy',
          subject: 'Wycieczka klasowa do muzeum w przyszłym tygodniu',
          preview: 'Proszę o zgody rodziców do piątku.',
          receivedAt: now.subtract(const Duration(hours: 3)),
          unread: true,
        ),
      ],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
  }

  @override
  Future<List<Lesson>> fetchTimetableWeek(
    DateTime day, {
    String? profileId,
  }) async => const [];
}
