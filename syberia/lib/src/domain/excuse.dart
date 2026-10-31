/// Why a child was, or will be, away.
enum ExcuseReason {
  illness,
  doctor,
  family,
  other;

  /// The reason as the message to the school says it, in Polish.
  String get polish => switch (this) {
    illness => 'choroba',
    doctor => 'wizyta u lekarza',
    family => 'sprawy rodzinne',
    other => '',
  };
}

/// One lesson a child missed.
typedef ExcuseLesson = ({DateTime date, int lesson, String subject});

const _weekdays = [
  'poniedziałek',
  'wtorek',
  'środa',
  'czwartek',
  'piątek',
  'sobota',
  'niedziela',
];

String _date(DateTime value, {bool year = true}) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}${year ? '.${value.year}' : ''}';
}

/// The message to the class teacher, always in Polish, as the teacher reads
/// it: excusing [lessons] [child] missed, or, with [from] and [to], telling
/// of days [child] will be away. [note] is the reason when [reason] is
/// [ExcuseReason.other], and a line of its own otherwise.
({String subject, String body}) excuseMessage({
  required String child,
  List<ExcuseLesson> lessons = const [],
  DateTime? from,
  DateTime? to,
  required ExcuseReason reason,
  String note = '',
  String signature = '',
}) {
  final planned = from != null;
  final why = reason == ExcuseReason.other ? note.trim() : reason.polish;
  final extra = reason == ExcuseReason.other ? '' : note.trim();
  final lines = <String>['Dzień dobry,', ''];
  if (planned) {
    final last = to ?? from;
    final sameDay =
        last.year == from.year &&
        last.month == from.month &&
        last.day == from.day;
    lines.add(
      'informuję, że moje dziecko, $child, nie będzie obecne w szkole '
      '${sameDay ? 'w dniu ${_date(from)}' : 'w dniach ${_date(from, year: from.year != last.year)}–${_date(last)}'}.',
    );
  } else {
    lines.add(
      'proszę o usprawiedliwienie nieobecności mojego dziecka, $child:',
    );
    final days = <DateTime, List<ExcuseLesson>>{};
    for (final lesson in lessons) {
      final day = DateTime(
        lesson.date.year,
        lesson.date.month,
        lesson.date.day,
      );
      days.putIfAbsent(day, () => []).add(lesson);
    }
    for (final day in days.keys.toList()..sort()) {
      final missed = days[day]!..sort((a, b) => a.lesson.compareTo(b.lesson));
      final numbers = [
        for (final lesson in missed)
          if (lesson.lesson > 0) '${lesson.lesson}',
      ];
      final subjects = {
        for (final lesson in missed)
          if (lesson.subject.trim().isNotEmpty) lesson.subject.trim(),
      };
      final what = numbers.isEmpty
          ? ''
          : ': ${numbers.length == 1 ? 'lekcja' : 'lekcje'} ${numbers.join(', ')}';
      lines.add(
        '– ${_weekdays[day.weekday - 1]} ${_date(day)}$what'
        '${subjects.isEmpty ? '' : ' (${subjects.join(', ')})'}',
      );
    }
  }
  lines.add('');
  if (why.isNotEmpty) lines.add('Powód: $why.');
  if (extra.isNotEmpty) lines.add(extra);
  lines
    ..add('')
    ..add('Z poważaniem');
  if (signature.trim().isNotEmpty) lines.add(signature.trim());
  return (
    subject:
        '${planned ? 'Planowana nieobecność' : 'Usprawiedliwienie nieobecności'} – $child',
    body: lines.join('\n'),
  );
}
