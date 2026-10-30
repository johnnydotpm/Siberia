import '../domain/models.dart';

/// Fictional school data held only in memory for the current demo session.
///
/// The demo has two profiles of one student: the regular school, and a
/// music school in the afternoons ([DemoData.music]). Both have the same
/// name, the case where profiles are hardest to tell apart.
class DemoData {
  DemoData({DateTime? now})
    : this._(
        now: now,
        studentId: 'demo-student',
        school: 'Demo School · Class 2A · fictional data',
        subjects: _regularSubjects,
        teachers: recipients,
        firstHour: 8,
        lessonsPerDay: 6,
      );

  /// The same student's music school: fewer lessons, in the afternoon.
  DemoData.music({DateTime? now})
    : this._(
        now: now,
        studentId: 'demo-student-music',
        school: 'Demo Music School · fictional data',
        subjects: _musicSubjects,
        teachers: _musicTeachers,
        firstHour: 15,
        lessonsPerDay: 2,
      );

  DemoData._({
    required DateTime? now,
    required String studentId,
    required String school,
    required this.subjects,
    required this.teachers,
    required this.firstHour,
    required this.lessonsPerDay,
  }) : _studentId = studentId {
    final time = now ?? DateTime.now();
    final today = DateTime(time.year, time.month, time.day);
    final semester = time.month >= 2 && time.month <= 8 ? 2 : 1;
    final messages = [
      for (var i = 0; i < subjects.length; i++)
        SchoolMessage(
          id: 'demo-inbox-$i',
          sender: teachers[i % teachers.length].name,
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
      profile: StudentProfile(
        id: studentId,
        name: 'Alex Demo',
        school: school,
        provider: 'Demo',
      ),
      lessons: [
        for (var week = 0; week < 3; week++)
          ...timetableWeek(
            DateTime(today.year, today.month, today.day + (week * 7)),
          ),
      ],
      grades: [
        for (var subject = 0; subject < subjects.length; subject++)
          for (var i = 0; i < 6; i++)
            Grade(
              id: 'demo-grade-$subject-$i',
              subject: subjects[subject],
              value: ['5', '4+', '3', '6', '4', '2'][((subject + i) % 6)],
              description: [
                'Written test',
                'Homework',
                'Class participation',
              ][i % 3],
              category: ['Test', 'Homework', 'Activity'][i % 3],
              date: DateTime(
                today.year,
                today.month,
                today.day - (i * 3 + subject),
              ),
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
            subject: subjects[i],
            date: DateTime(today.year, today.month, today.day + (i + 1)),
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
          recipients: [teachers.first.name],
          recipientRead: true,
        ),
      ],
      attendance: [
        for (var i = 0; i < 60; i++)
          AttendanceRecord(
            id: 'demo-attendance-$i',
            date: DateTime(today.year, today.month, today.day - (i ~/ 6)),
            lessonNumber: i % 6 + 1,
            subject: subjects[i % 6],
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
          validUntil: DateTime(today.year, today.month, today.day + 14),
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
            teacher: teachers[index].name,
            date: DateTime(today.year, today.month, today.day - (index)),
            tone: tone,
          ),
      ],
      lastSync: time,
    );
  }

  late AppSnapshot snapshot;
  Map<String, DateTime> doneHomework = {};
  var _sentCount = 0;

  final String _studentId;
  final List<String> subjects;
  final List<MessageRecipient> teachers;
  final int firstHour;
  final int lessonsPerDay;

  static const _regularSubjects = [
    'Mathematics',
    'English',
    'Biology',
    'History',
    'Physics',
    'Geography',
  ];
  static const _musicSubjects = [
    'Piano',
    'Solfège',
    'Music history',
    'Choir',
    'Ensemble',
    'Rhythmics',
  ];
  static const recipients = [
    MessageRecipient(id: 1, name: 'Emma Sample', group: 'Teachers'),
    MessageRecipient(id: 2, name: 'Oliver Example', group: 'Teachers'),
    MessageRecipient(id: 3, name: 'Sofia Demo', group: 'Teachers'),
  ];
  static const _musicTeachers = [
    MessageRecipient(id: 4, name: 'Clara Sample', group: 'Teachers'),
    MessageRecipient(id: 5, name: 'Leo Example', group: 'Teachers'),
    MessageRecipient(id: 6, name: 'Mia Demo', group: 'Teachers'),
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
        for (var lesson = 0; lesson < lessonsPerDay; lesson++)
          Lesson(
            id: 'demo-lesson-$_studentId-${monday.year}-${monday.month}-${monday.day}-$d-$lesson',
            subject: subjects[(lesson + d) % subjects.length],
            teacher: teachers[lesson % teachers.length].name,
            room: '${201 + lesson}',
            start: DateTime(
              monday.year,
              monday.month,
              monday.day + d,
              firstHour,
              lesson * 55,
            ),
            end: DateTime(
              monday.year,
              monday.month,
              monday.day + d,
              firstHour,
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
