import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/legacy/streak_counter.dart';

/// One test per bug in currentStreak. Each input is chosen so the test would
/// still fail if every other bug were fixed and only its own bug remained.
void main() {
  // Sunday 8 November 2026, 20:00 local time.
  final now = DateTime(2026, 11, 8, 20);

  int streak(List<DateTime> sessions) =>
      StreakCounter(sessions, now: () => now).currentStreak();

  test('bug 1: no session today gives 0', () {
    // Sessions on the two days before today, none today.
    final sessions = [DateTime(2026, 11, 6, 10), DateTime(2026, 11, 7, 10)];

    expect(streak(sessions), 0);
  });

  test('bug 2: a session yesterday extends the streak (comparison direction)',
      () {
    // Exactly 24 hours apart, at the same time of day as "now", so only the
    // direction of the comparison matters.
    final sessions = [DateTime(2026, 11, 7, 20), DateTime(2026, 11, 8, 20)];

    expect(streak(sessions), 2);
  });

  test('bug 3: days less than 24 hours apart still count (time of day)', () {
    // Consecutive calendar days, but only one hour apart.
    final sessions = [
      DateTime(2026, 11, 7, 23, 30),
      DateTime(2026, 11, 8, 0, 30),
    ];

    expect(streak(sessions), 2);
  });

  test('bug 4: two sessions on one day count as one day (duplicates)', () {
    final sessions = [
      DateTime(2026, 11, 7, 12),
      DateTime(2026, 11, 8, 9),
      DateTime(2026, 11, 8, 18),
    ];

    expect(streak(sessions), 2);
  });

  test('bug 5: the loop checks every earlier day (loop bounds)', () {
    // The oldest session is at index 0, which the loop never reaches, and the
    // loop starts by re-checking today's session.
    final sessions = [
      DateTime(2026, 11, 6, 12),
      DateTime(2026, 11, 7, 12),
      DateTime(2026, 11, 8, 12),
    ];

    expect(streak(sessions), 3);
  });

  test('an empty list gives 0', () {
    expect(streak([]), 0);
  });

  test('a single session today gives 1', () {
    expect(streak([DateTime(2026, 11, 8, 9)]), 1);
  });

  test('a missing day ends the streak even when sessions are 26 hours apart',
      () {
    // Nov 7 is missing. A 24-hour Duration check would count these as
    // consecutive because they are 26 hours apart.
    final sessions = [DateTime(2026, 11, 6, 23), DateTime(2026, 11, 8, 1)];

    expect(streak(sessions), 1);
  });

  // Catches a missing toLocal() on any machine not set to UTC: with a
  // positive offset both UTC dates fall on Nov 7, with a negative one both
  // fall on Nov 8.
  test('UTC input near midnight is counted on the local day', () {
    final sessions = [
      DateTime(2026, 11, 7, 23, 30).toUtc(),
      DateTime(2026, 11, 8, 0, 30).toUtc(),
    ];

    expect(streak(sessions), 2);
  });

  test('the original StreakCounter(sessionDays) constructor still works', () {
    // An empty list gives 0 whatever the real date is, so this cannot flake.
    expect(StreakCounter([]).currentStreak(), 0);
  });
}
