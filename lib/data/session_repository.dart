import 'dart:convert';

import 'package:focus_sessions/models/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores finished sessions in shared_preferences.
///
/// Sessions are kept under one key as a list of strings, one JSON-encoded
/// session per entry, so a corrupted entry only loses itself. Corrupted
/// entries are skipped when reading and left untouched when writing.
///
/// Sessions are identified by their start time.
class SessionRepository {
  SessionRepository(this._prefs);

  static const _storageKey = 'sessions';

  final SharedPreferences _prefs;

  /// Returns all readable sessions, newest first by start time.
  Future<List<Session>> loadSessions() async {
    return _readEntries().map(_decode).whereType<Session>().toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Saves [session].
  ///
  /// Throws [StateError] if a session with the same start time already
  /// exists.
  Future<void> addSession(Session session) async {
    final entries = _readEntries();
    final exists = entries.map(_decode).any(
        (s) => s != null && s.startTime.isAtSameMomentAs(session.startTime));
    if (exists) {
      throw StateError(
        'A session starting at ${session.startTime} already exists',
      );
    }
    await _write([...entries, jsonEncode(session.toJson())]);
  }

  /// Deletes the session that started at [startTime], in any time zone.
  ///
  /// Does nothing if no session matches.
  Future<void> deleteSession(DateTime startTime) async {
    final entries = _readEntries();
    final remaining = entries.where((entry) {
      final session = _decode(entry);
      return session == null || !session.startTime.isAtSameMomentAs(startTime);
    }).toList();
    if (remaining.length == entries.length) return;
    await _write(remaining);
  }

  List<String> _readEntries() => _prefs.getStringList(_storageKey) ?? const [];

  Future<void> _write(List<String> entries) async {
    var saved = false;
    try {
      saved = await _prefs.setStringList(_storageKey, entries);
    } finally {
      // setStringList updates its in-memory cache before writing to disk, and
      // a failed write does not undo that. Reload so later reads match disk.
      if (!saved) await _prefs.reload();
    }
    if (!saved) {
      throw Exception('Failed to save sessions');
    }
  }

  /// Returns `null` for an entry that is not a valid session.
  static Session? _decode(String entry) {
    try {
      final json = jsonDecode(entry);
      if (json is! Map<String, dynamic>) return null;
      return Session.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}
