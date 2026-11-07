class StreakCounter {
  final List<DateTime> sessionDays;
  StreakCounter(this.sessionDays);

  /// Returns the number of consecutive days, ending today, with a session.
  int currentStreak() {
    if (sessionDays.isEmpty) return 0;
    final days = sessionDays.toList()..sort();
    var streak = 1;
    var cursor = DateTime.now();
    for (var i = days.length - 1; i > 0; i--) {
      if (days[i].difference(cursor).inDays == 1) {
        streak++;
        cursor = days[i];
      } else {
        break;
      }
    }
    return streak;
  }
}