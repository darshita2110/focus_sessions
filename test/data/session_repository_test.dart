import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/data/session_repository.dart';
import 'package:focus_sessions/models/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'sessions';

  Session sessionAt(int hour, {String note = ''}) => Session(
        plannedLength: FocusLength.medium,
        startTime: DateTime.utc(2026, 11, 6, hour),
        endTime: DateTime.utc(2026, 11, 6, hour, 25),
        note: note,
      );

  String encode(Session session) => jsonEncode(session.toJson());

  Future<SharedPreferences> prefsWith([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('loadSessions', () {
    test('returns an empty list when nothing is stored', () async {
      final repository = SessionRepository(await prefsWith());

      expect(await repository.loadSessions(), isEmpty);
    });

    test('returns sessions newest first', () async {
      final repository = SessionRepository(await prefsWith());
      await repository.addSession(sessionAt(9));
      await repository.addSession(sessionAt(11));
      await repository.addSession(sessionAt(10));

      expect(
        await repository.loadSessions(),
        [sessionAt(11), sessionAt(10), sessionAt(9)],
      );
    });

    test('skips corrupted entries', () async {
      final invalidSession = sessionAt(10).toJson()..['plannedMinutes'] = 30;
      final repository = SessionRepository(
        await prefsWith({
          key: [
            'not json',
            '[1, 2, 3]',
            jsonEncode(invalidSession),
            encode(sessionAt(9)),
          ],
        }),
      );

      expect(await repository.loadSessions(), [sessionAt(9)]);
    });
  });

  group('addSession', () {
    test('saves a session that can be loaded', () async {
      final repository = SessionRepository(await prefsWith());
      final session = sessionAt(9, note: 'Deep work');

      await repository.addSession(session);

      expect(await repository.loadSessions(), [session]);
    });

    test('stores one JSON string per session', () async {
      final prefs = await prefsWith();
      await SessionRepository(prefs).addSession(sessionAt(9));

      expect(prefs.getStringList(key), [encode(sessionAt(9))]);
    });

    test('persists across repository instances', () async {
      final prefs = await prefsWith();
      await SessionRepository(prefs).addSession(sessionAt(9));

      expect(await SessionRepository(prefs).loadSessions(), [sessionAt(9)]);
    });

    test('throws StateError for a duplicate start time', () async {
      final prefs = await prefsWith();
      final repository = SessionRepository(prefs);
      await repository.addSession(sessionAt(9));

      await expectLater(
        repository.addSession(sessionAt(9, note: 'Different note')),
        throwsStateError,
      );
      expect(prefs.getStringList(key), [encode(sessionAt(9))]);
    });

    test('keeps corrupted entries', () async {
      final prefs = await prefsWith({
        key: ['not json'],
      });

      await SessionRepository(prefs).addSession(sessionAt(9));

      expect(prefs.getStringList(key), ['not json', encode(sessionAt(9))]);
    });
  });

  group('deleteSession', () {
    test('removes only the matching session', () async {
      final repository = SessionRepository(await prefsWith());
      await repository.addSession(sessionAt(9));
      await repository.addSession(sessionAt(10));

      await repository.deleteSession(sessionAt(9).startTime);

      expect(await repository.loadSessions(), [sessionAt(10)]);
    });

    test('matches a start time given in local time', () async {
      final repository = SessionRepository(await prefsWith());
      await repository.addSession(sessionAt(9));

      await repository.deleteSession(sessionAt(9).startTime.toLocal());

      expect(await repository.loadSessions(), isEmpty);
    });

    test('does nothing when no session matches', () async {
      final repository = SessionRepository(await prefsWith());
      await repository.addSession(sessionAt(9));

      await repository.deleteSession(DateTime.utc(2026, 11, 6, 12));

      expect(await repository.loadSessions(), [sessionAt(9)]);
    });

    test('keeps corrupted entries', () async {
      final prefs = await prefsWith({
        key: ['not json', encode(sessionAt(9))],
      });

      await SessionRepository(prefs).deleteSession(sessionAt(9).startTime);

      expect(prefs.getStringList(key), ['not json']);
    });
  });
}
