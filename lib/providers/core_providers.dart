import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_sessions/data/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns the current time.
typedef Clock = DateTime Function();

/// Creates a new stream that emits once per timer tick.
typedef Ticker = Stream<void> Function();

/// Must be overridden with an instance from `SharedPreferences.getInstance()`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(sharedPreferencesProvider)),
);

/// Overridden in tests to control time.
final clockProvider = Provider<Clock>((ref) => DateTime.now);

/// Overridden in tests to fire ticks by hand.
final tickerProvider = Provider<Ticker>(
  (ref) => () => Stream<void>.periodic(const Duration(seconds: 1)),
);
