import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/models/focus_timer_state.dart';
import 'package:focus_sessions/models/session.dart';

void main() {
  TimerRunning runningWith(Duration remaining) {
    final start = DateTime.utc(2026, 11, 6, 10);
    return TimerRunning(
      plannedLength: FocusLength.medium,
      startTime: start,
      plannedEndTime: start.add(FocusLength.medium.duration),
      remaining: remaining,
    );
  }

  group('TimerRunning.remainingSeconds', () {
    test('is the full length at the start', () {
      expect(runningWith(const Duration(minutes: 25)).remainingSeconds, 1500);
    });

    test('rounds a partial second up', () {
      expect(
        runningWith(const Duration(minutes: 24, seconds: 59, milliseconds: 1))
            .remainingSeconds,
        1500,
      );
    });

    test('is 1, not 0, while any time remains', () {
      expect(
        runningWith(const Duration(microseconds: 1)).remainingSeconds,
        1,
      );
    });

    test('does not round up a whole second', () {
      expect(runningWith(const Duration(seconds: 90)).remainingSeconds, 90);
    });
  });
}
