/// Why a child was, or will be, away: [genitive] is how the note says it
/// after "z powodu", always in Polish.
enum ExcuseReason {
  unwell('złego samopoczucia'),
  illness('choroby'),
  doctor('wizyty u lekarza'),
  medicalTests('badań lekarskich'),
  dentist('wizyty u dentysty'),
  family('spraw rodzinnych'),
  familyTrip('wyjazdu rodzinnego'),
  celebration('uroczystości rodzinnej'),
  sport('udziału w zawodach sportowych'),
  contest('udziału w konkursie'),
  office('spraw urzędowych'),
  transport('problemów z dojazdem'),
  weather('złych warunków pogodowych'),

  /// Written by the parent, as it goes after "z powodu".
  other('');

  const ExcuseReason(this.genitive);
  final String genitive;

  static ExcuseReason byName(String? name) =>
      values.where((reason) => reason.name == name).firstOrNull ?? unwell;
}

/// How the note speaks of the child.
enum ExcuseChild {
  son('mojego syna', 'mój syn', 'obecny'),
  daughter('mojej córki', 'moja córka', 'obecna'),
  child('mojego dziecka', 'moje dziecko', 'obecne');

  const ExcuseChild(this.genitive, this.nominative, this.present);

  /// "nieobecności mojego syna"
  final String genitive;

  /// "mój syn nie będzie obecny"
  final String nominative;
  final String present;

  static ExcuseChild byName(String? name) =>
      values.where((word) => word.name == name).firstOrNull ?? child;
}

/// One day of the note and why the child was away then. [other] is the
/// reason in the parent's words, for [ExcuseReason.other].
typedef ExcuseDay = ({DateTime date, ExcuseReason reason, String other});

const defaultExcuseGreeting = 'Dzień dobry,';
const defaultExcuseClosing = 'Dziękuję za zrozumienie.';

const _months = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

/// "27 października"
String polishDate(DateTime value) => '${value.day} ${_months[value.month - 1]}';

String _list(List<String> items) => items.length < 2
    ? items.join()
    : '${items.take(items.length - 1).join(', ')} i ${items.last}';

String _why(ExcuseReason reason, String other) =>
    reason == ExcuseReason.other ? other.trim() : reason.genitive;

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// The sentence that asks to excuse [days] of the child spoken of as [word]:
/// "Proszę o usprawiedliwienie nieobecności mojego syna w dniu 27
/// października z powodu złego samopoczucia oraz 29 z powodu spraw
/// rodzinnych." Days with the same reason go together; a month already
/// said is not said again.
String excuseSentence(List<ExcuseDay> days, {required ExcuseChild word}) {
  final groups = <(ExcuseReason, String), List<DateTime>>{};
  for (final day in [...days]..sort((a, b) => a.date.compareTo(b.date))) {
    final key = (
      day.reason,
      day.reason == ExcuseReason.other ? day.other.trim() : '',
    );
    final dates = groups.putIfAbsent(key, () => []);
    final date = _day(day.date);
    if (!dates.contains(date)) dates.add(date);
  }
  (int, int)? said;
  final parts = <String>[];
  for (final MapEntry(key: (reason, other), value: dates) in groups.entries) {
    // Days of one month share it: "27 i 28 października".
    final runs = <List<DateTime>>[];
    for (final date in dates) {
      if (runs.isNotEmpty &&
          runs.last.last.year == date.year &&
          runs.last.last.month == date.month) {
        runs.last.add(date);
      } else {
        runs.add([date]);
      }
    }
    final phrases = <String>[];
    for (final run in runs) {
      final month = (run.first.year, run.first.month);
      final numbers = _list([for (final date in run) '${date.day}']);
      phrases.add(
        month == said ? numbers : '$numbers ${_months[month.$2 - 1]}',
      );
      said = month;
    }
    final why = _why(reason, other);
    final when = _list(phrases);
    final lead = parts.isEmpty
        ? (dates.length == 1 ? 'w dniu $when' : 'w dniach $when')
        : when;
    parts.add(why.isEmpty ? lead : '$lead z powodu $why');
  }
  final all = parts.length < 2
      ? parts.join()
      : '${parts.take(parts.length - 1).join(', ')} oraz ${parts.last}';
  return 'Proszę o usprawiedliwienie nieobecności ${word.genitive}'
      '${all.isEmpty ? '' : ' $all'}.';
}

/// The sentence that tells of the days from [from] to [to] the child will
/// be away: "Uprzejmie informuję, że mój syn nie będzie obecny w szkole w
/// dniach 3–5 listopada z powodu wyjazdu rodzinnego."
String plannedSentence({
  required DateTime from,
  required DateTime to,
  required ExcuseChild word,
  required ExcuseReason reason,
  String other = '',
}) {
  final first = _day(from);
  final last = _day(to).isBefore(first) ? first : _day(to);
  final String when;
  if (last == first) {
    when = 'w dniu ${polishDate(first)}';
  } else if (last.year == first.year && last.month == first.month) {
    when = 'w dniach ${first.day}–${polishDate(last)}';
  } else {
    when = 'w dniach ${polishDate(first)} – ${polishDate(last)}';
  }
  final why = _why(reason, other);
  return 'Uprzejmie informuję, że ${word.nominative} nie będzie '
      '${word.present} w szkole $when${why.isEmpty ? '' : ' z powodu $why'}.';
}

/// The note as the class teacher reads it: the greeting, the [sentence],
/// the closing and, when there is one, the parent's [signature].
String excuseBody({
  required String sentence,
  String greeting = defaultExcuseGreeting,
  String closing = defaultExcuseClosing,
  String signature = '',
}) {
  final hello = greeting.trim().isEmpty
      ? defaultExcuseGreeting
      : greeting.trim();
  final bye = closing.trim().isEmpty ? defaultExcuseClosing : closing.trim();
  return [
    hello,
    sentence,
    '',
    bye,
    if (signature.trim().isNotEmpty) signature.trim(),
  ].join('\n');
}

/// The subject of the note about [child]'s absences, or of a [planned] one.
String excuseSubject(String child, {bool planned = false}) =>
    '${planned ? 'Planowana nieobecność' : 'Usprawiedliwienie nieobecności'}'
    '${child.trim().isEmpty ? '' : ' – ${child.trim()}'}';

/// Greetings for the class teacher named [teacher] as Librus shows the name,
/// whichever way round: "Dzień dobry Pani Anno," for each word that reads as
/// a woman's first name, then the plain one. A surname such as Kowalska or
/// Nowakowa is left out; a man's name gets only the plain greeting.
List<String> excuseGreetings(String teacher) {
  final names = <String>[];
  for (final word in teacher.trim().split(RegExp(r'\s+'))) {
    final lower = word.toLowerCase();
    if (word.length < 3 ||
        !lower.endsWith('a') ||
        RegExp(r'(ska|cka|dzka|owa)$').hasMatch(lower)) {
      continue;
    }
    final stem = word.substring(0, word.length - 1);
    // Maja, Kaja: Maju; Anna, Maria, Wioleta: Anno, Mario, Wioleto.
    final vocative = RegExp(r'[aeiouy]j$').hasMatch(stem.toLowerCase())
        ? '${stem.substring(0, stem.length - 1)}ju'
        : '${stem}o';
    final greeting = 'Dzień dobry Pani $vocative,';
    if (!names.contains(greeting)) names.add(greeting);
  }
  return [...names, defaultExcuseGreeting];
}
