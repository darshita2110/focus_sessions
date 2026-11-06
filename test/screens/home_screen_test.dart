import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/data/session_repository.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:focus_sessions/providers/core_providers.dart';
import 'package:focus_sessions/screens/home_screen.dart';
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

void main() {
  final start = DateTime.utc(2026, 11, 6, 10);

  late DateTime now;
  late StreamController<void> ticks;
  late _FailableSessionRepository repository;

  setUp(() async {
    now = start;
    ticks = StreamController<void>.broadcast(sync: true);
    SharedPreferences.setMockInitialValues({});
    repository =
        _FailableSessionRepository(await SharedPreferences.getInstance());
  });

  tearDown(() => ticks.close());

  Future<void> pumpHome(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          tickerProvider.overrideWithValue(() => ticks.stream),
          sessionRepositoryProvider.overrideWithValue(repository),
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
}
