import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/data/session_repository.dart';
import 'package:focus_sessions/models/focus_timer_state.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:focus_sessions/providers/core_providers.dart';
import 'package:focus_sessions/providers/focus_timer_provider.dart';
import 'package:focus_sessions/providers/session_history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real repository on mock storage that counts saves, can fail, and can hold
/// a save open until [gate] completes.
class FakeSessionRepository extends SessionRepository {
  FakeSessionRepository(super.prefs);

  int addCalls = 0;
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<void> addSession(Session session) async {
    addCalls++;
    await gate?.future;
    if (fail) throw Exception('Save failed');
    await super.addSession(session);
  }
}

void main() {
  final start = DateTime.utc(2026, 11, 6, 10);
  final plannedEnd = start.add(const Duration(minutes: 25));

  late DateTime now;
  late StreamController<void> ticks;
  late FakeSessionRepository repository;

  setUp(() async {
    now = start;
    ticks = StreamController<void>.broadcast(sync: true);
    SharedPreferences.setMockInitialValues({});
    repository = FakeSessionRepository(await SharedPreferences.getInstance());
  });

  tearDown(() => ticks.close());

  ProviderContainer createContainer({bool disposeAfterTest = true}) {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        tickerProvider.overrideWithValue(() => ticks.stream),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    if (disposeAfterTest) addTearDown(container.dispose);
    return container;
  }

  FocusTimerState stateOf(ProviderContainer c) => c.read(focusTimerProvider);
  FocusTimerNotifier notifierOf(ProviderContainer c) =>
      c.read(focusTimerProvider.notifier);

  /// Starts a 25-minute session at [start].
  ProviderContainer startedContainer() {
    final container = createContainer();
    notifierOf(container).start(FocusLength.medium);
    return container;
  }

  TimerEnded endedAt(DateTime endTime) => TimerEnded(
        plannedLength: FocusLength.medium,
        startTime: start,
        endTime: endTime,
      );

  group('start', () {
    test('begins idle', () {
      expect(stateOf(createContainer()), const TimerIdle());
    });

    test('moves to running with the full planned length remaining', () {
      final container = startedContainer();

      expect(
        stateOf(container),
        TimerRunning(
          plannedLength: FocusLength.medium,
          startTime: start,
          endTime: plannedEnd,
          remaining: const Duration(minutes: 25),
        ),
      );
      expect(ticks.hasListener, isTrue);
    });

    test('throws StateError while running', () {
      final container = startedContainer();

      expect(
        () => notifierOf(container).start(FocusLength.short),
        throwsStateError,
      );
    });

    test('throws StateError while waiting for a note', () {
      final container = startedContainer();
      notifierOf(container).end();

      expect(
        () => notifierOf(container).start(FocusLength.short),
        throwsStateError,
      );
    });
  });

  group('ticking', () {
    test('remaining time comes from the clock', () {
      final container = startedContainer();
      now = start.add(const Duration(minutes: 10));

      ticks.add(null);

      expect(
        (stateOf(container) as TimerRunning).remaining,
        const Duration(minutes: 15),
      );
    });

    test('ticks without the clock moving do not change remaining time', () {
      final container = startedContainer();

      ticks
        ..add(null)
        ..add(null)
        ..add(null);

      expect(
        (stateOf(container) as TimerRunning).remaining,
        const Duration(minutes: 25),
      );
    });

    test('clamps remaining time if the clock moves backward', () {
      final container = startedContainer();
      now = start.subtract(const Duration(minutes: 10));

      ticks.add(null);

      expect(
        (stateOf(container) as TimerRunning).remaining,
        const Duration(minutes: 25),
      );
    });
  });

  group('finishing', () {
    test('moves to TimerEnded at the planned end without saving', () async {
      final container = startedContainer();
      now = plannedEnd;

      ticks.add(null);

      expect(stateOf(container), endedAt(plannedEnd));
      expect(repository.addCalls, 0);
      expect(await repository.loadSessions(), isEmpty);
    });

    test('caps endTime at the planned end after finishing in the background',
        () {
      final container = startedContainer();
      now = start.add(const Duration(hours: 3));

      ticks.add(null);

      expect(stateOf(container), endedAt(plannedEnd));
    });

    test('cancels the ticker', () {
      startedContainer();
      now = plannedEnd;

      ticks.add(null);

      expect(ticks.hasListener, isFalse);
    });
  });

  group('end', () {
    test('ending early moves to TimerEnded at the current time', () {
      final container = startedContainer();
      final stoppedAt = start.add(const Duration(minutes: 7));
      now = stoppedAt;

      notifierOf(container).end();

      expect(stateOf(container), endedAt(stoppedAt));
      expect(repository.addCalls, 0);
    });

    test('cancels the ticker', () {
      final container = startedContainer();

      notifierOf(container).end();

      expect(ticks.hasListener, isFalse);
    });

    test('clamps endTime to startTime if the clock moved backward', () {
      final container = startedContainer();
      now = start.subtract(const Duration(minutes: 10));

      notifierOf(container).end();

      expect(stateOf(container), endedAt(start));
    });

    test('does nothing when idle', () {
      final container = createContainer();

      notifierOf(container).end();

      expect(stateOf(container), const TimerIdle());
    });
  });

  group('saveNote', () {
    test('saves the session with the note and returns to idle', () async {
      final container = startedContainer();
      final stoppedAt = start.add(const Duration(minutes: 20));
      now = stoppedAt;
      notifierOf(container).end();

      await notifierOf(container).saveNote('Finished the draft');

      expect(stateOf(container), const TimerIdle());
      expect(await repository.loadSessions(), [
        Session(
          plannedLength: FocusLength.medium,
          startTime: start,
          endTime: stoppedAt,
          note: 'Finished the draft',
        ),
      ]);
    });

    test('refreshes the history after a successful save', () async {
      final container = startedContainer();
      expect(await container.read(sessionHistoryProvider.future), isEmpty);
      notifierOf(container).end();

      await notifierOf(container).saveNote('Note');

      final history = await container.read(sessionHistoryProvider.future);
      expect(history.single.note, 'Note');
    });

    test('a double-tap saves only once', () async {
      final container = startedContainer();
      notifierOf(container).end();
      repository.gate = Completer<void>();

      final first = notifierOf(container).saveNote('Note');
      final second = notifierOf(container).saveNote('Note');
      repository.gate!.complete();
      await Future.wait([first, second]);

      expect(repository.addCalls, 1);
      expect(await repository.loadSessions(), hasLength(1));
      expect(stateOf(container), const TimerIdle());
    });

    test('a failed save stays in TimerEnded and can be retried', () async {
      final container = startedContainer();
      notifierOf(container).end();
      repository.fail = true;

      await expectLater(notifierOf(container).saveNote('Note'), throwsException);
      expect(stateOf(container), endedAt(start));

      repository.fail = false;
      await notifierOf(container).saveNote('Note');

      expect(stateOf(container), const TimerIdle());
      expect(await repository.loadSessions(), hasLength(1));
    });

    test('does nothing when idle', () async {
      final container = createContainer();

      await notifierOf(container).saveNote('Note');

      expect(repository.addCalls, 0);
    });
  });

  test('dispose cancels the ticker', () {
    final container = createContainer(disposeAfterTest: false);
    notifierOf(container).start(FocusLength.medium);

    container.dispose();

    expect(ticks.hasListener, isFalse);
  });
}
