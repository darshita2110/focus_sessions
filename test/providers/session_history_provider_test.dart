import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/data/session_repository.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:focus_sessions/providers/core_providers.dart';
import 'package:focus_sessions/providers/session_history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real repository on mock storage whose deletes can be held open or fail.
class _FakeRepository extends SessionRepository {
  _FakeRepository(super.prefs);

  final failingStartTimes = <DateTime>{};
  Completer<void>? deleteGate;

  @override
  Future<void> deleteSession(DateTime startTime) async {
    await deleteGate?.future;
    if (failingStartTimes.contains(startTime)) {
      throw Exception('Delete failed');
    }
    await super.deleteSession(startTime);
  }
}

void main() {
  Session sessionAt(int hour) => Session(
        plannedLength: FocusLength.medium,
        startTime: DateTime.utc(2026, 11, 6, hour),
        endTime: DateTime.utc(2026, 11, 6, hour, 25),
      );

  late _FakeRepository repository;
  late ProviderContainer container;

  List<Session> historyState() =>
      container.read(sessionHistoryProvider).requireValue;

  SessionHistoryNotifier notifier() =>
      container.read(sessionHistoryProvider.notifier);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeRepository(await SharedPreferences.getInstance());
    await repository.addSession(sessionAt(9));
    await repository.addSession(sessionAt(11));
    await repository.addSession(sessionAt(10));
    container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(sessionHistoryProvider.future);
  });

  test('loads sessions newest first', () {
    expect(historyState(), [sessionAt(11), sessionAt(10), sessionAt(9)]);
  });

  test('removes the session from state before storage finishes', () async {
    repository.deleteGate = Completer<void>();

    final delete = notifier().deleteSession(sessionAt(10));

    expect(historyState(), [sessionAt(11), sessionAt(9)]);
    expect(await repository.loadSessions(), hasLength(3));

    repository.deleteGate!.complete();
    await delete;
    expect(await repository.loadSessions(), [sessionAt(11), sessionAt(9)]);
  });

  test('a failed delete rethrows and restores the session in order', () async {
    repository.failingStartTimes.add(sessionAt(10).startTime);

    await expectLater(
      notifier().deleteSession(sessionAt(10)),
      throwsException,
    );

    expect(historyState(), [sessionAt(11), sessionAt(10), sessionAt(9)]);
  });

  test('waits for beforeRestore before restoring', () async {
    repository.failingStartTimes.add(sessionAt(10).startTime);
    final frame = Completer<void>();

    final delete = notifier().deleteSession(
      sessionAt(10),
      beforeRestore: () => frame.future,
    );
    await pumpEventQueue();
    expect(historyState(), [sessionAt(11), sessionAt(9)]);

    frame.complete();
    await expectLater(delete, throwsException);
    expect(historyState(), [sessionAt(11), sessionAt(10), sessionAt(9)]);
  });

  test('a failed delete does not bring back a row deleted meanwhile', () async {
    repository
      ..failingStartTimes.add(sessionAt(10).startTime)
      ..deleteGate = Completer<void>();

    final failing = notifier().deleteSession(sessionAt(10));
    final succeeding = notifier().deleteSession(sessionAt(9));
    repository.deleteGate!.complete();

    await expectLater(failing, throwsException);
    await succeeding;
    expect(historyState(), [sessionAt(11), sessionAt(10)]);
  });
}
