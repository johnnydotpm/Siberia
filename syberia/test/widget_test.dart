import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/data/snapshot_cache.dart';
import 'package:syberia/src/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'mailbox failure shows an error instead of No data, including from cache',
    (tester) async {
      final snapshot = AppSnapshot(
        profile: const StudentProfile(
          id: '1',
          name: 'Test',
          school: 'School',
          provider: 'Librus Synergia',
        ),
        lessons: const [],
        grades: const [],
        events: const [],
        messages: const [],
        attendance: const [],
        announcements: const [],
        notices: const [],
        lastSync: DateTime.now(),
        messagesError: const AppError(
          errorCode: LibrusErrorCode.serverReply,
          detail: 'mailbox unavailable',
        ),
      );
      final cached = SnapshotCache.decode(SnapshotCache.encode(snapshot))!;
      expect(cached.messagesError!.detail, 'mailbox unavailable');
      final controller = AppController(
        _TestRepository(cached),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Messages').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('mailbox unavailable'), findsOneWidget);
      expect(find.text('No data'), findsNothing);
    },
  );

  testWidgets('logging out waits for a running sync', (tester) async {
    final data = AppSnapshot(
      profile: const StudentProfile(
        id: '1',
        name: 'Test',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: const [],
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: DateTime.now(),
    );
    final repository = _SlowSyncRepository(data);
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(_profileButton().first);
    await tester.pumpAndSettle();
    ButtonStyleButton logout() =>
        tester.widget(find.byKey(const ValueKey('account-logout')));
    expect(logout().onPressed, isNotNull);

    final sync = controller.sync();
    await tester.pump();
    expect(controller.syncing, isTrue);
    expect(logout().onPressed, isNull);

    repository.pending.complete(data);
    await sync;
    await tester.pumpAndSettle();
    expect(logout().onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('asks for Librus login instead of showing demo school', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
    final controller = AppController(AppRepository(), updatesEnabled: false);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Connect to Librus'), findsOneWidget);
    expect(find.textContaining('demonstr'), findsNothing);
    await tester.tap(find.text('Connect Librus account'));
    await tester.pumpAndSettle();
    expect(find.textContaining('VPN'), findsOneWidget);
  });

  testWidgets(
    'renders daily plan, attendance and separate homework and remarks',
    (tester) async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day, 8);
      // Never the lesson in progress: its progress bar keeps moving, and the
      // page would not settle while the test runs during the lesson.
      final lesson = day.add(Duration(hours: now.hour < 12 ? 6 : 0));
      final snapshot = AppSnapshot(
        profile: const StudentProfile(
          id: '1',
          name: 'Uczeń testowy',
          school: 'School',
          provider: 'Librus Synergia',
        ),
        lessons: [
          Lesson(
            id: 'l1',
            subject: 'Matematyka',
            teacher: 'Nauczyciel A',
            room: '2',
            start: lesson,
            end: lesson.add(const Duration(minutes: 45)),
            substitution: true,
            originalSubject: 'Fizyka',
            originalTeacher: 'Nauczyciel B',
          ),
        ],
        grades: const [],
        events: [
          SchoolEvent(
            id: 'h1',
            title: 'Zadanie 1',
            subject: 'Matematyka',
            date: day,
            kind: EventKind.homework,
          ),
          SchoolEvent(
            id: 'past',
            title: 'Past event',
            subject: 'Matematyka',
            date: day.subtract(const Duration(days: 1)),
            kind: EventKind.event,
          ),
          SchoolEvent(
            id: 'future',
            title: 'Future event',
            subject: 'Matematyka',
            date: day.add(const Duration(days: 1)),
            kind: EventKind.event,
            typeLabel: 'Wywiadówka',
          ),
        ],
        messages: [
          SchoolMessage(
            id: 'm1',
            sender: 'Nauczyciel A',
            subject: 'Test message',
            preview: 'Preview',
            receivedAt: day,
            unread: true,
          ),
        ],
        attendance: [
          AttendanceRecord(
            id: 'a1',
            date: day,
            lessonNumber: 1,
            subject: 'Matematyka',
            type: 'Obecność',
            symbol: 'ob',
            kind: AttendanceKind.present,
          ),
          AttendanceRecord(
            id: 'a2',
            date: day,
            lessonNumber: 2,
            subject: 'Matematyka',
            type: 'Spóźnienie',
            symbol: 'sp',
            kind: AttendanceKind.late,
          ),
          AttendanceRecord(
            id: 'a3',
            date: day,
            lessonNumber: 3,
            subject: 'Matematyka',
            type: 'Zwolnienie',
            symbol: 'zw',
            kind: AttendanceKind.released,
          ),
          AttendanceRecord(
            id: 'a4',
            date: day,
            lessonNumber: 4,
            subject: 'Matematyka',
            type: 'Nieobecność',
            symbol: 'nb',
            kind: AttendanceKind.absent,
          ),
        ],
        announcements: const [],
        notices: [
          StudentNotice(
            id: 'n1',
            text: 'Aktywna praca',
            category: 'Pochwała',
            teacher: 'Nauczyciel A',
            date: day,
            tone: NoticeTone.positive,
          ),
        ],
        lastSync: now,
      );
      final controller = AppController(
        _TestRepository(snapshot),
        updatesEnabled: false,
      );
      await controller.bootstrap();
      await tester.pumpWidget(SyberiaApp(controller: controller));
      await tester.pumpAndSettle();
      for (final (key, tab) in const [
        ('summary-grades', 2),
        ('summary-absences', 6),
        ('summary-messages', 5),
      ]) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(controller.tabIndex, tab);
        controller.selectTab(0);
        await tester.pumpAndSettle();
      }
      expect(find.text('Past event'), findsNothing);
      await tester.scrollUntilVisible(find.text('Future event'), 160);
      expect(find.text('Future event'), findsOneWidget);
      expect(find.textContaining('Wywiadówka'), findsOneWidget);

      controller.selectTab(1);
      await tester.pumpAndSettle();
      expect(_dayChips(), findsAtLeastNWidgets(5));
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('timeline-lesson-l1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('lesson-details-sheet')))
            .width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
      expect(find.text('Substitution'), findsOneWidget);
      expect(find.textContaining('Fizyka'), findsOneWidget);
      Navigator.of(tester.element(find.text('Substitution'))).pop();
      await tester.pumpAndSettle();
      // The view preference switches to the list and back, and is remembered.
      await controller.setTimetableView(TimetableView.list);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timetable-row-l1')), findsOneWidget);
      expect(controller.timetableView, TimetableView.list);
      await controller.setTimetableView(TimetableView.timeline);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timeline-lesson-l1')), findsOneWidget);

      controller.selectTab(4);
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
      // The assignment is the title; with no description there is nothing
      // to expand.
      expect(find.text('Zadanie 1'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);

      controller.selectTab(3);
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);

      controller.selectTab(5);
      await tester.pumpAndSettle();
      expect(find.text('New message'), findsOneWidget);
      await tester.tap(find.text('Test message'));
      await tester.pumpAndSettle();
      expect(find.text('Full message body'), findsOneWidget);
      expect(find.text('attachment.pdf'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      controller.selectTab(6);
      await tester.pumpAndSettle();
      expect(find.text('Full year'), findsOneWidget);
      expect(find.text('Attendance summary'), findsOneWidget);
      expect(find.text('Late: 1'), findsOneWidget);
      expect(find.text('Released: 1'), findsOneWidget);
      final attendanceDayKey = ValueKey(
        'attendance-day-${DateTime(day.year, day.month, day.day).toIso8601String()}',
      );
      // The subjects come first, so the calendar is further down.
      expect(
        find.byKey(const ValueKey('attendance-by-subject')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('attendance-calendar-legend')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final attendanceDay = tester.widget<Container>(
        find.byKey(attendanceDayKey).first,
      );
      expect(
        (attendanceDay.decoration! as BoxDecoration).color,
        const Color(0xFFF28C28),
      );
      // The calendar explains its colours.
      final legend = find.byKey(const ValueKey('attendance-calendar-legend'));
      expect(
        find.descendant(of: legend, matching: find.text('Partly absent')),
        findsOneWidget,
      );
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Pn'), findsNothing);
      expect(find.textContaining('lekcja'), findsNothing);
      await controller.setAttendanceChartStyle(AttendanceChartStyle.bar);
      await tester.pumpAndSettle();
      // Back to the summary at the top.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      final flatChart = find.byKey(const ValueKey('attendance-flat-chart'));
      expect(flatChart, findsOneWidget);
      expect(tester.getSize(flatChart).width, greaterThan(250));
      final flatSegments = find.descendant(
        of: flatChart,
        matching: find.byType(ColoredBox),
      );
      expect(flatSegments, findsNWidgets(4));
      for (var index = 0; index < 4; index++) {
        expect(
          tester.getSize(flatSegments.at(index)).height,
          tester.getSize(flatChart).height,
        );
      }
      final segmentWidths = List.generate(
        4,
        (index) => tester.getSize(flatSegments.at(index)).width,
      );
      expect(
        segmentWidths.reduce((sum, width) => sum + width),
        closeTo(tester.getSize(flatChart).width, 1),
      );
      expect(tester.takeException(), isNull);

      controller.selectTab(8);
      await tester.pumpAndSettle();
      // What the note is leads; its tone shows once it opens.
      expect(find.text('Pochwała'), findsOneWidget);
      expect(find.text('Nauczyciel A'), findsOneWidget);
      expect(find.text('Aktywna praca'), findsNothing);
      await tester.tap(find.text('Pochwała'));
      await tester.pumpAndSettle();
      expect(find.text('Aktywna praca'), findsOneWidget);
      expect(find.text('Positive'), findsOneWidget);
    },
  );

  testWidgets('marks the current lesson and shows elapsed progress', (
    tester,
  ) async {
    final now = DateTime.now();
    // A lesson cannot span two calendar days. Avoid a false failure if this
    // wall-clock test happens to run within half an hour of midnight.
    if (!DateUtils.isSameDay(
      now.subtract(const Duration(minutes: 15)),
      now.add(const Duration(minutes: 30)),
    )) {
      return;
    }
    final snapshot = AppSnapshot(
      profile: const StudentProfile(
        id: '1',
        name: 'Uczeń testowy',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: [
        Lesson(
          id: 'current',
          subject: 'Matematyka',
          teacher: 'Nauczyciel A',
          room: '2',
          start: now.subtract(const Duration(minutes: 15)),
          end: now.add(const Duration(minutes: 30)),
        ),
      ],
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
    final controller = AppController(
      _TestRepository(snapshot),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    controller.selectTab(1);
    await tester.pump();

    expect(find.text('Now'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timetable-current-time-current')),
      findsOneWidget,
    );
    expect(find.textContaining('45 min'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Today skips finished lessons and shows the next day', (
    tester,
  ) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 8);
    final snapshot = AppSnapshot(
      profile: const StudentProfile(
        id: '1',
        name: 'Uczeń testowy',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: [
        Lesson(
          id: 'finished',
          subject: 'Finished lesson',
          teacher: 'Nauczyciel A',
          room: '1',
          // Over at any time of the day, even just after midnight.
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 0, 0, 1),
        ),
        Lesson(
          id: 'tomorrow',
          subject: 'Tomorrow lesson',
          teacher: 'Nauczyciel B',
          room: '2',
          start: tomorrow,
          end: tomorrow.add(const Duration(minutes: 45)),
        ),
      ],
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
    final controller = AppController(
      _TestRepository(snapshot),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Finished lesson'), findsNothing);
    expect(find.text('Tomorrow lesson'), findsOneWidget);
    expect(
      find.textContaining('${tomorrow.day.toString().padLeft(2, '0')}.'),
      findsWidgets,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Today loads a future timetable week when this one is over', (
    tester,
  ) async {
    final now = DateTime.now();
    final snapshot = AppSnapshot(
      profile: const StudentProfile(
        id: '1',
        name: 'Uczeń testowy',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: [
        Lesson(
          id: 'finished',
          subject: 'Finished lesson',
          teacher: 'Nauczyciel A',
          room: '1',
          // Over at any time of the day, even just after midnight.
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 0, 0, 1),
        ),
      ],
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
    final repository = _WeekAheadRepository(snapshot);
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    expect(repository.weekRequests, 1);
    expect(find.text('Finished lesson'), findsNothing);
    expect(find.text('Next week lesson'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Today looks ahead from an empty week, as over a school break', (
    tester,
  ) async {
    final now = DateTime.now();
    final snapshot = AppSnapshot(
      profile: const StudentProfile(
        id: '1',
        name: 'Uczeń testowy',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: const [],
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
    final repository = _WeekAheadRepository(snapshot);
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();

    expect(repository.weekRequests, 1);
    expect(find.text('Next week lesson'), findsOneWidget);
    // Next Monday at midnight, counted in calendar days.
    final monday = repository.requestedDays.single;
    expect(monday.weekday, DateTime.monday);
    expect((monday.hour, monday.minute), (0, 0));
    expect(monday.isAfter(now), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps the current-time marker visible during a break', (
    tester,
  ) async {
    final now = DateTime.now();
    final beforeStart = now.subtract(const Duration(minutes: 2));
    final afterEnd = now.add(const Duration(minutes: 2));
    // A school break cannot span two calendar days. Avoid a false failure if
    // this wall-clock test happens to run within two minutes of midnight.
    if (!DateUtils.isSameDay(beforeStart, afterEnd)) return;
    final snapshot = AppSnapshot(
      profile: const StudentProfile(
        id: '1',
        name: 'Uczeń testowy',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: [
        Lesson(
          id: 'before-break',
          subject: 'Matematyka',
          teacher: 'Nauczyciel A',
          room: '2',
          start: beforeStart,
          end: now.subtract(const Duration(minutes: 1)),
        ),
        Lesson(
          id: 'after-break',
          subject: 'Polski',
          teacher: 'Nauczyciel B',
          room: '3',
          start: now.add(const Duration(minutes: 1)),
          end: afterEnd,
        ),
      ],
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
    final controller = AppController(
      _TestRepository(snapshot),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    controller.selectTab(1);
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('timetable-current-time-break-before-break-after-break'),
      ),
      findsOneWidget,
    );
    final dot = tester.getRect(find.byKey(const ValueKey('timetable-now-dot')));
    final firstLesson = tester.getRect(
      find.byKey(const ValueKey('timeline-lesson-before-break')),
    );
    expect(dot.center.dx, greaterThan(firstLesson.center.dx));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('uses the next school day and keeps long lesson names readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final lessonDay = DateTime(now.year, now.month, now.day + 2);
    final start = DateTime(lessonDay.year, lessonDay.month, lessonDay.day, 8);
    final snapshot = AppSnapshot(
      profile: const StudentProfile(
        id: '1',
        name: 'Uczeń testowy',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: [
        Lesson(
          id: 'long-subject',
          subject: 'przykładowy przedmiot z bardzo długą nazwą',
          teacher: 'Nauczyciel A',
          room: 'A1',
          start: start,
          end: start.add(const Duration(minutes: 45)),
        ),
        Lesson(
          id: 'after-break',
          subject: 'drugi przedmiot',
          teacher: 'Nauczyciel B',
          room: 'A2',
          start: start.add(const Duration(minutes: 50)),
          end: start.add(const Duration(minutes: 95)),
        ),
      ],
      grades: const [],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
    final controller = AppController(
      _TestRepository(snapshot),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    controller.selectTab(1);
    await tester.pumpAndSettle();

    // Shown with a capital letter, as Librus's lower case looks careless.
    expect(
      find.text('Przykładowy przedmiot z bardzo długą nazwą'),
      findsOneWidget,
    );
    expect(find.text('08:00'), findsOneWidget);
    expect(find.textContaining('08:45'), findsOneWidget);
    final firstLesson = tester.getRect(
      find.byKey(const ValueKey('timeline-lesson-long-subject')),
    );
    final lessonAfterBreak = tester.getRect(
      find.byKey(const ValueKey('timeline-lesson-after-break')),
    );
    expect(lessonAfterBreak.top - firstLesson.top, closeTo(87.5, 0.5));
    expect(lessonAfterBreak.top - firstLesson.bottom, greaterThan(5));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.calendar_month_rounded));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('timetable-lessons-${lessonDay.toIso8601String()}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters grades by term, calculates averages and opens details', (
    tester,
  ) async {
    final now = DateTime.now();
    final snapshot = AppSnapshot(
      profile: const StudentProfile(
        id: '1',
        name: 'Uczeń testowy',
        school: 'School',
        provider: 'Librus Synergia',
      ),
      lessons: const [],
      grades: [
        Grade(
          id: 'g1',
          subject: 'Matematyka',
          value: '4+',
          description: 'Rozdział 1',
          date: now,
          weight: 2,
          semester: 1,
          category: 'Sprawdzian',
          previousGrades: [
            Grade(
              id: 'g1-oldest',
              subject: 'Matematyka',
              value: '0',
              description: 'Najstarszy wpis',
              date: now.subtract(const Duration(days: 14)),
              weight: 1,
              semester: 1,
              category: 'Sprawdzian',
            ),
            Grade(
              id: 'g1-previous',
              subject: 'Matematyka',
              value: '1',
              description: 'Pośredni wpis',
              date: now.subtract(const Duration(days: 7)),
              weight: 2,
              semester: 1,
              category: 'Sprawdzian',
            ),
          ],
        ),
        Grade(
          id: 'g2',
          subject: 'Matematyka',
          value: '5',
          description: '',
          date: now,
          weight: 1,
          semester: 1,
          category: 'Kartkówka',
        ),
        Grade(
          id: 'g3',
          subject: 'Matematyka',
          value: '6',
          description: 'Drugi okres',
          date: now,
          weight: 1,
          semester: 2,
          category: 'Odpowiedź',
        ),
      ],
      events: const [],
      messages: const [],
      attendance: const [],
      announcements: const [],
      notices: const [],
      lastSync: now,
    );
    final controller = AppController(
      _TestRepository(snapshot),
      updatesEnabled: false,
    );
    await controller.bootstrap();
    await tester.pumpWidget(SyberiaApp(controller: controller));
    controller.selectTab(2);
    await tester.pumpAndSettle();

    // The semester average and the subject's, each in its own pill.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('grades-overview')),
        matching: find.text('4.75'),
      ),
      findsOneWidget,
    );
    final subject = find.byKey(const ValueKey('grades-subject-Matematyka'));
    expect(
      find.descendant(of: subject, matching: find.text('4.75')),
      findsOneWidget,
    );
    // A corrected grade keeps Librus's brackets.
    expect(
      find.descendant(of: subject, matching: find.text('[4+]')),
      findsOneWidget,
    );
    await tester.tap(subject);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('subject-grades-sheet')), findsOneWidget);
    expect(find.text('Sprawdzian'), findsOneWidget);
    await tester.tap(find.text('Sprawdzian'));
    await tester.pumpAndSettle();
    expect(find.text('Grade details'), findsOneWidget);
    final current = find.byKey(const ValueKey('grade-history-g1'));
    final previous = find.byKey(const ValueKey('grade-history-g1-previous'));
    final oldest = find.byKey(const ValueKey('grade-history-g1-oldest'));
    expect(current, findsOneWidget);
    expect(previous, findsOneWidget);
    expect(oldest, findsOneWidget);
    expect(
      find.descendant(of: current, matching: find.text('Rozdział 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: previous, matching: find.text('Pośredni wpis')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: oldest, matching: find.text('Najstarszy wpis')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(current).dy,
      lessThan(tester.getTopLeft(previous).dy),
    );
    expect(
      tester.getTopLeft(previous).dy,
      lessThan(tester.getTopLeft(oldest).dy),
    );
    Navigator.of(tester.element(find.text('Grade details'))).pop();
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const ValueKey('subject-grades-sheet'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Semester 2'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('grade-chip-g3')), findsOneWidget);
    expect(find.byKey(const ValueKey('grade-chip-g1')), findsNothing);
  });
}

class _TestRepository extends AppRepository {
  _TestRepository(this.data);
  final AppSnapshot data;
  @override
  Future<AppSnapshot> load() async => data;

  @override
  Future<SchoolMessageContent> fetchMessageContent(
    SchoolMessage message,
  ) async => SchoolMessageContent(
    id: message.id,
    sender: message.sender,
    subject: message.subject,
    body: 'Full message body',
    receivedAt: message.receivedAt,
    attachments: const [MessageAttachment(id: 'a1', name: 'attachment.pdf')],
  );

  @override
  Future<AttendanceChartStyle> loadAttendanceChartStyle() async =>
      AttendanceChartStyle.ring;

  // The real one would reach Librus; the Today look-ahead asks for weeks.
  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}

class _SlowSyncRepository extends _TestRepository {
  _SlowSyncRepository(super.data);

  final pending = Completer<AppSnapshot>();

  @override
  Future<AppSnapshot> sync(AppSnapshot current) => pending.future;
}

class _WeekAheadRepository extends _TestRepository {
  _WeekAheadRepository(super.data);

  int weekRequests = 0;
  final requestedDays = <DateTime>[];

  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async {
    weekRequests++;
    requestedDays.add(day);
    final start = DateTime(day.year, day.month, day.day, 8);
    return [
      Lesson(
        id: 'next-week',
        subject: 'Next week lesson',
        teacher: 'Nauczyciel B',
        room: '2',
        start: start,
        end: start.add(const Duration(minutes: 45)),
      ),
    ];
  }
}

/// The weekday buttons above the timetable.
Finder _dayChips() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('timetable-day-'),
);

/// The profile button of the top bar, in either design.
Finder _profileButton() => find.byWidgetPredicate(
  (widget) =>
      widget.key == const ValueKey('profile-button') ||
      widget.key == const ValueKey('glass-bar-button-account'),
);
