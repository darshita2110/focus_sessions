import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_sessions/models/session.dart';

void main() {
  final start = DateTime.utc(2026, 11, 6, 9);
  final end = DateTime.utc(2026, 11, 6, 9, 25);

  Map<String, dynamic> validJson() => {
        'plannedMinutes': 25,
        'startTime': '2026-11-06T09:00:00.000Z',
        'endTime': '2026-11-06T09:25:00.000Z',
        'note': 'Wrote tests',
      };

  group('FocusLength', () {
    test('has the three supported lengths', () {
      expect(FocusLength.short.duration, const Duration(minutes: 15));
      expect(FocusLength.medium.duration, const Duration(minutes: 25));
      expect(FocusLength.long.duration, const Duration(minutes: 45));
    });

    test('fromMinutes finds a supported length', () {
      expect(FocusLength.fromMinutes(45), FocusLength.long);
    });

    test('fromMinutes returns null for an unsupported length', () {
      expect(FocusLength.fromMinutes(30), isNull);
    });
  });

  group('Session constructor', () {
    test('converts local times to UTC', () {
      final session = Session(
        plannedLength: FocusLength.medium,
        startTime: start.toLocal(),
        endTime: end.toLocal(),
      );

      expect(session.startTime.isUtc, isTrue);
      expect(session.endTime.isUtc, isTrue);
      expect(session.startTime, start);
    });

    test('defaults note to an empty string', () {
      final session = Session(
        plannedLength: FocusLength.medium,
        startTime: start,
        endTime: end,
      );

      expect(session.note, '');
    });

    test('allows endTime equal to startTime', () {
      final session = Session(
        plannedLength: FocusLength.short,
        startTime: start,
        endTime: start,
      );

      expect(session.actualDuration, Duration.zero);
    });

    test('throws ArgumentError when endTime is before startTime', () {
      expect(
        () => Session(
          plannedLength: FocusLength.short,
          startTime: start,
          endTime: start.subtract(const Duration(seconds: 1)),
        ),
        throwsArgumentError,
      );
    });
  });

  group('actualDuration', () {
    test('equals the planned length for a completed session', () {
      final session = Session(
        plannedLength: FocusLength.medium,
        startTime: start,
        endTime: start.add(FocusLength.medium.duration),
      );

      expect(session.actualDuration, const Duration(minutes: 25));
    });

    test('is shorter than planned when stopped early', () {
      final session = Session(
        plannedLength: FocusLength.long,
        startTime: start,
        endTime: start.add(const Duration(minutes: 12, seconds: 30)),
      );

      expect(
        session.actualDuration,
        const Duration(minutes: 12, seconds: 30),
      );
    });
  });

  group('toJson', () {
    test('writes minutes and UTC ISO-8601 strings', () {
      final session = Session(
        plannedLength: FocusLength.medium,
        startTime: start,
        endTime: end,
        note: 'Wrote tests',
      );

      expect(session.toJson(), validJson());
    });

    test('round-trips through a JSON string', () {
      final original = Session(
        plannedLength: FocusLength.long,
        startTime: start.toLocal(),
        endTime: start.add(const Duration(minutes: 40)).toLocal(),
        note: 'Stopped early',
      );

      final encoded = jsonEncode(original.toJson());
      final decoded =
          Session.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded, original);
    });
  });

  group('fromJson', () {
    test('reads valid JSON', () {
      final session = Session.fromJson(validJson());

      expect(session.plannedLength, FocusLength.medium);
      expect(session.startTime, start);
      expect(session.endTime, end);
      expect(session.note, 'Wrote tests');
    });

    test('accepts an explicit UTC offset', () {
      final json = validJson()..['startTime'] = '2026-11-06T14:30:00.000+05:30';

      expect(Session.fromJson(json).startTime, start);
    });

    test('treats a missing note as empty', () {
      final json = validJson()..remove('note');

      expect(Session.fromJson(json).note, '');
    });

    test('treats a null note as empty', () {
      final json = validJson()..['note'] = null;

      expect(Session.fromJson(json).note, '');
    });

    test('throws FormatException for unsupported plannedMinutes', () {
      final json = validJson()..['plannedMinutes'] = 30;

      expect(() => Session.fromJson(json), throwsFormatException);
    });

    test('throws FormatException when endTime is before startTime', () {
      final json = validJson()..['endTime'] = '2026-11-06T08:59:59.000Z';

      expect(() => Session.fromJson(json), throwsFormatException);
    });

    test('throws FormatException for a non-int plannedMinutes', () {
      final json = validJson()..['plannedMinutes'] = '25';

      expect(() => Session.fromJson(json), throwsFormatException);
    });

    test('throws FormatException for missing fields', () {
      for (final key in ['plannedMinutes', 'startTime', 'endTime']) {
        final json = validJson()..remove(key);

        expect(
          () => Session.fromJson(json),
          throwsFormatException,
          reason: 'missing $key',
        );
      }
    });

    test('throws FormatException for a non-string time', () {
      final json = validJson()..['startTime'] = start.millisecondsSinceEpoch;

      expect(() => Session.fromJson(json), throwsFormatException);
    });

    test('throws FormatException for an unparseable time', () {
      final json = validJson()..['endTime'] = 'not a date';

      expect(() => Session.fromJson(json), throwsFormatException);
    });

    test('throws FormatException for a non-string note', () {
      final json = validJson()..['note'] = 42;

      expect(() => Session.fromJson(json), throwsFormatException);
    });
  });

  group('equality', () {
    test('sessions with the same values are equal', () {
      final a = Session.fromJson(validJson());
      final b = Session.fromJson(validJson());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('the same instant in local and UTC is equal', () {
      final utc = Session(
        plannedLength: FocusLength.medium,
        startTime: start,
        endTime: end,
      );
      final local = Session(
        plannedLength: FocusLength.medium,
        startTime: start.toLocal(),
        endTime: end.toLocal(),
      );

      expect(local, utc);
    });

    test('sessions with different notes are not equal', () {
      final a = Session.fromJson(validJson());
      final b = Session.fromJson(validJson()..['note'] = 'Other');

      expect(a, isNot(b));
    });
  });
}
