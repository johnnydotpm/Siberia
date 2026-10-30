/// Whole calendar days from [from] to [to]: 1 from any time today to any
/// time tomorrow, negative into the past.
///
/// The day the clocks change has 23 or 25 hours, so the days are counted on
/// their dates, not in hours.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
