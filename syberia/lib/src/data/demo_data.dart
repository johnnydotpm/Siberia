import '../domain/models.dart';

/// Fictional school data held only in memory for the current demo session.
class DemoData {
  DemoData({DateTime? now}) {
    final time = now ?? DateTime.now();
    final today = DateTime(time.year, time.month, time.day);
    final semester = time.month >= 2 && time.month <= 8 ? 2 : 1;
    final messages = [
      for (var i = 0; i < _subjects.length; i++)
        SchoolMessage(
          id: 'demo-inbox-$i',
          sender: recipients[i % recipients.length].name,
          subject: [
            'Class trip information',
            'Project feedback',
            'Parent meeting',
          ][i % 3],
          preview: [
            'Our class trip is next Friday. Please bring a packed lunch and arrive at school by 08:00.',
            'Thank you for your project. Your presentation was clear and well researched. Please review the notes before our next lesson.',
            'The next parent meeting is on Thursday at 17:00 in room 204. We will discuss the class timetable and upcoming activities.',
          ][i % 3],
          receivedAt: time.subtract(Duration(hours: i * 5 + 1)),
          unread: i < 3,
        ),
    ];
    snapshot = AppSnapshot(
      profile: const StudentProfile(
        id: 'demo-student',
        name: 'Alex Demo',
        school: 'Demo School · Class 2A · fictional data',
        provider: 'Demo',
      ),
      lessons: [
        for (var week = 0; week < 3; week++)
          ...timetableWeek(today.add(Duration(days: week * 7))),
      ],
      grades: [
        for (var subject = 0; subject < _subjects.length; subject++)
          for (var i = 0; i < 6; i++)
            Grade(
              id: 'demo-grade-$subject-$i',
              subject: _subjects[subject],
              value: ['5', '4+', '3', '6', '4', '2'][((subject + i) % 6)],
              description: [
                'Written test',
                'Homework',
                'Class participation',
              ][i % 3],
              category: ['Test', 'Homework', 'Activity'][i % 3],
              date: today.subtract(Duration(days: i * 3 + subject)),
              weight: i % 3 == 0 ? 3 : 1,
              semester: i == 5 ? 3 - semester : semester,
            ),
      ],
      events: [
        for (var i = 0; i < 6; i++)
          SchoolEvent(
            id: 'demo-event-$i',
            title: i.isEven
                ? 'Practice exercises ${i + 1}–${i + 4}'
                : 'Chapter ${i + 1} test',
            subject: _subjects[i],
            date: today.add(Duration(days: i + 1)),
            kind: i.isEven ? EventKind.homework : EventKind.exam,
            description: 'Sample assignment for demo testing. Review the chapter and prepare your notes.',
          ),
      ],
      messages: messages,
      sentMessages: [
        SchoolMessage(
          id: 'demo-sent-1',
          sender: '',
          subject: 'Question about the project',
          preview: 'Could you clarify the deadline for our group presentation?',
          receivedAt: time.subtract(const Duration(hours: 2)),
          sent: true,
          recipients: [recipients.first.name],
          recipientRead: true,
        ),
      ],
      attendance: [
        for (var i = 0; i < 60; i++)
          AttendanceRecord(
            id: 'demo-attendance-$i',
            date: today.subtract(Duration(days: i ~/ 6)),
            lessonNumber: i % 6 + 1,
            subject: _subjects[i % 6],
            type: _attendanceKind(i).name,
            symbol: switch (_attendanceKind(i)) {
              AttendanceKind.absent => 'nb',
              AttendanceKind.absentExcused => 'u',
              AttendanceKind.late => 'sp',
              _ => 'ob',
            },
            kind: _attendanceKind(i),
            semester: semester,
          ),
      ],
      announcements: [
        SchoolAnnouncement(
          id: 'demo-announcement',
          title: 'Welcome to Demo School',
          content: 'This is fictional school data for exploring SiberiaGB. No school account is connected.',
          author: 'Demo School Office',
          createdAt: today,
          validUntil: today.add(const Duration(days: 14)),
          read: false,
        ),
      ],
      notices: [
        for (final (index, tone) in NoticeTone.values.indexed)
          StudentNotice(
            id: 'demo-remark-$index',
            text: [
              'Helped classmates prepare for the school science fair.',
              'Please remember to bring your workbook to the next lesson.',
              'Forgot the homework assignment. Please complete it before Friday.',
            ][index],
            category: ['Praise', 'Information', 'Reminder'][index],
            teacher: recipients[index].name,
            date: today.subtract(Duration(days: index)),
            tone: tone,
          ),
      ],
      lastSync: time,
    );
  }

  late AppSnapshot snapshot;
  Map<String, DateTime> doneHomework = {};
  var _sentCount = 0;

  static const _subjects = [
    'Mathematics',
    'English',
    'Biology',
    'History',
    'Physics',
    'Geography',
  ];
  static const recipients = [
    MessageRecipient(id: 1, name: 'Emma Sample', group: 'Teachers'),
    MessageRecipient(id: 2, name: 'Oliver Example', group: 'Teachers'),
    MessageRecipient(id: 3, name: 'Sofia Demo', group: 'Teachers'),
  ];

  static AttendanceKind _attendanceKind(int index) => switch (index % 13) {
    0 => AttendanceKind.absent,
    1 => AttendanceKind.absentExcused,
    2 => AttendanceKind.late,
    _ => AttendanceKind.present,
  };

  List<Lesson> timetableWeek(DateTime day) {
    final monday = DateTime(day.year, day.month, day.day - day.weekday + 1);
    return [
      for (var d = 0; d < 5; d++)
        for (var lesson = 0; lesson < 6; lesson++)
          Lesson(
            id: 'demo-lesson-${monday.year}-${monday.month}-${monday.day}-$d-$lesson',
            subject: _subjects[(lesson + d) % _subjects.length],
            teacher: recipients[lesson % recipients.length].name,
            room: '${201 + lesson}',
            start: DateTime(
              monday.year,
              monday.month,
              monday.day + d,
              8,
              lesson * 55,
            ),
            end: DateTime(
              monday.year,
              monday.month,
              monday.day + d,
              8,
              lesson * 55 + 45,
            ),
            lessonNumber: lesson + 1,
            substitution: d == 2 && lesson == 3,
          ),
    ];
  }

  SchoolMessageContent openMessage(SchoolMessage message) {
    final content = SchoolMessageContent(
      id: message.id,
      sender: message.sender,
      subject: message.subject,
      body: '${message.preview}\n\nThis is a fictional demo message.',
      receivedAt: message.receivedAt,
      recipients: [
        for (final name in message.recipients)
          MessageReceiver(name: name, read: message.recipientRead),
      ],
    );
    snapshot = snapshot.withOpened(message, content);
    return content;
  }

  SchoolMessage sendMessage({
    required List<MessageRecipient> recipients,
    required String subject,
    required String body,
  }) {
    final message = SchoolMessage(
      id: 'demo-outgoing-${++_sentCount}',
      sender: '',
      subject: subject.trim(),
      preview: body.trim(),
      receivedAt: DateTime.now(),
      sent: true,
      recipients: recipients.map((recipient) => recipient.name).toList(),
      recipientRead: false,
    );
    snapshot = snapshot.withSent(message);
    return message;
  }
}
