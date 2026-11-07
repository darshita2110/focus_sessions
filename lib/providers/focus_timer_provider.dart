import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_sessions/models/focus_timer_state.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:focus_sessions/providers/core_providers.dart';
import 'package:focus_sessions/providers/session_history_provider.dart';

/// Not autoDispose, so the timer keeps running while other screens are open.
final focusTimerProvider =
    NotifierProvider<FocusTimerNotifier, FocusTimerState>(
  FocusTimerNotifier.new,
);

/// Runs one focus session at a time: idle → running → ended → idle.
///
/// Remaining time is always `plannedEndTime - clock()`, clamped to between
/// zero and the planned length, so a late tick, a backgrounded app or a clock
/// change never leaves it wrong.
class FocusTimerNotifier extends Notifier<FocusTimerState> {
  StreamSubscription<void>? _ticks;
  bool _isSaving = false;

  @override
  FocusTimerState build() {
    ref.onDispose(_stopTicking);
    return const TimerIdle();
  }

  /// Starts a session of [length]. Does nothing unless the timer is idle, so a
  /// second tap cannot replace a running or ended session.
  void start(FocusLength length) {
    if (state is! TimerIdle) return;
    final now = _now();
    state = TimerRunning(
      plannedLength: length,
      startTime: now,
      plannedEndTime: now.add(length.duration),
      remaining: length.duration,
    );
    _ticks = ref.read(tickerProvider)().listen((_) => _tick());
  }

  /// Ends the running session early. Does nothing if no session is running.
  void end() {
    final current = state;
    if (current is! TimerRunning) return;
    _finish(
      current,
      _clampTime(_now(), current.startTime, current.plannedEndTime),
    );
  }

  /// Saves the ended session with [note], trimmed, then returns to idle.
  ///
  /// Does nothing if no session has ended or a save is already in progress.
  /// If saving fails, the error is rethrown and the state stays [TimerEnded]
  /// so the user can retry.
  Future<void> saveNote(String note) async {
    final current = state;
    if (current is! TimerEnded || _isSaving) return;
    _isSaving = true;
    try {
      await ref.read(sessionRepositoryProvider).addSession(
            Session(
              plannedLength: current.plannedLength,
              startTime: current.startTime,
              endTime: current.endTime,
              note: note.trim(),
            ),
          );
      state = const TimerIdle();
      ref.invalidate(sessionHistoryProvider);
    } finally {
      _isSaving = false;
    }
  }

  void _tick() {
    final current = state;
    if (current is! TimerRunning) return;
    final now = _now();
    if (!now.isBefore(current.plannedEndTime)) {
      // Covers finishing while backgrounded: the session counts as ending at
      // its planned end, not when the app next ticked.
      _finish(current, current.plannedEndTime);
      return;
    }
    state = TimerRunning(
      plannedLength: current.plannedLength,
      startTime: current.startTime,
      plannedEndTime: current.plannedEndTime,
      remaining: _clampDuration(
        current.plannedEndTime.difference(now),
        current.plannedLength.duration,
      ),
    );
  }

  void _finish(TimerRunning running, DateTime endTime) {
    _stopTicking();
    state = TimerEnded(
      plannedLength: running.plannedLength,
      startTime: running.startTime,
      endTime: endTime,
    );
  }

  void _stopTicking() {
    _ticks?.cancel();
    _ticks = null;
  }

  DateTime _now() => ref.read(clockProvider)().toUtc();

  /// Keeps an end time inside the session even if the clock moved, so
  /// `Session` never gets an endTime before its startTime.
  static DateTime _clampTime(DateTime time, DateTime min, DateTime max) {
    if (time.isBefore(min)) return min;
    if (time.isAfter(max)) return max;
    return time;
  }

  /// Caps remaining time at [max] if the clock moved back before the start.
  ///
  /// [value] is always positive here: [_tick] finishes the session before
  /// calling this once the planned end is reached.
  static Duration _clampDuration(Duration value, Duration max) {
    if (value > max) return max;
    return value;
  }
}
