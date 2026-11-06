import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/data/quote_repository.dart';
import 'package:focus_sessions/data/session_repository.dart';
import 'package:focus_sessions/models/quote.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:focus_sessions/providers/core_providers.dart';
import 'package:focus_sessions/providers/daily_quote_provider.dart';
import 'package:focus_sessions/screens/home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real repository on mock storage whose saves can be made to fail.
class _FailableSessionRepository extends SessionRepository {
  _FailableSessionRepository(super.prefs);

  bool fail = false;

  @override
  Future<void> addSession(Session session) {
    if (fail) return Future.error(Exception('Save failed'));
    return super.addSession(session);
  }
}

/// Keeps timer tests away from quote fetching, unless a test passes a client.
class _StubDailyQuote extends DailyQuoteNotifier {
  @override
  Future<QuoteResult> build() async => const QuoteResult(
        quote: Quote(text: 'Stub quote', author: 'Stub author'),
        source: QuoteSource.fresh,
      );
}

void main() {
  final start = DateTime.utc(2026, 11, 6, 10);

  late DateTime now;
  late StreamController<void> ticks;
  late SharedPreferences prefs;
  late _FailableSessionRepository repository;

  setUp(() async {
    now = start;
    ticks = StreamController<void>.broadcast(sync: true);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _FailableSessionRepository(prefs);
  });

  tearDown(() => ticks.close());

  Future<void> pumpHome(WidgetTester tester, {http.Client? quoteClient}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          tickerProvider.overrideWithValue(() => ticks.stream),
          sessionRepositoryProvider.overrideWithValue(repository),
          if (quoteClient == null)
            dailyQuoteProvider.overrideWith(_StubDailyQuote.new)
          else ...[
            httpClientProvider.overrideWithValue(quoteClient),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
  }

  Future<void> tick(WidgetTester tester) async {
    ticks.add(null);
    await tester.pump();
  }

  Future<void> startAndEnd(WidgetTester tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('25 min'));
    await tester.pump();
    await tester.tap(find.text('End Session'));
    await tester.pump();
  }

  group('idle', () {
    testWidgets('shows a button for each focus length', (tester) async {
      await pumpHome(tester);

      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
    });
  });

  group('running', () {
    testWidgets('starts at the full length', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('25 min'));
      await tester.pump();

      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('End Session'), findsOneWidget);
      expect(find.text('15 min'), findsNothing);
    });

    testWidgets('rounds remaining seconds up as the clock advances',
        (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('25 min'));
      await tester.pump();

      now = start.add(const Duration(minutes: 10, milliseconds: 500));
      await tick(tester);
      expect(find.text('15:00'), findsOneWidget);

      now = start.add(const Duration(minutes: 24, seconds: 59, milliseconds: 1));
      await tick(tester);
      expect(find.text('00:01'), findsOneWidget);
    });

    testWidgets('shows the note step when the session finishes',
        (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('25 min'));
      await tester.pump();

      now = start.add(const Duration(minutes: 25));
      await tick(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('ended', () {
    testWidgets('End Session shows the note step', (tester) async {
      await startAndEnd(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('End Session'), findsNothing);
    });

    testWidgets('saves the note and returns to idle', (tester) async {
      await startAndEnd(tester);

      await tester.enterText(find.byType(TextField), 'Wrote the intro');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('25 min'), findsOneWidget);
      final sessions = await repository.loadSessions();
      expect(sessions.single.note, 'Wrote the intro');
    });

    testWidgets('saves an empty note as an empty string', (tester) async {
      await startAndEnd(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('25 min'), findsOneWidget);
      final sessions = await repository.loadSessions();
      expect(sessions.single.note, '');
    });

    testWidgets('a failed save shows a SnackBar and keeps the note',
        (tester) async {
      await startAndEnd(tester);
      repository.fail = true;

      await tester.enterText(find.byType(TextField), 'Keep me');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(
        find.text('Could not save the session. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Keep me'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      repository.fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('25 min'), findsOneWidget);
      final sessions = await repository.loadSessions();
      expect(sessions.single.note, 'Keep me');
    });
  });

  group('daily quote', () {
    const credit = 'Quotes from ZenQuotes';
    const cachedNote =
        'Could not fetch a new quote. Showing the last saved one.';
    const fallbackNote = 'Could not fetch a quote. Showing a built-in one.';
    const body = '[{"q":"Fetched quote","a":"Fetched author"}]';

    http.Client okClient() =>
        MockClient((_) async => http.Response(body, 200));
    http.Client failingClient() =>
        MockClient((_) async => http.Response('', 500));

    testWidgets('shows a spinner until the quote arrives', (tester) async {
      final response = Completer<http.Response>();

      await pumpHome(
        tester,
        quoteClient: MockClient((_) => response.future),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Fetched quote'), findsNothing);

      response.complete(http.Response(body, 200));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Fetched quote'), findsOneWidget);
    });

    testWidgets('shows a fetched quote and credit with no note',
        (tester) async {
      await pumpHome(tester, quoteClient: okClient());
      await tester.pumpAndSettle();

      expect(find.text('Fetched quote'), findsOneWidget);
      expect(find.text('— Fetched author'), findsOneWidget);
      expect(find.text(credit), findsOneWidget);
      expect(find.text(cachedNote), findsNothing);
      expect(find.text(fallbackNote), findsNothing);
    });

    testWidgets('shows the cached quote with a note when the fetch fails',
        (tester) async {
      await QuoteRepository(okClient(), prefs).fetchDailyQuote();

      await pumpHome(tester, quoteClient: failingClient());
      await tester.pumpAndSettle();

      expect(find.text('Fetched quote'), findsOneWidget);
      expect(find.text(cachedNote), findsOneWidget);
      expect(find.text(credit), findsOneWidget);
    });

    testWidgets('shows the built-in quote with a note when nothing is cached',
        (tester) async {
      await pumpHome(tester, quoteClient: failingClient());
      await tester.pumpAndSettle();

      expect(find.text(QuoteRepository.fallbackQuote.text), findsOneWidget);
      expect(find.text(fallbackNote), findsOneWidget);
    });

    testWidgets('a request that never answers stops after the default timeout',
        (tester) async {
      await pumpHome(
        tester,
        quoteClient: MockClient((_) => Completer<http.Response>().future),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(fallbackNote), findsOneWidget);
    });

    testWidgets('stays visible while running without fetching again',
        (tester) async {
      var requests = 0;
      await pumpHome(
        tester,
        quoteClient: MockClient((_) async {
          requests++;
          return http.Response(body, 200);
        }),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('25 min'));
      await tester.pump();

      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('Fetched quote'), findsOneWidget);
      expect(find.text(credit), findsOneWidget);
      expect(requests, 1);
    });

    testWidgets('is hidden on the note form', (tester) async {
      await pumpHome(tester, quoteClient: okClient());
      await tester.pumpAndSettle();
      await tester.tap(find.text('25 min'));
      await tester.pump();

      await tester.tap(find.text('End Session'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Fetched quote'), findsNothing);
      expect(find.text(credit), findsNothing);
    });

    testWidgets('a very long quote does not overflow a small screen',
        (tester) async {
      tester.view
        ..physicalSize = const Size(320, 480)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final longQuote = 'A long quote that keeps going. ' * 40;

      await pumpHome(
        tester,
        quoteClient: MockClient(
          (_) async => http.Response(
            '[{"q":"$longQuote","a":"Author"}]',
            200,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(longQuote), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('25 min'));
      await tester.pump();

      expect(find.text('25:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
