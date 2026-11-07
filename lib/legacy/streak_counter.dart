class StreakCounter {
  final List<DateTime> sessionDays;
  final DateTime Function() _now;

  /// [now] supplies the current time and defaults to [DateTime.now]. Tests
  /// pass a fixed time so they do not depend on the real date.
  StreakCounter(this.sessionDays, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// Returns the number of consecutive days, ending today, with a session.
  ///
  /// Days are local calendar days, so UTC times are converted first. Returns 0
  /// if there is no session today.
  int currentStreak() {
    final days = {for (final time in sessionDays) _localDate(time)};
    var day = _localDate(_now());
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      // Calendar arithmetic, not a 24-hour Duration, so daylight-saving days
      // of 23 or 25 hours still step back exactly one day.
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  /// Midnight at the start of [time]'s local calendar day.
  static DateTime _localDate(DateTime time) {
    final local = time.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}