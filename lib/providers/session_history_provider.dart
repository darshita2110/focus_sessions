import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:focus_sessions/providers/core_providers.dart';

final sessionHistoryProvider =
    AsyncNotifierProvider<SessionHistoryNotifier, List<Session>>(
  SessionHistoryNotifier.new,
);

/// The saved sessions, newest first.
class SessionHistoryNotifier extends AsyncNotifier<List<Session>> {
  @override
  Future<List<Session>> build() =>
      ref.watch(sessionRepositoryProvider).loadSessions();

  /// Removes [session] from state synchronously, then from storage.
  ///
  /// If storage fails, the session is put back and the error is rethrown.
  /// [beforeRestore] is awaited first, so a caller can delay the row's return
  /// until the UI has processed its removal.
  Future<void> deleteSession(
    Session session, {
    Future<void> Function()? beforeRestore,
  }) async {
    // Runs before the first await, so a Dismissible's onDismissed sees the row
    // leave state before it returns.
    state = AsyncData([
      for (final other in state.valueOrNull ?? const <Session>[])
        if (!other.startTime.isAtSameMomentAs(session.startTime)) other,
    ]);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .deleteSession(session.startTime);
    } catch (_) {
      await beforeRestore?.call();
      _restore(session);
      rethrow;
    }
  }

  /// Adds [session] to the current list rather than restoring an old snapshot,
  /// which could bring back a row removed by another delete in the meantime.
  void _restore(Session session) {
    final current = state.valueOrNull ?? const <Session>[];
    if (current.any((s) => s.startTime.isAtSameMomentAs(session.startTime))) {
      return;
    }
    state = AsyncData(
      [...current, session]..sort((a, b) => b.startTime.compareTo(a.startTime)),
    );
  }
}
