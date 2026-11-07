import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/data/session_repository.dart';
import 'package:focus_sessions/models/quote.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:focus_sessions/providers/core_providers.dart';
import 'package:focus_sessions/providers/daily_quote_provider.dart';
import 'package:focus_sessions/screens/history_screen.dart';
import 'package:focus_sessions/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real repository on mock storage whose loads and deletes can be controlled.
class _FakeRepository extends SessionRepository {
  _FakeRepository(super.prefs);

  Completer<void>? loadGate;
  bool failLoad = false;
  bool failDelete = false;

  @override
  Future<List<Session>> loadSessions() async {
    await loadGate?.future;
    if (failLoad) throw Exception('Load failed');
    return super.loadSessions();
  }

  @override
  Future<void> deleteSession(DateTime startTime) {
    // Fails with no delay, so the failure arrives before the next frame.
    if (failDelete) return Future.error(Exception('Delete failed'));
    return super.deleteSession(startTime);
  }
}

/// Keeps these tests away from quote fetching, which has its own tests.
class _StubDailyQuote extends DailyQuoteNotifier {
  @override
  Future<QuoteResult> build() async => const QuoteResult(
        quote: Quote(text: 'Stub quote', author: 'Stub author'),
        source: QuoteSource.fresh,
      );
}

void main() {
  late _FakeRepository repository;
  late DateTime now;
  late StreamController<void> ticks;

  Session session({
    required int day,
    int hour = 9,
    String note = '',
    FocusLength plannedLength = FocusLength.medium,
    Duration actual = const Duration(minutes: 25),
  }) {
    final start = DateTime(2026, 11, day, hour);
    return Session(
      plannedLength: plannedLength,
      startTime: start,
      endTime: start.add(actual),
      note: note,
    );
  }

  setUp(() async {
    now = DateTime.utc(2026, 11, 6, 10);
    ticks = StreamController<void>.broadcast(sync: true);
    SharedPreferences.setMockInitialValues({});
    repository = _FakeRepository(await SharedPreferences.getInstance());
  });

  tearDown(() => ticks.close());

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          tickerProvider.overrideWithValue(() => ticks.stream),
          sessionRepositoryProvider.overrideWithValue(repository),
          dailyQuoteProvider.overrideWith(_StubDailyQuote.new),
        ],
        child: MaterialApp(home: home),
      ),
    );
  }

  Future<void> pumpHistory(WidgetTester tester) async {
    await pumpApp(tester, const HistoryScreen());
    await tester.pumpAndSettle();
  }

  Future<void> swipeAway(WidgetTester tester, String text) async {
    await tester.drag(find.text(text), const Offset(-600, 0));
    await tester.pumpAndSettle();
  }

  group('states', () {
    testWidgets('shows a spinner while loading', (tester) async {
      repository.loadGate = Completer<void>();

      await pumpApp(tester, const HistoryScreen());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows a message when loading fails', (tester) async {
      repository.failLoad = true;

      await pumpHistory(tester);

      expect(find.text('Could not load sessions.'), findsOneWidget);
    });

    testWidgets('shows a message when there are no sessions', (tester) async {
      await pumpHistory(tester);

      expect(find.text('No sessions yet.'), findsOneWidget);
    });
  });

  group('rows', () {
    testWidgets('show the date, durations and note', (tester) async {
      await repository.addSession(
        session(
          day: 6,
          note: 'Wrote the intro',
          plannedLength: FocusLength.long,
          actual: const Duration(minutes: 12, seconds: 30),
        ),
      );

      await pumpHistory(tester);

      expect(find.text('Nov 6, 2026'), findsOneWidget);
      expect(
          find.text('Planned 45 min · Actual 12 min 30 sec'), findsOneWidget);
      expect(find.text('Wrote the intro'), findsOneWidget);
    });

    testWidgets('format whole-minute and under-a-minute durations',
        (tester) async {
      await repository.addSession(session(day: 6));
      await repository.addSession(
        session(day: 5, actual: const Duration(seconds: 40)),
      );

      await pumpHistory(tester);

      expect(find.text('Planned 25 min · Actual 25 min'), findsOneWidget);
      expect(find.text('Planned 25 min · Actual 40 sec'), findsOneWidget);
    });

    testWidgets('are ordered newest first', (tester) async {
      await repository.addSession(session(day: 4));
      await repository.addSession(session(day: 6));
      await repository.addSession(session(day: 5));

      await pumpHistory(tester);

      final tops = ['Nov 6, 2026', 'Nov 5, 2026', 'Nov 4, 2026']
          .map((date) => tester.getTopLeft(find.text(date)).dy)
          .toList();
      expect(tops, orderedEquals([...tops]..sort()));
    });

    // Times are built in local time. These can only catch a missing toLocal()
    // when the machine running them is not on UTC: a positive offset (such as
    // IST) is caught by the first test and a negative one by the second.
    testWidgets('a session just after local midnight shows that day',
        (tester) async {
      await repository.addSession(
        Session(
          plannedLength: FocusLength.short,
          startTime: DateTime(2026, 11, 6, 0, 0, 30),
          endTime: DateTime(2026, 11, 6, 0, 15, 30),
        ),
      );

      await pumpHistory(tester);

      expect(find.text('Nov 6, 2026'), findsOneWidget);
    });

    testWidgets('a session just before local midnight shows that day',
        (tester) async {
      await repository.addSession(
        Session(
          plannedLength: FocusLength.short,
          startTime: DateTime(2026, 11, 5, 23, 59, 30),
          endTime: DateTime(2026, 11, 6, 0, 14, 30),
        ),
      );

      await pumpHistory(tester);

      expect(find.text('Nov 5, 2026'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('swiping removes the row and the stored session',
        (tester) async {
      final kept = session(day: 5);
      await repository.addSession(kept);
      await repository.addSession(session(day: 6));
      await pumpHistory(tester);

      await swipeAway(tester, 'Nov 6, 2026');

      expect(find.text('Nov 6, 2026'), findsNothing);
      expect(find.text('Nov 5, 2026'), findsOneWidget);
      expect(await repository.loadSessions(), [kept]);
    });

    testWidgets('deleting the last row shows the empty state', (tester) async {
      await repository.addSession(session(day: 6));
      await pumpHistory(tester);

      await swipeAway(tester, 'Nov 6, 2026');

      expect(find.text('No sessions yet.'), findsOneWidget);
    });

    testWidgets('a failed delete restores the row and shows a SnackBar',
        (tester) async {
      await repository.addSession(session(day: 4));
      await repository.addSession(session(day: 5));
      await repository.addSession(session(day: 6));
      await pumpHistory(tester);
      repository.failDelete = true;

      await swipeAway(tester, 'Nov 5, 2026');

      expect(tester.takeException(), isA<Exception>());
      expect(find.text('Could not delete the session.'), findsOneWidget);
      final tops = ['Nov 6, 2026', 'Nov 5, 2026', 'Nov 4, 2026']
          .map((date) => tester.getTopLeft(find.text(date)).dy)
          .toList();
      expect(tops, orderedEquals([...tops]..sort()));
      expect(await repository.loadSessions(), hasLength(3));
    });
  });

  group('with the home screen', () {
    Future<void> openHistory(WidgetTester tester) async {
      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();
    }

    Future<void> goBack(WidgetTester tester) async {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    testWidgets('saving a note refreshes a history that was already loaded',
        (tester) async {
      await pumpApp(tester, const HomeScreen());
      await openHistory(tester);
      expect(find.text('No sessions yet.'), findsOneWidget);
      await goBack(tester);

      await tester.tap(find.text('25 min'));
      await tester.pump();
      await tester.tap(find.text('End Session'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Fresh note');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await openHistory(tester);

      expect(find.text('No sessions yet.'), findsNothing);
      expect(find.text('Fresh note'), findsOneWidget);
    });

    testWidgets(
        'a session finishing during History shows the note step on Home',
        (tester) async {
      await pumpApp(tester, const HomeScreen());
      await tester.tap(find.text('25 min'));
      await tester.pump();
      await openHistory(tester);

      now = now.add(const Duration(minutes: 25));
      ticks.add(null);
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await goBack(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
