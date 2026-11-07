import 'package:focus_sessions/models/session.dart';

/// The state of the focus timer. All times are in UTC.
sealed class FocusTimerState {
  const FocusTimerState();
}

/// No session is running or waiting for a note.
class TimerIdle extends FocusTimerState {
  const TimerIdle();

  @override
  bool operator ==(Object other) => other is TimerIdle;

  @override
  int get hashCode => (TimerIdle).hashCode;

  @override
  String toString() => 'TimerIdle()';
}

/// A session is counting down to [plannedEndTime].
///
/// [remaining] is recalculated from the clock on every tick; it is never
/// decremented.
class TimerRunning extends FocusTimerState {
  const TimerRunning({
    required this.plannedLength,
    required this.startTime,
    required this.plannedEndTime,
    required this.remaining,
  });

  final FocusLength plannedLength;
  final DateTime startTime;

  /// The planned end: [startTime] plus [plannedLength]. Named apart from
  /// [TimerEnded.endTime], which is when the session actually ended.
  final DateTime plannedEndTime;

  final Duration remaining;

  /// Whole seconds left, rounded up, so a countdown starts at the full
  /// length and never shows zero while time remains.
  int get remainingSeconds =>
      (remaining.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
      Duration.microsecondsPerSecond;

  @override
  bool operator ==(Object other) =>
      other is TimerRunning &&
      other.plannedLength == plannedLength &&
      other.startTime == startTime &&
      other.plannedEndTime == plannedEndTime &&
      other.remaining == remaining;

  @override
  int get hashCode =>
      Object.hash(plannedLength, startTime, plannedEndTime, remaining);

  @override
  String toString() => 'TimerRunning(plannedLength: $plannedLength, '
      'startTime: $startTime, plannedEndTime: $plannedEndTime, '
      'remaining: $remaining)';
}

/// A session has finished or was ended early and is waiting for a note
/// before it is saved.
class TimerEnded extends FocusTimerState {
  const TimerEnded({
    required this.plannedLength,
    required this.startTime,
    required this.endTime,
  });

  final FocusLength plannedLength;
  final DateTime startTime;

  /// When the session actually ended, never before [startTime] and never
  /// after the planned end.
  final DateTime endTime;

  @override
  bool operator ==(Object other) =>
      other is TimerEnded &&
      other.plannedLength == plannedLength &&
      other.startTime == startTime &&
      other.endTime == endTime;

  @override
  int get hashCode => Object.hash(plannedLength, startTime, endTime);

  @override
  String toString() => 'TimerEnded(plannedLength: $plannedLength, '
      'startTime: $startTime, endTime: $endTime)';
}
