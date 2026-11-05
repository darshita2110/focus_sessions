/// The lengths a focus block can be planned for.
enum FocusLength {
  short(15),
  medium(25),
  long(45);

  const FocusLength(this.minutes);

  final int minutes;

  Duration get duration => Duration(minutes: minutes);

  /// Returns the length with exactly [minutes], or `null` if none matches.
  static FocusLength? fromMinutes(int minutes) {
    for (final length in values) {
      if (length.minutes == minutes) return length;
    }
    return null;
  }
}

/// A finished focus session.
///
/// [startTime] and [endTime] are always stored in UTC. Callers must call
/// `toLocal()` before displaying dates or grouping sessions by day, otherwise
/// sessions near midnight land on the wrong day.
///
/// Sessions are identified by [startTime]: only one session can run at a
/// time, so no two sessions share a start time.
class Session {
  /// Creates a session. Times are converted to UTC.
  ///
  /// Throws [ArgumentError] if [endTime] is before [startTime].
  Session({
    required this.plannedLength,
    required DateTime startTime,
    required DateTime endTime,
    this.note = '',
  })  : startTime = startTime.toUtc(),
        endTime = endTime.toUtc() {
    if (this.endTime.isBefore(this.startTime)) {
      throw ArgumentError.value(
        endTime,
        'endTime',
        'must not be before startTime',
      );
    }
  }

  /// Reads a session from JSON produced by [toJson].
  ///
  /// Throws [FormatException] if any field is missing, has the wrong type,
  /// or holds an invalid value. A missing or `null` note becomes `''`.
  factory Session.fromJson(Map<String, dynamic> json) {
    final minutes = json['plannedMinutes'];
    if (minutes is! int) {
      throw FormatException('plannedMinutes must be an int', minutes);
    }
    final plannedLength = FocusLength.fromMinutes(minutes);
    if (plannedLength == null) {
      throw FormatException('Unsupported plannedMinutes', minutes);
    }

    final startTime = _parseTime(json, 'startTime');
    final endTime = _parseTime(json, 'endTime');
    if (endTime.isBefore(startTime)) {
      throw const FormatException('endTime must not be before startTime');
    }

    final note = json['note'] ?? '';
    if (note is! String) {
      throw FormatException('note must be a String', note);
    }

    return Session(
      plannedLength: plannedLength,
      startTime: startTime,
      endTime: endTime,
      note: note,
    );
  }

  final FocusLength plannedLength;

  /// When the session started, in UTC.
  final DateTime startTime;

  /// When the session ended (completed or stopped early), in UTC.
  final DateTime endTime;

  final String note;

  /// Derived from the timestamps so it can never disagree with them.
  Duration get actualDuration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
        'plannedMinutes': plannedLength.minutes,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'note': note,
      };

  /// Parses the ISO-8601 timestamp stored under [key].
  ///
  /// Throws [FormatException] if the value is not a String or not a valid
  /// date.
  static DateTime _parseTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('$key must be a String', value);
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$key is not a valid date', value);
    }
    return parsed;
  }

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.plannedLength == plannedLength &&
      other.startTime == startTime &&
      other.endTime == endTime &&
      other.note == note;

  @override
  int get hashCode => Object.hash(plannedLength, startTime, endTime, note);

  @override
  String toString() => 'Session(plannedLength: $plannedLength, '
      'startTime: $startTime, endTime: $endTime, note: $note)';
}
